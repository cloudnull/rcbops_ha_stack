#!/usr/bin/env bash

set -e
set -v
set -u


# Copyright [2013] [Kevin Carter]
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# This is a crude script which will deploy an openstack HA environment
# YOU have to populate the IP addresses for Controller 1 and 2 as well as
# The IP addresses for your compute nodes.  Additionally you will need to
# Populate the PUB_PREFIX with the first three octets of your VIP addresses.
# You should run this script on the node designated as controller1.

# This script will build you an environment using the Rackspace Private Cloud
# software and will have most, if not all, of the current offerings of the
# Rackspace Private cloud. This script was created to provide an environment
# which resembles environments built by the Rackspace Private Cloud support
# team. This script is NOT for production User and is NOT a sanctioned product
# from Rackspace.  This is a development too made by me and I have shared it
# with you.  Please submit bug reports to to me directly using github issues.


# NOTICE:
# If you run this script on a cloud server, IE Rackspace Public Cloud Servers,
# I recommend you use a "cloud network" to isolate your traffic between
# your compute nodes and your controllers. While, you could simply use
# SNET(Service Net) as your VIP addresses changes and or more nodes will be
# required. IF YOU USE SOMETHING LIKE SERVICE NET ON A CLOUD SERVER YOU WILL
# NOT CONTROL ALL OF THE NETWORK ADDRESS SPACE!

# This script presently only supports Ubuntu 12.04, please don't cry if the
# you attempt to run this and it does not work on RHEL-ish systems.  If you
# would like to have RHEL support added please create a github issue asking
# for a feature request. or submit a Pull request with the required changes.


# What is Happening Here:
# Controller1 is built with Chef Server, RabbitMQ, and Openstack Controller
# all on the same box.  The controller2 is added into the pool. After Controller1
# and controller2 are built all compute nodes are bootstrapped.



# Rabbit Password
RMQ_PW=${RMQ_PW:-"Passw0rd"}

# Rabbit IP address, this should be the host ip which is on
# the same network used by your management network
RMQ_IP=${RMQ_IP:-"10.0.0.1"}

# Set the cookbook version that we will upload to chef
COOKBOOK_VERSION=${COOKBOOK_VERSION:-"master"}

# SET THE NODE IP ADDRESSES
CONTROLLER1=${CONTROLLER1:-"10.0.0.1"}
CONTROLLER2=${CONTROLLER2:-"10.0.0.2"}

# ADD ALL OF THE COMPUTE NODE IP ADDRESSES, SPACE SEPARATED.
COMPUTE_NODES=${COMPUTE_NODES:-"10.0.0.3 10.0.0.4"}

# This is the VIP prefix, IE the beginning of your IP addresses for all your VIPS.
# Note, This makes a lot of assumptions for your PUBLIC_PREFIX. The environment use
# .154, .155, .156 for your HA VIPS.  All of these can be the same IP address.

PUB_PREFIX=${PUB_PREFIX:-"10.0.0"}
MANAGEMENT_PREFIX=${MANAGEMENT_PREFIX:-"10.0.1"}
NOVA_PREFIX=${NOVA_PREFIX:-"10.0.2"}

# The name of the network to be used with neutron
PROVIDER_NETWORK=${PROVIDER_NETWORK:-"eth2"}


# Make the system key used for bootstrapping self and others.
if [ ! -f "/root/.ssh/id_rsa" ];then
    ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ''
    pushd /root/.ssh/
    cat id_rsa.pub | tee -a authorized_keys
    popd
fi

# Send your key out to all of your nodes.
for node in ${CONTROLLER1} ${CONTROLLER2} ${COMPUTE_NODES};do
    ssh-copy-id ${node}
done

apt-get update
apt-get install -y python-dev python-pip git erlang erlang-nox erlang-dev curl lvm2
pip install git+https://github.com/cloudnull/mungerator
RABBIT_URL="http://www.rabbitmq.com"

function rabbit_setup() {
    if [ ! "$(rabbitmqctl list_vhosts | grep -w '/chef')" ];then
      rabbitmqctl add_vhost /chef
    fi

    if [ "$(rabbitmqctl list_users | grep -w 'chef')" ];then
      rabbitmqctl delete_user chef
    fi

    rabbitmqctl add_user chef "${RMQ_PW}"
    rabbitmqctl set_permissions -p /chef chef '.*' '.*' '.*'
}

function install_apt_packages() {
    RABBITMQ_KEY="${RABBIT_URL}/rabbitmq-signing-key-public.asc"
    wget -O /tmp/rabbitmq.asc ${RABBITMQ_KEY};
    apt-key add /tmp/rabbitmq.asc
    RABBITMQ="${RABBIT_URL}/releases/rabbitmq-server/v3.1.5/rabbitmq-server_3.1.5-1_all.deb"
    wget -O /tmp/rabbitmq.deb ${RABBITMQ}
    dpkg -i /tmp/rabbitmq.deb
    rabbit_setup

    CHEF="https://www.opscode.com/chef/download-server?p=ubuntu&pv=12.04&m=x86_64"
    CHEF_SERVER_PACKAGE_URL=${CHEF}
    wget -O /tmp/chef_server.deb ${CHEF_SERVER_PACKAGE_URL}
    dpkg -i /tmp/chef_server.deb
}

