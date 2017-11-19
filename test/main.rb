require "faraday"
require "faraday_middleware"
require "active_support/notifications"
require "logger"
require "pry"

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
  logger.info "#{http_method} #{url} in #{time_ms}ms"
end


# ------ Test -------
c.get "/initialize"
c.get "/rooms"
c.get "/rooms/1"
