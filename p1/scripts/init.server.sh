#!/bin/bin/bash

# 1 - install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# 2 - install k3s in control plane mode
curl -sfL https://get.k3s.io | sh -