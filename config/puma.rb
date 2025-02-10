# Set Puma threads
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Set the port Puma will listen on
port ENV.fetch("PORT", 3000)

# Specifies the environment
rails_env = ENV.fetch("RAILS_ENV") { "development" }
environment rails_env

# Specifies the number of worker processes (only for production)
worker_count = Integer(ENV.fetch("WEB_CONCURRENCY") { 2 })
if rails_env == "production" && worker_count > 1
  workers worker_count
else
  preload_app!
end

# Ensure workers gracefully restart
on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

# Allow Puma to be restarted by `bin/rails restart`
plugin :tmp_restart

# Define PID file location
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Bind to 0.0.0.0 to allow external connections (important for Render)
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 3000)}"

# Worker timeout for development
worker_timeout 3600 if rails_env == "development"

# Enable the Puma control app (optional for debugging)
activate_control_app if rails_env == "development"
