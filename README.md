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

##### Running Locally using Docker and Daedalus
- Run a local testnet Daedalus
- Once it's ready note your environment variable $CARDANO_NODE_SOCKET_PATH as it points to the socket we're going to extend
```bash 
echo $CARDANO_NODE_SOCKET_PATH
```

Running in server mode
```bash
export LOCAL_TCP_PORT=9965
# -v mount our directory where the node.socket file resides
docker run -it --rm --name cardano_socat_server \
	-p ${LOCAL_TCP_PORT}:3317 \
	-v $(dirname $CARDANO_NODE_SOCKET_PATH):/cardano-socat-test-client/data/test/cardano-node/data \
	-e SOURCE_SOCKET_PATH=/cardano-socat-test-client/data/test/cardano-node/data/node.socket \
	-e DESTINATION_TCP_PORT=3317 \
	bigthink/cardano:socat-v1.0.0 --socket-file-to-tcp
```

Running in client mode
```bash
export LOCAL_DESTINATION_SOCKET_PATH=~/cardano-socat-test-client/data/test/cardano-node/data
mkdir -p ${LOCAL_DESTINATION_SOCKET_PATH}
export CSC_SOURCE_IP=$(ipconfig getifaddr en0) # or whatever network adaptor you use
or
export CSC_SOURCE_IP=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' cardano_socat_server)

docker run -it --rm --name cardano_socat_client \
	-v ${LOCAL_DESTINATION_SOCKET_PATH}:/cardano-socat-test-client/data/test/cardano-node/data \
	-e DESTINATION_SOCKET_PATH=/cardano-socat-test-client/data/test/cardano-node/data/node.socket \
	-e SOURCE_TCP_PORT=${LOCAL_TCP_PORT} \
	-e SOURCE_IP=${CSC_SOURCE_IP} \
	bigthink/cardano:socat-v1.0.0 --tcp-to-socket-file
```

Running a cardano-cli locally to show the uses
- From the same system running the client mode as above, run this to show the cli at work
- Try stopping cardano_socat_client and running this command, note how it stops working!
```bash
docker run -it --rm --name cardano-cli \
	-v ${LOCAL_DESTINATION_SOCKET_PATH}:/cardano-socat-test-client/data/test/cardano-node/data \
	-v /data \
	-e NETWORK=testnet \
	-e CARDANO_NODE_SOCKET_PATH=/cardano-socat-test-client/data/test/cardano-node/data/node.socket \
	--entrypoint "/usr/local/bin/cardano-cli" \
	inputoutput/cardano-node:1.30.1 \
	query tip --testnet-magic 1097911063
```

##### Running in Kubernetes:
- TODO:// this should have more details, it might be nice to have an actually mini kube showcasing everything but...
- Run the server on a compute unit that's running a cardano node as a relay or producer
- Ensure you know the path of the socket file and adjust DIRECTORY_TO_CARDANO_NODE_SOCKET_FILE_WITHOUT_SOCKET_FILE_SUFFIX below
- Note that we do NOT want the socket file in the path of DIRECTORY_TO_CARDANO_NODE_SOCKET_FILE_WITHOUT_SOCKET_FILE_SUFFIX
- WARNING: Don't test this out on mainnet, use a testnet node first

Running in server mode
```bash
export LOCAL_TCP_PORT=9965
# -v mount our directory where the node.socket file resides without the actual socket file name
docker run -it --rm --name cardano_socat_server \
	-p ${LOCAL_TCP_PORT}:3317 \
	-v DIRECTORY_TO_CARDANO_NODE_SOCKET_FILE_WITHOUT_SOCKET_FILE_SUFFIX:/cardano-socat-test-client/data/test/cardano-node/data \
	-e SOURCE_SOCKET_PATH=/cardano-socat-test-client/data/test/cardano-node/data/node.socket \
	-e DESTINATION_TCP_PORT=3317 \
	bigthink/cardano:socat-v1.0.0 --socket-file-to-tcp
```

Running in client mode (on a separate compute unit or use different directory to write the socket file)
```bash
# this is the directory on your host
export LOCAL_DESTINATION_SOCKET_PATH=~/cardano-socat-test-client/data/test/cardano-node/data
mkdir -p ${LOCAL_DESTINATION_SOCKET_PATH}
# get the ip and port of cardano_socat_server and ensure you have mount points in place
#	if you're using PV's set that up instead
# replace IP_GOES_HERE with the of of cardano_socat_server

docker run -it --rm --name cardano_socat_client \
	-v ${LOCAL_DESTINATION_SOCKET_PATH}:/cardano-socat-test-client/data/test/cardano-node/data \
	-e DESTINATION_SOCKET_PATH=/cardano-socat-test-client/data/test/cardano-node/data/node.socket \
	-e SOURCE_TCP_PORT=${LOCAL_TCP_PORT} \
	-e SOURCE_IP=IP_GOES_HERE \
	bigthink/cardano:socat-v1.0.0 --tcp-to-socket-file
```

Running a cardano-cli in your k8s cluster
- From the same system running the client mode as above, run this to show the cli at work
- Try stopping cardano_socat_client and running this command, note how it stops working!
```bash
docker run -it --rm --name cardano-cli \
	-v ${LOCAL_DESTINATION_SOCKET_PATH}:/cardano-socat-test-client/data/test/cardano-node/data \
	-v /data \
	-e NETWORK=testnet \
	-e CARDANO_NODE_SOCKET_PATH=/cardano-socat-test-client/data/test/cardano-node/data/node.socket \
	--entrypoint "/usr/local/bin/cardano-cli" \
	inputoutput/cardano-node:1.30.1 \
	query tip --testnet-magic 1097911063
```

That's all for now!

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

