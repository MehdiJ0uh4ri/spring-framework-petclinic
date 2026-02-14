# ============================================================================
# Stage 1: Build
# ============================================================================
FROM maven:3.9-eclipse-temurin-17 AS builder

WORKDIR /build

# Copy only pom.xml first (for better caching)
COPY pom.xml .

# Download dependencies
RUN ./mvnw dependency:resolve

# Copy source code
COPY src ./src
COPY .mvn ./.mvn
COPY mvnw .

# Build application
RUN ./mvnw clean package -DskipTests

# ============================================================================
# Stage 2: Runtime (Minimal image)
# ============================================================================
FROM eclipse-temurin:17-jre-alpine

# Install curl for health checks (minimal install)
RUN apk add --no-cache curl

# Create non-root user for security
RUN addgroup -S petclinic && adduser -S petclinic -G petclinic

WORKDIR /app

# Copy JAR from builder
COPY --from=builder --chown=petclinic:petclinic /build/target/spring-petclinic-*.jar app.jar

# Switch to non-root user
USER petclinic

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run application
ENTRYPOINT ["java", "-jar", "app.jar"]
