# Dockerfile to test nginx modsecurity configuration
# Uses the OWASP CRS nginx image (nginx with modsecurity module)

FROM owasp/modsecurity-crs:nginx

USER root

# Install ruby for ERB template processing
RUN apt-get update \
    && apt-get install -y --no-install-recommends ruby \
    && rm -rf /var/lib/apt/lists/*

# Our config provides its own resolver; nginx rejects a duplicate one
RUN sed -i '/^    resolver /d' /etc/nginx/templates/nginx.conf.template

# Create app directory
RUN mkdir -p /app

# Copy the configuration files
COPY servers.conf.erb /app/servers.conf.erb
COPY common_rules.txt /app/common_rules.txt
COPY metabase_rules.txt /app/metabase_rules.txt
COPY n8n_rules.txt /app/n8n_rules.txt

# Render the config at startup. Numbered after the image entrypoint
# hooks so nginx.conf and modsecurity are ready.
COPY test/render-config.sh /docker-entrypoint.d/99-render-config.sh
RUN chmod +x /docker-entrypoint.d/99-render-config.sh

# Expose the port (can be overridden by ENV)
EXPOSE 8080

USER nginx