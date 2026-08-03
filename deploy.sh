#!/bin/bash
set -e

echo "Ensuring MicroK8s Registry is enabled..."
sudo microk8s enable registry
sudo microk8s enable dns

echo "Installing Cert Manager (required by SpinKube)..."
sudo microk8s kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml
sudo microk8s kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=90s

echo "Installing kwasm operator..."
sudo microk8s kubectl apply -f https://github.com/KWasm/kwasm-operator/releases/download/v0.3.0/kwasm-operator.yaml
sudo microk8s kubectl annotate node --all kwasm.sh/kwasm-node=true --overwrite

echo "Installing Spin Operator..."
sudo microk8s kubectl apply -f https://github.com/spinkube/spin-operator/releases/download/v0.2.0/spin-operator.runtime-class.yaml
sudo microk8s kubectl apply -f https://github.com/spinkube/spin-operator/releases/download/v0.2.0/spin-operator.crds.yaml
sudo microk8s kubectl apply -f https://github.com/spinkube/spin-operator/releases/download/v0.2.0/spin-operator.yaml
sudo microk8s kubectl wait --for=condition=Available deployment/spin-operator-controller-manager -n spin-operator --timeout=90s

echo "Building and Pushing Spring Boot App using Jib..."
cd springboot-app
./mvnw compile jib:build
cd ..

echo "Building and Pushing Spin App..."
cd spin-app
# Spin requires passing the insecure flag for localhost registry
../spin build
../spin registry push --insecure localhost:32000/spin-app:latest
cd ..

echo "Deploying applications..."
sudo microk8s kubectl apply -f springboot-app/k8s/springboot-deployment.yaml
sudo microk8s kubectl apply -f spin-app/k8s/spinapp.yaml

echo "Waiting for deployments..."
sudo microk8s kubectl wait --for=condition=Available deployment/springboot-app --timeout=60s || true
sudo microk8s kubectl wait --for=condition=Ready spinapp/spin-app --timeout=60s || true

echo "Done! Use 'sudo microk8s kubectl get pods' and 'sudo microk8s kubectl top pods' for comparison."
