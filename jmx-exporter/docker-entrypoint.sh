#!/usr/bin/env bash

mvn package
find . -name "jmx_prometheus_javaagent-*.jar" -type f -print0 | xargs -0 cp -ft ./lib
chown -R "$(stat -c "%u:%g" ./lib)" ./lib/