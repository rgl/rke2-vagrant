#!/bin/bash
set -euxo pipefail

rke2_command="$1"; shift
rke2_channel="${1:-latest}"; shift
rke2_version="${1:-v1.24.9+rke2r1}"; shift
ip_address="$1"; shift
krew_version="${1:-v0.4.3}"; shift || true # NB see https://github.com/kubernetes-sigs/krew
fqdn="$(hostname --fqdn)"
rke2_url="https://server.$(hostname --domain):9345"

# configure the motd.
# NB this was generated at http://patorjk.com/software/taag/#p=display&f=Big&t=rke2%0Aserver.
#    it could also be generated with figlet.org.
cat >/etc/motd <<'EOF'

       _        ___
      | |      |__ \
  _ __| | _____   ) |
 | '__| |/ / _ \ / /
 | |  |   <  __// /_
 |_|_ |_|\_\___|____|____ _ __
 / __|/ _ \ '__\ \ / / _ \ '__|
 \__ \  __/ |   \ V /  __/ |
 |___/\___|_|    \_/ \___|_|

EOF

# configure the rke2 server.
# see https://docs.rke2.io/install/configuration
# see https://docs.rke2.io/reference/server_config
install -d -m 700 /etc/rancher/rke2
install /dev/null -m 600 /etc/rancher/rke2/config.yaml
if [ "$rke2_command" != 'cluster-init' ]; then
  cat >>/etc/rancher/rke2/config.yaml <<EOF
server: $rke2_url
token: $(cat /vagrant/tmp/node-token)
EOF
fi
cat >>/etc/rancher/rke2/config.yaml <<EOF
node-ip: $ip_address
node-taint: CriticalAddonsOnly=true:NoExecute
tls-san:
 - server.$(hostname --domain)
 - $fqdn
cni: calico
cluster-cidr: 10.12.0.0/16
service-cidr: 10.13.0.0/16
cluster-dns: 10.13.0.10
cluster-domain: cluster.local
EOF

# install rke2 server.
# see https://docs.rke2.io/install/configuration
# see https://docs.rke2.io/reference/server_config
curl -sfL https://raw.githubusercontent.com/rancher/rke2/$rke2_version/install.sh \
  | \
    INSTALL_RKE2_CHANNEL="$rke2_channel" \
    INSTALL_RKE2_VERSION="$rke2_version" \
    INSTALL_RKE2_TYPE="server" \
    sh -

# start the rke2-server service.
systemctl cat rke2-server
systemctl enable rke2-server.service
systemctl start rke2-server.service

# symlink the utilities and setup the environment variables to use them.
ln -fs /var/lib/rancher/rke2/bin/{kubectl,crictl,ctr} /usr/local/bin/
cat >/etc/profile.d/01-rke2.sh <<'EOF'
export CONTAINERD_ADDRESS=/run/k3s/containerd/containerd.sock
export CONTAINERD_NAMESPACE=k8s.io
export CRI_CONFIG_FILE=/var/lib/rancher/rke2/agent/etc/crictl.yaml
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
EOF
source /etc/profile.d/01-rke2.sh

# install the bash completion scripts.
crictl completion bash >/usr/share/bash-completion/completions/crictl
kubectl completion bash >/usr/share/bash-completion/completions/kubectl

# wait for this node to be Ready.
# e.g. server     Ready    control-plane,etcd,master   3m    v1.24.9+rke2r1
$SHELL -c 'node_name=$(hostname); echo "waiting for node $node_name to be ready..."; while [ -z "$(kubectl get nodes $node_name | grep -E "$node_name\s+Ready\s+")" ]; do sleep 3; done; echo "node ready!"'

# wait for the kube-dns pod to be Running.
# e.g. rke2-coredns-rke2-coredns-7bb4f446c-jksvq   1/1     Running   0          33m
$SHELL -c 'while [ -z "$(kubectl get pods --selector k8s-app=kube-dns --namespace kube-system | grep -E "\s+Running\s+")" ]; do sleep 3; done'

