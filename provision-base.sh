#!/bin/bash
set -euxo pipefail

extra_hosts="$1"; shift || true

# set the extra hosts.
cat >>/etc/hosts <<EOF
$extra_hosts
EOF

# prevent apt-get et al from asking questions.
# NB even with this, you'll still get some warnings that you can ignore:
#     dpkg-preconfigure: unable to re-open stdin: No such file or directory
export DEBIAN_FRONTEND=noninteractive

# # make sure the system does not uses swap (a kubernetes requirement).
# # NB see https://kubernetes.io/docs/tasks/tools/install-kubeadm/#before-you-begin
# swapoff -a
# sed -i -E 's,^([^#]+\sswap\s.+),#\1,' /etc/fstab

# show mac/ip addresses and the machine uuid to troubleshoot they are unique within the cluster.
ip addr
cat /sys/class/dmi/id/product_uuid

# update the package cache.
apt-get update

# expand the root partition.
apt-get install -y --no-install-recommends parted
partition_device="$(findmnt -no SOURCE /)"
partition_number="$(echo "$partition_device" | perl -ne '/(\d+)$/ && print $1')"
disk_device="$(echo "$partition_device" | perl -ne '/(.+?)\d+$/ && print $1')"
parted ---pretend-input-tty "$disk_device" <<EOF
resizepart $partition_number 100%
yes
EOF
resize2fs "$partition_device"

# install jq.
apt-get install -y jq

# install curl.
apt-get install -y curl

# install the bash completion.
apt-get install -y bash-completion

# install vim.
apt-get install -y --no-install-recommends vim
cat >/etc/vim/vimrc.local <<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
EOF

# configure the shell.
cat >/etc/profile.d/login.sh <<'EOF'
[[ "$-" != *i* ]] && return
export EDITOR=vim
export PAGER=less
alias l='ls -lF --color'
alias ll='l -a'
alias h='history 25'
alias j='jobs -l'
EOF

cat >/etc/inputrc <<'EOF'
set input-meta on
set output-meta on
set show-all-if-ambiguous on
set completion-ignore-case on
"\e[A": history-search-backward
"\e[B": history-search-forward
"\eOD": backward-word
"\eOC": forward-word
EOF

# install arp-scan.
# arp-scan lets us discover nodes in the local network.
# e.g. arp-scan --localnet --interface eth1
apt-get install -y --no-install-recommends arp-scan

# install useful tools.
apt-get install -y --no-install-recommends \
    tcpdump \
    traceroute \
    iptables \
    ipvsadm \
    ipset
