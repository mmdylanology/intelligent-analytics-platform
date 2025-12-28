# Grafana Dashboard Summary

## 📊 Dashboard Overview

### Shipment Operations Dashboard
**URL:** http://localhost:3001/d/shipment-ops-001/shipment-operations

#### Panels:

1. **Total Packages** (Stat)
   - Shows total package count: **892**
   - Big red number for visibility

2. **Status Distribution** (Donut Chart)
   - Colorful breakdown of package statuses
   - Largest slice: CREATED (704 packages - 78.9%)
   - Other statuses: SHIPMENT_INITIATED (53), DELIVERED (4), etc.
   - 20+ different status values displayed

3. **Delivery Success Rate** (Gauge)
   - Current rate: **0.45%** (4 delivered out of 892)
   - Color coded: Red (0-30%), Yellow (30-70%), Green (70-100%)
   - Shows delivery performance at a glance

4. **Daily Package Volume** (Bar Gauge)
   - Last 14 days of package creation
   - Gradient bars: green → yellow → orange → red
   - Peak day: **Dec 17 with 672 packages**
   - Shows volume trends and busy periods

5. **Package Status Timeline** (Time Series)
   - 7-day activity chart
   - Shows status update patterns
   - Activity spikes visible on Dec 23, 24, 26

6. **Executor Performance** (Table)
   - Top performers:
     * **DKT**: 677 packages, 721 updates, 8 active days
     * **USP**: 54 packages, 41 updates, 4 active days
     * **dinat**: 18 packages, 18 updates, 4 active days
   - Shows carrier workload distribution

7. **Latest Shipments** (Table)
   - 20 most recent shipments
   - Columns: shipment_id, client_id, destination_country, package_count, created_at
   - Real-time monitoring of new shipments

8. **Packages by Status** (Horizontal Bar Chart)
   - Status breakdown with readable labels
   - Easier to read than pie chart for many statuses

9. **Geographic Distribution** (Table)
   - Packages by country:
     * PE (Peru): 885 shipments, 884 packages
     * AR (Argentina): 5 shipments, 5 packages  
     * CL (Chile): 3 shipments, 3 packages

10. **Packages Over Time** (Table)
    - Hourly breakdown of package creation
    - Shows detailed timing patterns

## 🗄️ Database Schema Used

### Tables:
- **packages**: Main package data (892 rows)
- **shipments**: Shipment information (893 rows)
- **executor_status_updates**: Package status change history
- **carrier**: Carrier master data
- **geography_***: Location hierarchy (country, state, county, district, zipcode)

### Key Relationships:
- shipments (1) → packages (many) via shipment_id
- packages (1) → executor_status_updates (many) via package_id

## 📈 Key Metrics

- **Total Packages**: 892
- **Total Shipments**: 893
- **Delivery Rate**: 0.45% (4 delivered)
- **Most Active Executor**: DKT (677 packages)
- **Primary Destination**: Peru (99%)
- **Busiest Day**: Dec 17, 2025 (672 packages)
- **Date Range**: Dec 15-27, 2025

## 🎨 Visualization Types Used

1. **Stat** - Big number display
2. **Donut Chart** - Colorful status distribution
3. **Gauge** - Percentage with color thresholds
4. **Bar Gauge** - Gradient horizontal bars
5. **Time Series** - Line chart over time
6. **Table** - Detailed data rows
7. **Bar Chart** - Horizontal bars for comparisons

## 🔄 Auto-Refresh

Dashboard refreshes every **30 seconds** to show near real-time data.

## 🎯 Dashboard Goals

1. **Operations Monitoring**: Track package flow in real-time
2. **Performance Metrics**: Measure delivery success rates
3. **Executor Analytics**: Compare carrier performance
4. **Volume Tracking**: Identify busy periods and trends
5. **Status Visibility**: Quick overview of package lifecycle

## 📝 Notes

- SSL disabled on database connection for compatibility
- All times in database timezone
- Dashboards use SQL queries directly (no transformations)
- Color schemes optimized for visibility
