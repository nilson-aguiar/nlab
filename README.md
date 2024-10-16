# Homelab

This is the companion configuration that goes with the video from [Dreams of Autonomy](https://youtu.be/2yplBzPCghA).

This project is split into different directories depending on each service used.

## Requirements

To use this, you'll need the following installed on your sysetm

- nix
- kubectl
- helmfile
- helm
- git

Additionally, you'll also want to make changes to the user information found in the `nixos/configuration.nix`

## nixos

This directory contains the nixos configuration for setting
up each node with k3s.

The configuration makes use of nix flakes under the hood, with each node configuration being:

```
homelab-0
homelab-1
homelab-2
```

To set up a node from fresh, you can use [nixos-anywhere](https://github.com/nix-community/nixos-anywhere). This requires loading the nixos installer and then booting the node into it. You can then install remotely once you've set the nodes password using the `passwd` command. 

The command I use is as follows:

```shell
nix run github:nix-community/nixos-anywhere \
--extra-experimental-features "nix-command flakes" \
-- --flake '.#homelab-0' nixos@192.168.1.100 
```

`--build-on-remote` can be added in the end of the command in case you don't have a laptop with the same architecture, but cache won't be re-used in this case.

make sure to replace with your own ip.

After finished you can copy the connection details from `homelab-0` with:

```shell
scp -r naguiar@homelab-0:/etc/rancher/k3s/k3s.yaml .kube/config
```

then open the copied file and update the ip for the server

When changes are made you can update the node using:

```shell
sudo nixos-rebuild switch --flake github:nilson-aguiar/nlab?dir=nixos
```

## helm

This directory is used to store the helm configuration of the node and is managed using [helmfile](https://github.com/helmfile/helmfile), which is a declarative spec for defining helm charts.

To install this on your cluster, you can simply use the following command.

```
helmfile apply
```


## kustomize

Kustomize allows you to manage multiple manifest files in a `Kustomize.yaml`, which also allows you to override values if you need to.

I don't use Kustomize that much in the video, but it's a tool I do often use and is available in `kubectl`.


## Istio

Testing istio configurations with istioctl

```shell
istioctl install -y \
    --set profile=ambient \
    --set values.cni.cniConfDir=/var/lib/rancher/k3s/agent/etc/cni/net.d \
    --set values.cni.cniBinDir=/var/lib/rancher/k3s/data/current/bin/ \
    --set meshConfig.accessLogFile=/dev/stdout \
    --set "components.egressGateways[0].name=istio-egressgateway" \
    --set "components.egressGateways[0].enabled=true" \
    --set values.pilot.env.PILOT_ENABLE_IP_AUTOALLOCATE=true \
    --set values.cni.ambient.dnsCapture=true
```