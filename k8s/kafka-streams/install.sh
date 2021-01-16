#!/usr/bin/env bash

helm upgrade --install --wait -f values.yaml kafka-streams ../kafka-streams