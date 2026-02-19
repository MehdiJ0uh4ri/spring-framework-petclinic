# Use an official Jetty runtime as a parent image
FROM jetty:11-jdk17

# Remove the default webapp
RUN rm -rf /var/lib/jetty/webapps/*

# Copy the WAR file from the build context into the webapps folder
COPY target/petclinic.war /var/lib/jetty/webapps/ROOT.war

# Install curl for health checks
USER root
RUN apt-get update && apt-get install -y curl && rm -rf /var/cache/apt/lists/*
USER jetty

# Healthcheck - Check for the home page
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1
