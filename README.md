# TreeSITS-k8s -- Tree Species Classification Run Within a kubernetes Cluster

Transformers and LSTMs for tree species classification from satellite image time series bundled together with workflows and kubeconfig objects to assist *one-and-done* and near-realtime workflow execution on homogenous and heterogenous compute infrastructure.

## Cluster Setup and Configuration

The setup process described below applies only when using the infrastructure provided by EO-Lab. While the configuration of the cluster itself is indepent of your compute infrastruture or hosting provider, the clustercreation is specific to your setup.

For further information regarding executing a Nextflow workflow on a kubernetes cluster check out this repo: https://github.com/seqeralabs/nf-k8s-best-practices. It seems that the linked blog post https://seqera.io/blog/deploying-nextflow-on-amazon-eks/ offers many useful tips that ended up in the Rangeland worflow of FONDA as well. This is an alternative source, together with FONDA's geoflow, for useful information.

### Install `kubectl`

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

Note, that instead of executing the supplied OpenStack-RC file, it needs to be executed in the current shell, i.e. sourced. Otherwise, the environment variables will not be usable by programs run afterwards.

> [!WARNING]
> You need to source this file everytime you create a new session (e.g. new terminal session, new ssh session, reboot, etc.).

```bash
pip3 install python-openstackclient python-magnumclient lxml

source cloud_xxxx/xxx-openrc.sh
```

### Create a Cluster

The cluster definition below applies to the workflows described here. It's subject to frequent changes and may be outdated. The master node is intentionally assigned a lower-spec Vm flavor as no data processing is done here.

> [!WARNING]
> Depending on your wallet settings and approved compute quotas, certain VM flavors may or may not be available. This however, is seemingly not represented in the error messages. When resource quotas should not be exhausted by the queries while the error messages suggest over-usage of certain resource types (e.g. vCPU), you likely tried to use a flavor not available to you. If errors persist, contact the EO-Lab support team. Additionally, due to quirks of EO-Lab, you must manually set the `etcd_volume_type` to either `hdd` or `__DEFAULT__` except when you're a paying client of CODE-DE. Then, you can use the SSD volumes (but you'd need to pay for them nonetheless).

```bash
 openstack coe cluster create \
    --cluster-template k8s-1.23.16-v1.0.3 \
    --keypair <name-of-previously-generated-keypair> \
    --master-count 1 --master-flavor eo1.large \ 
    --node-count 7 --flavor hm.2xlarge \
    --labels eodata_access_enabled=true,min_node_count=1,max_node_count=7,auto_healing_enabled=true,auto_scaling_enabled=false,etcd_volume_type='__DEFAULT__' --merge-labels \
    --master-lb-enabled \
    <cluster-name>
```

### Add Additional Pods, Potentially of Different Flavor, to Existing Cluster

Additional node groups can be added to the above-created cluster. They do not need to have the same host-image nor be the same compute flavor, i.e. this allows you to create a heterogenous compute environment.

The command below adds 1 node with the `vm.a6000.4` flavor (8 CPUs, 80Gb disk space, 57Gb RAM, Nvidia A6000) with the `Ubuntu 22.04 NVIDIA_AI` image as the host operating system to the cluster `<cluster-name>`. This configuration allows the nodes belonging to the nodegroup `gpu` to automatically scale between 1 and 4 instances. All labels set when the cluster was originally created are merged (applied) with the ones of this new node group.

> [!WARNING]
> The addition of GPU-flavored VMs only works if the cluster template used supports GPUs. I.e. `k8s-1.23.16-vgpu-v1.0.0`.

```bash
openstack coe nodegroup create \
    --node-count 1 --min-nodes 1 --max-nodes 4 \
    --role worker \
    --flavor vm.a6000.4 --image c14f8254-ecdf-4734-9214-569420220899 \
    --merge-labels \
    <cluster-name> gpu

openstack coe nodegroup create \
    --node-count 1 --min-nodes 1 --max-nodes 2 \
    --role worker \
    --flavor hm.xlarge --image 4236365e-9f14-41ff-9841-7c7f58af5e5b \
    --merge-labels \
    <cluster-name> addons
```

