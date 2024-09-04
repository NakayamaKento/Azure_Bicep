Install-WindowsFeature -Name DNS -IncludeManagementTools
$Forwarders = "10.1.1.4","10.2.1.4"
Set-DnsServerForwarder -IPAddress $Forwarders