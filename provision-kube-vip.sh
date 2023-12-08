#!/bin/bash
set -euxo pipefail

kube_vip_version="${1:-v0.6.4}"; shift || true
vip="${1:-10.11.0.100}"; shift || true
kube_vip_rbac_url="https://raw.githubusercontent.com/kube-vip/kube-vip/$kube_vip_version/docs/manifests/rbac.yaml"
kube_vip_image="ghcr.io/kube-vip/kube-vip:$kube_vip_version"
rke2_server_domain="${1}"; shift || true
rke2_server_url="https://$rke2_server_domain:6443"

# load the IPVS kernel modules.
cat >/etc/modules-load.d/ipvs.conf <<'EOF'
ip_vs
ip_vs_rr
EOF
for m in $(cat /etc/modules-load.d/ipvs.conf); do
  modprobe $m
done

# install kube-vip.
# NB this creates a HA VIP (L2 IPVS) for the k8s control-plane k3s/api-server.
# see https://kube-vip.io/docs/usage/k3s/
# see https://kube-vip.io/docs/installation/daemonset/
# see https://kube-vip.io/docs/about/architecture/
ctr image pull "$kube_vip_image"
(
  wget -qO- "$kube_vip_rbac_url"
  echo ---
  ctr run --rm --net-host "$kube_vip_image" vip \
    /kube-vip \
    manifest \
    daemonset \
    --arp \
    --interface eth1 \
    --address "$vip" \
    --inCluster \
    --taint \
    --controlplane \
    --leaderElection
) | kubectl apply -f -

# wait until $rke2_server_url is available.
while ! wget \
  --quiet \
  --spider \
  --ca-certificate=/var/lib/rancher/rke2/server/tls/server-ca.crt \
  --certificate=/var/lib/rancher/rke2/server/tls/client-admin.crt \
  --private-key=/var/lib/rancher/rke2/server/tls/client-admin.key \
  "$rke2_server_url"; do sleep 5; done
