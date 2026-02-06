threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count

# Use APP_PORT from environment, fallback to PORT, then default 3000
port ENV.fetch("APP_PORT") { ENV.fetch("PORT", "3000") }

plugin :tmp_restart

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
