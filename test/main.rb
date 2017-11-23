require "faraday"
require "faraday_middleware"
require "active_support/notifications"
require "logger"
require "pry"
require "json"

url = 'http://localhost:9292'
c = Faraday.new(url: url) do |faraday|
  faraday.request :url_encoded
  faraday.use FaradayMiddleware::Instrumentation
  faraday.adapter Faraday.default_adapter
end

logger = Logger.new(STDOUT)
ActiveSupport::Notifications.subscribe('request.faraday') do |name, starts, ends, _, env|
  url = env[:url]
  http_method = env[:method].to_s.upcase
  time_sec = ends - starts
  time_ms = time_sec * 1000
  http_status = env[:response].status
  if http_status > 200
    logger.error "#{http_status} #{http_method} #{url} in #{time_ms}ms"
  else
    logger.info "#{http_status} #{http_method} #{url} in #{time_ms}ms"
  end
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

c.get "/api/rooms/1"
