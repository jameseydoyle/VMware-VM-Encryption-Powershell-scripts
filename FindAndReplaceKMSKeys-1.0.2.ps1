############################################################################
### This script is designed to interactively allow a user to find all    ###
### objects encrypted using keys from a specific KMS and perform a       ###
### shallow rekey operation on all selected objects                      ###
###                                                                      ###
### Designed by James Doyle                                              ###
### Staff Technical Support Training Specialist                         ###
### VMware Inc. 														 ###
### jdoyle@vmware.com                                                    ###
############################################################################



##################################################################
###Beginning of script
##################################################################


# Globals
$VersionText = "Version 1.0.2"

# Display version information before launching script
Write-Host -ForegroundColor Cyan "`n`n############################################`nVM Encryption Rekey Script: " $VersionText
Write-Host -ForegroundColor Cyan "############################################"
Write-Host "`n`n"
Write-Host -ForegroundColor Yellow "This script requires that you download and save the`nVM Encryption PowerCLI Module"
Write-Host -ForegroundColor Yellow "For information, please see:" 
Write-Host -ForegroundColor Yellow "http://blogs.vmware.com/vsphere/2016/12/powercli-for-vm-encryption.html"
Write-Host "`n`n`n"

######################################################################
### Check for existence of VMEncryption PS Module
### If not available, prompt for location of psm file
### Exit script if module is not found or location is not specified
### Once location has been specified, run Import-Module command
######################################################################

Write-Host -ForegroundColor White "`n`n"
Write-Host -ForegroundColor White "Checking for required PowerCLI Module......"
Write-Host -ForegroundColor White "`n`n"

$CheckVMEncryption = Get-Module -Name VMware.VMEncryption
    if ($CheckVMEncryption -eq $null){
       Write-Host -ForegroundColor Red "The required VMEncryption PowerCLI module has not been found.`nIf you have not already done so, please visit `nhttp://blogs.vmware.com/vsphere/2016/12/powercli-for-vm-encryption.html `n and download the module from the Github repository."
	   Start-Process -FilePath "http://blogs.vmware.com/vsphere/2016/12/powercli-for-vm-encryption.html"
       $AskForPSM = Read-host -Prompt "Please enter the full path to the VMEncryption PowerCLI module (.psm file) 
       [Entering no value will exit the script]"
        if ($AskForPSM -like $null) {
            Write-Host "OK. Exiting...."
            Exit
        } else {
            Import-Module $AskForPSM -ea SilentlyContinue
        }
    } else {Write-Host -ForegroundColor Green "*****Required PowerCLI module has been located*****"
    Write-Host "`n`n"
    }

#######################################################################
##Prompt user for the name of the vCenter to which they wish to connect
#######################################################################

$viserver = Read-Host -Prompt "Please enter the name of the vCenter Server instance where your encrypted Virtual Machines are registered"

##########################################
###Connect to the specified vCenter Server
##########################################
#Set-PowerCLIConfiguration -InvalidCertificateAction Ignore

connect-viserver -server $viserver
Write-Host "`n`n`n"
Write-Host -ForegroundColor Yellow "You are now connected to $viserver." 
Write-Host -ForegroundColor Yellow "You will be presented with a list of connected KMS Servers.`nPlease choose which KMS Server provides the keys you wish to replace."
Write-Host -ForegroundColor Yellow "`nIf the keys are provided by a disconnected KMS, you will be required`nto manually enter the KMS Cluster name"

###############################################
### Retrieve a list of connected KMS Servers
### User will select the KMS from the Grid View
### from which to select objects to rekey
###############################################

$KMSConnected = Read-Host -Prompt "Is the required KMS currently connected to vCenter? [y or n]"
    if ($KMSConnected -notlike "y*") {
        $KMSid = ""
        Read-Host -Prompt "Please enter the name of the KMS Cluster whose keys are to be replaced:" -OutVariable KMSid
        } else { 
            $KMS = ""
            Get-KMSCluster |
            Select-Object -Property Id | 
            Out-GridView -OutputMode Single -Title "Please select which KMS server provides the current keys you wish to replace" -OutVariable KMS
            $KMSid = $KMS.id
            }

