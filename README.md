# Autoscaling Kafka Streams applications with Prometheus and Kubernetes
Detailed explanation what this repo is about is available at [post](https://blog.softwaremill.com/autoscaling-kafka-streams-applications-with-kubernetes-9aed2e37d3a0).

## Requirements
1. Kubernetes cluster. You can install [minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/) locally.
2. [Helm](https://helm.sh/docs/intro/install/) version 3+.

## PreInstall
Install external helm repositories [bitnami](https://github.com/bitnami/charts) & [prometheus-community](https://github.com/prometheus-community/helm-charts)

``` helm repo add bitnami https://charts.bitnami.com/bitnami ```

``` helm repo add prometheus-community https://prometheus-community.github.io/helm-charts ```

``` helm repo update ```

## TL;DR

``` APP_HOME=<absolute_path_to_application> ```

``` mkdir --parents $APP_HOME && cd $APP_HOME ``` then download [default deployment helm configuration](https://github.com/DmitryAEfimov/kafka-streams-scaling/tree/main/k8s) to it

``` minikube start [<...you minikube config here...>] ```

``` kubectl create namespace kafka ```

``` kubectl config set-context --current --namespace kafka ```

### Install or Update prometheus-stack
``` cd $APP_HOME/k8s/prometheus-stack && ./install.sh ```

### Install or Update kafka-streams
Check [dependencies](https://github.com/DmitryAEfimov/kafka-streams-scaling/blob/main/k8s/kafka-streams/Chart.yaml) actual version ``` helm search repo | grep '<repo_name>/<chart_name>' ```. 

Update versions if needed:
* Edit version numbers in ``` $APP_HOME/k8s/kafka-streams/Chart.yaml ```
* ``` cd $APP_HOME/k8s/kafka-streams/charts && helm pull <repo_name>/<chart_name> ```

``` cd $APP_HOME/k8s/kafka-streams && ./install.sh ```

### Check results
You can use ``` watch kubectl get all ``` command to watch pods state

Forward grafana service TCP port to localhost ``` kubectl port-forward service/prometheus-stack-grafana <localhost_tcp_port>:80 ```.

Open grafana dashboards in browser ``` http://localhost:<localhost_tcp_port> ``` and login with default credentials ``` admin/prom-operator ```

Select dashboard named ``` Kafka Streams Auto Scaling ```

See similar ![result](k8s/result.png)

### Stop containers
``` cd $APP_HOME/k8s/kafka-streams && ./delete.sh ```

``` cd $APP_HOME/k8s/prometheus-stack && ./delete.sh ```

## Build Application from scratch
As described in agenda's [post](https://blog.softwaremill.com/autoscaling-kafka-streams-applications-with-kubernetes-9aed2e37d3a0)
application's idea is to collect JMX metrics on remote host and expose they in prometheus format. But instead of deploying exporter sidecar container
javaagent is used as described in [this post](https://grafana.com/blog/2020/06/25/monitoring-java-applications-with-the-prometheus-jmx-exporter-and-grafana/) 

### Getting JMX to Prometheus exporter
You can get ``` jmx_prometheus_javaagent ``` following next steps
1. Download [jmx-exporter src](https://github.com/prometheus/jmx_exporter/releases)
2. Execute ```cd <src_directory> && mvn package ``` to build ``` jmx_prometheus_javaagent ```.

Also you can build ``` jmx_prometheus_javaagent ``` with [dockerfile](https://github.com/DmitryAEfimov/kafka-streams-scaling/tree/separate-jmx-build/jmx-exporter)

1. Pull it locally
2. Execute command with
   * ``` ARG jmx_branch_name ``` - any [repo](https://github.com/prometheus/jmx_exporter) branch or tag. Default is [parent-0.14.0](https://github.com/prometheus/jmx_exporter/tree/parent-0.14.0)
   * ``` <jmx_prometheus_javaagent_jar_file_directory> ``` - absolute path to host-side directory where to the jar file should be copied.
``` 
    docker build --no-cache
    --build-arg jmx_branch_name=<git_branch>
    -t jmx-exporter . &&
    docker run
    -v <jmx_prometheus_javaagent_jar_file_directory>:/jmx-exporter/lib
    --name jmx-exporter
    -it --rm
    jmx-exporter
```

### Dockerize application
Pull or download current repository

Execute command with
   * ``` ARG jmx_exporter_jar ``` - path to javaagent jar

``` 
    docker build
    --build-arg jmx_exporter_jar=<path_to_javaagent_jar>
    -t kafka-streams-scaling:latest . 
```

Push to repo. In case of ```minikube``` just cache local image ``` minikube cache add kafka-streams-scaling:latest ```

## Image specification
### Environments
#### Common envs
|Name|Required|Default|Description|
|:---|:---:|:---:|:---|
|``` BOOTSTRAP_SERVERS_CONFIG ```|Yes| |See [Apache Kafka](https://kafka.apache.org/20/documentation/streams/developer-guide/config-streams.html#bootstrap-servers) for details.|
|``` SENDER_MODE ```|No| |Set to ```1``` to run application as ```Sender```. ```Consumer``` otherwise|
|``` IN_TOPIC_NAME ```|No|```inScalingTopic```|Topic name to send to/consume from|

#### Consumer envs

|Name|Required|Default|Description|
|:---|:---:|:---:|:---|
|``` OUT_TOPIC_NAME ```|No|```outScalingTopic```|Topic name to send processed messages|
|``` JMX_REMOTE_PORT ```|No|5555|RMI registry port|
|``` JMX_REMOTE_AUTH_ENABLE ```|No|false|Disable password authentication|
|``` JMX_REMOTE_SSL ```|No|false|Authentification over SSL|
|``` METRICS_EXPOSE_PORT ```|No|5556|Endpoint port that the metrics will be exposed on.  http://localhost:<port_number>/metrics|

#### Sender envs
|Name|Required|Default|Description|
|:---|:---:|:---:|:---|
|```MESSAGE_KEY_CNT```|No|30|Number of different message keys|
|```KEY_CHUNK_SIZE```|No|10000|Number of messages in each key|

**Caution!!!** You should change ENTRYPOINT and CMD when enable [PASSWORD](https://docs.oracle.com/javadb/10.10.1.2/adminguide/radminjmxenablepwd.html) or [SSL](https://docs.oracle.com/javadb/10.10.1.2/adminguide/radminjmxenablepwdssl.html) authentification.

#### Volumes
```/opt/app/logging```. Rewrite logging.properties to configure logging level

```/opt/app/metrics```. Rewrite metrics.yaml to configure export rules

#### Run
```
docker run
-p <host_port>:5556
--env METRICS_EXPOSE_PORT=5556
--env BOOTSTRAP_SERVERS_CONFIG=plaintext://<host>:<port>
--name kafka-streams-scaling
-it
kafka-streams-scaling:latest
```

### Helm chart default values

|Name|Description|Value|
|:---|:---|:---:|
|application.sender.keyCnt|Number of different message keys|``` 30 ```|
|application.sender.chunkSize|Number of messages in each key|``` 10000 ```|
|application.kafka.inTopicName|Topic name to send to/consume from|``` inScalingTopic ```|
|application.kafka.outTopicName|Topic name to send processed messages|``` outScalingTopic ```|
|application.jmxExport.serviceMonitor.enabled|Metrics lookup| ```true``` |
|application.jmxExport.logMountPath|Logging volume.|/opt/app/logging|
|application.jmxExport.metricMountPath|Metrics volume.|/opt/app/metrics|
|application.jmxExport.config.*|Configuration parameters.|See [exporter configuration](https://github.com/prometheus/jmx_exporter#configuration) for details|
|application.jmxRemote.url|Target host|127.0.0.1|
|application.jmxRemote.port|RMI registry port|5555|
|application.jmxRemote.auth.enable|Enable auth|false|
|application.jmxRemote.ssl|Enable ssl|false|
|autoscaling.enabled|Enable application pod autoscaling|true|
|autoscaling.minReplicas|Lower scaling bound|1|
|autoscaling.maxReplicas|Upper scaling bound|3|
|autoscaling.targetAverageFetchLag|Consumer fetch lag threshold. Initiate scaling up/down|10000|
|service.port|The port that will be exposed by this service|5556|
|service.containerPort|Port to expose on pod's IP address|5556|
|kafka.*|kafka pods configuration|See [bitnami/kafka](https://github.com/bitnami/bitnami-docker-kafka) for details|
|prometheus-adapter.*|Provide Custom Metric API|See [prometheus-community/helm-charts](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus-adapter) for details| 