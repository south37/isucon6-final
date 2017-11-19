require 'json'
require 'time'

require 'mysql2'
require 'sinatra/base'

require 'redis'

Redis.current = Redis.new(host: ENV['REDIS_HOST'])

module Isuketch
  class Web < ::Sinatra::Base
    JSON.load_default_options[:symbolize_names] = true

    set :protection, except: [:json_csrf]

    configure :development do
      require 'sinatra/reloader'
      register Sinatra::Reloader
    end

    helpers do
      def get_dbh
        host = ENV['MYSQL_HOST'] || 'localhost'
        port = ENV['MYSQL_PORT'] || '3306'
        user = ENV['MYSQL_USER'] || 'root'
        pass = ENV['MYSQL_PASS'] || ''
        name = 'isuketch'
        mysql = Mysql2::Client.new(
          username: user,
          password: pass,
          database: name,
          host: host,
          port: port,
          encoding: 'utf8mb4',
          init_command: %|
            SET TIME_ZONE = 'UTC'
          |,
        )
        mysql.query_options.update(symbolize_keys: true)
        mysql
      end

      def redis
        @redis ||= Redis.current
      end

      def select_one(dbh, sql, binds)
        select_all(dbh, sql, binds).first
      end

      def select_all(dbh, sql, binds)
        stmt = dbh.prepare(sql)
        result = stmt.execute(*binds)
        result.to_a
      ensure
        stmt.close
      end

      def get_room(dbh, room_id)
        select_one(dbh, %|
          SELECT `id`, `name`, `canvas_width`, `canvas_height`, `created_at`
          FROM `rooms`
          WHERE `id` = ?
        |, [room_id])
      end

      def get_strokes(dbh, room_id, greater_than_id)
        select_all(dbh, %|
          SELECT `id`, `room_id`, `width`, `red`, `green`, `blue`, `alpha`, `created_at`
          FROM `strokes`
          WHERE `room_id` = ?
            AND `id` > ?
          ORDER BY `id` ASC;
        |, [room_id, greater_than_id])
      end

      def to_room_json(room)
        {
          id: room[:id].to_i,
          name: room[:name],
          canvas_width: room[:canvas_width].to_i,
          canvas_height: room[:canvas_height].to_i,
          created_at: (room[:created_at] ? to_rfc_3339(room[:created_at]) : ''),
          strokes: (room[:strokes] ? room[:strokes].map {|stroke| to_stroke_json(stroke) } : []),
          stroke_count: room[:stroke_count] || 0,
          watcher_count: room[:watcher_count] || 0,
        }
      end

      def to_rfc_3339(dt)
        dt.strftime('%Y-%m-%dT%H:%M:%S.%6N%:z').
          sub(/\+00:00/, 'Z') # RFC3339では+00:00のときはZにするという仕様
      end

      def to_stroke_json(stroke)
        {
          id: stroke[:id].to_i,
          room_id: stroke[:room_id].to_i,
          width: stroke[:width].to_i,
          red: stroke[:red].to_i,
          green: stroke[:green].to_i,
          blue: stroke[:blue].to_i,
          alpha: stroke[:alpha].to_f,
          points: (stroke[:points] ? stroke[:points].map {|point| to_point_json(point) } : []),
          created_at: (stroke[:created_at] ? to_rfc_3339(stroke[:created_at]) : ''),
        }
      end

      def to_point_json(point)
        {
          id: point[:id].to_i,
          stroke_id: point[:stroke_id].to_i,
          x: point[:x].to_f,
          y: point[:y].to_f,
        }
      end

      def check_token(dbh, csrf_token)
        select_one(dbh, %|
          SELECT `id`, `csrf_token`, `created_at` FROM `tokens`
          WHERE `csrf_token` = ?
            AND `created_at` > CURRENT_TIMESTAMP(6) - INTERVAL 1 DAY
        |, [csrf_token])
      end

      def initialize_points(dbh)
        s = Time.now

        orgs = nil
        begin
          # 2sくらい
          stroke_hash_data = File.read("initial_points_hash.json")
          orgs = JSON.parse(stroke_hash_data)
        rescue

          # 6.877798s
          points = dbh.prepare('SELECT * FROM points order by id').execute

          puts "finished get points: #{Time.now - s}"

          # 3.837764s
          stroke_hash = {}
          points.each do |point|
            stroke_hash[point[:stroke_id]] ||= []
            stroke_hash[point[:stroke_id]] << {id: point[:id], x: point[:x], y: point[:y]}
          end

          puts "finished create hash: #{Time.now - s}"

          # 9sくらい
          orgs = []
          stroke_hash.each do |stroke_id, arr|
            orgs << ["points:#{stroke_id}", arr.to_json]
          end
          puts "finished create orgs: #{Time.now - s}"

          File.write("initial_points_hash.json", orgs.to_json)
        end

        # 2s
        redis.mset *orgs.flatten

        # 42s(local) 150万件
        # redis.pipelined do
        #   points.each do |point|
        #     redis.zadd "points:#{point[:stroke_id]}", point[:id], "#{point[:x]},#{point[:y]}"
        #   end
        # end

        last_point = dbh.prepare('SELECT * FROM points order by id DESC limit 1').execute.first
        redis.set "points_key", last_point[:id]

        puts "finished initialize_points: #{Time.now - s}"
      end

      def get_points(stroke_ids)
        orgs = stroke_ids.map{|stroke_id| "points:#{stroke_id}" }
        datas = redis.mget *orgs
        datas.each_with_index.map do |data, index|
          points = JSON.parse(data, symbolize_names: true)
          points.map{|point| point[:stroke_id] = stroke_ids[index];point}
        end
      end

      def get_stroke_points(dbh, stroke_id)
        points = JSON.parse(redis.get("points:#{stroke_id}"), symbolize_names: true)
        points.map{|point| point[:stroke_id] = stroke_id;point}
      end

      def set_points(stroke_id, points)
        points_key = redis.incrby "points_key", points.size
        start_points_key = points_key.to_i - points.size
        points = points.map do |point|
          start_points_key += 1
          point[:id] = start_points_key
        end
        redis.set "points:#{stroke_id}", points.to_json
        points
      end

      def get_watcher_count(dbh, room_id)
        select_one(dbh, %|
          SELECT COUNT(*) AS `watcher_count`
          FROM `room_watchers`
          WHERE `room_id` = ?
            AND `updated_at` > CURRENT_TIMESTAMP(6) - INTERVAL 3 SECOND
        |, [room_id])[:watcher_count].to_i
      end

      def update_room_watcher(dbh, room_id, csrf_token)
        stmt = dbh.prepare(%|
          INSERT INTO `room_watchers` (`room_id`, `token_id`)
          VALUES (?, ?)
          ON DUPLICATE KEY UPDATE `updated_at` = CURRENT_TIMESTAMP(6)
        |)
        stmt.execute(room_id, csrf_token)
      ensure
        stmt.close
      end
    end

    get '/initialize' do
      redis.flushall

      dbh = get_dbh

      dbh.prepare('DELETE FROM rooms WHERE id > 1000').execute
      dbh.prepare('DELETE FROM strokes WHERE id > 41000').execute
      dbh.prepare('DELETE FROM room_owners WHERE room_id > 1000').execute
      dbh.prepare('DELETE FROM points WHERE id > 1443000').execute
      dbh.prepare('DELETE FROM room_watchers WHERE room_id > 1000').execute
      dbh.prepare('DELETE FROM room_watchers WHERE room_id > 1000').execute
      dbh.prepare('DELETE FROM tokens WHERE id > 50000').execute

      initialize_points(dbh)
    end

    post '/api/csrf_token' do
      dbh = get_dbh
      dbh.query(%|
        INSERT INTO `tokens` (`csrf_token`)
        VALUES
        (SHA2(CONCAT(RAND(), UUID_SHORT()), 256))
      |)

      id = dbh.last_id
      token = select_one(dbh, %|
        SELECT `id`, `csrf_token`, `created_at`
        FROM `tokens`
        WHERE `id` = ?
      |, [id])

      content_type :json
      JSON.generate(
        token: token[:csrf_token],
      )
    end

    get '/img/:id' do |id|
      dbh = get_dbh()
      room = get_room(dbh, id)
      unless room
        halt(404, {'Content-Type' => 'application/json'}, JSON.generate(
          error: 'この部屋は存在しません。'
        ))
      end

      strokes = get_strokes(dbh, room[:id], 0)
      points_arr = get_points(strokes.map{|stroke| stroke[:id]})
      strokes.each_with_index do |stroke, index|
        stroke[:points] = points_arr[index]
      end
      room[:strokes] = strokes

      key = "#{room[:id]}:#{strokes.size}"

      body = '<?xml version="1.0" standalone="no"?>' +
        '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">'

      body += <<EOS
