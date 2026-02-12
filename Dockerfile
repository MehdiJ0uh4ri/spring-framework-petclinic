# Multi-stage Dockerfile for Spring Framework Petclinic (WAR)
# Build stage
FROM maven:3.8.8-eclipse-temurin-17 AS build
WORKDIR /workspace
COPY pom.xml ./
COPY src ./src
RUN mvn -B -DskipTests package

# Runtime stage (Jetty)
FROM jetty:11.0-jdk17
COPY --from=build /workspace/target/petclinic.war /var/lib/jetty/webapps/ROOT.war
EXPOSE 8080
ENV JAVA_OPTS=""
CMD ["sh","-c","java $JAVA_OPTS -jar /usr/local/jetty/start.jar"]