function CREATE_SWAP() {

  cat > /tmp/swap.sh <<EOF
#!/usr/bin/env bash
if [ ! "\$(swapon -s | grep -v Filename)" ];then
  SWAPFILE="/SwapFile"
  if [ -f "\${SWAPFILE}" ];then
    swapoff -a
    rm \${SWAPFILE}
  fi
  dd if=/dev/zero of=\${SWAPFILE} bs=1M count=1024
  chmod 600 \${SWAPFILE}
  mkswap \${SWAPFILE}
  swapon \${SWAPFILE}
fi
EOF

  cat > /tmp/swappiness.sh <<EOF
#!/usr/bin/env bash
SWAPPINESS=\$(sysctl -a | grep vm.swappiness | awk -F' = ' '{print \$2}')

if [ "\${SWAPPINESS}" != 60 ];then
  sysctl vm.swappiness=60
fi
EOF

  if [ ! "$(swapon -s | grep -v Filename)" ];then
    chmod +x /tmp/swap.sh
    chmod +x /tmp/swappiness.sh
    /tmp/swap.sh && /tmp/swappiness.sh
  fi
}

CREATE_SWAP
install_apt_packages

mkdir -p /etc/chef-server
cat > /etc/chef-server/chef-server.rb <<EOF
erchef["s3_url_ttl"] = 3600
nginx["ssl_port"] = 4000
nginx["non_ssl_port"] = 4080
nginx["enable_non_ssl"] = true
rabbitmq["enable"] = false
rabbitmq["password"] = "${RMQ_PW}"
rabbitmq["vip"] = "${RMQ_IP}"
rabbitmq['node_ip_address'] = "${RMQ_IP}"
chef_server_webui["web_ui_admin_default_password"] = "THISisAdefaultPASSWORD"
bookshelf["url"] = "https://#{node['ipaddress']}:4000"
EOF

chef-server-ctl reconfigure

sysctl net.ipv4.conf.default.rp_filter=0 | tee -a /etc/sysctl.conf
sysctl net.ipv4.conf.all.rp_filter=0 | tee -a /etc/sysctl.conf
sysctl net.ipv4.ip_forward=1 | tee -a /etc/sysctl.conf

