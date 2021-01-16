ARG jmx_exporter_version="0.14.0"
# build application
FROM gradle:6.8.0-jdk11-openj9 AS app-build
COPY --chown=gradle:gradle . /home/gradle/app
WORKDIR /home/gradle/app
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

COPY --from=app-build /home/gradle/app/build/libs/kafka-streams-scaling-all.jar .
COPY --from=jmx-exporter-build /jmx_exporter/jmx_prometheus_javaagent/target/jmx_prometheus_javaagent-"${JMX_EXPORTER_VERSION}".jar .
COPY docker-build-config/entrypoint.sh .

RUN mkdir ./logging && mkdir ./metrics
COPY docker-build-config/metrics.yaml ./metrics
COPY docker-build-config/logging.properties ./logging

RUN groupadd -g 999 appuser && \
    useradd -r -u 999 -g appuser appuser && \
    chown -R appuser:appuser . && \
    find . -type f -print0 | xargs -0 chmod 644 && \
    find . -type d -print0 | xargs -0 chmod 755 && \
    chmod 755 entrypoint.sh
USER appuser

EXPOSE 5556

ENV JMX_REMOTE_PORT=5555
ENV JMX_REMOTE_AUTH_ENABLE="false"
ENV JMX_REMOTE_SSL="false"
ENV METRICS_EXPOSE_PORT=5556

ENTRYPOINT /opt/app/entrypoint.sh