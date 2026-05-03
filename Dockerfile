FROM eclipse-temurin:11-jre

ENV APP_HOME=/usr/src/app
WORKDIR $APP_HOME

COPY target/*.jar app.jar

EXPOSE 8087

ENTRYPOINT ["java", "-jar", "app.jar"]