FROM eclipse-temurin:25-jre-alpine

WORKDIR /app

RUN mkdir -p /app/STORAGE_ROOT

COPY target/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]