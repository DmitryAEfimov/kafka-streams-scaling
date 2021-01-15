ARG jmx_exporter_version="0.14.0"
# build application
FROM gradle:6.8.0-jdk11-openj9 AS app-build
COPY --chown=gradle:gradle . /home/gradle/src
WORKDIR /home/gradle/src
RUN gradle clean build fatJar --no-daemon

# clone jmx-exporter
FROM alpine/git:v2.26.2 AS clone
WORKDIR /repo
ARG jmx_exporter_version
ARG jmx_release_tag="parent-${jmx_exporter_version}"
RUN git clone --depth 1 --branch "${jmx_release_tag}" https://github.com/prometheus/jmx_exporter.git

# build jmx-exporter
FROM maven:3.6.3-jdk-11 as jmx-exporter-build
WORKDIR /jmx_exporter
COPY --from=clone /repo/jmx_exporter/ /jmx_exporter/
RUN mvn package

# compile image
FROM openjdk:11-jre-slim
MAINTAINER  Dmitry Efimov <dmitry.a.efimov@gmail.com>

ARG jmx_exporter_version
ENV JMX_EXPORTER_VERSION="${jmx_exporter_version}"

WORKDIR /opt/app
COPY --from=app-build /home/gradle/src/build/libs/kafka-streams-scaling-all.jar .

RUN mkdir ./jmx-exporter
COPY --from=jmx-exporter-build /jmx_exporter/jmx_prometheus_javaagent/target/jmx_prometheus_javaagent-"${JMX_EXPORTER_VERSION}".jar ./jmx-exporter/
COPY jmx-config/ ./jmx-exporter/config/

RUN groupadd -g 999 appuser && \
    useradd -r -u 999 -g appuser appuser && \
    chown -R appuser:appuser /opt/app/ && \
    chmod 644 kafka-streams-scaling-all.jar && \
    chmod 644 ./jmx-exporter/jmx_prometheus_javaagent-"${JMX_EXPORTER_VERSION}".jar && \
    chmod 644 ./jmx-exporter/config/*
USER appuser

EXPOSE 5556

ENV JMX_REMOTE_PORT=5555
ENV JMX_REMOTE_AUTH_ENABLE="false"
ENV JMX_REMOTE_SSL="false"
ENV JMX_LOG_PROPERTIES="/opt/app/jmx-exporter/config/logging.properties"
ENV JMX_METRICS_CFG_FILE="/opt/app/jmx-exporter/config/metrics.yaml"

ENTRYPOINT java -Dcom.sun.management.jmxremote.authenticate="${JMX_REMOTE_AUTH_ENABLE}" \
                -Dcom.sun.management.jmxremote.ssl="${JMX_REMOTE_SSL}" \
                -Djava.util.logging.config.file="${JMX_LOG_PROPERTIES}" \
                -javaagent:/opt/app/jmx-exporter/jmx_prometheus_javaagent-"${JMX_EXPORTER_VERSION}".jar=${JMX_REMOTE_PORT}:"${JMX_METRICS_CFG_FILE}" \
                -jar /opt/app/kafka-streams-scaling-all.jar