RCBOPS HA Stack in a Box
########################
:date: 2013-11-06 09:51
:tags: rackspace, openstack, private cloud, development, chef, cookbooks
:category: \*nix


So you want to try Openstack?
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Want to build a cloud? Want to try Openstack? Curious how the Openstack Cloud ecosystem all works? In the past you, the cloud operator, had to have a lot of tribal knowledge to simply stand Openstack up. In later releases, Openstack became more robust and better documented, but the process to build all of the components of Openstack into a working system was still arduous. Today the general community is vibrant with eager people who want to help spread the goodness of Openstack around, and we have a myriad of methods for installing Openstack and consuming the fruits of the communal labor.


Cloud as an Instance!
^^^^^^^^^^^^^^^^^^^^^

The Openstack cloud has grown to encompass some amazing projects. These projects allow for authentication, imaging, orchestration, monitoring, compute, and many more. If you were curious how all this works together, you'd have a few ready made options. One is Devstack, another is PackStack, and then there is this one. As you are reading you may think to yourself, what method is this one? The script is easy to understand and hack on but allows for a robust deployment of Openstack. The real mustard behind this single script is the Open Source Chef cookbooks project produced by the Rackspace Private Cloud Development Team (1). The cookbooks serve as the basis for the deployment mechanism, but the script allows all of the bits to come together and work seamlessly.


Getting Cloudy
^^^^^^^^^^^^^^

To begin using the script you have have to have a Linux operating system available with at least 15GB Hard disk and 2GB or RAM. Your Linux operating system must be Ubuntu 12.04 at this time. I mention the OS restriction because I have not tested anything other than Ubuntu 12.04

* When using Ubuntu the stock 3.2 Kernel works out of the box but it may be wise to upgrade to the 3.8 kernel as it's a better code base and has better support for Neutron networking and some hypervisors such as LXC and Docker.  To upgrade to the 3.8 Kernel in Ubuntu please go to the `Raring Kernel in Precise`_ section of this doc and read it.

I have tested this installation on Rackspace Public Cloud, HP Cloud, VMFusion 6, Virtual Box 4.3.x, Amazon Ubuntu 12.04 AMI, Desktop, and KVM.


How to use The Script
^^^^^^^^^^^^^^^^^^^^^

**YOU** have to populate the IP addresses for Controller **1** and **2** as well as The IP addresses for your Compute nodes.  Additionally you will need to Populate the **VIP_PREFIX** with the first three octets of your VIP address. You should run this script on the node designated as **controller1**.  IE: Login to controller 1, filling the blanks or set some environment variables and run the script.

This script will build you an environment using the Rackspace Private Cloud software and will have most, if not all, of the current offerings of the Rackspace Private cloud. This script was created to provide an environment which resembles an environment built by the Rackspace Private Cloud support team. This script is **NOT** for production use and is **NOT** a sanctioned product from Rackspace.  This is a development tool made by me and I have shared it with you.  Please submit bug reports to to me directly using github issues.


To use this script the first step is to build at least 3 servers.

* Two Controllers
* One Compute Node

This script can scale out. Simply add more compute nodes to the **COMPUTE_NODES** variable.


Set the Variables that you NEED
-------------------------------


Here are all of the variables that **NEED** to be set. I recommend that you write these variables to a file and then source the file prior to running the script. While that is my recommendation it is not required you could simply run the following exports into your shell and then execute the script.

NOTICE: I have set my network in the examples provided to be "10.0.0.0" this is just an example, Change these network settings to something that you are using. Other common networks are "192.168.0.0" or "172.16.0.0" you just have to use the right class of network for your installation.


Rabbit Password::

  export RMQ_PW="secrete"


Rabbit IP address, this should be an IP address on your management network::

  export RMQ_IP="10.0.0.1"


Set the cookbook version that we will upload to chef::

  export COOKBOOK_VERSION="master"


SET THE NODE IP ADDRESSES::

  export CONTROLLER1="10.0.0.1"
  export CONTROLLER2="10.0.0.2"