################################################
###Output the chosen KMS and ask user to confirm
################################################

#Clear-Host
Write-Host "`n`n"
Write-Host -ForegroundColor White "You have chosen a KMS Cluster called $KMSid" 
$KMSConfirm = Read-Host -Prompt "Do you wish to continue? [Y or N] (default is No)"
	if ($KMSConfirm -notlike "y*") {
		Write-Host "OK, exiting ..."
        Disconnect-viserver -Confirm:$false -Force $viserver
		Exit
	}

#################################################
###User will select VM Hosts to rekey first
###Upon confirmation, the rekey will be performed
#################################################

Write-Host -ForegroundColor Yellow "`n`nNext we will search your inventory for hosts with installed`nHostKeys provided by the selected KMS"
Write-Host -ForegroundColor Yellow "`n`n"

$HostsToRekey = Get-EntityByCryptoKey -SearchVMHosts -KMSClusterId $KMSid 
$HostList = ""
$HostsToRekey.VMHostList |
    Select-Object -Property Name |
    Sort-Object |
    Out-GridView -OutputMode Multiple -Title "Please choose which hosts you wish to rekey" -OutVariable HostList

$ConfirmHostRekey = Read-host -Prompt "`n`nYou have selected the above hosts to be rekeyed.`n`nDo you wish to rekey all these hosts with a new key from the default KMS Cluster? `n[Y or N}?"
if ($ConfirmHostRekey -notlike "y*") {
    Write-Host -ForegroundColor White "OK, continuing with Encrypted VM discovery"
    } else {
        Get-VMHost -Name $HostList.Name | Set-VMHostCryptoKey
        }


#####################################################
###User will select VMs to rekey
#####################################################

Write-Host -ForegroundColor Yellow "`n`nNow we will search the inventory for Virtual Machines whose`nconfiguration files are encrypted with keys provided`nby the selected KMS"
Write-Host -ForegroundColor Yellow "`n`n"

$VMsToRekey = Get-EntityByCryptoKey -SearchVMs -KMSClusterId $KMSid
$VMList=""
$VMsToRekey.VMList |
    Select-Object -Property Name |
    Sort-Object |
    Out-Gridview -OutputMode Multiple -Title "Please choose which VMs you wish to rekey" -OutVariable VMList

$ConfirmVMRekey = Read-Host -Prompt "`n`nYou have selected the above VMs to be shallow rekeyed.`n`nDo you wish to rekey the selected VMs' congifuration files`nwith new keys provided by the default KMS?`nProceed [y or n]"
if ($ConfirmVMRekey -notlike "y*") {
    Write-Host -ForegroundColor White "OK. Exiting...."
    Disconnect-viserver -Confirm:$false -Force $viserver
    Exit
    } else {
        Write-Host -ForegroundColor White "`n`n"
        Write-Host -ForegroundColor Yellow "It is also possible to rekey any disks that are attached to the selected VMs`nwhere the encryption key is also provided by the same KMS"
        $AddDisks = Read-Host -Prompt "Do you wish to rekey all disks attached to the selected VMs? [y or n]"
        if ($AddDisks -notlike "y*") {
            Get-VM $VMList.Name | Set-VMEncryptionKey -SkipHardDisks
            Write-Progress
            } else {
            Get-VM $VMList.Name | Set-VMEncryptionKey
            }
        }


##########################
### Finishing Up
##########################

Write-Host -ForegroundColor White "Thank you for using this script."
Write-Host -ForegroundColor White "`n`n"
Write-Host -ForegroundColor White "Disconnecting from vCenter ...."
Disconnect-viserver -Confirm:$false -Force $viserver
Write-Host -ForegroundColor White "`n`nExiting ..."
Exit
