# Spring Boot vs Spin (WASM) on MicroK8s

This repository demonstrates running a simple web application using two completely different paradigms on a Kubernetes cluster (MicroK8s):

1. **Spring Boot (Java):** A traditional robust containerized application.
2. **Spin (WASM/Rust):** A lightweight, serverless WebAssembly component deployed via SpinKube.

## Applications

Both applications implement two HTTP endpoints:
- `/hello`: Returns a plain string "Hello, World!"
- `/compute`: Calculates the 35th Fibonacci number recursively (to simulate CPU load).

## Deployment

Run the `deploy.sh` script to set up SpinKube on MicroK8s, build the apps, push them to the local registry, and deploy them. Note: You will need `sudo` for `microk8s` commands.

```bash
./deploy.sh
```

## Comparison Metrics

After deployment, you can observe the following differences:

### 1. Image / Artifact Size
- **Spring Boot:** Typically 100-200MB depending on the JRE base image.
- **Spin (WASM):** Typically a few megabytes (~2-5MB) as it only contains the compiled Wasm module.

### 2. Startup Time
- **Spring Boot:** Usually takes a few seconds (1-5s) to start the JVM and Spring Application Context.
- **Spin (WASM):** Starts in sub-milliseconds because it doesn't run a long-lived server; the Wasmtime runtime spins up per-request or stays warm with negligible overhead.

### 3. Resource Usage (Idle)
Run `sudo microk8s kubectl top pods` to see memory footprint.
- **Spring Boot:** Expect it to reserve 100-300MB of RAM just sitting idle.
- **Spin (WASM):** The SpinApp Pod running `containerd-shim-spin` will consume practically no idle resources compared to a JVM.

### 4. Development Experience
- **Spring Boot:** Feature-rich ecosystem, easy to test, standard Dockerfile pipeline.
- **Spin:** Instant compilation (with Rust/Go), easy to write serverless-like functions, but requires specific operators (SpinKube/Kwasm) on the Kubernetes cluster.
