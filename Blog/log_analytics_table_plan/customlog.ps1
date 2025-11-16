# Azure IMDS Data Collection Script
# This script collects data from Azure Instance Metadata Service (IMDS) every minute
# and saves it to C:\Logs\ directory with proper error handling and logging

[CmdletBinding()]
param(
    [string]$LogDirectory = "C:\Logs",
    [int]$IntervalSeconds = 60,
    [bool]$IncludeAttestationData = $false,
    [bool]$IncludeScheduledEvents = $true,
    [bool]$ContinuousMode = $true,
    [ValidateSet("Text","Json")]
    [string]$OutputFormat = "Text" # Azure Monitor カスタムテキストログ取り込みを既定に
)

# Error handling and logging setup
$ErrorActionPreference = "Continue"
$LogFile = Join-Path $LogDirectory "imds-collection.log"

# Function to write log messages
function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARN"  { Write-Host $logEntry -ForegroundColor Yellow }
        "INFO"  { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry }
    }
    
    # Write to log file
    try {
        Add-Content -Path $LogFile -Value $logEntry -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
    }
}

# Function to ensure directory exists
function Ensure-Directory {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-LogMessage "Created directory: $Path"
        }
        catch {
            Write-LogMessage "Failed to create directory $Path : $_" -Level "ERROR"
            throw
        }
    }
}

# Function to make IMDS API call with retry logic
function Invoke-IMDSRequest {
    param(
        [string]$Uri,
        [int]$MaxRetries = 3,
        [int]$RetryDelaySeconds = 2
    )
    
    $headers = @{
        'Metadata' = 'true'
    }
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-LogMessage "Attempting IMDS request to $Uri (attempt $attempt/$MaxRetries)"
            
            $response = Invoke-RestMethod -Uri $Uri -Headers $headers -Method Get -TimeoutSec 30
            Write-LogMessage "Successfully retrieved data from $Uri"
            return $response
        }
        catch {
            $errorMessage = "IMDS request failed (attempt $attempt/$MaxRetries): $_"
            
            if ($attempt -eq $MaxRetries) {
                Write-LogMessage $errorMessage -Level "ERROR"
                throw
            }
            else {
                Write-LogMessage $errorMessage -Level "WARN"
                Start-Sleep -Seconds ($RetryDelaySeconds * $attempt)
            }
        }
    }
}

# Function to collect instance metadata
function Get-InstanceMetadata {
    $baseUri = "http://169.254.169.254/metadata/instance"
    $apiVersion = "2021-02-01"
    
    try {
        # Get compute metadata
        $computeUri = "$baseUri/compute?api-version=$apiVersion"
        $computeData = Invoke-IMDSRequest -Uri $computeUri
        
        # Get network metadata
        $networkUri = "$baseUri/network?api-version=$apiVersion"
        $networkData = Invoke-IMDSRequest -Uri $networkUri
        
        # Combine metadata
        $metadata = @{
            timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
            compute = $computeData
            network = $networkData
        }
        
        return $metadata
    }
    catch {
        Write-LogMessage "Failed to collect instance metadata: $_" -Level "ERROR"
        throw
    }
}

# Function to collect scheduled events
function Get-ScheduledEvents {
    if (-not $IncludeScheduledEvents) {
        return $null
    }
    
    try {
        $scheduledEventsUri = "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01"
        $scheduledEvents = Invoke-IMDSRequest -Uri $scheduledEventsUri
        
        Write-LogMessage "Retrieved scheduled events data"
        return $scheduledEvents
    }
    catch {
        Write-LogMessage "Failed to collect scheduled events: $_" -Level "WARN"
        return $null
    }
}

