require "faraday"
require "faraday_middleware"
require "active_support/notifications"
require "logger"
require "pry"
require "json"
require "diffy"

url = 'http://localhost:9292'
c = Faraday.new(url: url) do |faraday|
  faraday.request :url_encoded
  faraday.use FaradayMiddleware::Instrumentation
  faraday.adapter Faraday.default_adapter
end

req_id = 0
logger = Logger.new(STDOUT)
ActiveSupport::Notifications.subscribe('request.faraday') do |name, starts, ends, _, env|
  url = env[:url]
  http_method = env[:method].to_s.upcase
  time_sec = ends - starts
  time_ms = time_sec * 1000
  res = env[:response]
  http_status = res.status
  if http_status > 200
    logger.error "#{http_status} #{http_method} #{url} in #{time_ms}ms"
  else
    logger.info "#{http_status} #{http_method} #{url} in #{time_ms}ms"
  end

  filename = "#{req_id.to_s.rjust(2, "0")}__#{http_method}#{env.url.path.gsub("/", "__")}"
  filepath = File.expand_path("../fixtures/#{filename}", __FILE__)
  if File.exist?(filepath)
    expected = File.read(filepath)
    if res.body != expected
      logger.info "\n" + Diffy::Diff.new(res.body, expected).to_s(:color)
    end
  else
    File.write(filepath, res.body)
  end
  req_id += 1
end


# ------ Test -------
c.get "/initialize"

# Get token
res = c.post "/api/csrf_token"
token = JSON.parse(res.body)["token"]

# post room
res = c.post "/api/rooms" do |req|
  req.headers['X_CSRF_TOKEN'] = token
  req.body = {
    name: "test",
    canvas_width: 1000,
    canvas_height: 800,
  }.to_json
end

room_id = JSON.parse(res.body)["room"]["id"]

# get room
c.get "/api/rooms/#{room_id}"


# post stroke
res = c.post "/api/strokes/rooms/#{room_id}" do |req|
  req.headers['X_CSRF_TOKEN'] = token
  req.body = {
    width: 200,
    red: 255,
    green: 255,
    blue: 255,
    alpha: 1,
    points: [{ x: 1, y:1 }],
  }.to_json
end
