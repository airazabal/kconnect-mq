
#clean up
rm -rf k8s
rm -rf connectors
mkdir connectors
cd connectors

#pull jdbc jar from artifactory
curl https://artifactory-tools.tch-cluster-0143c5dd31acd8e030a1d6e0ab1380e3-0000.us-south.containers.appdomain.cloud/artifactory/libs-snapshot-local/com/ibm/eventstreams/connect/kafka-connect-jdbc-sink/0.0.1-SNAPSHOT/kafka-connect-jdbc-sink-0.0.1-20200513.145820-1-jar-with-dependencies.jar -O
#pull avro converter
curl https://artifactory-tools.tch-cluster-0143c5dd31acd8e030a1d6e0ab1380e3-0000.us-south.containers.appdomain.cloud/artifactory/libs-snapshot-local/com/ibm/eventstreams/connect/kafka-connect-avro-converter/1.0-SNAPSHOT/kafka-connect-avro-converter-1.0-20200513.182234-1-jar-with-dependencies.jar -O
cd ..

Docker build -t jdbc-connector$1 .
Docker tag  jdbc-connector$1 default-route-openshift-image-registry.tch-cluster-0143c5dd31acd8e030a1d6e0ab1380e3-0000.us-south.containers.appdomain.cloud/rabbitmq/jdbc-connector$1

Docker push default-route-openshift-image-registry.tch-cluster-0143c5dd31acd8e030a1d6e0ab1380e3-0000.us-south.containers.appdomain.cloud/rabbitmq/jdbc-connector$1

# create a temporary directory for deployment
mkdir config
mkdir k8s
yq w ../k8s/deployment-rmq-kconnect.yaml "spec.template.spec.containers[0].image" image-registry.openshift-image-registry.svc:5000/rabbitmq/jdbc-connector$1 > ./k8s/deployment-jdbc-connector.yaml
yq w -i k8s/deployment-jdbc-connector.yaml "metadata.name" jdbc-connector$1
yq w -i k8s/deployment-jdbc-connector.yaml "spec.selector.matchLabels.app" jdbc-connector$1
yq w -i k8s/deployment-jdbc-connector.yaml "spec.template.metadata.labels.app" jdbc-connector$1
yq w -i k8s/deployment-jdbc-connector.yaml "spec.template.spec.containers[0].name" jdbc-connector$1

yq w ../k8s/service-rmq-kconnect.yaml "metadata.name" jdbc-connector$1 > ./k8s/service-jdbc-connector.yaml
yq w -i k8s/service-jdbc-connector.yaml "spec.selector.app" jdbc-connector$1
oc delete -f k8s
oc delete route/jdbc-connector$1
oc create -f k8s
oc expose svc/jdbc-connector$1 -n rabbitmq
oc get -n rabbitmq route,svc,pods,route
#get hostname
#hostname=$(oc get route jdbc-connector$1 -o 'jsonpath={.spec.host}')
#echo 'hostname: '$hostname
#sleep 10
#wait for pod to be ready
#while [[ $(oc get pod | grep jdbc-conn | grep Runn | awk '{ print $3 }') != "Running" ]]; do echo "waiting for pod" && sleep 1; done
#./config/set-jdbc-connector.sh $hostname


