cardano-socat
=============================

Docker image to support forwarding file based sockets to TCP and TCP to file based sockets. Tested using the cardano-node, cardano-db-sync, cardano-wallet-server

### Current Status:
This isn't completed yet! We'll remove this banner once we're ready!

### Why
------------
While running cardano nodes, dbsync, postgres and wallet-server we found it difficult to meet the minimum hardware requirements and remain scalable/stable with all of our custom software components. 
When a [hardfork](#Learning-About-Cardano-Hardforks-the-Hard-Way) comes along we often found ourselves down or struggling last minute to keep up.

We run a kubernetes cluster, separating our logical units of work using namespaces.
In the past, our software components that require the cardano-cli or such, required access to the socket file, limiting us to the same local machine or some sort of filesystem networking (nfs...).

We wanted to use our own image!

### Solution
------------
This cardano-socat component allows us to install the "server" version with the cardano node and a "client" version elsewhere. The server version connects to the linux file socket and sets up a TCP listener over a port we decide. The client version connects to the TCP port and IP address of the server and writes the linux file socket to the location we choose. This means a cardano component such as a dbsync can be on separate hardware and simply listen to the node socket. We can chain this and have several clients/servers running so we can simply change our workload configurations to use a new cardano setup.

What a game changer for us, we could run separate compute units for the cardano components, simplifying our hardware requirements and sticking with the pets vs cattle mentality. In the past our pets vs cattle story was always following the logic that a cardano unit is a pet, rather than having more than one running at the same time and simply forwarding traffic to the favoured one.

Now we can simply run an ansible script, creating the compute unit, adding it as a node to Kubernetes and configuring it to run the favoured version of cardano node or... Sanity restored (almost).

### Solution Caveats - dyor, caveat emptor, blaah blah
-----
As always with open source software, we do not promise anything, we hope this works for you, and would love to help you out if you get stuck or suffer any issues.
Cardano designed their software using file sockets on purpose, while I'm not really a fan of this I do appreciate the effort. Our systems are secured using several methods, including 2FA, firewalls and more. 
Please make sure you DO NOT expose these TCP ports over the internet without running in a secure tunnel or something similar. We use private networks to transmit this!


### Installation and Usage
------------
- Run a local testnet Daedalus
- Once it's ready note your environment variable $CARDANO_NODE_SOCKET_PATH as it points to the socket we're going to extend
```bash 
echo $CARDANO_NODE_SOCKET_PATH
```

TODO:// we shouldn't point mount points at the node.socket file directly, only the directory up by one


Running in server mode
```bash
export CSS_SOURCE_SOCKET_PATH=${CARDANO_NODE_SOCKET_PATH}
export CSS_DESTINATION_TCP_PORT=3317
sudo docker run -it --rm --name cardano_socat_server \
	-p 9965:${CSS_DESTINATION_TCP_PORT} \
	--privileged \
	-v ${CSS_SOURCE_SOCKET_PATH}:/cardano-socat/node.socket \
	-e SOURCE_SOCKET_PATH=/cardano-socat/node.socket \
	-e DESTINATION_TCP_PORT=${CSS_DESTINATION_TCP_PORT} \
	bigthink/cardano:socat-v1.0.0 --socket-file-to-tcp
```

Running in client mode
```bash
export CSC_SOURCE_TCP_PORT=9965
export CSC_DESTINATION_SOCKET_PATH=/cardano-socat-test-client/data/test/cardano-node/data/node.socket
export CSC_DESTINATION_SOCKET_PATH_ROOT=/cardano-socat-test-client/data/test/cardano-node/data
export LOCAL_DESTINATION_SOCKET_PATH=~/cardano-socat-test-client/data/test/cardano-node/data
mkdir -p ${LOCAL_DESTINATION_SOCKET_PATH}
export CSC_SOURCE_IP=$(ipconfig getifaddr en0) # or whatever network adaptor you use
or
export CSC_SOURCE_IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' cardano_socat_server)

sudo docker run -it --rm --name cardano_socat_client \
	--privileged \
	-v ${LOCAL_DESTINATION_SOCKET_PATH}:${CSC_DESTINATION_SOCKET_PATH_ROOT} \
	-e DESTINATION_SOCKET_PATH=${CSC_DESTINATION_SOCKET_PATH} \
	-e SOURCE_TCP_PORT=${CSC_SOURCE_TCP_PORT} \
	-e SOURCE_IP=${CSC_SOURCE_IP} \
	bigthink/cardano:socat-v1.0.0 --tcp-to-socket-file
```

TODO:// this isn't correct yet!
Running a cardano-node to query tip on the new socket file
cardano-cli query tip --testnet-magic 1097911063

```bash
export CSC_DESTINATION_SOCKET_PATH_ROOT=/cardano-socat-test-client/data/test/cardano-node/data
export LOCAL_DESTINATION_SOCKET_PATH=~/cardano-socat-test-client/data/test/cardano-node/data
mkdir -p ${LOCAL_DESTINATION_SOCKET_PATH}/config
wget -O ${LOCAL_DESTINATION_SOCKET_PATH}/config/config.json https://hydra.iohk.io/build/7654130/download/1/testnet-config.json
wget -O ${LOCAL_DESTINATION_SOCKET_PATH}/config/shelley-genesis.json https://hydra.iohk.io/build/7654130/download/1/testnet-shelley-genesis.json
wget -O ${LOCAL_DESTINATION_SOCKET_PATH}/config/byron-genesis.json https://hydra.iohk.io/build/7654130/download/1/testnet-byron-genesis.json
wget -O ${LOCAL_DESTINATION_SOCKET_PATH}/config/alonzo-genesis.json https://hydra.iohk.io/build/7654130/download/1/testnet-alonzo-genesis.json
wget -O ${LOCAL_DESTINATION_SOCKET_PATH}/config/topology.json https://hydra.iohk.io/build/7654130/download/1/testnet-topology.json


sudo docker run -it --rm --name cardano_client \
	--privileged \
	-v ${LOCAL_DESTINATION_SOCKET_PATH}:${CSC_DESTINATION_SOCKET_PATH_ROOT} \
	-e CARDANO_NODE_SOCKET_PATH=${LOCAL_DESTINATION_SOCKET_PATH}/node.socket \
	-e NETWORK="--testnet-magic 1097911063" \
	inputoutput/cardano-node:1.30.1 \
	--config ${CSC_DESTINATION_SOCKET_PATH_ROOT}/config.json \
    --topology ${CSC_DESTINATION_SOCKET_PATH_ROOT}/topology.json \
	"cardano-cli query tip"
```

### Usage examples and Design Patterns
------------
Coming Soon, this will show examples of how to relay traffic from server to client. This can be done with several systems, possibly allowing multiple rpi's to be connected to solve, and more such as k8s !

### Learning About Cardano Hardforks the Hard Way
-----
Yes, during our start with Cardano development, we studied what a hardfork event meant. Seemed pretty clear, things would change in the way blocks are written and we'd upgrade to a new version of the services that understood those changes. Crystal clear! Simple! Not really! Nobody tells you this is about to happen.
We struggled learning that a hard fork was coming. Why? When? Do we have a way of being told about this?
We're often busy building software, we're not out there searching for when a hardfork will hit. This has bit us on more than one occassion.

Why doesn't Cardano publish this on their homepage? They must have an idea when it's coming!

The folks at [adapools](https://adapools.org/latest) seem to have it figured out, when a hardfork was on its way the versions being used increases, thereby hinting that around 90% usage of a version means hardfork was happening within 24 hours. One day we will write a bot that tells us these things automatically, so we're always on top of it.

The [Cardano Compatibilty Matrix](https://docs.cardano.org/tools/comp-matrix) doesn't help us too much with this but it's useful to see

### Shoutouts - sites we found useful tips and hints on
Just wanted to thank the people that participated in solving similar problems:
- https://medium.com/neoncat-io/how-to-communicate-with-the-cardano-node-on-a-remote-host-fe05dfd1bb94
- https://github.com/input-output-hk/cardano-wallet/issues/1556
- https://github.com/binlab/docker-socat
- https://lihsmi.ch/docker/2020/01/02/socat-docker.html

