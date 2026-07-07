FROM eclipse-temurin:11-jre

ENV APP_HOME=/usr/src/app
WORKDIR $APP_HOME

RUN addgroup --system app && adduser --system --ingroup app app
COPY target/*.jar app.jar
RUN chown app:app app.jar
USER app

EXPOSE 8087

ENTRYPOINT ["java", "-jar", "app.jar"]