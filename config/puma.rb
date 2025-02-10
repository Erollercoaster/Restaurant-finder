# Set Puma threads
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Set the port Puma will listen on
port ENV.fetch("PORT", 3000)

# Specifies the environment
environment ENV.fetch("RAILS_ENV") { "development" }

# Specifies the number of worker processes (only for production)
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Use preload_app! to optimize memory usage with multiple workers
preload_app!

# Ensure workers gracefully restart
on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

# Allow Puma to be restarted by `bin/rails restart`
plugin :tmp_restart

# Define PID file location (useful for Render)
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Bind to 0.0.0.0 to allow external connections (important for Render)
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 3000)}"

# Enable the Puma control app (optional but useful for debugging)
activate_control_app
