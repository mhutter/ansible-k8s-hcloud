#!/bin/bash
set -e -u -o pipefail

### Config
NETWORK_NAME="$(awk '/hcloud_network_name:/{print $2}' group_vars/all.yml)"

LOCATION="${LOCATION:-fsn1}"
SSH_KEY="${SSH_KEY:-rokkit2020}"
IMAGE_ID="${IMAGE_ID:-11543187}"
MASTER_TYPE="${MASTER_TYPE:-cx21}"
WORKER_TYPE="${WORKER_TYPE:-cx31}"

FIP_NAME="${FIP_NAME:-ingress}"
###

create_network() {
  if hcloud network describe "$NETWORK_NAME" &>/dev/null; then
    echo "Network $NETWORK_NAME already exists"
    return
  fi

  hcloud network create --name "$NETWORK_NAME" \
    --ip-range 10.98.0.0/16
  hcloud network add-subnet "$NETWORK_NAME" --network-zone eu-central \
    --type server --ip-range 10.98.0.0/16
}

create_server() {
  local name="$1"
  local type="$2"

  if hcloud server describe "$name" &>/dev/null; then
    echo "Server $name already exists"
    return
  fi

  hcloud server create --name "$name" \
    --type "$type" \
    --location "$LOCATION" \
    --image "$IMAGE_ID" \
    --ssh-key "$SSH_KEY" \
    --network "$NETWORK_NAME" \
    --user-data-from-file cloud-config.yml
}

create_floating_ip() {
  if hcloud floating-ip describe "$FIP_NAME" &>/dev/null; then
    echo "Floating IP $FIP_NAME already exists"
    return
  fi

  hcloud floating-ip create --name "$FIP_NAME" \
    --type ipv4 --home-location "$LOCATION"
}


create_network
create_server master-99d4 "$MASTER_TYPE"
create_server worker-2c22 "$WORKER_TYPE"
create_server worker-91fd "$WORKER_TYPE"
create_server worker-b2d2 "$WORKER_TYPE"
create_floating_ip

fip="$(hcloud floating-ip describe "$FIP_NAME" -o json | jq .ip --raw-output)"
echo "hcloud_floating_ip: '$fip'"
