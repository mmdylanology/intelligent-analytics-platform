# Last Mile Ecommerce Dashboard - Import Guide

## 📊 Dashboard Ready!

Your **Last Mile Ecommerce** dashboard has been created and is ready to import into Grafana.

### Quick Import Steps

#### Option 1: Grafana UI (Recommended)

1. **Open Grafana:**
   ```
   http://localhost:3001
   ```

2. **Import Dashboard:**
   - Click **"+"** (Plus icon) in sidebar
   - Select **"Import"**
   - Click **"Upload JSON file"**
   - Select: `last-mile-ecommerce-dashboard.json`

3. **Configure Data Source:**
   - When prompted, select datasource: **Postgres (nucleo)**
   - UID should be: `postgres-nucleo` or similar

4. **Click** "Import"

5. **Done!** Dashboard is now available 🎉

#### Option 2: API Import (Automated)

```bash
# Run from grafana-setup directory
./import_dashboard.sh
```

---

## 🎨 What's Included

### Dashboard: "Last Mile Ecommerce - Distribución"

**Global Filters (Top Bar):**
- 📅 **Año** (Year) - Dropdown
- 📅 **Mes** (Month) - Dropdown  
- 📅 **Semana** (Week) - Multi-select with "All" option
- 📦 **Cliente** (Client) - Multi-select with "All" option

**Page 1: Overview (11 Panels)**

**Row 1 - KPIs:**
1. **TOTAL PEDIDOS** - Total order count
2. **OTIF GENERAL** - Gauge (0-100%)
3. **% ON TIME** - Percentage stat
4. **% IN FULL** - Percentage stat
5. **A Tiempo** - Pie chart (On-time vs Late)
6. **CERRADO** - Pie chart (Pending vs Closed)

**Row 2 - Charts:**
7. **Cant Pedidos Real** - Weekly trend line chart
8. **COBERTURA** - Donut chart (Local vs Nacional)

**Row 3 - Analytics:**
9. **% ON TIME** (by coverage) - Horizontal bar chart
10. **% IN FULL** (by coverage) - Horizontal bar chart
11. **ON_TIME SEMANAL** - Weekly performance table

---

## ⚙️ Dashboard Features

### Auto-Refresh
- ✅ Refreshes every **30 seconds**
- Change in dashboard settings if needed

### Time Zone
- 🌎 Set to **America/Lima** (Peru)

### Theme
- 🌓 **Dark theme** (matching Power BI design)

### Filters
- All panels respect global variables
- Change year/month/week at top
- All charts update automatically

---

## 🔧 Customization

### Edit Panels
1. Click panel title → **Edit**
2. Modify SQL query in Query tab
3. Adjust visualization in Panel options
4. Save dashboard

### Add New Panels
1. Click **Add** → **Visualization**
2. Write SQL query
3. Choose visualization type
4. Position and save

### Modify Variables
1. Dashboard settings (gear icon)
2. Variables section
3. Edit existing or add new
4. Save dashboard

---

## 📝 Known Placeholders

> [!WARNING]
> The following metrics use **placeholder calculations** and need refinement:

1. **OTIF GENERAL** - Currently using delivered count / total
   - *TODO:* Add TAT (Turn Around Time) logic from `carrier_coverage`

2. **% ON TIME** - Static 95.74%
   - *TODO:* Calculate based on actual delivery times vs expected TAT

3. **% IN FULL** - Static 95.32%
   - *TODO:* Define "IN FULL" logic (first attempt delivery?)

4. **Coverage (Local/Nacional)** - Currently PE = Local, others = Nacional
   - *TODO:* Clarify business rule for Local vs Nacional

5. **Weekly breakdown values** - Using sample calculations
   - *TODO:* Implement actual weekly aggregations

---

## 🚀 Next Steps

### Immediate
- [ ] Import dashboard to Grafana
- [ ] Verify all panels load
- [ ] Test filter variables
- [ ] Review visual layout

### Short-term (This Week)
- [ ] Get clarification on 5 questions from implementation plan
- [ ] Implement correct OTIF calculation
- [ ] Add real ON TIME / IN FULL logic
- [ ] Test with actual date filters

### Medium-term (Next Week)
- [ ] Add Page 2: Detailed Analytics
  - Department hierarchy table
  - Status breakdown
  - Delivery visit analysis
  - Failure reasons
  - Pending orders table
- [ ] Add interactivity (drill-downs)
- [ ] Performance optimization
- [ ] User acceptance testing

---

## 📚 Files Created

| File | Purpose |
|------|---------|
| `generate_dashboard.py` | Python script to regenerate dashboard JSON |
| `last-mile-ecommerce-dashboard.json` | Dashboard definition (ready to import) |
| `last-mile-ecommerce.json` | Initial template (superseded) |
| `IMPORT_GUIDE.md` | This file |

---

## 🔍 Troubleshooting

**Dashboard not loading?**
- Check Grafana logs: `docker-compose logs grafana`
- Verify datasource connection in Grafana → Connections → Data sources

**Panels showing "No data"?**
- Check date filters (year/month/week)
- Ensure packages table has data for selected period
- Test queries directly in PostgreSQL

**Variables not working?**
- Make sure datasource UID is correct (`${DS_POSTGRES}`)
- Check variable queries in dashboard settings

**Import fails?**
- Verify JSON is valid (check for syntax errors)
- Try importing via Grafana API instead of UI

---

## 📞 Support

If you encounter issues:

1. Check Grafana documentation: https://grafana.com/docs/
2. Review SQL queries in panel edit mode
3. Test queries directly in database
4. Check browser console for errors

---

**Ready to import?** Open http://localhost:3001 and follow the steps above! 🚀
