############User Variables################
$User="administrator@vsphere.local"
$password="VMware1!" | ConvertTo-SecureString -AsPlainText -Force
$vc="sa-vcsa-01.vclass.local"
$CryptoPSModule="C:\Vmware.VMEncryption.psm1"
$cluster="sa-compute-01"
##########################################

Import-Module $CryptoPSModule
$cred=New-Object System.Management.Automation.PSCredential($User,$password)
Connect-Viserver -Server $vc -Credential $cred
$getvc=Get-viserver -server $vc -Credential $cred

Write-Host -ForegroundColor Green "*********`n*vCenter*`n*********"
$VCCryptoView=Get-View -Id $getvc.ExtensionData.Content.CryptoManager
    $VCListKeys=$VCCryptoView.ListKeys($null)
    Write-Host -ForegroundColor Yellow "Key IDs vCenter is aware of:"
        $VCKeysTable=New-Object System.Data.DataTable "Key Ids Known to VC"
        $VCkeysTableCol1=New-Object System.Data.DataColumn KeyID,([string])
        $VCkeysTableCol2=New-Object System.Data.DataColumn KMS_ClusterId,([string])
        $VCKeysTable.columns.add($VCkeysTableCol1)
        $VCKeysTable.columns.add($VCkeysTableCol2)
        $VCListKeys | % {$row=$VCKeysTable.NewRow();$row.KeyID=$_.KeyId;$row.KMS_ClusterId=$_.ProviderId.Id;$VCKeysTable.Rows.Add($row)}
        $VCKeysTable | Format-Table -AutoSize

Write-Host -ForegroundColor Green "`n************************`n*Host Key Cache Summary*`n************************"
$Hostlist=Get-VMHost -Location $cluster
foreach ($VMHost in $Hostlist) {
    $VMHostCryptoView=Get-View -Id $VMHost.ExtensionData.ConfigManager.CryptoManager
        $VMHostListKeys=$VMHostCryptoView.ListKeys($null)
        Write-Host -ForegroundColor Yellow "`nHostname: $VMhost"
        Write-Host -ForegroundColor Cyan "KeyIds in host's cache"
        $VMHostListKeys.KeyId | fl
        $VMHostKeyProvider=$VMHostListKeys.ProviderId
        Write-Host -ForegroundColor Cyan "KMS Cluster providing keys"
        $VMHostKeyProvider.Id 
    }

Write-Host -ForeGroundColor Green "`n************************************`n*HostKeys used by Crypto-safe Hosts*`n************************************"
$CryptoVMs=Get-VM|Where {$_.Encrypted}
$Hostlist=Get-VMHost -Location $cluster
foreach ($VMHost in $Hostlist) {
    $VMHostView=$VMHost | Get-View
        $HostKeysTable=New-Object System.Data.DataTable "TestVM Key"
        $HostkeysTableCol1=New-Object System.Data.DataColumn KeyID,([string])
        $HostkeysTableCol2=New-Object System.Data.DataColumn KMS_ClusterId,([string])
        $HostKeysTable.columns.add($HostkeysTableCol1)
        $HostKeysTable.columns.add($HostkeysTableCol2)
        $row=$HostKeysTable.NewRow();$row.KeyID=$VMHostView.Runtime.CryptoKeyId.KeyId;$row.KMS_ClusterId=$VMHostView.Runtime.CryptoKeyId.ProviderId.Id;$HostKeysTable.Rows.Add($row)
        $HostKeysTable | Format-Table -AutoSize
    }
	
Write-Host -ForeGroundColor Green "`n****************************`n*Keys used by Encrypted VMs*`n****************************"
$CryptoVMs=Get-VM|Where {$_.Encrypted}
foreach ($vm in $CryptoVMs) {
    Write-Host -ForegroundColor Yellow "$vm"
    $VMinfo=$vm | Get-VMEncryptionInfo
        $VMKeysTable=New-Object System.Data.DataTable "TestVM Key"
        $VMkeysTableCol1=New-Object System.Data.DataColumn KeyID,([string])
        $VMkeysTableCol2=New-Object System.Data.DataColumn KMS_ClusterId,([string])
        $VMKeysTable.columns.add($VMkeysTableCol1)
        $VMKeysTable.columns.add($VMkeysTableCol2)
        $row=$VMKeysTable.NewRow();$row.KeyID=$VMinfo.KeyId.KeyId;$row.KMS_ClusterId=$VMinfo.keyId.ProviderId.Id;$VMKeysTable.Rows.Add($row)
        $VMKeysTable | Format-Table -AutoSize
    }
