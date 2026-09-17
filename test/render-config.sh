#!/bin/bash
set -e

# Set default environment variables if not provided
export PORT=${PORT:-8080}
export METABASE_UPSTREAM_SERVER=${METABASE_UPSTREAM_SERVER:-metabase:3000}
export N8N_UPSTREAM_SERVER=${N8N_UPSTREAM_SERVER:-n8n:5678}
export DEPEC_WEB_UPSTREAM_SERVER=${DEPEC_WEB_UPSTREAM_SERVER:-depec-web:8000}
export GESEC_WEB_UPSTREAM_SERVER=${GESEC_WEB_UPSTREAM_SERVER:-gesec-web:8000}
export SFTP_WEB_UPSTREAM_SERVER=${SFTP_WEB_UPSTREAM_SERVER:-sftp-web:8000}
export METABASE_HOST=${METABASE_HOST:-metabase.local}
export N8N_HOST=${N8N_HOST:-n8n.local}
export DEPEC_WEB_HOST=${DEPEC_WEB_HOST:-depec-web.local}
export GESEC_WEB_HOST=${GESEC_WEB_HOST:-gesec-web.local}
export SFTP_WEB_HOST=${SFTP_WEB_HOST:-sftp-web.local}
export N8N_LOGIN_PATH=${N8N_LOGIN_PATH:-"/rest/login"}
export DEPEC_WEB_ADMIN_LOGIN_PATH=${DEPEC_WEB_ADMIN_LOGIN_PATH:-"/admin/login"}
export GESEC_WEB_ADMIN_LOGIN_PATH=${GESEC_WEB_ADMIN_LOGIN_PATH:-"/admin/login"}
export SFTP_WEB_ADMIN_LOGIN_PATH=${SFTP_WEB_ADMIN_LOGIN_PATH:-"/admin/login"}

# Compile the ERB template to nginx configuration
erb /app/servers.conf.erb > /etc/nginx/conf.d/default.conf