<svg xmlns="http://www.w3.org/2000/svg" version="1.1" baseProfile="full" width="#{room[:canvas_width]}" height="#{room[:canvas_height]}" style="width:#{room[:canvas_width]}px;height:#{room[:canvas_height]}px;background-color:white;" viewBox="0 0 #{room[:canvas_width]} #{room[:canvas_height]}">
EOS
      strokes.each do |stroke|
        points = get_stroke_points(dbh, stroke[:id])
        points_str = points.map do |point|
          x = (point[:x] == point[:x].to_i) ? point[:x].to_i : sprintf("%.4f", point[:x])
          y = (point[:y] == point[:y].to_i) ? point[:y].to_i : sprintf("%.4f", point[:y])
          "#{x},#{y}"
        end.join(" ")
        body += <<EOS
<polyline id="#{stroke[:id]}" stroke="rgba(#{stroke[:red]},#{stroke[:green]},#{stroke[:blue]},#{sprintf("%.1f", stroke[:alpha])})" stroke-width="#{stroke[:width]}" stroke-linecap="round" stroke-linejoin="round" fill="none" points="#{points_str}"></polyline>
EOS
      end
      body = body.gsub("\n", "")
      body += "</svg>"

      content_type 'image/svg+xml; charset=utf-8'
      etag key, kind: :weak
      body
    end

    get '/api/rooms' do
      dbh = get_dbh
      results = select_all(dbh, %|
        SELECT `room_id`, MAX(`id`) AS `max_id`
        FROM `strokes`
        GROUP BY `room_id`
        ORDER BY `max_id` DESC
        LIMIT 100
      |, [])

      rooms = results.map {|res|
        room = get_room(dbh, res[:room_id])
        room[:stroke_count] = get_strokes(dbh, room[:id], 0).size
        room
      }

      content_type :json
      JSON.generate(
        rooms: rooms.map {|room| to_room_json(room) },
      )
    end

    post '/api/rooms' do
      dbh = get_dbh
      token = check_token(dbh, request.env['HTTP_X_CSRF_TOKEN'])
      unless token
        halt(400, {'Content-Type' => 'application/json'}, JSON.generate(
          error: 'トークンエラー。ページを再読み込みしてください。'
        ))
      end

      posted_room = JSON.load(request.body)
      if (posted_room[:name] || '').empty? || !posted_room[:canvas_width] || !posted_room[:canvas_height]
        halt(400, {'Content-Type' => 'application/json'}, JSON.generate(
          error: 'リクエストが正しくありません。'
        ))
      end

      room_id = nil
      begin
        dbh.query(%|BEGIN|)

        stmt = dbh.prepare(%|
          INSERT INTO `rooms`
          (`name`, `canvas_width`, `canvas_height`)
          VALUES
          (?, ?, ?)
        |)
        stmt.execute(posted_room[:name], posted_room[:canvas_width], posted_room[:canvas_height])
        room_id = dbh.last_id
        stmt.close

        stmt = dbh.prepare(%|
          INSERT INTO `room_owners`
          (`room_id`, `token_id`)
          VALUES
          (?, ?)
        |)
        stmt.execute(room_id, token[:id])
      rescue
        dbh.query(%|ROLLBACK|)
        halt(500, {'Content-Type' => 'application/json'}, JSON.generate(
          error: 'エラーが発生しました。'
        ))
      else
        dbh.query(%|COMMIT|)
      ensure
        stmt.close
      end

      room = get_room(dbh, room_id)
      content_type :json
      JSON.generate(
        room: to_room_json(room)
      )
    end

    get '/api/rooms/:id' do |id|
      dbh = get_dbh()
      room = get_room(dbh, id)
      unless room
        halt(404, {'Content-Type' => 'application/json'}, JSON.generate(
          error: 'この部屋は存在しません。'
        ))
      end

      strokes = get_strokes(dbh, room[:id], 0)
      strokes.each do |stroke|
        stroke[:points] = get_stroke_points(dbh, stroke[:id])
      end
      room[:strokes] = strokes
      room[:watcher_count] = get_watcher_count(dbh, room[:id])

      dbh.close
      content_type :json
      JSON.generate(
        room: to_room_json(room)
      )

    end

    post '/api/strokes/rooms/:id' do |id|
      dbh = get_dbh()
      token = check_token(dbh, request.env['HTTP_X_CSRF_TOKEN'])
      unless token
        halt(400, {'Content-Type' => 'application/json'}, JSON.generate(
          error: 'トークンエラー。ページを再読み込みしてください。'
        ))
      end

      room = get_room(dbh, id)
      unless room
        halt(404, {'Content-Type' => 'application/json'}, JSON.generate(
          error: 'この部屋は存在しません。'
        ))
      end

      posted_stroke = JSON.load(request.body)
      if !posted_stroke[:width] || !posted_stroke[:points]
        halt(400, {'Content-Type' => 'application/json'}, JSON.generate(
          error: 'リクエストが正しくありません。'
        ))
      end

      stroke_count = get_strokes(dbh, room[:id], 0).count
      if stroke_count == 0
        count = select_one(dbh, %|
          SELECT COUNT(*) as cnt FROM `room_owners`
          WHERE `room_id` = ?
            AND `token_id` = ?
        |, [room[:id], token[:id]])[:cnt].to_i
        if count == 0
          halt(400, {'Content-Type' => 'application/json'}, JSON.generate(
            error: '他人の作成した部屋に1画目を描くことはできません'
          ))
        end
      end

      stroke_id = nil
      begin
        dbh.query(%| BEGIN |)

        stmt = dbh.prepare(%|
          INSERT INTO `strokes`
          (`room_id`, `width`, `red`, `green`, `blue`, `alpha`)
          VALUES
          (?, ?, ?, ?, ?, ?)
        |)
        stmt.execute(room[:id], posted_stroke[:width], posted_stroke[:red], posted_stroke[:green], posted_stroke[:blue], posted_stroke[:alpha])
        stroke_id = dbh.last_id
        stmt.close

        set_stroke_points(stroke_id, posted_stroke)
        posted_stroke[:points].each do |point|
          stmt = dbh.prepare(%|
            INSERT INTO `points`
            (`stroke_id`, `x`, `y`)
            VALUES
            (?, ?, ?)
          |)
          stmt.execute(stroke_id, point[:x], point[:y])
          stmt.close
        end
      rescue
        dbh.query(%| ROLLBACK |)
        halt(500, {'Content-Type' => 'application/json'}, JSON.generate(
          error: 'エラーが発生しました。'
        ))
      else
        dbh.query(%| COMMIT |)
      end

      stroke = select_one(dbh, %|
        SELECT `id`, `room_id`, `width`, `red`, `green`, `blue`, `alpha`, `created_at`
        FROM `strokes`
        WHERE `id`= ?
      |, [stroke_id])
      stroke[:points] = get_stroke_points(dbh, stroke_id)

      content_type :json
      JSON.generate(
        stroke: to_stroke_json(stroke)
      )
    end

    get '/api/stream/rooms/:id', provides: 'text/event-stream' do |id|
      stream do |writer|
        dbh = get_dbh
        token = check_token(dbh, request.params['HTTP_X_CSRF_TOKEN'])
        token = check_token(dbh, request.params['csrf_token'])
        unless token
          logger.warn("---> mismatched token")
          writer << ("event:bad_request\n" + "data:トークンエラー。ページを再読み込みしてください。\n\n")
          writer.close
          next
        end

        room = get_room(dbh, id)
        unless room
          writer << ("event:bad_request\n" + "data:この部屋は存在しません\n\n")
          writer.close
          next
        end

        update_room_watcher(dbh, room[:id], token[:id])
        watcher_count = get_watcher_count(dbh, room[:id])

        writer << ("retry:500\n\n" + "event:watcher_count\n" + "data:#{watcher_count}\n\n")

        last_stroke_id = 0
        if request.env['HTTP_LAST_EVENT_ID']
          last_stroke_id = request.env['HTTP_LAST_EVENT_ID'].to_i
        end

        5.downto(0) do |i|
          sleep 0.5

          strokes = get_strokes(dbh, room[:id], last_stroke_id)
          strokes.each do |stroke|
            stroke[:points] = get_stroke_points(dbh, stroke[:id])
            writer << ("id:#{stroke[:id]}\n\n" + "event:stroke\n" + "data:#{JSON.generate(to_stroke_json(stroke))}\n\n")
            last_stroke_id = stroke[:id]
          end

          update_room_watcher(dbh, room[:id], token[:id])
          new_watcher_count = get_watcher_count(dbh, room[:id])
          if new_watcher_count != watcher_count
            watcher_count = new_watcher_count
            writer << ("event:watcher_count\n" + "data:#{watcher_count}\n\n")
          end
        end

        writer.close
      end
    end
  end
end
