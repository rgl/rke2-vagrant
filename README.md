# About

This is a [rke2](https://github.com/rancher/rke2) kubernetes cluster playground wrapped in a Vagrant environment.

# Usage

Configure your hosts file with:

```
10.11.0.101 server.rke2.test
10.11.0.201 example-app.rke2.test
```

Install the base [Ubuntu 20.04 vagrant box](https://github.com/rgl/ubuntu-vagrant).

Launch the environment:

```bash
time vagrant up --no-destroy-on-error --no-tty --provider=libvirt
```

**NB** The server nodes (e.g. `server1`) are [tainted](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) to prevent them from executing non control-plane workloads. That kind of workload is executed in the agent nodes (e.g. `agent1`).

Access the cluster from the host:

```bash
export KUBECONFIG=$PWD/tmp/admin.conf
kubectl cluster-info
kubectl get nodes -o wide
```

Access the example application:

http://example-app.rke2.test

## Kubernetes API

Access the Kubernetes API at:

    https://server.rke2.test:6443

**NB** You must use the client certificate that is inside the `tmp/admin.conf`,
`tmp/*.pem`, or `/etc/rancher/rke2/rke2.yaml` (inside the `server1` machine)
file.

Access the Kubernetes API using the client certificate with httpie:

```bash
http \
    --verify tmp/default-ca-crt.pem \
    --cert tmp/default-crt.pem \
    --cert-key tmp/default-key.pem \
    https://server.rke2.test:6443
```

Or with curl:

```bash
curl \
    --cacert tmp/default-ca-crt.pem \
    --cert tmp/default-crt.pem \
    --key tmp/default-key.pem \
    https://server.rke2.test:6443
```

## K9s Dashboard

The [K9s](https://github.com/derailed/k9s) console UI dashboard is also
installed in the server node. You can access it by running:

```bash
vagrant ssh server1
sudo su -l
k9s
```
