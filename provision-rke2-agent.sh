#!/bin/bash
set -euxo pipefail

rke2_channel="$1"; shift
rke2_version="$1"; shift
rke2_server_url="$1"; shift
rke2_token="$1"; shift
ip_address="$1"; shift

# configure the motd.
# NB this was generated at http://patorjk.com/software/taag/#p=display&f=Big&t=rke2%0Aagent.
#    it could also be generated with figlet.org.
cat >/etc/motd <<'EOF'

       _        ___
      | |      |__ \
  _ __| | _____   ) |
 | '__| |/ / _ \ / /     _
 | |  |   <  __// /_    | |
 |_|_ |_|\_\___|____|__ | |_
  / _` |/ _` |/ _ \ '_ \| __|
 | (_| | (_| |  __/ | | | |_
  \__,_|\__, |\___|_| |_|\__|
         __/ |
        |___/

EOF

# install rke2 agent.
# see https://docs.rke2.io/install/install_options/install_options/
# see https://docs.rke2.io/install/install_options/linux_agent_config/
install -d -m 700 /etc/rancher/rke2
install /dev/null -m 600 /etc/rancher/rke2/config.yaml
cat >>/etc/rancher/rke2/config.yaml <<EOF
server: $rke2_server_url
token: $rke2_token
node-ip: $ip_address
EOF
curl -sfL https://raw.githubusercontent.com/rancher/rke2/$rke2_version/install.sh \
  | \
    INSTALL_RKE2_CHANNEL="$rke2_channel" \
    INSTALL_RKE2_VERSION="$rke2_version" \
    INSTALL_RKE2_TYPE="agent" \
    sh -

# start the rke2-agent service.
systemctl cat rke2-agent
systemctl enable rke2-agent.service
systemctl start rke2-agent.service

# symlink the utilities and setup the environment variables to use them.
# NB kubectl should not be available in worker nodes as rke2 does not
#    install a kubeconfig.
ln -fs /var/lib/rancher/rke2/bin/{kubectl,crictl,ctr} /usr/local/bin/
cat >/etc/profile.d/01-rke2.sh <<'EOF'
export CONTAINERD_ADDRESS=/run/k3s/containerd/containerd.sock
export CONTAINERD_NAMESPACE=k8s.io
export CRI_CONFIG_FILE=/var/lib/rancher/rke2/agent/etc/crictl.yaml
EOF
source /etc/profile.d/01-rke2.sh

# NB do not try to use kubectl on a agent node, as kubectl does not work on a
#    agent node without a proper kubectl configuration (which you could copy
#    from the server, but we do not do it here).

# install the bash completion scripts.
crictl completion bash >/usr/share/bash-completion/completions/crictl
kubectl completion bash >/usr/share/bash-completion/completions/kubectl

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
crictl version
ctr version
