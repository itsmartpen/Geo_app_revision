FROM adoptopenjdk/openjdk11 
ENV APP_HOME=/usr/src/app
WORKDIR $APP_HOME

COPY target/my-app-0.0.1-SNAPSHOT.jar app.jar

EXPOSE 8087
ENTRYPOINT ["java", "-jar", "app.jar"]