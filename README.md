# Grafana Setup for Nucleo Shipment Tracking

## 🎯 What's Included

- **3 Pre-built Dashboards:**
  1. Live Operations Monitor (real-time tracking)
  2. Carrier Performance & Coverage
  3. Exception & Delay Tracking

- **Auto-configured PostgreSQL connection** to your AWS RDS database
- **Data persistence** - your dashboards are saved even if you restart

## 🚀 Quick Start

### Start Grafana:
```bash
cd ~/grafana-setup
docker-compose up -d
```

### Access Grafana:
Open in browser: **http://localhost:3001**

**Login:**
- Username: `admin`
- Password: `admin`
- (You'll be prompted to change password on first login)

### Stop Grafana:
```bash
docker-compose down
```

### View Logs (if issues):
```bash
docker-compose logs -f grafana
```

## 📊 Dashboards Available

After login, go to **Dashboards** → **Browse** to see:

1. **Live Operations Monitor**
   - Total packages/shipments today
   - Active packages (not delivered)
   - Hourly package volume
   - Latest status updates (real-time)
   - Packages by executor

2. **Carrier Performance & Coverage**
   - Active carriers & coverage rules
   - Average TAT & logistics cost
   - Packages by carrier
   - Service type distribution
   - Coverage by country

3. **Exception & Delay Tracking**
   - 🚨 Packages with no update > 48hrs
   - Failed packages
   - Packages in transit > 7 days
   - Exception rate %
   - Delivery success rate

## 🔧 Customization

### Change Database Connection:
Edit: `provisioning/datasources/postgres.yml`

### Add New Dashboards:
1. Create dashboard in Grafana UI
2. Export as JSON
3. Save to `dashboards/` folder
4. Restart: `docker-compose restart`

### Change Grafana Port:
Edit `docker-compose.yml` → change `3001:3000` to your preferred port

## 🗑️ Uninstall

To completely remove Grafana:
```bash
cd ~/grafana-setup
docker-compose down -v  # -v removes volumes (your dashboards)
cd ..
rm -rf grafana-setup
```

**Note:** This NEVER touches your PostgreSQL database - Grafana only reads data.

## 🔒 Security Notes

1. **Change admin password** after first login (currently: admin/admin)
2. Credentials are in `.env` file (keep it private, added to .gitignore)
3. Database password in `provisioning/datasources/postgres.yml` with SSL disabled
4. Grafana runs locally on port 3001 (not exposed to internet)
5. **Never commit** `.env` or backup files to git

## 🔄 Data Persistence

Your Grafana data persists across container restarts via Docker volumes:
- **grafana-data volume**: Stores all dashboards, users, settings
- Even if you `docker-compose down`, your data remains safe
- Only `docker-compose down -v` will delete the volume

**To verify data persistence:**
```bash
docker-compose down    # Stop containers
docker-compose up -d   # Restart - your dashboards still there!
```

## 💾 Backup & Restore

### Create Backup
Automatically backs up Grafana data, dashboards, and configurations:
```bash
./backup.sh
```
Backups are stored in `./backups/grafana_backup_YYYYMMDD_HHMMSS/`

### Restore from Backup
```bash
./restore.sh 20251229_014500  # Use your backup timestamp
```
Lists available backups if no timestamp provided.

### What's Backed Up?
- ✅ Grafana volume data (users, settings, plugins)
- ✅ All dashboards (JSON files + API export)
- ✅ Datasource configurations
- ✅ Docker Compose and environment files

**💡 Tip:** Run `./backup.sh` before major changes!

## 📈 Dashboard Features

### Current Dashboards:
1. **Shipment Operations** - Main monitoring dashboard with:
   - Total Packages stat (892)
   - Status Distribution (colorful donut chart)
   - Delivery Success Rate gauge (0.45% - red warning)
   - Daily Package Volume (rainbow gradient bars)
   - Package Status Timeline (7-day activity)
   - Executor Performance table
   - Latest Shipments table
   - Packages by Status (horizontal bar chart)

### Auto-Refresh
Dashboards refresh every 30 seconds by default. Change in dashboard settings → Time range.

### Customization
- Click panel titles → **Edit** to modify queries
- Drag panels to rearrange layout
- Click **Add** → **Visualization** for new panels
- Use **Variables** for dynamic filters (Settings → Variables)

## 🆘 Troubleshooting

**Can't connect to database?**
- Check AWS RDS security groups allow your IP
- Verify credentials in `provisioning/datasources/postgres.yml`
- Check logs: `docker-compose logs grafana`

**Dashboard not loading?**
- Wait 10-30 seconds after startup
- Check data source is connected: Settings → Data Sources
- Refresh browser

**Port 3001 already in use?**
- Edit `docker-compose.yml` → change port
- Or stop other service using port 3001
