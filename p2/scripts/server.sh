#!/bin/bash
set -euo pipefail

readonly SERVER_IP="$1"
readonly CONFS_DIR="/vagrant/confs"
readonly K3S_INSTALL_URL="https://get.k3s.io"
readonly KUBECONFIG_MODE="644"
readonly NODE_WAIT_SECONDS=2
readonly READY_TIMEOUT="180s"
readonly POLL_INTERVAL_SECONDS=5
readonly MAX_ROUTING_CHECKS=60

find_interface_for_ip() {
  ip -o -4 addr show | awk -v ip="$SERVER_IP" '$4 ~ "^" ip "/" { print $2 }'
}

install_k3s_server() {
  local interface
  interface="$(find_interface_for_ip)"
  if [ -z "$interface" ]; then
    echo "No network interface has IP $SERVER_IP" >&2
    exit 1
  fi

  curl -sfL "$K3S_INSTALL_URL" | INSTALL_K3S_EXEC="server \
    --node-ip=$SERVER_IP \
    --flannel-iface=$interface \
    --write-kubeconfig-mode=$KUBECONFIG_MODE" sh -
}

wait_for_node_ready() {
  until kubectl get nodes 2>/dev/null | grep -q .; do
    sleep "$NODE_WAIT_SECONDS"
  done
  kubectl wait --for=condition=Ready node --all --timeout="$READY_TIMEOUT"
}

deploy_applications() {
  kubectl apply -f "$CONFS_DIR"
  kubectl wait --for=condition=Available deployment --all --timeout="$READY_TIMEOUT"
}

# K3s installs Traefik asynchronously after boot; port 80 stays closed until it is running.
wait_for_http_routing() {
  local attempt
  for attempt in $(seq 1 "$MAX_ROUTING_CHECKS"); do
    if curl -sf -o /dev/null "http://$SERVER_IP"; then
      echo "Ingress is serving on http://$SERVER_IP"
      return
    fi
    sleep "$POLL_INTERVAL_SECONDS"
  done
  echo "Ingress did not answer on http://$SERVER_IP after $attempt checks" >&2
  exit 1
}

install_k3s_server
wait_for_node_ready
deploy_applications
wait_for_http_routing
