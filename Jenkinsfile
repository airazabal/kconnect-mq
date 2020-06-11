/*
 * This is a vanilla Jenkins pipeline that relies on the Jenkins kubernetes plugin to dynamically provision agents for
 * the build containers.
 *
 * The individual containers are defined in the `jenkins-pod-template.yaml` and the containers are referenced by name
 * in the `container()` blocks. The underlying pod definition expects certain kube Secrets and ConfigMap objects to
 * have been created in order for the Pod to run. See `jenkins-pod-template.yaml` for more information.
 *
 * The cloudName variable is set dynamically based on the existance/value of env.CLOUD_NAME which allows this pipeline
 * to run in both Kubernetes and OpenShift environments.
 */

def buildAgentName(String jobNameWithNamespace, String buildNumber, String namespace) {
    def jobName = removeNamespaceFromJobName(jobNameWithNamespace, namespace);

    if (jobName.length() > 52) {
        jobName = jobName.substring(0, 52);
    }

    return "a.${jobName}${buildNumber}".replace('_', '-').replace('/', '-').replace('-.', '.');
}

def removeNamespaceFromJobName(String jobName, String namespace) {
    return jobName.replaceAll(namespace + "-", "").replaceAll(jobName + "/", "");
}

def buildSecretName(String jobNameWithNamespace, String namespace) {
    return jobNameWithNamespace.replaceFirst(namespace + "/", "").replaceFirst(namespace + "-", "").replace(".", "-").toLowerCase();
}

def secretName = buildSecretName(env.JOB_NAME, env.NAMESPACE)
println "Job name: ${env.JOB_NAME}"
println "Secret name: ${secretName}"