# save the node-token in the host.
# NB do not create a token yourself as a simple hex random string, as that will
#    not include the Cluster CA which means the joining nodes will not
#    verify the server certificate. rke2 warns about this as:
#       Cluster CA certificate is not trusted by the host CA bundle, but the
#       token does not include a CA hash. Use the full token from the server's
#       node-token file to enable Cluster CA validation
if [ "$rke2_command" == 'cluster-init' ]; then
  install -d /vagrant/tmp
  cp /var/lib/rancher/rke2/server/node-token /vagrant/tmp/node-token
fi

# install the krew kubectl package manager.
echo "installing the krew $krew_version kubectl package manager..."
apt-get install -y --no-install-recommends git
wget -qO- "https://github.com/kubernetes-sigs/krew/releases/download/$krew_version/krew-linux_amd64.tar.gz" | tar xzf - ./krew-linux_amd64
wget -q "https://github.com/kubernetes-sigs/krew/releases/download/$krew_version/krew.yaml"
./krew-linux_amd64 install --manifest=krew.yaml
rm krew-linux_amd64
cat >/etc/profile.d/krew.sh <<'EOF'
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
EOF
source /etc/profile.d/krew.sh
kubectl krew version

# save kubeconfig in the host.
if [ "$rke2_command" == 'cluster-init' ]; then
  mkdir -p /vagrant/tmp
  python3 - <<EOF
import base64
import yaml

d = yaml.load(open('/etc/rancher/rke2/rke2.yaml', 'r'))

# save cluster ca certificate.
for c in d['clusters']:
    open(f"/vagrant/tmp/{c['name']}-ca-crt.pem", 'wb').write(base64.b64decode(c['cluster']['certificate-authority-data']))

# save user client certificates.
for u in d['users']:
    open(f"/vagrant/tmp/{u['name']}-crt.pem", 'wb').write(base64.b64decode(u['user']['client-certificate-data']))
    open(f"/vagrant/tmp/{u['name']}-key.pem", 'wb').write(base64.b64decode(u['user']['client-key-data']))
    print(f"Kubernetes API Server https://$ip_address:6443 user {u['name']} client certificate in tmp/{u['name']}-*.pem")

# set the server ip.
for c in d['clusters']:
    c['cluster']['server'] = 'https://$ip_address:6443'

yaml.dump(d, open('/vagrant/tmp/admin.conf', 'w'), default_flow_style=False)
EOF
fi

# show cluster-info.
kubectl cluster-info

# list etcd members.
etcdctl --write-out table member list

# show the endpoint status.
etcdctl --write-out table endpoint status

# list nodes.
kubectl get nodes -o wide

# rbac info.
kubectl get serviceaccount --all-namespaces
kubectl get role --all-namespaces
kubectl get rolebinding --all-namespaces
kubectl get rolebinding --all-namespaces -o json | jq .items[].subjects
kubectl get clusterrole --all-namespaces
kubectl get clusterrolebinding --all-namespaces
kubectl get clusterrolebinding --all-namespaces -o json | jq .items[].subjects

# rbac access matrix.
# see https://github.com/corneliusweig/rakkess/blob/master/doc/USAGE.md
kubectl krew install access-matrix
kubectl access-matrix version --full
kubectl access-matrix # at cluster scope.
kubectl access-matrix --namespace default
kubectl access-matrix --sa kubernetes-dashboard --namespace kubernetes-dashboard

# list system secrets.
kubectl -n kube-system get secret

# list all objects.
# NB without this hugly redirect the kubectl output will be all messed
#    when used from a vagrant session.
kubectl get all --all-namespaces

# really get all objects.
# see https://github.com/corneliusweig/ketall/blob/master/doc/USAGE.md
kubectl krew install get-all
kubectl get-all

# list services.
kubectl get svc

# list running pods.
kubectl get pods --all-namespaces -o wide

# list runnnig pods.
crictl pods

# list running containers.
crictl ps
ctr containers ls

# show listening ports.
ss -n --tcp --listening --processes

# show network routes.
ip route

# show memory info.
free

# show versions.
kubectl version
crictl version
ctr version
