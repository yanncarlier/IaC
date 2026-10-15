# IAC Projects

Infrastructure as Code / automation collection — container runtimes, Linux VM
provisioning, AWS infrastructure, and GCP project bootstrap.

## Contents

| Directory | What it does |
| --- | --- |
| [`container-runtimes`](container-runtimes/) | Install and drive container runtimes — bubblewrap sandboxes, containerd/nerdctl, Firecracker microVMs, Podman — plus Docker/Podman cleanup scripts. |
| [`virtualization`](virtualization/) | Provision Linux VMs. [`lxd`](virtualization/lxd/) builds reusable LXD VMs (btcpayserver, hermes, openclaw, openfang, paperclip); [`libvirt`](virtualization/libvirt/) installs desktop/server images with `virt-install`. |
| [`aws-terraform`](aws-terraform/) | AWS infrastructure as code. [`aws-eks-lb-autoscaler`](aws-terraform/aws-eks-lb-autoscaler/) is an EKS cluster with Load Balancer Controller, cluster autoscaler, IRSA and Rancher certs; [`aws-simple-services`](aws-terraform/aws-simple-services/) holds standalone examples (RDS, ECR, jumpbox, secrets, and more). |
| [`gcp-project-provisioning`](gcp-project-provisioning/) | Python/`uv` automation that creates Google Cloud projects and Gemini API keys via the Cloud Resource Manager API. |