# Function to collect attestation data
function Get-AttestationData {
    if (-not $IncludeAttestationData) {
        return $null
    }
    
    try {
        $attestationUri = "http://169.254.169.254/metadata/attested/document?api-version=2020-09-01"
        $attestationData = Invoke-IMDSRequest -Uri $attestationUri
        
        Write-LogMessage "Retrieved attestation data"
        return $attestationData
    }
    catch {
        Write-LogMessage "Failed to collect attestation data: $_" -Level "WARN"
        return $null
    }
}

# Function to save data to file
function Save-IMDSData {
    param(
        [object]$Data,
        [string]$Directory,
        [string]$Prefix = "imds-data"
    )
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $filename = "$Prefix-$timestamp.json"
        $filepath = Join-Path $Directory $filename
        
        # Convert to JSON with proper formatting
        $jsonData = $Data | ConvertTo-Json -Depth 10 -Compress:$false
        
        # Save to file
        Set-Content -Path $filepath -Value $jsonData -Encoding UTF8
        
        Write-LogMessage "Saved IMDS data to: $filepath"
        
        # Clean up old files (keep last 24 hours worth of data)
        Remove-OldFiles -Directory $Directory -Prefix $Prefix -MaxAgeHours 24
    }
    catch {
        Write-LogMessage "Failed to save IMDS data: $_" -Level "ERROR"
        throw
    }
}

# 新: カスタムテキストログ 1 行レコード保存 (または従来 JSON) 用関数
function Save-IMDSRecord {
    param(
        [object]$Data,
        [string]$Directory,
        [int]$CycleNumber,
        [string]$Status = "Information", # Information | Warning | Error
        [string]$Category = "IMDS"
    )

    try {
        Ensure-Directory -Path $Directory

        if ($OutputFormat -eq "Json") {
            # 旧方式互換 (サイクル毎 JSON ファイル)
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filename = "imds-data-$timestamp.json"
            $filepath = Join-Path $Directory $filename
            $jsonData = $Data | ConvertTo-Json -Depth 10 -Compress:$false
            Set-Content -Path $filepath -Value $jsonData -Encoding UTF8
            Write-LogMessage "Saved JSON IMDS data to: $filepath"
            Remove-OldFiles -Directory $Directory -Prefix "imds-data" -MaxAgeHours 24
        }
        else {
            # 新方式: 単一ログファイルへ 1 行追記
            $logFile = Join-Path $Directory "imds-customtext.log"
            $line = Build-IMDSLogLine -Data $Data -CycleNumber $CycleNumber -Level $Status -Category $Category
            Append-LineWithRetry -Path $logFile -Value $line -MaxRetries 6 -DelayMs 180
            # 内部ログ出力を抑止: 2行出力を避けるため (必要なら -Verbose で確認)
            Write-Verbose "Appended (retry-safe) custom text log line to: $logFile"
        }
    }
    catch {
        Write-LogMessage "Failed to save record: $_" -Level "ERROR"
        throw
    }
}

