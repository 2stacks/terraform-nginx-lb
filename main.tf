# instance the provider
provider "libvirt" {
  uri = "${var.libvirt_uri}"
}

data "template_file" "user_data" {
  template = "${file("${path.module}/templates/cloud_init.yml")}"

  vars {
    user_name          = "${var.user_name}"
    ssh_authorized-key = "${var.ssh_authorized-key}"
  }
}

data "template_file" "meta_data" {
  count    = "${var.guest_count}"
  template = "${file("${path.module}/templates/meta_data.yml")}"

  vars {
    hostname = "${format("${var.hostname}-%02d", count.index + 1)}"
  }
}

data "template_file" "network_config" {
  template = "${file("${path.module}/templates/network_config.yml")}"
}

data "template_file" "xslt_config" {
  template = "${file("${path.module}/templates/override.xsl")}"

  vars {
    network    = "${var.network}"
    port_group = "${var.port_group}"
  }
}

data "template_file" "nginx_config" {
  count    = "${var.guest_count}"
  template = "${file("${path.module}/templates/nginx.conf")}"

  vars {
    hostname    = "${format("${var.hostname}-%02d", count.index + 1)}"
    domain_name = "${var.domain_name}"
  }
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "ubuntu-qcow2" {
  name   = "${var.prefix}-ubuntu.qcow2"
  pool   = "${var.libvirt_volume_pool}"
  source = "${var.libvirt_volume_source}"
  format = "qcow2"
}

resource "libvirt_volume" "ubuntu-qcow2_resized" {
  name           = "${format("${var.prefix}-%01d.qcow2", count.index + 1)}"
  base_volume_id = "${libvirt_volume.ubuntu-qcow2.id}"
  pool           = "${var.libvirt_volume_pool}"
  size           = "${var.libvirt_volume_size}"
  count          = "${var.guest_count}"
}

# for more info about paramater check this out
# https://github.com/dmacvicar/terraform-provider-libvirt/blob/master/website/docs/r/cloudinit.html.markdown
# Use CloudInit to add our ssh-key to the instance
# you can add also meta_data field
resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "${format("${var.prefix}-seed-%01d.iso", count.index + 1)}"
  pool           = "${var.libvirt_volume_pool}"
  user_data      = "${data.template_file.user_data.rendered}"
  meta_data      = "${data.template_file.meta_data.*.rendered[count.index]}"
#  network_config = "${data.template_file.network_config.rendered}"
  count          = "${var.guest_count}"
}

# Create the machine
resource "libvirt_domain" "domain-ubuntu" {
  count      = "${var.guest_count}"
  name       = "${format("${var.hostname}-%02d", count.index + 1)}"
  memory     = "${var.memory}"
  vcpu       = "${var.vcpu}"
  qemu_agent = true
  cloudinit  = "${element(libvirt_cloudinit_disk.commoninit.*.id, count.index)}"

  network_interface {
    network_name   = "${var.network}"
    mac            = "${format("${var.mac_prefix}:%02d", count.index + 1)}"
    wait_for_lease = true
  }
  # used to support features the provider does not allow to set from the schema
  xml {
    xslt = "${data.template_file.xslt_config.rendered}"
  }
  # IMPORTANT: this is a known bug on cloud images, since they expect a console
  # we need to pass it
  # https://bugs.launchpad.net/cloud-images/+bug/1573095
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }
  disk {
    volume_id = "${element(libvirt_volume.ubuntu-qcow2_resized.*.id, count.index)}"
  }
  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  connection {
    type        = "ssh"
    private_key = "${file("~/.ssh/do_rsa")}"
    user        = "${var.user_name}"
    timeout     = "2m"
  }

  provisioner "file" {
    source      = "templates/self-signed.conf"
    destination = "/tmp/self-signed.conf"
  }

  provisioner "file" {
    source      = "templates/ssl-params.conf"
    destination = "/tmp/ssl-params.conf"
  }

  provisioner "file" {
    content     = "${data.template_file.nginx_config.*.rendered[count.index]}"
    destination = "/tmp/nginx.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl disable systemd-resolved",
      "sudo systemctl stop systemd-resolved",
      "sudo rm /etc/resolv.conf",
      "sudo sh -c 'echo \"nameserver ${var.nameserver}\nsearch ${var.domain_name}\" > /etc/resolv.conf'",
      #"sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj \"/C=US/ST=Washington/L=D.C./O=2stacks/OU=IT Department/CN=${format("${var.hostname}-%02d", count.index + 1)}.${var.domain_name}\"",
      #"sudo openssl dhparam -out /etc/nginx/dhparam.pem 2048",
      #"sudo mv /tmp/self-signed.conf /etc/nginx/snippets/self-signed.conf",
      #"sudo mv /tmp/ssl-params.conf /etc/nginx/snippets/ssl-params.conf",
      "sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf",
      "sudo rm /etc/nginx/sites-enabled/default",
      "sudo nginx -t",
      "sudo systemctl restart nginx",
    ]
  }
}

# IPs: use wait_for_lease true or after creation use terraform refresh and terraform show for the ips of domain
output "ip" {
  value = "${libvirt_domain.domain-ubuntu.*.network_interface.0.addresses}"
}
