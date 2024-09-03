Param(
    [Parameter(Mandatory=$true)]
    [String[]]$Forwarders = @('10.1.0.4', '10.2.0.4')
)

Install-WindowsFeature -Name DNS
Set-DnsServerForwarder -IPAddress $Forwarders