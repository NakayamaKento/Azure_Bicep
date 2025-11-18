<#
	register-imds-startup.ps1

	役割:
		- C:\Scripts\customlog.ps1 を Windows 起動時に実行するスケジュールタスクを登録する
		- 既にタスクが存在する場合は上書きする

	想定:
		- customlog.ps1 は既に C:\Scripts\customlog.ps1 に配置済み
		- Custom Script Extension などから管理者権限で実行される
#>

[CmdletBinding()]
param()

$scriptDir  = 'C:\Scripts'
$scriptPath = Join-Path $scriptDir 'customlog.ps1'

if (-not (Test-Path $scriptPath)) {
		Write-Error "Script not found: $scriptPath"
		exit 1
}

$taskName = 'Start-IMDSCollectionOnBoot'

try {
		Write-Host "Registering scheduled task '$taskName' for $scriptPath" -ForegroundColor Cyan

		$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
		$trigger = New-ScheduledTaskTrigger -AtStartup
		$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

		$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal

		# 既存タスクがあれば上書き
		Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null

		Write-Host "Scheduled task '$taskName' registered successfully." -ForegroundColor Green
}
catch {
		Write-Error "Failed to register scheduled task '$taskName': $_"
		exit 1
}

