#!/bin/bash
/usr/bin/packer init -var-file=./windows-packer-install-sensitive.auto.pkrvars.hcl .
/usr/bin/packer validate -var-file=./windows-packer-install-sensitive.auto.pkrvars.hcl .
/usr/bin/packer build -force -var-file=./windows-packer-install-sensitive.auto.pkrvars.hcl .
