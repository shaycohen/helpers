#!/bin/bash

# Default Elasticsearch port
esPort=9200
useHttps=0

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -esUser|--esUser) esUser="$2"; shift ;;
        -esPassword|--esPassword) esPassword="$2"; shift ;;
        -esHost|--esHost) esHost="$2"; shift ;;
        -backupDestination|--backupDestination) backupDestination="$2"; shift ;;
        -retentionDays|--retentionDays) retentionDays="$2"; shift ;;
        -esPort|--esPort) esPort="$2"; shift ;;
        -UseHttps|--UseHttps) useHttps=1 ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Validate input parameters
if [ -z "$esUser" ] || [ -z "$esPassword" ] || [[ ! "$esHost" =~ ^[a-zA-Z0-9.-]+$ ]] || [ -z "$backupDestination" ] || [ ! -d "$backupDestination" ] || [ -z "$retentionDays" ] || [ "$retentionDays" -lt 1 ]; then
    echo "Error: Invalid input parameters."
    exit 1
fi

# Determine protocol
protocol="http"
if [ "$useHttps" -eq 1 ]; then
    protocol="https"
fi

# Build the Elasticsearch URL
esUrl="${protocol}://${esHost}:${esPort}/_search?pretty&size=1000"
echo "Constructed URL: $esUrl"

# Base64 encode credentials
base64AuthInfo=$(echo -n "$esUser:$esPassword" | base64)

# Define the backup filename
date=$(date +"%Y%m%d%H%M%S")
backupFile="${backupDestination}/es_backup_${date}.json"

# Perform backup
curl -s -X GET "$esUrl" -H "Authorization: Basic $base64AuthInfo" -o "$backupFile"

# Validate and compress backup
if [ -s "$backupFile" ]; then
    echo "Backup successful, compressing..."
    zip -j "${backupFile}.zip" "$backupFile"
    rm -f "$backupFile"

    if [ -f "${backupFile}.zip" ]; then
        echo "Backup compressed successfully: ${backupFile}.zip"
    else
        echo "Failed to compress the backup file."
    fi
else
    echo "Backup failed, file is empty or not created."
fi

# Remove old backups
find "$backupDestination" -type f -name '*.zip' -mtime +$retentionDays -exec rm {} \;
echo "Old backups removed."