To delete the above-created node group, e.g. to free up resource for stand-alone VMs, execute the following command:

```bash
openstack coe nodegroup delete <cluster-name> gpu
openstack coe nodegroup delete <cluster-name> addons
```

### Configure `kubectl` to acces EO-Lab Cluster

After successfully creating a cluster and a successful setup of the OpenStack and Magnum clients, `kubectl` can be configured to connect to your cluster. Kubernetes looks for the environment variable `KUBECONFIG` or for `$HOME/.kube/config`. The process is detailed here: https://knowledgebase.eo-lab.org/en/latest/kubernetes/How-To-Access-Kubernetes-Cluster-Post-Deployment-Using-Kubectl-On-EO-Lab-OpenStack-Magnum.html

```bash
cd $HOME
openstack coe cluster config --dir .kube --output-certs <cluster-name>
```

If you specify `$HOME/.kube` as the output directory as mentioned above, you don't need to set the `KUBECONFIG` environment variable by adding the scripts output to your shell's RC file. However, when storing credentials to different clusters, it's likely better to seperate directories and update the `KUBECONFIG` environment variable.

### Create ServiceAccounts, PVCs, Pods et cetera

After creating the cluster, provisioning additional nodes, etc. some further cluster operations are needed either to facilitate workflow execution in general or allow for easier testing/staging.

#### ServiceAccount

- PodSecurityPolicy must be referenced

In order to perform actions, i.e. submit new desired states, in the kubernetes cluster one must authenticate to the API server. For processes that run inside the cluster itself but need to manage the cluster state, so-called ServiceAccounts exist. Since Nextflow needs to create, manage, delete, supervise, etc. a service account is needed. Such a service account is bound to a role via a role binding. The role kubeconfig describes the actions any service account bound to it is allowed to perform. For further information, see [here](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/).

```bash
kubectl apply -f kubernetes/nextflow-serviceaccount.yml
```

#### PersistentVolume and PersistentVolumeClaim

The filesystem used by containers is ephemeral by default. Thus, any changes such as the creation of new files etc. does not persist container restarts. Additionally, sharing files between containers within the same pod or across different pods is difficult to set up only in the container scope. Kubernetes offers the abstractions of volumes, a directory containing data accessible by containers inside of pods, to address above-mentioned issues. The basis for in-cluster volume are so-called storageClasses which define how new storage gets provisioned and what its characteristics are. Building on top of storageClasses are different volume types. Here, only persistentVolumes are of interest which are particular pieces of storage. They can be requested/bound by a persistentVolumeClaim which is not bound to the lifecycle of a particular pod and can thus be used to make files, such as the intermediate files created by a scientific workflow, to be accessible to all other pods and thus containers in the cluster. The neccessary PVCs as well as the integration of the FORCE community data cube via NFS are described in `kubernetes/volumes.yml`.

```bash
kubectl apply -f kubernetes/volumes.yml
```

> [!NOTE]
> While three of the four volumes defined in this file are not used, it also contains the definition needed to use the FORCE Community Cube inside the cluster. Thus, the command above needs to be executed depending from where you execute the workflow (see below).

##### AWS S3 Buckets