bash <(wget -O - http://opscode.com/chef/install.sh)

SYS_IP=$(ohai ipaddress | awk '/^ / {gsub(/ *\"/, ""); print; exit}')
export CHEF_SERVER_URL=https://${SYS_IP}:4000

# Configure Knife
mkdir -p /root/.chef
cat > /root/.chef/knife.rb <<EOF
log_level                :info
log_location             STDOUT
node_name                'admin'
client_key               '/etc/chef-server/admin.pem'
validation_client_name   'chef-validator'
validation_key           '/etc/chef-server/chef-validator.pem'
chef_server_url          "https://${SYS_IP}:4000"
cache_options( :path => '/root/.chef/checksums' )
cookbook_path            [ '/opt/chef-cookbooks/cookbooks' ]
EOF


if [ ! -d "/opt/" ];then
    mkdir -p /opt/
fi

if [ -d "/opt/chef-cookbooks" ];then
    rm -rf /opt/chef-cookbooks
fi

git clone https://github.com/rcbops/chef-cookbooks.git /opt/chef-cookbooks
pushd /opt/chef-cookbooks
git checkout ${COOKBOOK_VERSION}
git submodule init
git submodule sync
git submodule update


# Get add-on Cookbooks
knife cookbook site download -f /tmp/cron.tar.gz cron 1.2.6
tar xf /tmp/cron.tar.gz -C /opt/chef-cookbooks/cookbooks

knife cookbook site download -f /tmp/chef-client.tar.gz chef-client 3.0.6
tar xf /tmp/chef-client.tar.gz -C /opt/chef-cookbooks/cookbooks

# Upload all of the RCBOPS Cookbooks
knife cookbook upload -o /opt/chef-cookbooks/cookbooks -a
popd

# Save the erlang cookie
if [ ! -f "/var/lib/rabbitmq/.erlang.cookie" ];then
    ERLANG_COOKIE="ANYSTRINGWILLDOJUSTFINE"
else
    ERLANG_COOKIE="$(cat /var/lib/rabbitmq/.erlang.cookie)"
fi

# DROP THE BASE ENVIRONMENT FILE
cat > /opt/base.env.json <<EOF
{
  "name": "RCBOPS_Openstack_Environment",
  "description": "Environment for Openstack Private Cloud",
  "cookbook_versions": {
  },
  "json_class": "Chef::Environment",
  "chef_type": "environment",
  "default_attributes": {
  },
  "override_attributes": {
    "monitoring": {
      "procmon_provider": "monit",
      "metric_provider": "collectd"
    },
    "enable_monit": true,
    "osops_networks": {
      "management": "${MANAGEMENT_PREFIX}.0/24",
      "swift": "${MANAGEMENT_PREFIX}.0/24",
      "public": "${PUB_PREFIX}.0/24",
      "nova": "${NOVA_PREFIX}.0/24"
    },
    "rabbitmq": {
      "cluster": true,
      "erlang_cookie": "${ERLANG_COOKIE}"
    },
    "nova": {
      "config": {
        "use_single_default_gateway": false,
        "ram_allocation_ratio": 1.0,
        "disk_allocation_ratio": 1.0,
        "cpu_allocation_ratio": 2.0,
        "resume_guests_state_on_host_boot": false
      },
      "network": {
        "provider": "neutron"
      },
      "scheduler": {
        "default_filters": [
          "AvailabilityZoneFilter",
          "ComputeFilter",
          "RetryFilter"
        ]
      },
      "libvirt": {
        "vncserver_listen": "0.0.0.0",
        "virt_type": "qemu"
      }
    },
    "keystone": {
      "pki": {
        "enabled": false
      },
      "admin_user": "admin",
      "tenants": [
        "service",
        "admin",
        "demo",
        "demo2"
      ],
      "users": {
        "admin": {
          "password": "secrete",
          "roles": {
            "admin": [
              "admin"
            ]
          }
        },
        "demo": {
          "password": "secrete",
          "default_tenant": "demo",
          "roles": {
            "Member": [
              "demo2",
              "demo"
            ]
          }
        },
        "demo2": {
          "password": "secrete",
          "default_tenant": "demo2",
          "roles": {
            "Member": [
              "demo2",
              "demo"
            ]
          }
        }
      }
    },
    "neutron": {
      "ovs": {
        "external_bridge": "",
        "network_type": "gre",
        "provider_networks": [
          {
            "bridge": "br-${PROVIDER_NETWORK}",
            "vlans": "1024:1024",
            "label": "ph-${PROVIDER_NETWORK}"
          }
        ]
      },
      "lbaas": {
        "enabled": true
      },
      "vpnaas": {
        "enabled": true
      },
      "fwaas": {
        "enabled": true
      }
    },
    "mysql": {
      "tunable": {
        "log_queries_not_using_index": false
      },
      "allow_remote_root": true,
      "root_network_acl": "127.0.0.1"
    },
    "vips": {
      "horizon-dash": "${PUB_PREFIX}.156",
      "keystone-service-api": "${PUB_PREFIX}.156",
      "nova-xvpvnc-proxy": "${PUB_PREFIX}.156",
      "nova-api": "${PUB_PREFIX}.156",
      "cinder-api": "${PUB_PREFIX}.156",
      "nova-ec2-public": "${PUB_PREFIX}.156",
      "config": {
        "${PUB_PREFIX}.156": {
          "vrid": 12,
          "network": "public"
        },
        "${PUB_PREFIX}.154": {
          "vrid": 10,
          "network": "public"
        },
        "${PUB_PREFIX}.155": {
          "vrid": 11,
          "network": "public"
        }
      },
      "rabbitmq-queue": "${PUB_PREFIX}.155",
      "nova-novnc-proxy": "${PUB_PREFIX}.156",
      "mysql-db": "${PUB_PREFIX}.154",
      "glance-api": "${PUB_PREFIX}.156",
      "keystone-internal-api": "${PUB_PREFIX}.156",
      "horizon-dash_ssl": "${PUB_PREFIX}.156",
      "glance-registry": "${PUB_PREFIX}.156",
      "neutron-api": "${PUB_PREFIX}.156",
      "ceilometer-api": "${PUB_PREFIX}.156",
      "ceilometer-central-agent": "${PUB_PREFIX}.156",
      "heat-api": "${PUB_PREFIX}.156",
      "heat-api-cfn": "${PUB_PREFIX}.156",
      "heat-api-cloudwatch": "${PUB_PREFIX}.156",
      "keystone-admin-api": "${PUB_PREFIX}.156"
    },
    "glance": {
      "image_upload": false
    },
    "osops": {
      "do_package_upgrades": false,
      "apply_patches": false
    },
    "developer_mode": false
  }
}
EOF


# Upload all of the RCBOPS Roles
knife role from file /opt/chef-cookbooks/roles/*.rb
knife environment from file /opt/base.env.json

# Build all the things
knife bootstrap -E RCBOPS_Openstack_Environment -r role[ha-controller1],role[single-network-node] ${CONTROLLER1}
knife bootstrap -E RCBOPS_Openstack_Environment -r role[ha-controller2],role[single-network-node] ${CONTROLLER2}

# Bootstrap all of the compute nodes.
for node in ${COMPUTE_NODES};do
  ssh root@${node} < /tmp/swap.sh
  ssh root@${node} < /tmp/swappiness.sh
  knife bootstrap -E RCBOPS_Openstack_Environment -r role[single-compute] ${node}
done

ssh root@${CONTROLLER1} "chef-client"
ssh root@${CONTROLLER2} "chef-client"

echo "All Done!"
