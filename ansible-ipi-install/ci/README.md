# Airflow CI 

Portal - http://airflow.apps.sailplane.perf.lab.eng.rdu2.redhat.com/
Airflow DAGs - https://github.com/cloud-bulldozer/airflow-kubernetes 

Airflow CI pipelines are written in python and stored in the mentioned github repository, the airflow webserver will continuously sync with them and update pipelines. Variables/secrets are stored in the portal as `Variables` and referred during job execution. 
 
This image is required for running JetSki from a airflow container, Airflow KubernetesExecutor creates a pod for every new job and needs a container image with all required packages to run the playbooks. This file includes all packages required to run JetSki as well as Webfuse roles. 

```sh
podman build .

podman push <IMAGE_ID> quay.io/mukrishn/jetski:2.0
```
