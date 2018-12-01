# Jenkins CI/CD and Docker EE for DevOps Demo
This is to show a demo of how you can integrate Jenkins CI/CD workflow with Docker Enterprise Edition (EE).

I built a simple python app and use github for version control. When I commit and push to the github repo, Jenkins automatically builds the image and pushes to the Docker Trusted Registry (DTR) in Docker EE.

For all this to work, you need to generate a client bundle for the jenkins user that will access the Universal Control Plane (UCP) 

## Jenkins shell script to pull the client bundle

```
#!/bin/bash

set -e

if [ -f /var/lib/jenkins/ucp-bundle/env.sh ] && [ "${FORCE_BUNDLE}" != "true" ]
then
  echo "Client bundle already exists; exiting"
  ls -l /var/lib/jenkins/ucp-bundle/
  exit 0
else
  cd /var/lib/jenkins

  if [ ! -d ucp-bundle ]
  then
    mkdir ucp-bundle
  fi

  cd ucp-bundle

  echo -n "Retrieving auth token..."
  AUTH_TOKEN="$(curl -sk -d '{"username":"'${USERNAME}'","password":"'${PASSWORD}'"}' https://${UCP_FQDN}/auth/login | jq -r .auth_token 2>/dev/null)"
  if [ -z "${AUTH_TOKEN}" ]
  then
    echo -e "error\nError connecting to ${UCP_FQDN}"
    return 1
  fi
  echo "done"

  echo -n "Downloading client bundle for ${USERNAME}..."
  curl -sk -H "Authorization: Bearer ${AUTH_TOKEN}" https://${UCP_FQDN}/api/clientbundle -o bundle.zip
  echo "done"

  unzip -o bundle.zip
  eval "$(<env.sh)"

  ls -l
fi
```


## Jenkins shell script to build and push images
```
# find the short git SHA
GITID=$(echo ${GIT_COMMIT} | cut -c1-7)

# set environment variables to be able to talk to the docker engine
export DOCKER_TLS_VERIFY=1 COMPOSE_TLS_VERSION=TLSv1_2 DTR_URL=dtr1.demo.samgabrail.com DOCKER_CERT_PATH=/var/lib/jenkins/ucp-bundle KUBECONFIG=/var/lib/jenkins/ucp-bundle/kube.yml DOCKER_HOST=tcp://172.31.6.142:12376

# build the demo using the existing Dockerfile and tag the image with the short git SHA
docker build -t ${DTR_URL}/jenkins/jenkins-demo:${GITID} .

# list images
docker images | grep ^${DTR_URL}/jenkins/jenkins-demo

# docker login
set +x
echo "logging in to ${DTR_URL}"
docker login -u jenkins -p ${DTR_JENKINS_PASSWORD} ${DTR_URL}
set -x

# docker push
docker push ${DTR_URL}/jenkins/jenkins-demo:${GITID}
```

## Jenkins shell script to deploy the service
```
# find the short git SHA (if set)
if [ -n "${DEPLOY_GIT_SHA}" ]
then
  DEPLOY_GIT_SHA=$(echo ${DEPLOY_GIT_SHA} | cut -c1-7)
else
  echo "supply a git commit id"
  exit 1
fi

# set environment variables to be able to talk to the swarm manager
export DOCKER_TLS_VERIFY=1 COMPOSE_TLS_VERSION=TLSv1_2 DTR_URL=dtr1.demo.samgabrail.com DOCKER_CERT_PATH=/var/lib/jenkins/ucp-bundle KUBECONFIG=/var/lib/jenkins/ucp-bundle/kube.yml DOCKER_HOST=tcp://172.31.3.199:12376
#export DOCKER_TLS_VERIFY=1 DOCKER_CERT_PATH=/etc/docker SWARM_MASTER_IP=172.31.3.199 DOCKER_HOST=tcp://${SWARM_MASTER_IP}:2376

# deploy the container
#docker run -d --name jenkinsCoolDemo-${DEPLOY_GIT_SHA} ${DTR_URL}/jenkins/jenkins-demo:${DEPLOY_GIT_SHA}
docker service create -d --name jenkinsCoolDemo-${DEPLOY_GIT_SHA} ${DTR_URL}/jenkins/jenkins-demo:${DEPLOY_GIT_SHA}

# notify user of app being available
echo "Application successfully deployed"
```


