# Ultimus Dashboard Calculation Logic

This document explains how the data in the Ultimus Grafana dashboard is calculated directly from the PostgreSQL `nucleo` database.

---

## 🕒 Global Status Codes
All metrics are driven by the `packages_activity_log` table using these canonical codes:
- **8000**: Created (Creados)
- **8005**: Accepted by Partner (Aceptados)
- **2080**: Primary Zone Departure (Used for "Buscados" Stat Card)
- **7020**: Hub Arrival (Used for "Buscados" in Packet Table and P95)
- **7050**: Delivered (Entregados)

- **7050**: Delivered (Entregados)

### 🚨 Note on "Not Delivered" Logic
We do **NOT** calculate "Not Delivered" by only summing up failure codes (like 7060). Instead, we use a **Total Gap** approach:
`Accepted Packages - Delivered Packages = Not Delivered`

This ensures that everything currently "In Transit" or "Pending" is correctly counted against the delivery goal.

## 📊 Summary Panels

### Total Paquetes (Panel 3)
- **Goal**: Show the absolute universe of packages.
- **Logic**: Counts every unique `package_id` in the database within the selected time range.
- **Filter**: Ignores the "Courier" filter so you can see unassigned packages.

### Data Range Summary (Panel 2)
- **Goal**: Show the filtered workload.
- **Logic**: Counts unique `master_awb_no` (MAWBs) and `package_id` (PACKAGES).
- **Filter**: Respects both "MAWB" and "Courier" filters.

### Aceptados por UM (Panel 7)
- **Count**: Number of packages that reached status **8005**.
- **Percentage**: `(Aceptados / Creados) * 100`.

### Creados UM (Panel 6)
- **Count**: Number of packages that reached status **8000**.
- **Percentage**: `(Creados / Total_Pool) * 100`.

### Buscados UM (Panel 8)
- **Count**: Number of packages that reached status **2080**.
- **Percentage**: `(Buscados / Aceptados) * 100`.

---

## 📈 Performance Metrics

### Tasa de entrega (Panel 9)
- **Calculation**: `(Delivered / Accepted) * 100`.
- **Logic**: Only considers packages that were successfully accepted (**8005**) and subsequently delivered (**7050**).

### No entregados (Panel 10)
- **Calculation**: `(Accepted - Delivered) / Accepted * 100`
- **Logic**: This uses the **Gap Method**. Instead of just counting specific failure codes (like 7060), we subtract the total delivered from the total accepted. 
- **Why?**: This ensures that packages that are "In Transit" or have failed for undocumented reasons are still captured in the failure rate.

### Detalles enviados UM (Panel 11)
- **Logic**: Categorizes "No Entregados" as any package that was **Accepted** but has **NULL** for its delivery timestamp.

### Tiempo de Entrega UM (Panel 5)
- **Calculation**: `Average(Delivered_At - Created_At)` in hours.
- **Unit**: Forced to `hrs.` to prevent automatic conversion to days by Grafana.

---

## 🌍 P95 Delivery Times (Local vs Interior)
Calculates the 95th percentile of `(Delivered_At - Picked_At)` in days.

### Region Logic:
- **Local**: 
  - **Peru**: Region is exactly `LIMA`.
  - **Chile**: Region is exactly `SANTIAGO`.
- **Interior**: Every other region not matching the above.

---

## 📋 Detail Tables

### Detalle por master (Panel 24)
- **Aggregation**: Groups all metrics by `master_awb_no`.
- **Columns**: Totals, Creados, Aceptados, Buscados, Entregados, and No Entregados per MAWB.

### Detalle por paquete (Panel 25)
- **Granularity**: One row per unique package.
- **ID Reference**: Shows `package_id` (internal) and `tracking_number` (external).
- **Timestamps**: Uses the earliest occurrence in `activity_log` for each key lifecycle event (Created, Accepted, Picked, Delivered).

---

## 🔍 Filtering Behavior
- **MAWB Filter**: Applied to `master_awb_no`.
- **Courier Filter**: Applied to `partner_name`.
- **Time Filter**: Applied to `created_at`.
