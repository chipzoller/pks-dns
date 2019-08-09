# pks-dns
Automate the DNS record creation process for your VMware PKS clusters right from the cluster.

## What Is This?

`pks-dns.ps1` is a script written in PowerShell that is designed to be run from within your Kubernetes cluster that automates the end-to-end process of creating the necessary DNS records for a requestor to access their cluster externally.

## Why Do I Want This?

PKS (AKA "[Enterprise PKS](https://cloud.vmware.com/vmware-enterprise-pks)", "[Pivotal Container Service](https://pivotal.io/platform/pivotal-container-service)", "VMware PKS") is a solution designed to allow for the rapid and easy instantiation of Kubernetes clusters on a variety of different clouds, including on-premises via VMware vSphere. It provides a more-or-less turnkey approach to the otherwise difficult and cumbersome task of provisioning K8s clusters as well as allows for lifecycle management (upgrading, scaling, and healing) simultaneously. However, while it performs these tasks well, the final step required for a user to access his/her cluster is to create the necessary DNS records. In other words, although the K8s cluster might be up and running and ready for use, until DNS records exist, the cluster is inaccessible. This project aims to fix that by automating that DNS record addition process from **inside the cluster itself** without requiring additional automation "wrapper" tools for that process.

## How Does It Work?

Well, I'm glad you asked. This script (`pks-dns.ps1`) first uses `kubectl` to extract the node labels from your K8s nodes. It finds the name of your K8s cluster as you set from a `pks create-cluster` command then watches the PKS REST API for the availbility of the corresponding IP address of the API endpoint. Once it has this, it connects to a remote Windows jump box via SSH to add the DNS records via PowerShell using the [RSAT](https://support.microsoft.com/en-us/help/2693643/remote-server-administration-tools-rsat-for-windows-operating-systems).

## What Is Needed To Run?

There are a few tools required for this script to work properly:

* `pks-dns.ps1`
*  PowerShell Core 6.2+
* `kubectl`
* `sshpass`
* `openssh-client`
*  Any Linux distribution

## How Do I Get Started?

As mentioned above, in order for all this work properly, it needs to be run from **inside** your Kubernetes cluster. This means that it must run as a container wrapped in a Pod. There are a couple of ways to accomplish this.

1. You can either build your own Docker image from scratch by including this script and host in your own image registry.
2. You can use my convenient Dockerfile (included) to quickly build an image yourself (also host in your own registry).
3. You can pull my pre-built image directly from the repository on [Docker Hub](https://hub.docker.com/r/chipzoller/pks-dns)

Regardless of which method you choose, a Kubernetes manifest will need to be created for you to have this automatically pulled and executed whenever a new K8s cluster is built by PKS. Also fortunate for you, I have pre-built this manifest ready to be dropped inside a PKS plan.

## I'm Ready To Roll

Sounds good! Prior to that, best have a read of my article [here](https://www.sovsystems.com/blog/optimize-vmwarepks-a-powershell-script-for-all-your-vmware-pks-deployment-needs-0) which tells you all you need to know to get those sparks flying.
