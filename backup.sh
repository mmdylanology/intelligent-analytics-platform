#!/bin/bash
# Grafana Backup Script
# Creates timestamped backups of Grafana data and dashboards

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="grafana_backup_${TIMESTAMP}"

echo "🔄 Starting Grafana backup..."

# Create backup directory
mkdir -p ${BACKUP_DIR}/${BACKUP_NAME}

# Backup Grafana volume data
echo "📦 Backing up Grafana data volume..."
docker run --rm \
  -v grafana-setup_grafana-data:/data \
  -v $(pwd)/${BACKUP_DIR}/${BACKUP_NAME}:/backup \
  alpine tar czf /backup/grafana-data.tar.gz -C /data .

# Backup configuration files
echo "📋 Backing up configuration files..."
cp -r provisioning ${BACKUP_DIR}/${BACKUP_NAME}/
cp -r dashboards ${BACKUP_DIR}/${BACKUP_NAME}/
cp docker-compose.yml ${BACKUP_DIR}/${BACKUP_NAME}/
cp .env ${BACKUP_DIR}/${BACKUP_NAME}/

# Create backup info file
cat > ${BACKUP_DIR}/${BACKUP_NAME}/backup_info.txt << EOL
Grafana Backup Information
==========================
Backup Date: $(date)
Backup Name: ${BACKUP_NAME}
Dashboard Count: $(ls -1 dashboards/*.json 2>/dev/null | wc -l)
Datasource Count: $(ls -1 provisioning/datasources/*.yml 2>/dev/null | wc -l)

Contents:
- grafana-data.tar.gz (Grafana volume with dashboards and settings)
- provisioning/ (datasource and dashboard configs)
- dashboards/ (dashboard JSON files)
- docker-compose.yml
- .env

To restore:
1. Extract grafana-data.tar.gz to grafana volume
2. Copy provisioning/ and dashboards/ to grafana-setup directory
3. Run: docker-compose up -d
EOL

echo "✅ Backup completed: ${BACKUP_DIR}/${BACKUP_NAME}"
echo "📊 Backup size: $(du -sh ${BACKUP_DIR}/${BACKUP_NAME} | cut -f1)"
ls -lh ${BACKUP_DIR}/${BACKUP_NAME}/
