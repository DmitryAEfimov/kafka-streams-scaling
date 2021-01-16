#!/usr/bin/env bash

helm upgrade --install --wait -f values.yaml prometheus-stack prometheus-community/kube-prometheus-stack