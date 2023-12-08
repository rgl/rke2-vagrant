# to make sure the nodes are created in order, we
# have to force a --no-parallel execution.
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

require 'ipaddr'

# see https://update.rke2.io/v1-release/channels
# see https://github.com/rancher/rke2/releases
RKE2_CHANNEL = 'latest'
RKE2_VERSION = 'v1.26.0+rke2r2'
# see https://github.com/etcd-io/etcd/releases
# NB make sure you use the same version as rke2.
ETCDCTL_VERSION = 'v3.5.5'
# see https://github.com/derailed/k9s/releases
K9S_VERSION = 'v0.27.0'
# see https://github.com/kubernetes-sigs/krew/releases
KREW_VERSION = 'v0.4.4'

DOMAIN                  = 'rke2.test'
RKE2_SERVER_DOMAIN      = "server.#{DOMAIN}"
RKE2_SERVER_URL         = "https://#{RKE2_SERVER_DOMAIN}:9345"

RKE2_WINDOWS_SERVICE_USE_NSSM = true

NUMBER_OF_SERVER_NODES  = 1
NUMBER_OF_AGENT_NODES   = 1
NUMBER_OF_AGENTW_NODES  = 1

FIRST_SERVER_NODE_IP    = '10.11.0.101'
FIRST_AGENT_NODE_IP     = '10.11.0.201'
FIRST_AGENTW_NODE_IP    = '10.11.0.211'

EXTRA_HOSTS = """
#{FIRST_SERVER_NODE_IP} #{RKE2_SERVER_DOMAIN}
"""

def generate_nodes(first_ip_address, count, name_prefix)
  ip_addr = IPAddr.new first_ip_address
  (1..count).map do |n|
    ip_address, ip_addr = ip_addr.to_s, ip_addr.succ
    name = "#{name_prefix}#{n}"
    fqdn = "#{name}.#{DOMAIN}"
    [name, fqdn, ip_address, n]
  end
end

SERVER_NODES  = generate_nodes(FIRST_SERVER_NODE_IP, NUMBER_OF_SERVER_NODES, 'server')
AGENT_NODES   = generate_nodes(FIRST_AGENT_NODE_IP, NUMBER_OF_AGENT_NODES, 'agent')
AGENTW_NODES  = generate_nodes(FIRST_AGENTW_NODE_IP, NUMBER_OF_AGENTW_NODES, 'agentw')

Vagrant.configure(2) do |config|
  config.vm.box = 'ubuntu-22.04-amd64'

  config.vm.provider 'libvirt' do |lv, config|
    lv.cpus = 2
    lv.cpu_mode = 'host-passthrough'
    lv.nested = true
    lv.keymap = 'pt'
    lv.machine_virtual_size = 64
    config.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_version: '4.2', nfs_udp: false
  end

  SERVER_NODES.each do |name, fqdn, ip_address, n|
    config.vm.define name do |config|
      config.vm.provider 'libvirt' do |lv, config|
        lv.memory = 4*1024
      end
      config.vm.hostname = fqdn
      config.vm.network :private_network, ip: ip_address, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
      config.vm.provision 'shell', path: 'provision-base.sh', args: [EXTRA_HOSTS]
      config.vm.provision 'shell', path: 'provision-etcdctl.sh', args: [ETCDCTL_VERSION]
      config.vm.provision 'shell', path: 'provision-k9s.sh', args: [K9S_VERSION]
      config.vm.provision 'shell', path: 'provision-rke2-server.sh', args: [
        n == 1 ? "cluster-init" : "cluster-join",
        RKE2_CHANNEL,
        RKE2_VERSION,
        ip_address,
        KREW_VERSION
      ]
      if n == 1
        config.vm.provision 'shell', path: 'provision-example-app.sh'
      end
    end
  end

  AGENT_NODES.each do |name, fqdn, ip_address, n|
    config.vm.define name do |config|
      config.vm.provider 'libvirt' do |lv, config|
        lv.memory = 4*1024
      end
      config.vm.hostname = fqdn
      config.vm.network :private_network, ip: ip_address, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
      config.vm.provision 'shell', path: 'provision-base.sh', args: [EXTRA_HOSTS]
      config.vm.provision 'shell', path: 'provision-rke2-agent.sh', args: [
        RKE2_CHANNEL,
        RKE2_VERSION,
        RKE2_SERVER_URL,
        ip_address
      ]
    end
  end

  AGENTW_NODES.each do |name, fqdn, ip_address, n|
    config.vm.define name do |config|
      config.vm.box = 'windows-2022-amd64'
      config.vm.provider 'libvirt' do |lv, config|
        lv.memory = 4*1024
        config.vm.synced_folder '.', '/vagrant',
          type: 'smb',
          smb_username: ENV['VAGRANT_SMB_USERNAME'] || ENV['USER'],
          smb_password: ENV['VAGRANT_SMB_PASSWORD']
      end
      config.vm.hostname = name
      config.vm.network :private_network, ip: ip_address, libvirt__forward_mode: 'none', libvirt__dhcp_enabled: false
      config.vm.provision 'shell', path: 'ps.ps1', args: 'provision-containers-feature.ps1', reboot: true
      config.vm.provision 'shell', path: 'ps.ps1', args: 'provision-chocolatey.ps1'
      config.vm.provision 'shell', path: 'ps.ps1', args: ['provision-base.ps1', EXTRA_HOSTS]
      config.vm.provision 'shell', path: 'ps.ps1', args: [
        'provision-rke2-agent.ps1',
        RKE2_CHANNEL,
        RKE2_VERSION,
        RKE2_SERVER_URL,
        ip_address,
        RKE2_WINDOWS_SERVICE_USE_NSSM && '1' || '0'
      ]
    end
  end
end
