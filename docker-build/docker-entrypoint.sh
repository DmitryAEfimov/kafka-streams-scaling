#!/usr/bin/env bash

if [ -z "${SENDER_MODE}" ] || [ "${SENDER_MODE}" != "1" ]; then
  java  -Dcom.sun.management.jmxremote.port="${JMX_REMOTE_PORT}" \
        -Dcom.sun.management.jmxremote.authenticate="${JMX_REMOTE_AUTH_ENABLE}" \
        -Dcom.sun.management.jmxremote.ssl="${JMX_REMOTE_SSL}" \
        -Djava.util.logging.config.file=./logging/logging.properties \
        -javaagent:"${JMX_EXPORTER_JAR}"="${METRICS_EXPOSE_PORT}":./metrics/metrics.yaml \
    -jar kafka-streams-scaling-all.jar
else
  java -cp kafka-streams-scaling-all.jar kafka.streams.scaling.Sender
fi