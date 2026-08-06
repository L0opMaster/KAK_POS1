FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN set -eux; \
    for attempt in 1 2 3; do \
      mvn -q -e -DskipTests dependency:go-offline && break; \
      if [ "$attempt" -eq 3 ]; then exit 1; fi; \
      sleep 10; \
    done
COPY src ./src
RUN set -eux; \
    for attempt in 1 2 3; do \
      mvn -q -DskipTests package && break; \
      if [ "$attempt" -eq 3 ]; then exit 1; fi; \
      sleep 10; \
    done

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/target/backend-1.0.0.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
