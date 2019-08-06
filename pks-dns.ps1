[CmdletBinding()]
param(
    [string]$PKSUser,
    [string]$PKSPass,
    [string]$PKSServer, 
    [string]$RemoteUser,
    [string]$RemotePass,
    [string]$RemoteServer,
    [string]$DNSZoneName,
    [string]$DNSServerName
)
### Requires PowerShell Core 6.2+
#######Variables############
# $PKSUser: User account with the permission "pks.clusters.admin" granted.
# $PKSPass: Password for the "PKSUser" account.
# $PKSServer: FQDN of the PKS server itself.

# $RemoteUser: User name with access to the remote system that will perform the DNS adds.
# $RemotePass: Password of "RemoteUser" account.
# $RemoteServer: Remote server where the SSH session will be established. The DNS add will be performed on this machine.

# $DNSZoneName: DNS zone of the PKS clusters being added.
# $DNSServerName: DNS server to which the "RemoteServer" will connect to perform the actual DNS record adds.
#############################
#### Dump out the K8s cluster info into a file. We only need the node labels.
if (-not (Test-Path /clusterinfo)){
Write-Output "Dumping cluster info to file."
/kubectl cluster-info dump >> /clusterinfo
}
#### Strip the K8s cluster name from the dumped info via the node label. This is the short name of the K8s cluster.
$string1 = Select-String -Path /clusterinfo -Pattern "pks-system/cluster.name" | Select-Object -First 1
$PKSCluster = $string1 -replace '[\s\S]*pks-system/cluster.name":\s*"([^"]*)[\s\S]*', '$1'

$sourceK8scluster = $PKSCluster

#### Create credential and connect to UAAC to get the auth token.
$secpasswd = ConvertTo-SecureString "$PKSPass" -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ($PKSUser, $secpasswd)

$headers = @{
    'accept' = 'application/json'
}

$URI = ("https://" + $PKSServer + ":8443/oauth/token")
$BODY = @{
    grant_type = "client_credentials"
    response_type = "id_token"
    }

try {
    $oidc_tokens=Invoke-RestMethod -SkipCertificateCheck -Method Post -Uri $URI -Body $BODY -Headers $headers -ContentType 'application/x-www-form-urlencoded;charset=utf-8' -Credential $mycreds
    }

catch {
   write-error "Auth Failed"
   Throw $_
   }

#### Save the access token to a variable to be reused.
$access_token = $oidc_tokens.access_token
#Write-Output "My token is $access_token"
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null

#### Loop to check PKS API for master IP. The pod will get pulled and started often times much before the PKS API has the IP.
#### Sleep for 60 seconds until the IP is returned, then continue.
Do {
    Write-Output "Sleeping for 60 seconds."
    Start-Sleep -s 60
    $URI = ("https://" + $PKSServer + ":9021/v1/clusters")
    $headers = @{
        'accept' = 'application/json'
        'authorization' = "Bearer ${access_token}"
        }

    try {
        $output = Invoke-RestMethod -SkipCertificateCheck -Method GET -URI $URI -Headers $headers
        }

    catch {
        Write-Error "Failed"
        Throw $_
        }

#### Grab the assigned master IP from the request.
$k8sIP = ($output | Where-Object Name -eq $sourceK8scluster).kubernetes_master_ips[0]
    } Until ($k8sIP -notmatch "[a-z]")

#### Check the value one last time and fail if not. Pod should restart.
if ($k8sIP -match "[a-z]"){
    Write-Error "Detected a non-valid IP address. Script will fail."
    exit 1}
else{
    Write-Output "Master IP is $k8sIP"}

#### Grab the hostname configured for the master load balancer.
$k8sFQDN = ($output | Where-Object Name -eq $sourceK8scluster).parameters.kubernetes_master_host
Write-Output "Master FQDN is $k8sFQDN"

#### Connect to remote host via SSH to run DNS add. Requires sshpass and openssh-clients packages.
/usr/bin/sshpass -p $RemotePass /usr/bin/ssh -o 'StrictHostKeyChecking no' $RemoteUser@$RemoteServer "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command "Add-DnsServerResourceRecordA -ZoneName $DNSZoneName -Name $PKSCluster -IPv4Address $k8sIP -CreatePtr -ComputerName $DNSServerName""