# 新: テキストログ 1 行構築
function Build-IMDSLogLine {
    param(
        [object]$Data,
        [int]$CycleNumber,
        [string]$Level,
        [string]$Category
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $eventId = "{0:D4}" -f $CycleNumber

    function Safe {
        param($expr)
        try { if ($null -eq $expr) { '' } else { [string]$expr } } catch { '' }
    }

    $instance = $Data.instance
    $compute  = $instance.compute
    $network  = $instance.network

    $privateIps = @()
    $publicIps  = @()
    try {
        foreach ($iface in ($network.interface | ForEach-Object { $_ })) {
            foreach ($ip in ($iface.ipv4.ipAddress | ForEach-Object { $_ })) {
                if ($ip.privateIpAddress) { $privateIps += $ip.privateIpAddress }
                if ($ip.publicIpAddress)  { $publicIps  += $ip.publicIpAddress }
            }
            foreach ($ip6 in ($iface.ipv6.ipAddress | ForEach-Object { $_ })) {
                if ($ip6.ipAddress) { $privateIps += $ip6.ipAddress }
            }
        }
    } catch { }

    $scheduledEventsCount = 0
    if ($Data.scheduledEvents -and $Data.scheduledEvents.Events) {
        $scheduledEventsCount = ($Data.scheduledEvents.Events | Measure-Object).Count
    }

    $attestationPresent = if ($Data.attestation) { 'true' } else { 'false' }

    $messagePairs = @(
        "vmName={0}"            -f (Safe $compute.name)
        "vmSize={0}"            -f (Safe $compute.vmSize)
        "location={0}"          -f (Safe $compute.location)
        "subscriptionId={0}"    -f (Safe $compute.subscriptionId)
        "resourceGroup={0}"     -f (Safe $compute.resourceGroupName)
        "privateIps={0}"        -f ((($privateIps | Sort-Object -Unique) -join '|'))
        "publicIps={0}"         -f ((($publicIps | Sort-Object -Unique) -join '|'))
        "scheduledEventsCount={0}" -f $scheduledEventsCount
        "attestationPresent={0}"   -f $attestationPresent
        "collectionTs={0}"      -f (Safe $Data.collectionTimestamp)
    )

    $message = ($messagePairs -join ';')
    return "{0},{1},{2},{3},{4}" -f $timestamp,$eventId,$Level,$Category,$message
}

# 追加: ファイルロック競合を緩和する再試行付き安全追記関数
function Append-LineWithRetry {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Value,
        [int]$MaxRetries = 5,
        [int]$DelayMs = 200
    )

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            # 末尾に改行を付与 (一行レコード形式)
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value + [Environment]::NewLine)
            $fileStream = [System.IO.File]::Open($Path,
                [System.IO.FileMode]::Append,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::ReadWrite)
            $fileStream.Write($bytes, 0, $bytes.Length)
            $fileStream.Dispose()
            if ($attempt -gt 1) { Write-Verbose "Append-LineWithRetry: 成功 attempt=$attempt path=$Path" }
            return
        }
        catch {
            $err = $_
            if ($attempt -eq $MaxRetries) {
                Write-LogMessage "Append-LineWithRetry: 最大再試行到達 (attempt=$attempt) - $err" -Level "ERROR"
                throw
            }
            else {
                Write-LogMessage "Append-LineWithRetry: 追記失敗 (attempt=$attempt) - $err" -Level "WARN"
                # 線形ではなく緩やかな指数的待機
                $sleep = [int]($DelayMs * [math]::Pow(1.6, ($attempt - 1)))
                Start-Sleep -Milliseconds $sleep
            }
        }
    }
}

# Function to clean up old files
function Remove-OldFiles {
    param(
        [string]$Directory,
        [string]$Prefix,
        [int]$MaxAgeHours = 24
    )
    
    try {
        $cutoffTime = (Get-Date).AddHours(-$MaxAgeHours)
        $pattern = "$Prefix-*.json"
        
        Get-ChildItem -Path $Directory -Filter $pattern | 
            Where-Object { $_.CreationTime -lt $cutoffTime } |
            ForEach-Object {
                Remove-Item $_.FullName -Force
                Write-LogMessage "Removed old file: $($_.Name)"
            }
    }
    catch {
        Write-LogMessage "Failed to clean up old files: $_" -Level "WARN"
    }
}

