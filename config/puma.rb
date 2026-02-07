threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count

environment ENV.fetch("RAILS_ENV") { "development" }

# In production, bind to all interfaces for container deployment
if ENV["RAILS_ENV"] == "production"
  port_number = ENV.fetch("PORT", "3000")
  bind "tcp://0.0.0.0:#{port_number}"
else
  # In development, use port directive
  port ENV.fetch("PORT", "3000")
end

plugin :tmp_restart

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
