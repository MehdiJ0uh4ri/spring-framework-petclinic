# Stage 1: Build the application using a Maven image
# We use a base image that already has Maven installed, so we don't need ./mvnw
FROM maven:3.8.5-openjdk-17 AS builder
WORKDIR /app

# Copy pom.xml and download dependencies (Layer caching)
COPY pom.xml .
RUN mvn dependency:go-offline

# Copy source code and build
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Create the runtime image
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Copy the built artifact from the builder stage
# Note: This copies any JAR or WAR file found
COPY --from=builder /app/target/*.?ar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]