# Function to check if running on Azure VM
function Test-AzureVM {
    try {
        # Quick test to see if IMDS is accessible
        $testUri = "http://169.254.169.254/metadata/instance/compute/vmId?api-version=2021-02-01&format=text"
        $headers = @{ 'Metadata' = 'true' }
        
        $vmId = Invoke-RestMethod -Uri $testUri -Headers $headers -Method Get -TimeoutSec 5
        
        if ($vmId) {
            Write-LogMessage "Confirmed running on Azure VM (VM ID: $vmId)"
            return $true
        }
        else {
            Write-LogMessage "Not running on Azure VM - IMDS returned empty response" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-LogMessage "Not running on Azure VM - IMDS not accessible: $_" -Level "ERROR"
        return $false
    }
}

# Main execution function
function Start-IMDSCollection {
    Write-LogMessage "Starting Azure IMDS data collection"
    Write-LogMessage "Configuration: Directory=$LogDirectory, Interval=$IntervalSeconds seconds, Continuous=$ContinuousMode, OutputFormat=$OutputFormat"

    if (-not (Test-AzureVM)) {
        Write-LogMessage "IMDS がまだ利用できないか、Azure VM ではない可能性がありますが、ループを継続します" -Level "WARN"
    }

    Ensure-Directory -Path $LogDirectory

    $successCount = 0
    $errorCount   = 0

    do {
        $cycleNumber = $successCount + $errorCount + 1
        try {
            Write-LogMessage "Starting data collection cycle #$cycleNumber"
            $allData = @{
                collectionTimestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
                instance            = Get-InstanceMetadata
            }

            $partialWarning = $false

            if ($IncludeScheduledEvents) {
                $events = Get-ScheduledEvents
                if ($events -eq $null) { $partialWarning = $true }
                $allData.scheduledEvents = $events
            }

            if ($IncludeAttestationData) {
                $att = Get-AttestationData
                if ($att -eq $null) { $partialWarning = $true }
                $allData.attestation = $att
            }

            if ($partialWarning) {
                Save-IMDSRecord -Data $allData -Directory $LogDirectory -CycleNumber $cycleNumber -Status "Warning" -Category "IMDS"
            }
            else {
                Save-IMDSRecord -Data $allData -Directory $LogDirectory -CycleNumber $cycleNumber -Status "Information" -Category "IMDS"
            }

            $successCount++
            Write-LogMessage "Cycle #$cycleNumber completed (Success: $successCount / Errors: $errorCount)"
        }
        catch {
            $errorCount++
            Write-LogMessage "Cycle #$cycleNumber failed: $_ (Success: $successCount / Errors: $errorCount)" -Level "ERROR"
            try {
                $errorData = @{ collectionTimestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"; errorMessage = "$_" }
                Save-IMDSRecord -Data $errorData -Directory $LogDirectory -CycleNumber $cycleNumber -Status "Error" -Category "IMDS"
            } catch {
                Write-LogMessage "Failed to log error line: $_" -Level "ERROR"
            }
        }

        if ($ContinuousMode) {
            Write-LogMessage "Waiting $IntervalSeconds seconds until next collection..."
            Start-Sleep -Seconds $IntervalSeconds
        }
    } while ($ContinuousMode)

    Write-LogMessage "IMDS data collection completed. Final stats - Success: $successCount, Errors: $errorCount"
}

# Script entry point
try {
    # Ensure running as Administrator for best results
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-LogMessage "Warning: Script is not running as Administrator. Some operations may fail." -Level "WARN"
    }
    
    # Start the collection process
    Start-IMDSCollection
}
catch {
    Write-LogMessage "Script execution failed: $_" -Level "ERROR"
    exit 1
}
finally {
    Write-LogMessage "Script execution finished"
}

# Usage Examples:
# 
# Basic usage (1-minute intervals, continuous mode):
# .\windowsimds.ps1  # (既定 Text 出力 => C:\Logs\imds-customtext.log)
#
# Custom interval and directory:
# .\windowsimds.ps1 -LogDirectory "D:\Monitoring\IMDS" -IntervalSeconds 30
#
# One-time collection (non-continuous):
# .\windowsimds.ps1 -ContinuousMode $false
#
# Include all optional data:
# .\windowsimds.ps1 -IncludeAttestationData $true -IncludeScheduledEvents $true
#
# JSON 形式へ戻したい場合:
# .\windowsimds.ps1 -OutputFormat Json
#
# Run as Windows Service:
# Use tools like NSSM to run this script as a Windows service for production scenarios