ADD ALL OF THE COMPUTE NODE IP ADDRESSES, SPACE SEPARATED::

  export COMPUTE_NODES="10.0.0.3 10.0.0.4"


Set the VIP Prefix. IE: the beginning of your IP Addresses for all your VIPS::

  export VIP_PREFIX="10.0.0"

NOTICE: This makes a lot of assumptions for your VIPS. The environment uses .154, .155, .156 for your HA VIPS.


The name of the network to be used with neutron::

  export PROVIDER_NETWORK="eth1"


Execute the script::

  curl https://raw.github.com/cloudnull/rcbops_ha_stack/master/rcbops_ha_stack.sh | bash


* When you first execute the script, you will be asked for the passwords for all of your nodes you have set in config. These passwords are required to upload an SSH key from controller 1 to all of the boxes in your environment. The uploaded key will be used throughout the bootstrap process.
* Now simply sit back and enjoy my hard work and watch cloud cook. When done, you will have a functional Openstack Cloud with two controller nodes and some number of compute nodes.


What is Happening Here
^^^^^^^^^^^^^^^^^^^^^^

When you use this script here is what is happening. On Controller 1 RabbitMQ is installed then chef server is installed using the latest "stable" chef server as provided from the omni-truck API. Once these processes are ready the cookbooks and roles are cloned on to the system, uploaded to chef server. Finally the Controller Node bootstraps itself as Openstack Controller 1. Next, the script then bootstraps Controller 2 with all of the needed bits. Once the controllers are all online the script bootstraps the rest of the compute nodes. Upon completion of the bootstrapping Controller 1 and 2 chef-client is run one more time on both of the controllers which finallizes the installation.


========


*Raring Kernel in Precise*
--------------------------

Update your Repositories::

  sudo apt-get update


Install the new Kernel Image and headers::

  sudo apt-get install linux-image-generic-lts-raring linux-headers-generic-lts-raring


Reboot the System::

  sudo reboot


========


NOTES
~~~~~

* If you run this script on a cloud server, IE Rackspace Public Cloud Servers, I recommend you use a "cloud network" to isolate your traffic between your compute nodes and your controllers. While, you could simply use SNET(Service Net) for all of your VIP addresses you will need to make changes to this script or add more nodes to your installation base.
* This script assumes you will have at least 2 networks installed on the nodes. You should have setup eth0 and eth1 when provisioning your operating system. If you are not sure, run `ip a` to see what networks and interfaces you have on your proposed boxes.  If you are building on a Rackspace Cloud Server I recommend that you use a cloud network which will not only provide you a network segment which can be controller by you it will also provide you an interface to use with your cloud networks. If you use a cloud network the default interface will be "ETH2".
* This script presently only supports Ubuntu 12.04, please don't cry if the you attempt to run this and it does not work on RHEL-ish systems.  If you would like to have RHEL support added please create a github issue asking for a feature request, or submit a Pull request with the required changes. Pull requests are welcome!
* This script was create to allow for rapid deployment of a testing nodes based on the Rackspace Private Cloud Chef Cookbooks.
* This script assumes that you will be deploying version 4.2.x or later of the Rackspace Private Cloud Software. This has not been tested on earlier versions of the cookbooks.
* This script will not build networks for you. Thats your job.
* This script will not upload images that also your job.


Foot Notes
~~~~~~~~~~

1) I work for Rackspace on the Rackspace Private Cloud Team and am a member of the development group responsible for the Chef cookbooks used in this installation process. While I am a Racker and this Installation script uses The Rackspace Private Cloud Software I have contributed to this installation process and procedure is not an official installation process. I built this installation process for myself and have on my own decided to share it with the world.  By no means does this installation application contain proprietary data and or access to anything which may be considered proprietary.



I WOULD NOT RECOMMEND USING THIS IN PRODUCTION!
-----------------------------------------------


License:
  Copyright [2014] [Kevin Carter]

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

