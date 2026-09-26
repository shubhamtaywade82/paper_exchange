# Be sure to restart your server when you modify this file.

# CORS is deliberately tight (audits M2 + N5): the API is consumed by the
# trading agent and local operator tooling — non-browser clients (the bot,
# curl, Node) are not subject to CORS at all. Loopback origins are allowed
# so local dashboards (e.g. the lifecycle simulation page served from
# localhost) can call the API from a browser; every other origin gets no
# CORS headers. Previously origins was "*" with all methods, which paired
# badly with an unauthenticated API.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ->(origin) { origin.match?(/\Ahttps?:\/\/(localhost|127\.0\.0\.1)(:\d+)?\z/) }

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head]
  end
end
