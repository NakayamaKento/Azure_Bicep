Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Set-Location -Path C:\inetpub\wwwroot
Add-Content iisstart.htm "<H1><center>WELCOME to my Web Server $env:COMPUTERNAME, Azure Network Rocks!!!!!!!</center></H1>"
Invoke-Command -ScriptBlock { iisreset }