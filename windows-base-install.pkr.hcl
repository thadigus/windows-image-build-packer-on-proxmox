packer {
  required_plugins {
    proxmox = {
      version = "= 1.2.1"
      source  = "github.com/hashicorp/proxmox"
    }
    git = {
      version = ">= 0.4.2"
      source  = "github.com/ethanmdavidson/git"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
    windows-update = {
      version = ">=0.14.0"
      source = "github.com/rgl/windows-update"
    }
  }
}

//  BLOCK: data
//  Defines the data sources.

data "git-repository" "cwd" {}

//  BLOCK: variable
//  The many variables defined for build.

variable "proxmox_host" {
    type = string
}

variable "proxmox_node" {
    type = string
}

variable "proxmox_user" {
    type = string
}

variable "proxmox_apikey" {
    type = string
}

variable "vlan_tag" {
    type = string
    default = ""
}

variable "build_passwd" {
    type = string
    sensitive = true
}

variable "service_user" {
    type = string
}

variable "service_passwd" {
    type = string
    sensitive = true
}

variable "ansible_provisioner_playbook_path" {
    type = string
    default = "windows-packer-config.yml"
}

source "proxmox-iso" "windows-tpl" {

    proxmox_url = "https://${var.proxmox_host}:8006/api2/json"
    insecure_skip_tls_verify = true
    node = var.proxmox_node
    boot_iso {
      type = "sata"
      index = 1
      iso_file = "local:iso/WindowsServer2025_x64_en-us.iso"
      unmount = true
    }
    additional_iso_files {
      cd_content = {
        "autounattend.xml" = templatefile("./autounattend.xml", {build_passwd = var.build_passwd}),
        "setup.ps1" = file("./setup.ps1")
      }
      cd_label = "Unattend"
      iso_storage_pool = "local"
      unmount = true
      type = "sata"
      index = 2
    }
    additional_iso_files {
      type = "sata"
      index = 3
      iso_file = "local:iso/virtio-win.iso"
      unmount = true
    }
    vm_name = "windows-base-image"
    vm_id = 996
    username = var.proxmox_user
    token = var.proxmox_apikey
    os = "win11"
    bios = "ovmf"
    #machine = "q35"
    efi_config {
      efi_storage_pool  = "local-lvm"
      pre_enrolled_keys = true
      efi_format        = "raw"
      efi_type          = "4m"
    }
    qemu_agent = true
    tpm_config {
      tpm_version 	    = "v2.0"
      tpm_storage_pool  = "local-lvm"
    }
    cpu_type = "host"
    cores = "2"
    memory = "4096"
    scsi_controller = "virtio-scsi-pci"
    disks {
      type              = "sata"
      disk_size         = "20G"
      storage_pool      = "local-lvm"
      format	          = "raw"
    }
    network_adapters {
      bridge            = "vmbr0"
      vlan_tag          = var.vlan_tag
      model             = "virtio"
    }
    # WinRM
    communicator          = "winrm"
      winrm_username        = "Administrator"
      winrm_password        = var.build_passwd
      winrm_timeout         = "30m"
      winrm_port            = "5986"
      winrm_use_ssl         = true
      winrm_insecure        = true
      winrm_use_ntlm        = true
    boot_wait = "5s"
    boot_command = [
      "<enter>"
    ]
}

build {
  sources = ["source.proxmox-iso.windows-tpl"]

  provisioner "ansible" {
    user          = "Administrator"
    playbook_file = "${path.cwd}/${var.ansible_provisioner_playbook_path}"
    use_proxy     = false
    extra_arguments = [
      "--connection", "winrm",
      "--extra-vars", "admin_passwd='${var.build_passwd}' service_user='${var.service_user}' service_passwd='${var.service_passwd}' ansible_connection='winrm' ansible_winrm_transport='ntlm' ansible_winrm_server_cert_validation='ignore' ansible_user='Administrator' ansible_password='${var.build_passwd}'"
    ]
    ansible_env_vars = [
      "ANSIBLE_CONFIG=${path.cwd}/ansible.cfg",
      "ANSIBLE_BECOME_METHOD=runas",
      "ANSIBLE_BECOME_USER=Administrator",
      "ANSIBLE_BECOME_PASS=${var.build_passwd}"
    ]
  }

  /* - Removing the Windows Update Provisioner for now because it seems to have a ton of issues.
  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "include:$true",
    ]
    update_limit = 25
  }
  */

  provisioner "windows-restart" {
  }
} 