Unfortunately, the current openstack implementation of CloudFerro does not seem to match the requirements for the above-mentioned configuration to work correctly. The only available storageClass `cinder-csi` generally allows all access modes supported by kubernetes (see [here](https://github.com/kubernetes/cloud-provider-openstack/issues/1367#issuecomment-761981909) and [the official documentation](https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/cinder-csi-plugin/features.md#multi-attach-volumes)). However, on EO-Lab infrastructure, [the only mode implemented](https://knowledgebase.eo-lab.org/en/latest/kubernetes/Persistent-Volumes-and-Persistent-Volume-Claims-on-EO-Lab-FRA1-1-Server.html?highlight=persistentvolumeclaim#types-of-cinder-csi-persistence) is `RWO`, i.e. *ReadWriteOnce*. Thus, only a single Pod can access a PVC at a time. Alternatives are AWS S3 buckets, NFS-shares or using other external programs such as `rsync`. As storageClasses form the basis of all volumes inside kubernetes, using volumes provided by EO-Lab is currently not a viable option. As an alternative, EO-Lab suggests (among others) the use of AWS S3 storage buckets. As these are managed not by the kubernetes API-Server but by openstack, most of the definitions inside `kubernetes/volumes.yml` are not applicable anymore. Potential other solutions are discussed [here](https://forum.code-de.org/de/forum/cloud-infrastruktur-iaas-8/topic/datenaustausch-zwischen-vms-74/).

> [!NOTE]
> NFS-shares are not discussed as they can only be shared by specifying all IPs which may request access or share with entire subnets. The former would also allow access to individual nodes from outside the cluster and is generally discouraged. The latter could not be implemented either due to resource exhaustion or lack of technical understanding on my side.

The general proceeding is described in [EO-Lab's knowledge base](https://knowledgebase.eo-lab.org/en/latest/s3/How-to-mount-object-storage-container-as-a-file-system-in-Linux-using-s3fs-on-EO-Lab.html). First, three object storage containers are needed:

```bash
openstack container create indir outdir workdir
```

> [!NOTE]
> Using three seperate storage buckets may not be the most idiomatic usage strategy or hurt performance. This was not investigated further.

To allow access to these storage buckets or mount them locally, EC2 credentials are needed. Create them by executing the following command. For more detailed instructions, see this [document](https://knowledgebase.eo-lab.org/en/latest/general/How-to-generate-ec2-credentials-on-EO-Lab.html).

```bash
openstack ec2 credentials create

# list credentials by running
# openstack ec2 credentials list
```

Using `s3cmd`, access to these storage buckets can be granted. First configure `s3cmd` with the previously generated credentials, a detailed tutorial can be found [here](https://knowledgebase.eo-lab.org/en/latest/s3/How-to-access-private-object-storage-using-S3cmd-or-boto3-on-EO-Lab.html).

```bash
s3cmd --configure
```

Afterwards, apply the IAM-roles in the `aws-s3` directory which allows external tools to access the S3 bucktes.

```bash
s3cmd setpolicy kubernetes/nextflow-jail-indir.json s3://indir
s3cmd setpolicy kubernetes/nextflow-jail-workdir.json s3://workdir
s3cmd setpolicy kubernetes/nextflow-jail-outdir.json s3://outdir
```

Using the S3 buckets from within Nextflow necessitates setting parameters inside the Nextflow config. See the `aws` and `fusion` scopes of `workflows/oad-lstm-classification/nextflow.config` for a concrete implementation.

#### Submit Naked Pods

Kubernetes allows to create standalone pods. Usage of so-called "naked pods" is generally discouraged when working with kubernetes, however they proved to be useful for testing purposes. For example, they can be used to validate correct mounting of PersistentVolumeClaims within a container and checking correct workings of previously created container images. As an aside, it is not fully clear to me if the usage of "naked pods" is discouraged for one-shot-workflow-executions as well.

```bash
kubectl apply -f kubernetes/staging-pod.yml
```

### Data Prerequisites

Any additional data used as input to the workflow must be made accessible for containers running inside the cluster prior to execution. While the FORCE Community-Cube is mounted as a NFS-share, data such as a vector database used to query the AOI must be uploaded manually. To do so, use the `kubectl cp` command. Any subdirectories referenced need to exist and the user within a container needs to have write access to the chosen directory. Exemplary use is shown below.

```bash
kubectl cp germany-subset.gpkg default/staging-pod:/input/aoi
kubectl cp lstmv-v1.pkl default/staging-pod:/input/models
```

#### AWS S3 Buckets

To ingest data into the input storage bucket created above, mount the respective bucket locally with `s3fs`. A detailed description is provided by CloudFerro/EoLab [here](https://knowledgebase.eo-lab.org/en/latest/s3/How-to-mount-object-storage-container-as-a-file-system-in-Linux-using-s3fs-on-EO-Lab.html). An example is shown below.

```bash
sudo sed -i -e '/user_allow_other$/ s/#//' /etc/fuse.conf
mkdir wf-inputs
s3fs indir wf-inputs -o passwd_file=~/.passwd-s3fs -o url=https://cloud.fra1-1.cloudferro.com:8080 -o use_path_request_style -o umask=0002 -o allow_other

# Copy ESA Worldcover to S3 bucket
cp -r /code/auxdata/esa-worldcover-2020/ wf-inputs/
```

> [!IMPORTANT]
> Use S3 bucktes with nextflow by prefixing all paths with `s3://<bucket>`.

## Start a Workflow

### Implemented Workflows

#### One-And-Done Tree Species Classification Using LSTM-Models

The original tree species classification workflow is presented in [this GitHub repository](https://github.com/JKfuberlin/SITS-NN-Classification). The Nextflow implementation currently focuses on inference only and disregards creation of training data and model training. All related files are inside `workflows/oad-lstm-classification`.

The model used was only trained for a couple of epochs and thus produces nonsensical results. Nonetheless, it was used for workflow and cluster development/set up as it was the first one being *done*.

#### One-And-Done Tree Species Classification Using Transformer-Models

*To be implemented*

#### Continous Tree Species Classification Using Transformer-Models

*To be implemented*
- data cube is not updated every day, but almost. Thus a CronJob simply running every day might not be the mose sensible option.

### Execute Workflows

Workflows can be executed both from within the cluster and outside of it.

#### Execute from Outside of the Cluster

There exist two possiblities to start the workflow from outside the cluster using the command line. However, during workflow development, using `kuberun` unexpectedly did not work. If this is realted to the project structure is currently unclear (to me). Thus, `kuberun` was disregarded.

##### `kuberun`

```bash
# Does not work
# WARN: Cannot read project manifest -- Cause: Remote resource not found: https://api.github.com/repos/Florian-Katerndahl/TreeSITS-k8s/contents/nextflow.config
# Remote resource not found: https://api.github.com/repos/Florian-Katerndahl/TreeSITS-k8s/contents/main.nf
# related? https://github.com/nextflow-io/nextflow/issues/1050
nextflow kuberun -main-script workflows/oad-lstm-classification/main.nf -c workflows/oad-lstm-classification/nextflow.config https://github.com/Florian-Katerndahl/TreeSITS-k8s
```

##### Leveraging the kubernetes context

If the kubernetes context is specified in the `nextflow.config` file, and you set up your cluster to be adadministrable via `kubectl`, you can start the workflow as if it was local. For this to work, your Kubernetes config file likely must be located at  `~/.kube/config`. To get your kubernetes context, run `kubectl config get-contexts` and use the `NAME` column in your Nextflow configuration file -- in case you only manage a single cluster on EO-Lab it's likely your context is simply called "default". Afterwards, simply run the follwoing command - assuming your AWS EC2 credentials are stored in a file called `AWS.env`. Please note, that all file paths not indicating a cloud storage provider are resolved locally. Thus, the computer you start the workflow from needs access to a FORCE data cube.

```bash
source AWS.env
AWS_ACCESS_KEY=$AWS_ACCESS_KEY AWS_SECRET_KEY=$AWS_SECRET_KEY \ 
    nextflow run -c workflows/oad-lstm-classification/nextflow.config workflows/oad-lst-classification/main.nf -work-dir s3://workdir -resume
```

#### Execute from witihn the Cluster

To start a workflow from within the cluster, i.e. using a so-called *submitter pod*, first create a naked pod as described above and execute the workflow from within that pod. For this to work, the workflow definition itself must be encapsulated within the Docker container.

```bash
kubectl apply -f kubernetes/nf-submitter-pod.yml
kubectl exec -t pods/nf-submitter -- AWS_ACCESS_KEY="<previously created ec2 credential access>" AWS_SECRET_KEY="<previously created ec2 credential secret>" \
    nextflow run -c workflows/oad-lstm-classification/nextflow.config workflows/oad-lst-classification/main.nf
```

## Get Results off of your Cluster

To download files or directoires use `kubectl cp`. I.e., to download the output directory with all its subdirectories, run the following command:

```bash
mkdir output
kubectl cp default/staging-pod:/output output/
```

If AWS S3 buckets are used instead of volumes, mount the respective bucket locally using `s3fs` as described above or access the files via the S3 API. **Alternatively, you can specify a local directory!** Thus, starting the workflow from outside the cluster would automatically download all results to your machine.


## Running CUDA applications in Code-DE

To run CUDA application in Code-DE, follow these steps:

#### Create cluster with GPU support

When creating a cluster in Code-DE, make sure to select the correct template, i.e. `k8s-1.23.16-vgpu-v1.0.0`. As a flavour of the worker node(s), select one that has a gpu, e.g. `vm.a6000.1`. The rest of the settings you can choose as you wish.

Create the cluster. (It may take a while. If it fails, retry. Check also that enough GPUs are available.)

#### Check the availability of the nvidia plugin

Get the nodes with

```
kubectl get nodes
```

which will give you an output like this
```
NAME                                 STATUS   ROLES    AGE   VERSION
test-gpu-k8s-iqg4yblk2m55-master-0   Ready    master   49m   v1.23.16
test-gpu-k8s-iqg4yblk2m55-node-0     Ready    <none>   46m   v1.23.16

```
Check that the `nvidia-device-plugin` is available on the GPU node

```
kubectl describe node test-gpu-k8s-iqg4yblk2m55-node-0
```
If the following lines are present in the output, the plugin is avaliable and the GPUs can be used:
```
  Namespace                   Name                                                        CPU Requests  CPU Limits  Memory Requests  Memory Limits  Age
  ---------                   ----                                                        ------------  ----------  ---------------  -------------  ---
  nvidia-device-plugin        nvidia-device-plugin-gpu-feature-discovery-wnnhp            0 (0%)        0 (0%)      0 (0%)           0 (0%)         48m
  nvidia-device-plugin        nvidia-device-plugin-node-feature-discovery-worker-v8t9x    0 (0%)        0 (0%)      0 (0%)           0 (0%)         48m
  nvidia-device-plugin        nvidia-device-plugin-xhqf7                                  0 (0%)        0 (0%)      0 (0%)           0 (0%)         48m
  
  
  Resource           Requests    Limits
  --------           --------    ------
  nvidia.com/gpu     0           0
```

#### Check for taints

Check for taints on the nodes, especially on the GPU node:

```
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

This will give you a list of taints, for example:
```
NAME                                 TAINTS
test-gpu-k8s-iqg4yblk2m55-master-0   [map[effect:NoSchedule key:node-role.kubernetes.io/master]]
test-gpu-k8s-iqg4yblk2m55-node-0     [map[effect:NoSchedule key:node.cloudferro.com/type value:gpu]]
```

If the taints are present, i.e. you don't get an empty list, you have to add tolerations in the config file for your script, otherwise your GPU application will not run:

**Example mainfest:** `gpu-load-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-load-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gpu-load
  template:
    metadata:
      labels:
        app: gpu-load
    spec:
      containers:
      - name: gpu-load
        image: <username>/gpu-load:latest
        resources:
          limits:
            nvidia.com/gpu: 1 # Request one GPU
          requests:
            nvidia.com/gpu: 1
      tolerations:
        - key: "node.cloudferro.com/type"
          operator: "Equal"
          value: "gpu"
          effect: "NoSchedule"
```
