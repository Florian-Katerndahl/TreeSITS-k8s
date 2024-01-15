# TreeSITS-k8s -- Tree Species Classification Run Within a kubernetes Cluster

*Some introductory text*

## Cluster Setup and Configuration

The setup process described below applies only when using the infrastructure provided by EO-Lab. While the
configuration of the cluster itself is indepent of your compute infrastruture or hosting provider, the cluster
creation is specific to your setup.

For further information regarding executing a Nextflow workflow on a kubernetes cluster check out
this repo: https://github.com/seqeralabs/nf-k8s-best-practices. It seems that the linked blog post
https://seqera.io/blog/deploying-nextflow-on-amazon-eks/ offers many useful tips that ended up in the Rangeland
worflow of FONDA as well. This is an alternative source, together with FONDA's geoflow, for useful information.

### Installing `kubectl`

`kubectl` is used to apply kubernetes-objects to the cluster/"run commands against a cluster". See [this part](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-using-native-package-management) of kubernetes' documentation for up-to-date instructions on how to install `kubectl`. At the time of writing, Eo-Lab supports Kubernetes Clusters v1.26, thus the most up-to-date usable version of `kubectl` is v1.27 as per the documentation. Additionally, it is assumed you have a x86-machine running a 64-bit `Ubuntu 20.04.6 LTS`.

:point_right: It is advised to follow the official installation guidelines. :point_left:

```bash
sudo apt update
sudo apt upgrade
sudo apt install apt-transport-https ca-certificates curl

sudo mkdir -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.27/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install kubectl
```

### Command Line Interfaces for EO-Lab (Magnum Clients & OpenStack)

While not strictly needed, installation of command line applications to interact with CloudFerro's services makes the setup process of kubectl simpler.

Refer to the following pages in EO-Labs documentation:

1. https://knowledgebase.eo-lab.org/en/latest/openstackcli/How-to-install-OpenStackClient-for-Linux-on-EO-Lab.html
2. https://knowledgebase.eo-lab.org/en/latest/kubernetes/How-To-Install-OpenStack-and-Magnum-Clients-for-Command-Line-Interface-to-EO-Lab-Horizon.html

Note, that instead of executing the supplied OpenStack-RC file, it needs to be executed in the current shell, i.e. sourced. Otherwise, the environment 
variables will not be usable by programs run afterwards.

```bash
pip3 install python-openstackclient python-magnumclient lxml

source cloud_xxxx/xxx-openrc.sh
```

### Creating a Cluster

- Master Node (running the Control Plane) does not need to be as powerfull as the worker node as no data processing is done here

The cluster definitions below apply to the workflows described here. They're subject to frequent changes and may be outdated.

```bash
```

### Configuring `kubectl` to acces EO-Lab Cluster

After successfully creating a cluster and a successful setup of the OpenStack and Magnum clients, 
`kubectl` can be configured to connect to your cluster. Kubernetes looks for the environment variable `KUBECONFIG` or for `$HOME/.kube/config`. 
The process is detailed here: https://knowledgebase.eo-lab.org/en/latest/kubernetes/How-To-Access-Kubernetes-Cluster-Post-Deployment-Using-Kubectl-On-EO-Lab-OpenStack-Magnum.html

```bash
cd $HOME
opentack coe cluster config --dir .kube --output-certs <cluster-name>
```

If you specify `$HOME/.kube` as the output directory as mentioned above, you don't need to set the `KUBECONFIG` environment variable by adding the scripts 
output to your shell's RC file. However, when storing credentials to different clusters, it's likely better to seperate directories and update the 
`KUBECONFIG` environment variable.

### Creating PVCs, Pods et cetera

## Starting a Workflow

### Implemented Workflows

#### One-And-Done Tree Species Classification Using LSTM-Models

*To be implemented*

#### One-And-Done Tree Species Classification Using Transformer-Models

*To be implemented*

#### Continous Tree Species Classification Using Transformer-Models

*To be implemented*

### Starting Workflows Using `kuberun` vs. in-cluster-start

- `kuberun` is said to be unstable (see Links above)
- during the development phase, kuberun was used to test setups (at least that's the plan at the time of writing).
For completeness, their documentation is not removed as it may serve for future reference.

## Getting Results off of your Cluster

