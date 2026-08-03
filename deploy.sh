#!/bin/bash
set -e

echo "Ensuring MicroK8s Registry is enabled..."
sudo microk8s enable registry
sudo microk8s enable dns

echo "Installing Cert Manager (required by SpinKube)..."
sudo microk8s kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml
sudo microk8s kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=90s

echo "Enabling Helm3 in MicroK8s..."
sudo microk8s enable helm3

echo "Installing Spin Operator CRDs..."
sudo microk8s kubectl apply -f https://github.com/spinframework/spin-operator/releases/download/v0.6.1/spin-operator.crds.yaml

echo "Installing Runtime Class Manager..."
sudo microk8s helm3 upgrade --install runtime-class-manager --namespace runtime-class-manager --create-namespace --version 0.2.0 oci://ghcr.io/spinframework/charts/runtime-class-manager

echo "Configuring containerd-shim-spin for Runtime Class Manager..."
sudo microk8s kubectl apply -f https://github.com/spinframework/containerd-shim-spin/releases/download/v0.25.1/runtime-class-manager-shim-v1alpha1-v0.25.1.yaml

echo "Installing Spin Operator..."
sudo microk8s kubectl apply -f https://github.com/spinframework/spin-operator/releases/download/v0.6.1/spin-operator.runtime-class.yaml
sudo microk8s helm3 upgrade --install spin-operator --namespace spin-operator --create-namespace --version 0.6.1 oci://ghcr.io/spinframework/charts/spin-operator
sudo microk8s kubectl wait --for=condition=Available deployment/spin-operator-controller-manager -n spin-operator --timeout=90s || true

echo "Ensuring Java 21 is installed for Maven build..."
sudo apt-get update && sudo apt-get install -y openjdk-21-jdk-headless

echo "Building and Pushing Spring Boot App using Jib..."
cd springboot-app
./mvnw compile jib:build
cd ..

echo "Ensuring Rust and wasm32-wasip2 target are installed for Spin app build..."
if ! command -v cargo &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
source "$HOME/.cargo/env"
rustup target add wasm32-wasip2

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
