# Dockerfile to test nginx modsecurity configuration
# Uses nginx with modsecurity module

FROM nginx/ngx_modsecurity:latest

# Install ruby for ERB template processing
RUN apt-get update 
RUN apt-get install -y ruby 

# Create app directory
RUN mkdir -p /app

# Copy the configuration files
COPY servers.conf.erb /app/servers.conf.erb
COPY metabase_rules.txt /app/metabase_rules.txt
COPY n8n_rules.txt /app/n8n_rules.txt

# Copy the entrypoint script
COPY test/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Expose the port (can be overridden by ENV)
EXPOSE 80

# Use our custom entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]

