#!/bin/bash
set -e

# Set default environment variables if not provided
export PORT=${PORT:-80}
export METABASE_UPSTREAM_SERVER=${METABASE_UPSTREAM_SERVER:-metabase:3000}
export N8N_UPSTREAM_SERVER=${N8N_UPSTREAM_SERVER:-n8n:5678}
export METABASE_HOST=${METABASE_HOST:-metabase.local}
export WEBAPP_UPSTREAM_SERVER=${WEBAPP_UPSTREAM_SERVER:-webapp:8000}
export WEBAPP_HOST=${WEBAPP_HOST:-webapp.local}
export WEBAPP_ADMIN_LOGIN_PATH=${WEBAPP_ADMIN_LOGIN_PATH:-"/admin/login"}
export N8N_LOGIN_PATH=${N8N_LOGIN_PATH:-"/rest/login"}

# Ensure nginx config directory exists
mkdir -p /etc/nginx/conf.d

# Compile the ERB template to nginx configuration
echo "Compiling servers.conf.erb to /etc/nginx/conf.d/default.conf..."
erb /app/servers.conf.erb > /etc/nginx/conf.d/default.conf

# Check if the compilation was successful
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to compile ERB template"
    exit 1
fi

# Display the generated configuration for debugging
echo "Generated nginx configuration:"
cat /etc/nginx/conf.d/default.conf

# Test nginx configuration before starting
echo "Testing nginx configuration..."
nginx -t

if [ $? -ne 0 ]; then
    echo "ERROR: nginx configuration test failed"
    exit 1
fi

echo "Starting nginx..."
# Start nginx in the foreground
exec "$@"