def buildLabel = buildAgentName(env.JOB_NAME, env.BUILD_NUMBER, env.NAMESPACE);
def branch = env.BRANCH ?: "master"
def namespace = env.NAMESPACE ?: "dev"
def cloudName = env.CLOUD_NAME == "openshift" ? "openshift" : "kubernetes"
def workingDir = "/home/jenkins/agent"
podTemplate(
   label: buildLabel,
   cloud: cloudName,
   yaml: """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins
  volumes:
    - emptyDir: {}
      name: varlibcontainers
  containers:
    - name: jdk11
      image: maven:3.6.3-jdk-11-slim
      tty: true
      command: ["/bin/bash"]
      workingDir: ${workingDir}
      envFrom:
        - configMapRef:
            name: pactbroker-config
            optional: true
        - configMapRef:
            name: sonarqube-config
            optional: true
        - secretRef:
            name: sonarqube-access
            optional: true
      env:
        - name: HOME
          value: ${workingDir}
        - name: SONAR_USER_HOME
          value: ${workingDir}

    - name: node
      image: node:12-stretch
      tty: true
      command: ["/bin/bash"]
      workingDir: ${workingDir}
      envFrom:
        - configMapRef:
            name: pactbroker-config
            optional: true
        - configMapRef:
            name: sonarqube-config
            optional: true
        - secretRef:
            name: sonarqube-access
            optional: true
      env:
        - name: HOME
          value: ${workingDir}
        - name: BRANCH
          value: ${branch}
        - name: GIT_AUTH_USER
          valueFrom:
            secretKeyRef:
              name: git-credentials
              key: username
        - name: GIT_AUTH_PWD
          valueFrom:
            secretKeyRef:
              name: git-credentials
              key: password
    - name: buildah
      image: quay.io/buildah/stable:v1.11.0
      tty: true
      command: ["/bin/bash"]
      workingDir: ${workingDir}
      securityContext:
        privileged: true
      env:
        - name: HOME
          value: /home/devops
        - name: ENVIRONMENT_NAME
          value: ${env.NAMESPACE}
        - name: DOCKERFILE
          value: ./Dockerfile
        - name: CONTEXT
          value: .
        - name: TLSVERIFY
          value: "false"
        - name: REGISTRY_URL
          value: image-registry.openshift-image-registry.svc:5000
        - name: REGISTRY_NAMESPACE
          value: ${env.NAMESPACE}
        - name: REGISTRY_USER
          valueFrom:
            secretKeyRef:
              key: REGISTRY_USER
              name: registry-creds
              optional: true
        - name: REGISTRY_PASSWORD
          valueFrom:
            secretKeyRef:
              key: REGISTRY_PASSWORD
              name: registry-creds
              optional: true
      volumeMounts:
        - mountPath: /var/lib/containers
          name: varlibcontainers
    - name: ibmcloud
      image: docker.io/garagecatalyst/ibmcloud-dev:1.0.10
      tty: true
      command: ["/bin/bash"]
      workingDir: ${workingDir}
      envFrom:
        - configMapRef:
            name: artifactory-config
            optional: true
        - secretRef:
            name: artifactory-access
            optional: true
      env:
        - name: CHART_NAME
          value: helm
        - name: CHART_ROOT
          value: chart
        - name: TMP_DIR
          value: .tmp
        - name: HOME
          value: /home/devops
        - name: ENVIRONMENT_NAME
          value: ${namespace}
        - name: BUILD_NUMBER
          value: ${env.BUILD_NUMBER}
        - name: BRANCH
          value: ${branch}
        - name: INGRESS_SUBDOMAIN
          valueFrom:
            configMapKeyRef:
              name: ibmcloud-config
              key: INGRESS_SUBDOMAIN
              optional: true
        - name: TLS_SECRET_NAME
          valueFrom:
            configMapKeyRef:
              name: ibmcloud-config
              key: TLS_SECRET_NAME
              optional: true
        - name: CLUSTER_TYPE
          valueFrom:
            configMapKeyRef:
              name: ibmcloud-config
              key: CLUSTER_TYPE
              optional: true
        - name: REGISTRY_URL
          value: image-registry.openshift-image-registry.svc:5000


        - name: REGISTRY_NAMESPACE
          value: rabbitmq
    - name: trigger-cd
      image: docker.io/garagecatalyst/ibmcloud-dev:1.0.10
      tty: true
      command: ["/bin/bash"]
      workingDir: ${workingDir}
      env:
        - name: HOME
          value: /home/devops
      envFrom:
        - configMapRef:
            name: gitops-repo
            optional: true
        - secretRef:
            name: git-credentials
            optional: true

"""
) {
    node(buildLabel) {
        container(name: 'node', shell: '/bin/bash') {
            checkout scm
                stage('setup') {
                    sh '''
                       cat settings-template.xml | sed  -e "s/GIT_USER/$GIT_AUTH_USER/g" -e "s/GIT_TOKEN/$GIT_AUTH_PWD/g" > ./settings.xml
                       cat ./settings.xml
                    '''
                }
        }
        container(name: 'jdk11', shell: '/bin/bash') {

            stage('Build') {
                sh '''
                    mvn package -s settings.xml
                '''
            }
        }
        container(name: 'node', shell: '/bin/bash') {
            stage('Tag release') {
                sh '''#!/bin/bash
                    set -x
                    set -e

                    if [[ -z "$GIT_AUTH_USER" ]] || [[ -z "$GIT_AUTH_PWD" ]]; then
                      echo "Git credentials not found. The pipeline expects to find them in a secret named 'git-credentials'."
                      echo "  Update your CLI and register the pipeline again"
                      exit 1
                    fi

                    git config --local credential.helper "!f() { echo username=\\$GIT_AUTH_USER; echo password=\\$GIT_AUTH_PWD; }; f"

                    git tag -l

                    COMMIT_HASH=$(git rev-parse HEAD)
                    git checkout -b ${BRANCH} --track origin/${BRANCH}
                    git branch --set-upstream-to=origin/${BRANCH} ${BRANCH}
                    git reset ${COMMIT_HASH}

                    git config --global user.name "Jenkins Pipeline"
                    git config --global user.email "jenkins@ibmcloud.com"

                    if [[ "${BRANCH}" == "master" ]] && [[ $(git describe --tag `git rev-parse HEAD`) =~ (^[0-9]+.[0-9]+.[0-9]+$) ]] || \
                       [[ $(git describe --tag `git rev-parse HEAD`) =~ (^[0-9]+.[0-9]+.[0-9]+-${BRANCH}[.][0-9]+$) ]]
                    then
                        echo "Latest commit is already tagged"
                        echo "IMAGE_NAME=$(basename -s .git `git config --get remote.origin.url` | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')" > ./env-config
                        echo "IMAGE_VERSION=$(git describe --abbrev=0 --tags)" >> ./env-config
                        exit 0
                    fi

                    mkdir -p ~/.npm
                    npm config set prefix ~/.npm
                    export PATH=$PATH:~/.npm/bin
                    npm i -g release-it

                    if [[ "${BRANCH}" != "master" ]]; then
                        PRE_RELEASE="--preRelease=${BRANCH}"
                    fi

                    release-it patch ${PRE_RELEASE} \
                      --ci \
                      --no-npm \
                      --no-git.push \
                      --no-git.requireCleanWorkingDir \
                      --verbose \
                      -VV

                    git push --follow-tags -v

                    echo "IMAGE_VERSION=$(git describe --abbrev=0 --tags)" > ./env-config
                    echo "IMAGE_NAME=$(basename -s .git `git config --get remote.origin.url` | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')" >> ./env-config
                    echo "REPO_URL=$(git config --get remote.origin.url)" >> ./env-config

                    cat ./env-config
                '''
            }
        }
	      container(name: 'buildah', shell: '/bin/bash') {
            stage('Build image') {
                sh '''#!/bin/bash
                    set -e
                    . ./env-config

                    echo TLSVERIFY=${TLSVERIFY}
                    echo CONTEXT=${CONTEXT}

                    APP_IMAGE="${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${IMAGE_VERSION}"
                    APP_IMAGE_LATEST="${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:latest"

                    buildah bud --tls-verify=${TLSVERIFY} --format=docker -f ${DOCKERFILE} -t ${APP_IMAGE} ${CONTEXT}
                    if [[ -n "${REGISTRY_USER}" ]] && [[ -n "${REGISTRY_PASSWORD}" ]]; then
                        buildah login --tls-verify=${TLSVERIFY} -u "${REGISTRY_USER}" -p "${REGISTRY_PASSWORD}" "${REGISTRY_URL}"
                    fi
                    buildah push --tls-verify=${TLSVERIFY} "${APP_IMAGE}" "docker://${APP_IMAGE}"
                    buildah push --tls-verify=${TLSVERIFY} "${APP_IMAGE}" "docker://${APP_IMAGE_LATEST}"
                '''
            }
        }
        container(name: 'ibmcloud', shell: '/bin/bash') {
            stage('Deploy to DEV env') {
                sh '''#!/bin/bash
                    . ./env-config

                    set +x

                    if [[ "${CHART_NAME}" != "${IMAGE_NAME}" ]]; then
                      cp -R "${CHART_ROOT}/${CHART_NAME}" "${CHART_ROOT}/${IMAGE_NAME}"
                      cat "${CHART_ROOT}/${CHART_NAME}/Chart.yaml" | \
                          yq w - name "${IMAGE_NAME}" > "${CHART_ROOT}/${IMAGE_NAME}/Chart.yaml"
                    fi

                    CHART_PATH="${CHART_ROOT}/${IMAGE_NAME}"

                    echo "KUBECONFIG=${KUBECONFIG}"

                    RELEASE_NAME="${IMAGE_NAME}"
                    echo "RELEASE_NAME: $RELEASE_NAME"

                    echo "INITIALIZING helm with client-only (no Tiller)"
                    helm init --client-only 1> /dev/null 2> /dev/null

                    echo "CHECKING CHART (lint)"
                    helm lint ${CHART_PATH}

                    IMAGE_REPOSITORY="${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}"
                    PIPELINE_IMAGE_URL="${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${IMAGE_VERSION}"

                    INGRESS_ENABLED="true"
                    ROUTE_ENABLED="false"
                    if [[ "${CLUSTER_TYPE}" == "openshift" ]]; then
                        INGRESS_ENABLED="false"
                        ROUTE_ENABLED="true"
                    fi

                    # Using 'upgrade --install" for rolling updates. Note that subsequent updates will occur in the same namespace the release is currently deployed in, ignoring the explicit--namespace argument".
                    helm template ${CHART_PATH} \
                        --name ${RELEASE_NAME} \
                        --set image.repository=$IMAGE_REPOSITORY \
                        --namespace ${ENVIRONMENT_NAME} > ./release.yaml

                    echo -e "Generated release yaml for: ${CLUSTER_NAME}/${ENVIRONMENT_NAME}."
                    cat ./release.yaml

                    echo -e "Deploying into: ${CLUSTER_NAME}/${ENVIRONMENT_NAME}."
                    kubectl apply -n ${ENVIRONMENT_NAME} -f ./release.yaml --validate=false
                '''
            }

        }

    }
}
