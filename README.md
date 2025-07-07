# Windows Base Image Build with Hashicorp Packer

This is basic Packer and Ansible repo to deploy Windows Server 2025 on Proxmox with a basic `autounattend.xml` file to automatically install Windows with a user defined Administrator password and then configured with a user defined username/password combination through Ansible. While the autounattend file isn't terribly complicated, I would recommend that anyone extends the Ansible playbook to perform more setup in order to further customize their Windows Server template.

As an additional feature, I've added a snippet of code that will install VirtIO drivers from the public VirtIO ISO file that must be downloaded and attached to the VM. This will install all necessary drivers for optimal performance of Windows inside of the Proxmox hypervisor. Specifically, this is necessary in order to allow network commmunications into the VM for the provisioner.

Also, the QEMU guest agent is installed in the same process, which will allow Proxmox to see the IP address of the VM to pass to the provisioner. This is another necessary step to allow the VM to be managed with Packer. After drivers and agents are installed the script will then run the public Ansible setup PowerShell script to perform further configuration for WinRM. Lastly a quick reset of the autologon registry is performed for cleanup and then WinRM is enabled. This will signal to the provisioner that it can proceed now that WinRM is fully available.

Due to the many requirements for this process, it is important to make sure that the necessary ISO files are placed on the Proxmox host. You will need to make sure you have a latest Windows Server 2025 installation media, as well as the latest VirtIO Windows Drivers media sitting on the box so that it can be mounted up at runtime. Please make sure the following are available:

- `local:iso/WindowsServer2025_x64_en-us.iso` - <https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025>
- `local:iso/virtio-win.iso` - <https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso>

### Sample `autounattend.xml` File

The autounattend.xml file is kept extremely simple for this setup. The intention is to get the minimum viable configuration necessary in order to allow Ansible to come into the VM and perform the rest of the configuration. This Ansible-first decision was made in order to integrate well with other infrastructure as code projects. A sample XML file is shown below but it can be changes to suit your needs. Please note the `${build_passwd}` variable that is used to denote a variable that Packer should fill into the file at runtime before it is processed and placed on the ISO.

```autounattend.xml
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SetupUILanguage>
                <UILanguage>en-US</UILanguage>
            </SetupUILanguage>
			<InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UserLocale>en-US</UserLocale>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Type>EFI</Type>
                            <Size>512</Size>
                            <Order>1</Order>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Extend>false</Extend>
                            <Type>MSR</Type>
                            <Order>2</Order>
                            <Size>128</Size>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>3</Order>
                            <Type>Primary</Type>
                            <Extend>true</Extend>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Format>FAT32</Format>
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Order>2</Order>
                            <PartitionID>2</PartitionID>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Format>NTFS</Format>
                            <Label>Windows</Label>
                            <Order>3</Order>
                            <PartitionID>3</PartitionID>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>
            </DiskConfiguration>
            <ImageInstall>
                <OSImage>
                    <InstallFrom>
                        <MetaData wcm:action="add">
                            <Key>/IMAGE/NAME</Key>
                            <Value>Windows Server 2025 SERVERSTANDARD</Value>
                        </MetaData>
                    </InstallFrom>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>3</PartitionID>
                    </InstallTo>
                    <WillShowUI>OnError</WillShowUI>
                    <InstallToAvailablePartition>false</InstallToAvailablePartition>
                </OSImage>
            </ImageInstall>
            <UserData>
			    <AcceptEula>true</AcceptEula>
                <ProductKey>
                    <WillShowUI>Never</WillShowUI>
                    <Key>TVRH6-WHNXV-R9WG3-9XRFY-MY832</Key>
                </ProductKey>
            </UserData>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <TimeZone>Eastern Standard Time</TimeZone>
        </component>
		    <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <fDenyTSConnections>false</fDenyTSConnections>
        </component>
        <component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <FirewallGroups>
                <FirewallGroup wcm:action="add" wcm:keyValue="RemoteDesktop">
                    <Active>true</Active>
                    <Group>Remote Desktop</Group>
                    <Profile>all</Profile>
                </FirewallGroup>
            </FirewallGroups>
        </component>
        <component name="Microsoft-Windows-TerminalServices-RDP-WinStationExtensions" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SecurityLayer>2</SecurityLayer>
            <UserAuthentication>1</UserAuthentication>
        </component>
		    <component name="Microsoft-Windows-ServerManager-SvrMgrNc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DoNotOpenServerManagerAtLogon>true</DoNotOpenServerManagerAtLogon>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <AutoLogon>
                <Password>
                    <Value>${build_passwd}</Value>
                    <PlainText>true</PlainText>
                </Password>
                <LogonCount>2</LogonCount>
                <Username>Administrator</Username>
                <Enabled>true</Enabled>
            </AutoLogon>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <CommandLine>powershell -ExecutionPolicy Bypass -File E:\setup.ps1</CommandLine>
                    <Description>Enable WinRM service</Description>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
            </FirstLogonCommands>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>${build_passwd}</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
        </component>
    </settings>
    <cpi:offlineImage cpi:source="wim:c:/wims/install.wim#Windows Server 2025 SERVERDATACENTER" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
</unattend>
```

## Packer Configuration

A basic installation of Hashicorp Packer is requried. You can also use the Docker container but I'v ehad limited success with the Ansible provisioner in cases where you want to do anything slightly advanced. In order to get this provision to work you need to make sure that the Windows server ISO of choice is downloaded to the Proxmox LVM ISO location. You can use the `init` and `verify` commands to make sure that everything checks out locally before building.

### Sample Secure Vars

Ensure that your secure vars are configured with at least the following lines at `./windows-packer-install-sensitive.auto.pkrvars.hcl`. These are the variables that have been set aside to make sure that this works for your given Proxmox environment. The service user is used for post-install steps and for any other customizatoin you'd like to do. Be sure to add your own tasks/roles to `windows-packer-config.yml` for your own custom template.

```hcl
/*
    DESCRIPTION:
    Build account variables used for all builds.
    - Variables are passed to and used by guest operating system configuration files (e.g., ks.cfg, autounattend.xml).
    - Variables are passed to and used by configuration scripts.
*/

// Default Account Credentials
build_passwd             = "B9g4CSFbq6@kpB" // Administrator account password
service_user             = "SERVICE_USER"   // WinRM username for the local admin user to be provisioned
service_passwd           = "5ue6t2xkHE@Fhr" // Super secure password for lcoal admin user

/*
    DESCRIPTION:
    Proxmox WebUI variables used for Linux builds. 
    - Variables are use by the source blocks.
*/

//Proxmox Credentials
proxmox_host             = "10.x.x.x"
proxmox_node             = "PROXMOXNODE"
proxmox_user             = "root@pam!APIKEY"
proxmox_apikey           = "XXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXX"

// VM Config - if required, defaults to nothing
vlan_tag                 = ""

// Optional Override for path to Ansible playbook (assumes you're starting at top level directory on your Git repo)
// ansible_provisioner_playbook_path = "
```

### Script for Packer Build processes

I've created a script to perform the basic build process in order to make this as plug and play as possible.

```shell
windows-packer-build.sh
```