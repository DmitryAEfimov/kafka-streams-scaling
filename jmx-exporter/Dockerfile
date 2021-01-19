# clone jmx-exporter
FROM alpine/git:v2.26.2 AS clone
ARG jmx_branch_name="parent-0.14.0"

WORKDIR /repo
RUN git clone --depth 1 --branch "${jmx_branch_name}" https://github.com/prometheus/jmx_exporter.git

# build jmx-exporter
FROM maven:3.6.3-jdk-11
WORKDIR /jmx-exporter
COPY --from=clone /repo/jmx_exporter .
COPY docker-entrypoint.sh .

VOLUME ./lib
ENTRYPOINT ["/jmx-exporter/docker-entrypoint.sh"]