# to make sure the nodes are created in order, we
# have to force a --no-parallel execution.
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

require 'ipaddr'

# see https://update.rke2.io/v1-release/channels
# see https://github.com/rancher/rke2/releases
rke2_channel = 'latest'
rke2_version = 'v1.24.9+rke2r1'
# see https://github.com/etcd-io/etcd/releases
# NB make sure you use the same version as rke2.
etcdctl_version = 'v3.5.4'
# see https://github.com/derailed/k9s/releases
k9s_version = 'v0.26.7'
# see https://github.com/kubernetes-sigs/krew/releases
krew_version = 'v0.4.3'

number_of_server_nodes  = 1
number_of_agent_nodes   = 1

first_server_node_ip    = '10.11.0.101'
first_agent_node_ip     = '10.11.0.201'

server_node_ip_address  = IPAddr.new first_server_node_ip
agent_node_ip_address   = IPAddr.new first_agent_node_ip

domain                  = 'rke2.test'
rke2_server_domain      = "server.#{domain}"
rke2_server_url         = "https://#{rke2_server_domain}:9345"

extra_hosts = """
#{first_server_node_ip} #{rke2_server_domain}
"""

Vagrant.configure(2) do |config|
  config.vm.box = 'ubuntu-20.04-amd64'

  config.vm.provider 'libvirt' do |lv, config|
    lv.cpus = 2
    lv.cpu_mode = 'host-passthrough'
    lv.nested = true
    lv.keymap = 'pt'
    config.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_version: '4.2', nfs_udp: false
  end

  (1..number_of_server_nodes).each do |n|
    name = "server#{n}"
    fqdn = "#{name}.#{domain}"
    ip_address = server_node_ip_address.to_s; server_node_ip_address = server_node_ip_address.succ

    config.vm.define name do |config|
      config.vm.provider 'libvirt' do |lv, config|
        lv.memory = 3*1024
      end
      config.vm.hostname = fqdn
      config.vm.network :private_network, ip: ip_address, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
      config.vm.provision 'shell', path: 'provision-base.sh', args: [extra_hosts]
      config.vm.provision 'shell', path: 'provision-etcdctl.sh', args: [etcdctl_version]
      config.vm.provision 'shell', path: 'provision-k9s.sh', args: [k9s_version]
      config.vm.provision 'shell', path: 'provision-rke2-server.sh', args: [
        n == 1 ? "cluster-init" : "cluster-join",
        rke2_channel,
        rke2_version,
        ip_address,
        krew_version
      ]
      if n == 1
        config.vm.provision 'shell', path: 'provision-example-app.sh'
      end
    end
  end

  (1..number_of_agent_nodes).each do |n|
    name = "agent#{n}"
    fqdn = "#{name}.#{domain}"
    ip_address = agent_node_ip_address.to_s; agent_node_ip_address = agent_node_ip_address.succ

    config.vm.define name do |config|
      config.vm.provider 'libvirt' do |lv, config|
        lv.memory = 3*1024
      end
      config.vm.hostname = fqdn
      config.vm.network :private_network, ip: ip_address, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
      config.vm.provision 'shell', path: 'provision-base.sh', args: [extra_hosts]
      config.vm.provision 'shell', path: 'provision-rke2-agent.sh', args: [
        rke2_channel,
        rke2_version,
        rke2_server_url,
        ip_address
      ]
    end
  end
end
