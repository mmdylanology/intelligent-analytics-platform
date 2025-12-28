#!/bin/bash
# Grafana Restore Script
# Restores Grafana from a backup

if [ -z "$1" ]; then
  echo "Usage: ./restore.sh <backup_name>"
  echo "Available backups:"
  ls -1 ./backups/ 2>/dev/null || echo "No backups found"
  exit 1
fi

BACKUP_NAME=$1
BACKUP_PATH="./backups/${BACKUP_NAME}"

if [ ! -d "$BACKUP_PATH" ]; then
  echo "❌ Backup not found: ${BACKUP_PATH}"
  exit 1
fi

echo "🔄 Restoring Grafana from: ${BACKUP_NAME}"

# Stop Grafana
echo "⏸️  Stopping Grafana..."
docker-compose down

# Restore Grafana volume
echo "📦 Restoring Grafana data volume..."
docker run --rm \
  -v grafana-setup_grafana-data:/data \
  -v $(pwd)/${BACKUP_PATH}:/backup \
  alpine sh -c "cd /data && rm -rf ./* && tar xzf /backup/grafana-data.tar.gz"

# Restore configuration files
echo "📋 Restoring configuration files..."
cp -r ${BACKUP_PATH}/provisioning ./
cp -r ${BACKUP_PATH}/dashboards ./
cp ${BACKUP_PATH}/docker-compose.yml ./
cp ${BACKUP_PATH}/.env ./

# Restart Grafana
echo "🚀 Starting Grafana..."
docker-compose up -d

echo "✅ Restore completed!"
echo "🌐 Access Grafana at: http://localhost:3001"
