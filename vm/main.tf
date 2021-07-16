terraform {
  required_version = ">= 1.0.0"

  backend "local" {
    path = ".terraform/state/terraform.tfstate"
  }

  required_providers {
      libvirt = {
          source  = "dmacvicar/libvirt"
      }
  }
}

locals {
  hostname = "titanium-server"
  ssh_key = "~/.ssh/id_rsa"
  cloud_image_url = "https://download.fedoraproject.org/pub/fedora/linux/releases/34/Cloud/x86_64/images/Fedora-Cloud-Base-34-1.2.x86_64.qcow2"
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_volume" "titanium" {
  name = "${local.hostname}.qcow2"
  pool = "default"
  source = local.cloud_image_url
}

data "template_file" "userdata" {
  template = file("${path.module}/templates/userdata.yaml")

  vars = {
    ssh_public_key = file("${local.ssh_key}.pub")
  }
}

data "template_file" "metadata" {
  template = file("${path.module}/templates/metadata.yaml")

  vars = {
    hostname = local.hostname
  }
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name = "commoninit.iso"
  user_data = data.template_file.userdata.rendered
  meta_data = data.template_file.metadata.rendered
  pool = "default"
}

resource "libvirt_domain" "titanium" {
  name = local.hostname
  memory = "2048"
  vcpu = 2

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name = "default"
    wait_for_lease = true
    hostname = local.hostname
  }

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  console {
    type = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = libvirt_volume.titanium.id
  }
}