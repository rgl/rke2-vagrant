#!/bin/bash
set -euxo pipefail

# Get latest kube-vip tag
IMAGE_TAG_LATEST=$(curl -sL https://api.github.com/repos/kube-vip/kube-vip/releases | jq -r ".[0].name")

VIP="$1"; shift
INTERFACE="${1:-}"; shift || true
IMAGE_TAG="${1:-$IMAGE_TAG_LATEST}"; shift || true

# https://docs.rke2.io/install/ha/
#
# This endpoint can be set up using any number approaches, such as:
#
# * A layer 4 (TCP) load balancer
# * Round-robin DNS
# * Virtual or elastic IP addresses
#
# https://kube-vip.chipzoller.dev/docs/installation/daemonset/
# https://www.youtube.com/watch?v=QqSgiezqMAA
# https://gist.github.com/bgulla/7a6a72bdc5df6febb1e22dbc32f0ca4f

crictl pull ghcr.io/kube-vip/kube-vip:$IMAGE_TAG

mkdir -p /var/lib/rancher/rke2/server/manifests/

curl -s https://kube-vip.io/manifests/rbac.yaml > /var/lib/rancher/rke2/server/manifests/kube-vip-rbac.yaml
ctr --namespace k8s.io run --rm --net-host ghcr.io/kube-vip/kube-vip:$IMAGE_TAG vip /kube-vip \
    manifest daemonset \
    --interface $INTERFACE \
    --address $VIP \
    --inCluster \
    --taint \
    --controlplane \
    --services \
    --arp \
    --leaderElection | tee /var/lib/rancher/rke2/server/manifests/kube-vip.yaml
