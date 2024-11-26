param(
    [string]$esUser,
    [string]$esPassword,
    [string]$esHost,
    [string]$backupDestination,
    [int]$retentionDays,
    [int]$esPort = 9200,
    [switch]$UseHttps
)

function Backup-Elasticsearch {
    # Validate input parameters
    if (-not $esUser) { Write-Error "Elasticsearch user is not specified."; return }
    if (-not $esPassword) { Write-Error "Elasticsearch password is not specified."; return }
    if (-not $esHost -match "^[a-zA-Z0-9.-]+$") { Write-Error "Invalid Elasticsearch host."; return }
    if (-not $backupDestination -or -not (Test-Path $backupDestination)) {
        Write-Error "Backup destination is not specified or does not exist."; return
    }
    if (-not $retentionDays -or $retentionDays -lt 1) {
        Write-Error "Invalid retention days specified."; return
    }

    # Determine protocol
    $protocol = if ($UseHttps) { "https" } else { "http" }

    # Build the Elasticsearch URL
    $esUrl = "${protocol}://${esHost}:${esPort}/_search?pretty&size=1000"
    Write-Output "Constructed URL: $esUrl"

    # Base64 encode credentials
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $esUser, $esPassword)))

    # Define the backup filename
    $date = Get-Date -Format "yyyyMMddHHmmss"
    $backupFile = Join-Path -Path $backupDestination -ChildPath "es_backup_$date.json"

    # Perform backup
    try {
        $response = Invoke-WebRequest -Uri $esUrl -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method Get -OutFile $backupFile
    }
    catch {
        Write-Error "Error during Elasticsearch backup: $($_.Exception.Message)"
        return
    }

    # Validate and compress backup
    if (Test-Path $backupFile -and (Get-Item $backupFile).Length -gt 0) {
        Write-Output "Backup successful, compressing..."
        Compress-Archive -Path $backupFile -DestinationPath "$($backupFile).zip" -Force
        Remove-Item -Path $backupFile -Force

        if (Test-Path "$($backupFile).zip") {
            Write-Output "Backup compressed successfully: $($backupFile).zip"
        } else {
            Write-Error "Failed to compress the backup file."
        }
    } else {
        Write-Error "Backup failed, file is empty or not created."
    }

    # Remove old backups
    Get-ChildItem -Path $backupDestination -Filter *.zip | Where-Object {
        $_.LastWriteTime -lt (Get-Date).AddDays(-$retentionDays)
    } | ForEach-Object {
        Remove-Item $_.FullName -Force
        Write-Output "Removed old backup file: $($_.FullName)"
    }
}

Backup-Elasticsearch

