#!/bin/bash
set -e

CONFIG_FILE="/var/snap/microk8s/current/args/containerd-template.toml"

if ! grep -q '\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.spin\]' "$CONFIG_FILE"; then
    echo "Adding Spin runtime to MicroK8s containerd configuration..."
    
    cat <<EOF | sudo tee -a "$CONFIG_FILE" > /dev/null

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.spin]
          runtime_type = "io.containerd.spin.v2"
EOF
    
    echo "Downloading and installing containerd-shim-spin-v2 to /usr/local/bin..."
    curl -LO https://github.com/spinframework/containerd-shim-spin/releases/download/v0.25.1/containerd-shim-spin-v2-linux-x86_64.tar.gz
    sudo tar -C /usr/local/bin -xzf containerd-shim-spin-v2-linux-x86_64.tar.gz
    rm containerd-shim-spin-v2-linux-x86_64.tar.gz

    echo "Restarting MicroK8s to apply containerd changes..."
    microk8s stop
    microk8s start
    echo "Done! The spin-app pod should now start automatically."
else
    echo "Spin runtime is already configured in $CONFIG_FILE."
    
    if [ ! -f "/usr/local/bin/containerd-shim-spin-v2" ]; then
        echo "Shim binary missing in /usr/local/bin. Installing..."
        curl -LO https://github.com/spinframework/containerd-shim-spin/releases/download/v0.25.1/containerd-shim-spin-v2-linux-x86_64.tar.gz
        sudo tar -C /usr/local/bin -xzf containerd-shim-spin-v2-linux-x86_64.tar.gz
        rm containerd-shim-spin-v2-linux-x86_64.tar.gz
    fi

    echo "Restarting MicroK8s just in case..."
    microk8s stop
    microk8s start
fi
