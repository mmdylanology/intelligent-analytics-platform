# Quick Reference Guide

## 🚀 Daily Operations

### Start Grafana
```bash
cd ~/grafana-setup
docker-compose up -d
```
Access at: http://localhost:3001 (admin/admin)

### Stop Grafana
```bash
docker-compose down
```
**Your data is safe!** It persists in Docker volume.

### Check Status
```bash
./status.sh
```

### View Logs
```bash
docker-compose logs -f grafana
```

## 💾 Backup Commands

### Create Backup
```bash
./backup.sh
```
Stores in `backups/grafana_backup_YYYYMMDD_HHMMSS/`

### List Backups
```bash
./restore.sh
```
Shows all available backup timestamps.

### Restore Backup
```bash
./restore.sh 20251229_015248
```
**Warning:** Replaces current data!

## 🔧 Common Tasks

### Change Admin Password
1. Login to Grafana
2. Click profile icon (bottom left)
3. Preferences → Change Password

### Add New Dashboard
1. Click **+** icon → **Dashboard**
2. **Add visualization**
3. Select datasource: **Nucleo Postgres**
4. Write SQL query
5. Choose visualization type
6. **Apply** → **Save dashboard**

### Edit Existing Panel
1. Click panel title → **Edit**
2. Modify query or visualization
3. **Apply**
4. **Save dashboard**

### Export Dashboard
1. Dashboard settings (gear icon)
2. **JSON Model**
3. Copy JSON
4. Save to file

### Import Dashboard
1. **+** icon → **Import**
2. Paste JSON or upload file
3. Select datasource
4. **Import**

## 🗄️ Database Queries

### Test Connection
```bash
PGPASSWORD='d0=JIim46R6:dLg$KW' psql \
  -h serhafen-db-postgres-staging.cluster-chgg2qqoy9y6.us-east-1.rds.amazonaws.com \
  -U postgres \
  -d nucleo \
  -c "SELECT COUNT(*) FROM packages;"
```

### Useful Queries

**Total Packages:**
```sql
SELECT COUNT(*) FROM packages;
```

**Packages by Status:**
```sql
SELECT latest_status, COUNT(*) 
FROM packages 
GROUP BY latest_status 
ORDER BY COUNT(*) DESC;
```

**Today's Packages:**
```sql
SELECT COUNT(*) 
FROM packages 
WHERE created_at >= CURRENT_DATE;
```

**Executor Performance:**
```sql
SELECT executor_name, COUNT(*) as packages
FROM executor_status_updates
GROUP BY executor_name
ORDER BY packages DESC;
```

## 🔍 Troubleshooting

### Dashboard Shows "No Data"
1. Check datasource: Settings → Data Sources → Nucleo Postgres
2. Click **Save & test** - should show "Database Connection OK"
3. If failed, check:
   - Database credentials in `provisioning/datasources/postgres.yml`
   - AWS RDS security group allows your IP
   - SSL mode is `disable`

### Container Won't Start
```bash
# Check Docker is running
docker ps

# Check port 3001 is free
lsof -i :3001

# View error logs
docker-compose logs grafana
```

### Lost Dashboard Changes
Dashboards are auto-saved but can be recovered:
```bash
# List backups
./restore.sh

# Restore from backup
./restore.sh YYYYMMDD_HHMMSS
```

### Datasource Connection Fails
1. Check container can reach database:
   ```bash
   docker exec grafana-shipments nc -zv serhafen-db-postgres-staging.cluster-chgg2qqoy9y6.us-east-1.rds.amazonaws.com 5432
   ```
2. Verify password in `provisioning/datasources/postgres.yml`
3. Restart container:
   ```bash
   docker-compose restart
   ```

## 📊 Dashboard URLs

- Main: http://localhost:3001
- Shipment Operations: http://localhost:3001/d/shipment-ops-001/shipment-operations
- Datasources: http://localhost:3001/connections/datasources
- Dashboard List: http://localhost:3001/dashboards

## ⚙️ Configuration Files

- `docker-compose.yml` - Container config
- `.env` - Credentials (keep private!)
- `provisioning/datasources/postgres.yml` - Database connection
- `provisioning/dashboards/default.yml` - Dashboard auto-load
- `dashboards/*.json` - Dashboard definitions

## 🆘 Emergency Commands

### Complete Reset
```bash
docker-compose down -v  # DELETES ALL DATA!
docker-compose up -d    # Fresh start
```

### Backup Before Reset
```bash
./backup.sh
docker-compose down -v
docker-compose up -d
```

### Check Disk Usage
```bash
docker system df
```

### Clean Up Old Images
```bash
docker system prune -a
```
