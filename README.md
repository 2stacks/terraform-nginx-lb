# Nginx Loadbalancer for Rancher Kubernetes
Use Terraform to deploy a Nginx Loadbalancer for a Rancher Kubernetes Cluster.

## Summary

This is not a Kubernetes Ingress.  This project's goal is to provide an alternative to a hardware loadbalancer
such as an F5 for load balancing Kubernetes worker nodes.  More specifically this project allows you to host a 
public Kubernetes cluster behind a NAT boundary using [server names](https://nginx.org/en/docs/http/server_names.html) 
and [SSL SNI](https://nginx.org/en/docs/http/configuring_https_servers.html#sni).  The current Nginx configuration has 
been customized for running a three node [Rancher Kubernetes](https://rancher.com/) cluster however it can be modified 
to load balance any Kubernetes Cluster.

Note: This project is customized for KVM servers running Openvswitch.  Installation of these dependencies can be
complex and is outside the scope of this project.

### Prereqs
KVM Server running Openvswitch

- https://github.com/mrlesmithjr/ansible-kvm
- https://docs.openvswitch.org/en/latest/intro/install/distributions/

Terraform and the terraform-provider-libvirt

- https://www.terraform.io/downloads.html
- https://github.com/dmacvicar/terraform-provider-libvirt#installing


### Setup
Clone Repository
```bash
git clone https://github.com/2stacks/terraform-nginx-lb.git
cd terraform-nginx-lb
```

Create secrets variable file, add your SSH public key and update database passwords.
```bash
cp secret.auto.tfvars.example secret.auto.tfvars
```

Deploy libvirt guest with Terraform
```bash
terraform init
terraform plan
terraform apply
```

When Terraform finishes it will output the libvirt guest IP

Example:
```bash
Outputs:

ip = [
    [
        192.168.100.15,
        fe80::5054:ff:fec2:43bd
    ]
]
```

If running this load balancer behind a NAT boundary you should set up port forwarding for TCP 80 and 443 to the IP given in the
Terraform Output.

### Important Variables
|Variable Name |Usage |
|---|---|
| domain_name | Sets the domian name of the Rancher server and Kubernetes worker nodes to be loadbalanced |
| nameserver  | Name server the loadbalancer should use to resolve the Rancher server and node names

### TODO
- Use jinja2 to produce the nginx.conf