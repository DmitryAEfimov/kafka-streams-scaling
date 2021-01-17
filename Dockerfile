FROM gradle:6.8.0-jdk11-openj9 AS build
COPY --chown=gradle:gradle . /home/gradle/app
WORKDIR /home/gradle/app
RUN gradle build fatJar --no-daemon

FROM openjdk:11-jre-slim
MAINTAINER  Dmitry Efimov <dmitry.a.efimov@gmail.com>

ENV JMX_REMOTE_PORT=5555
ENV JMX_REMOTE_AUTH_ENABLE="false"
ENV JMX_REMOTE_SSL="false"
ENV METRICS_EXPOSE_PORT=5556

WORKDIR /opt/app

COPY --from=build /home/gradle/app/build/libs/kafka-streams-scaling-all.jar .
COPY "$JMX_EXPORTER_JAR" .
COPY docker-build/docker-entrypoint.sh .

RUN mkdir ./logging ./metrics
COPY docker-build/metrics.yaml ./metrics
COPY docker-build/logging.properties ./logging

RUN groupadd -g 999 appuser && \
    useradd -r -u 999 -g appuser appuser && \
    chown -R appuser:appuser . && \
    find . -type f -print0 | xargs -0 chmod 644 && \
    find . -type d -print0 | xargs -0 chmod 755 && \
    chmod 755 docker-entrypoint.sh
USER appuser

EXPOSE $METRICS_EXPOSE_PORT

ENTRYPOINT ["/opt/app/docker-entrypoint.sh"]