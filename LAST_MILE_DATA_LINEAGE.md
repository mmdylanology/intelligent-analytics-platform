# 📊 Last Mile Dashboard - Data Lineage & Table Reference Guide

**Purpose:** Technical reference showing which tables, joins, and data transformations are used in each dashboard panel  
**Date:** 2026-01-06  
**Audience:** Developers, Data Engineers, Database Administrators

---

## 🗺️ **Database Schema Overview**

### **Core Tables:**
```
shipments (master)
 └── packages (child - 1:N relationship)
      ├── packages_activity_log (1:N - status change history)
      └── executor_status_updates (1:N - partner status updates)

canonical_status_master (lookup table)
status_mappings (lookup table)
peru_ubigeo (geographic reference)
vw_get_shipments (VIEW - flattens shipment JSON data)
```

### **Table Relationships:**
```sql
packages.shipment_id → shipments.shipment_id (FK)
packages.package_id → packages_activity_log.package_id (FK)
packages.package_id → executor_status_updates.package_id (FK)
packages.canonical_status_code → canonical_status_master.code (JOIN)
packages_activity_log.new_canonical_status_code → canonical_status_master.code (JOIN)
packages.shipment_id → vw_get_shipments.shipment_id (LEFT JOIN for geography)
```

---

## 📋 **Panel-by-Panel Data Lineage**

---

### **Panel 1: Total Packages**

**Visual Type:** Stat (Big Number)  
**Metric:** Total count of unique packages

#### **Tables Used:**
1. **`packages`** (PRIMARY)

#### **Columns Accessed:**
- `package_id` (for COUNT DISTINCT)

#### **Joins:** None

#### **Aggregations:**
- `COUNT(DISTINCT package_id)`

#### **Filters:** None (shows all-time total)

#### **Data Flow:**
```
packages
  └─> COUNT(DISTINCT package_id) → 977
```

#### **Query Pattern:**
```sql
SELECT COUNT(DISTINCT package_id) as value
FROM packages
```

---

### **Panel 2: Successfully Delivered**

**Visual Type:** Stat (Big Number)  
**Metric:** Count of packages with delivered status

#### **Tables Used:**
1. **`packages_activity_log`** (PRIMARY)

#### **Columns Accessed:**
- `package_id` (for COUNT DISTINCT)
- `new_canonical_status_code` (for filtering)

#### **Joins:** None

#### **Aggregations:**
- `COUNT(DISTINCT package_id)`

#### **Filters:**
- `WHERE new_canonical_status_code = '7050'` (DELIVERED status)

#### **Data Flow:**
```
packages_activity_log
  └─> FILTER (new_canonical_status_code = '7050')
      └─> COUNT(DISTINCT package_id) → 13
```

#### **Query Pattern:**
```sql
SELECT COUNT(DISTINCT package_id) as value
FROM packages_activity_log
WHERE new_canonical_status_code = '7050'
```

#### **Why packages_activity_log?**
- `packages` table only shows CURRENT status
- `packages_activity_log` tracks STATUS CHANGES over time
- A package might have status 7050 in history but different current status

---

### **Panel 3: Delivery Success Rate %**

**Visual Type:** Gauge  
**Metric:** Percentage of packages delivered out of total

#### **Tables Used:**
1. **`packages`** (for total count)
2. **`packages_activity_log`** (for delivered count)

#### **Columns Accessed:**
- `packages.package_id`
- `packages_activity_log.package_id`
- `packages_activity_log.new_canonical_status_code`

#### **Joins:** 
- Separate subqueries (no direct join)
- Results combined via CTE (WITH clause)

#### **Aggregations:**
- CTE 1: `COUNT(DISTINCT package_id)` from packages
- CTE 2: `COUNT(DISTINCT package_id)` from packages_activity_log
- Final: Division and percentage calculation

#### **Filters:**
- CTE 2: `WHERE new_canonical_status_code = '7050'`

#### **Data Flow:**
```
CTE: total
  packages
    └─> COUNT(DISTINCT package_id) → 977

CTE: delivered
  packages_activity_log
    └─> FILTER (status = '7050')
        └─> COUNT(DISTINCT package_id) → 13

Result:
  (13 / 977) * 100 → 1.33%
```

#### **Query Pattern:**
```sql
WITH total AS (
    SELECT COUNT(DISTINCT package_id) as t 
    FROM packages
),
delivered AS (
    SELECT COUNT(DISTINCT package_id) as d 
    FROM packages_activity_log 
    WHERE new_canonical_status_code = '7050'
)
SELECT ROUND(100.0 * d / NULLIF(t, 0), 2) as value
FROM total, delivered
```

---

### **Panel 4: Avg Delivery Time (Hours)**

**Visual Type:** Stat  
**Metric:** Average time from pickup to delivery

#### **Tables Used:**
1. **`packages`** (base table)
2. **`packages_activity_log`** (for status timestamps)

#### **Columns Accessed:**
- `packages.package_id`
- `packages_activity_log.package_id`
- `packages_activity_log.new_canonical_status_code`
- `packages_activity_log.new_status_occurred_at`

#### **Joins:**
- `packages` JOIN `packages_activity_log` ON package_id

#### **Aggregations:**
1. Per package: `MIN(timestamp)` for each status code
2. Final: `AVG(delivery_time_hours)`

#### **Filters:**
- Only packages with BOTH status 7020 AND 7050
- `HAVING` clause ensures both milestones exist

#### **Data Flow:**
```
packages
  └─> JOIN packages_activity_log
      └─> GROUP BY package_id
          ├─> MIN(timestamp WHERE status = '7020') as picked
          └─> MIN(timestamp WHERE status = '7050') as delivered
      └─> FILTER (picked IS NOT NULL AND delivered IS NOT NULL)
      └─> AVG((delivered - picked) in hours) → 73.7 hours
```

#### **Key Logic:**
- Uses `MIN()` to get EARLIEST occurrence of each status
- Uses `CASE WHEN` to pivot status codes into columns
- Filters out packages without both milestones

#### **Query Pattern:**
```sql
WITH delivery_times AS (
    SELECT 
        p.package_id,
        MIN(CASE WHEN pal.new_canonical_status_code = '7020' THEN pal.new_status_occurred_at END) as picked,
        MIN(CASE WHEN pal.new_canonical_status_code = '7050' THEN pal.new_status_occurred_at END) as delivered
    FROM packages p
    JOIN packages_activity_log pal ON p.package_id = pal.package_id
    GROUP BY p.package_id
)
SELECT ROUND(AVG(EXTRACT(EPOCH FROM (delivered - picked)) / 3600)::numeric, 2) as value
FROM delivery_times
WHERE picked IS NOT NULL AND delivered IS NOT NULL
```

---

### **Panel 5: On-Time Delivery % (48h SLA)**

**Visual Type:** Gauge  
**Metric:** Percentage delivered within 48 hours of pickup

#### **Tables Used:**
1. **`packages`** (base table)
2. **`packages_activity_log`** (for status timestamps)

#### **Columns Accessed:**
- Same as Panel 4

#### **Joins:**
- Same as Panel 4

#### **Aggregations:**
1. Calculate delivery time per package
2. `COUNT(*) FILTER (WHERE time <= 48 hours)` - PostgreSQL conditional aggregation
3. Percentage calculation

#### **Filters:**
- Same as Panel 4 (packages with both milestones)

#### **Data Flow:**
```
packages
  └─> JOIN packages_activity_log
      └─> Calculate delivery_times CTE (same as Panel 4)
      └─> COUNT(*) WHERE delivery_hours <= 48 → 3 packages
      └─> COUNT(*) total → 13 packages
      └─> (3 / 13) * 100 → 23.1%
```

#### **Query Pattern:**
```sql
WITH delivery_times AS (
    -- Same CTE as Panel 4
)
SELECT 
    ROUND(100.0 * 
        COUNT(*) FILTER (WHERE EXTRACT(EPOCH FROM (delivered - picked)) / 3600 <= 48) / 
        NULLIF(COUNT(*), 0), 
    2) as value
FROM delivery_times
```

#### **PostgreSQL Feature Used:**
- `COUNT(*) FILTER (WHERE condition)` - PostgreSQL-specific conditional COUNT

---

### **Panel 6: Packages by Current Status**

**Visual Type:** Bar Chart (Horizontal)  
**Metric:** Distribution of packages across current status codes

#### **Tables Used:**
1. **`packages`** (PRIMARY)
2. **`canonical_status_master`** (LOOKUP - for status descriptions)

#### **Columns Accessed:**
- `packages.package_id`
- `packages.canonical_status_code`
- `canonical_status_master.code`
- `canonical_status_master.es_name`

#### **Joins:**
- `packages` LEFT JOIN `canonical_status_master` ON canonical_status_code = code

#### **Aggregations:**
- `COUNT(DISTINCT package_id)` per status
- `GROUP BY status`

#### **Filters:** None

#### **Data Flow:**
```
packages
  └─> LEFT JOIN canonical_status_master
      └─> GROUP BY es_name
          └─> COUNT(DISTINCT package_id)
              ├─> NULL status: 892
              ├─> ENVIO_CREADO_EN_SOCIO: 45
              ├─> ENVIO_INICIADO: 16
              └─> ...
```

#### **Why LEFT JOIN?**
- Many packages have NULL status → LEFT JOIN preserves these rows
- INNER JOIN would exclude NULL statuses

#### **Query Pattern:**
```sql
SELECT 
    csm.es_name as status,
    COUNT(DISTINCT p.package_id) as packages
FROM packages p
LEFT JOIN canonical_status_master csm ON p.canonical_status_code = csm.code
GROUP BY csm.es_name
ORDER BY packages DESC
```

---

### **Panel 7: Daily Package Creation**

**Visual Type:** Time Series (Line Chart)  
**Metric:** Number of packages created per day

#### **Tables Used:**
1. **`packages`** (ONLY)

#### **Columns Accessed:**
- `package_id`
- `created_at`

#### **Joins:** None

#### **Aggregations:**
- `DATE_TRUNC('day', created_at)` - timestamp → date
- `COUNT(DISTINCT package_id)` per day
- `GROUP BY date`

#### **Filters:** None (shows all history)

#### **Data Flow:**
```
packages
  └─> DATE_TRUNC('day', created_at) → group by date
      └─> COUNT(DISTINCT package_id) per date
          ├─> 2024-11-14: 1 package
          ├─> 2025-12-29: ~600 packages (SPIKE!)
          └─> 2026-01-02: ~50 packages
```

#### **Time Series Format:**
- Returns: `(timestamp, count)` pairs
- Grafana automatically plots as line chart

#### **Query Pattern:**
```sql
SELECT 
    DATE_TRUNC('day', created_at) as time,
    COUNT(DISTINCT package_id) as packages
FROM packages
GROUP BY time
ORDER BY time
```

---

### **Panel 8: Packages by Carrier**

**Visual Type:** Pie Chart  
**Metric:** Distribution of packages across carriers

#### **Tables Used:**
1. **`packages`** (ONLY)

#### **Columns Accessed:**
- `package_id`
- `executor_name` (carrier name)

#### **Joins:** None

#### **Aggregations:**
- `COUNT(DISTINCT package_id)` per carrier
- `GROUP BY executor_name`

#### **Filters:** None

#### **Data Flow:**
```
packages
  └─> COALESCE(executor_name, 'Unknown')
      └─> GROUP BY carrier
          └─> COUNT(DISTINCT package_id)
              ├─> DHL: ~763
              ├─> Unknown: ~118
              ├─> URE: ~53
              └─> ...
```

#### **Null Handling:**
- `COALESCE(executor_name, 'Unknown')` converts NULL → 'Unknown'

#### **Query Pattern:**
```sql
SELECT 
    COALESCE(executor_name, 'Unknown') as carrier,
    COUNT(DISTINCT package_id) as packages
FROM packages
GROUP BY executor_name
ORDER BY packages DESC
```

---

### **Panel 9: Package Status Activity Timeline**

**Visual Type:** Time Series (Multi-line)  
**Metric:** Number of status changes per day, grouped by status type

#### **Tables Used:**
1. **`packages_activity_log`** (PRIMARY)
2. **`canonical_status_master`** (LOOKUP)

#### **Columns Accessed:**
- `packages_activity_log.new_status_occurred_at`
- `packages_activity_log.new_canonical_status_code`
- `canonical_status_master.code`
- `canonical_status_master.es_name`

#### **Joins:**
- `packages_activity_log` LEFT JOIN `canonical_status_master` ON status code

#### **Aggregations:**
- `DATE_TRUNC('day', timestamp)` → group by date
- `COUNT(*)` per status per day (NOT DISTINCT - counts events, not packages)
- `GROUP BY date, status`

#### **Filters:**
- `WHERE new_canonical_status_code IS NOT NULL`

#### **Data Flow:**
```
packages_activity_log
  └─> FILTER (status_code IS NOT NULL)
      └─> LEFT JOIN canonical_status_master
          └─> DATE_TRUNC('day', occurred_at)
              └─> GROUP BY (date, status_name)
                  └─> COUNT(*) events
                      ├─> 2025-12-29, ENTREGADO: 10 events
                      ├─> 2025-12-29, ENVIO_CREADO: 48 events
                      └─> ...
```

#### **Why COUNT(*) not COUNT(DISTINCT)?**
- We want to count STATUS CHANGE EVENTS, not unique packages
- A package can have multiple status changes on the same day

#### **Multi-Line Chart:**
- Grafana automatically creates separate lines per `status_name`

#### **Query Pattern:**
```sql
SELECT 
    DATE_TRUNC('day', pal.new_status_occurred_at) as time,
    csm.es_name as status,
    COUNT(*) as changes
FROM packages_activity_log pal
LEFT JOIN canonical_status_master csm ON pal.new_canonical_status_code = csm.code
WHERE pal.new_canonical_status_code IS NOT NULL
GROUP BY time, csm.es_name
ORDER BY time
```

---

### **Panel 10: Top 10 Delivery Failure Reasons**

**Visual Type:** Bar Chart (Horizontal)  
**Metric:** Count of packages per failure reason

#### **Tables Used:**
1. **`packages_activity_log`** (PRIMARY)
2. **`canonical_status_master`** (REQUIRED - for descriptions)

#### **Columns Accessed:**
- `packages_activity_log.package_id`
- `packages_activity_log.new_canonical_status_code`
- `canonical_status_master.code`
- `canonical_status_master.es_name`

#### **Joins:**
- `packages_activity_log` INNER JOIN `canonical_status_master` ON status code

#### **Aggregations:**
- `COUNT(DISTINCT package_id)` per failure reason
- `GROUP BY reason`

#### **Filters:**
- **CRITICAL:** `WHERE new_canonical_status_code IN ('5523', '5524', '5525', '5530', '6043', '7060', '7080')`
- Only includes FAILURE status codes (5xxx, 7060, 7080)

#### **Data Flow:**
```
packages_activity_log
  └─> FILTER (status_code IN failure_codes)
      └─> INNER JOIN canonical_status_master (get descriptions)
          └─> GROUP BY es_name
              └─> COUNT(DISTINCT package_id)
                  ├─> LA_DIRECCION_DE_ENTREGA_ES_INCORRECTA: 3
                  ├─> EL_DESTINATARIO_NO_SE_ENCONTRABA: 2
                  └─> NO_FUE_POSIBLE_CONTACTAR: 1
```

#### **Why INNER JOIN?**
- All failure codes MUST have descriptions in canonical_status_master
- INNER JOIN ensures we don't show codes without descriptions

#### **Failure Code Mapping:**
| Code | Meaning |
|------|---------|
| 5523 | Recipient uncontactable |
| 5524 | Recipient not at home |
| 5525 | Incorrect delivery address |
| 5530 | Delivery delay |
| 6043 | Sorting error |
| 7060 | Not delivered (general) |
| 7080 | Not delivered at pickup office |

#### **Query Pattern:**
```sql
SELECT 
    csm.es_name as reason,
    COUNT(DISTINCT pal.package_id) as packages
FROM packages_activity_log pal
JOIN canonical_status_master csm ON pal.new_canonical_status_code = csm.code
WHERE pal.new_canonical_status_code IN (
    '5523', '5524', '5525', '5530', '6043', '7060', '7080'
)
GROUP BY csm.es_name, csm.code
ORDER BY packages DESC
LIMIT 10
```

---

### **Panel 11: National Geographic Breakdown**

**Visual Type:** Table  
**Metric:** Package counts, delivery metrics, and success rates by province/district

#### **Tables Used:**
1. **`packages`** (PRIMARY)
2. **`vw_get_shipments`** (VIEW - for province/district)
3. **`packages_activity_log`** (SUBQUERY - for delivery timestamps)

#### **Columns Accessed:**
- `packages.package_id`
- `packages.shipment_id`
- `packages.created_at`
- `packages_activity_log.package_id`
- `packages_activity_log.new_canonical_status_code`
- `packages_activity_log.new_status_occurred_at`
- `vw_get_shipments.shipment_id`
- `vw_get_shipments.province`
- `vw_get_shipments.district`

#### **Joins:**
- `packages` LEFT JOIN `vw_get_shipments` ON shipment_id

#### **Subqueries:**
- **Subquery 1:** Get MAX(timestamp) WHERE status = '7050' (delivery time)
- **Subquery 2:** Get MAX(timestamp) WHERE status = '7020' (pickup time)
- **Subquery 3:** EXISTS check for delivered packages

#### **Aggregations:**
1. `COUNT(DISTINCT package_id)` - total packages per location
2. `AVG(delivery_time_hours)` - average delivery time
3. `COUNT(CASE WHEN delivered)` - count delivered packages
4. `percentage calculation` - success rate

#### **Filters:**
- `GROUP BY province, district`

#### **Data Flow:**
```
packages
  └─> LEFT JOIN vw_get_shipments (get geography)
      └─> GROUP BY (province, district)
          ├─> COUNT(DISTINCT package_id) → package count
          │
          ├─> For each package:
          │   └─> SUBQUERY: get delivered timestamp (status 7050)
          │   └─> SUBQUERY: get picked timestamp (status 7020)
          │   └─> Calculate: delivered - picked (in hours)
          │
          ├─> AVG(delivery_hours) → avg delivery time
          │   (NULL if package not delivered)
          │
          ├─> COUNT(EXISTS delivery status) → delivered count
          │
          └─> (delivered / total) * 100 → success %
```

#### **Complex Calculation: Avg Hours**
```sql
-- For EACH package in the group:
EXTRACT(EPOCH FROM (
    (SELECT MAX(new_status_occurred_at) 
     FROM packages_activity_log 
     WHERE package_id = p.package_id 
       AND new_canonical_status_code = '7050')
    -
    (SELECT MAX(new_status_occurred_at) 
     FROM packages_activity_log 
     WHERE package_id = p.package_id 
       AND new_canonical_status_code = '7020')
)) / 3600

-- Then AVG() across all packages in group
```

#### **Why Subqueries?**
- Can't JOIN packages_activity_log directly (would create duplicates)
- Need to get SPECIFIC status timestamps per package
- Subqueries in aggregate functions = elegant solution

#### **Null Handling:**
```sql
COALESCE(s.province, 'Unknown')  -- NULL provinces → 'Unknown'
COALESCE(s.district, '(Empty)')  -- NULL districts → '(Empty)'
```

#### **Result Columns:**
1. **Province** - Geographic province
2. **District** - Geographic district
3. **Packages** - Total count
4. **Avg Hours** - Average delivery time (blank if not delivered)
5. **Delivered** - Count of delivered packages
6. **Success %** - Delivery success rate

#### **Query Pattern:**
```sql
SELECT 
    COALESCE(s.province, 'Unknown') as "Province",
    COALESCE(s.district, '(Empty)') as "District",
    COUNT(DISTINCT p.package_id) as "Packages",
    
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            (SELECT MAX(pal_delivered.new_status_occurred_at) 
             FROM packages_activity_log pal_delivered 
             WHERE pal_delivered.package_id = p.package_id 
               AND pal_delivered.new_canonical_status_code = '7050')
            -
            (SELECT MAX(pal_picked.new_status_occurred_at) 
             FROM packages_activity_log pal_picked 
             WHERE pal_picked.package_id = p.package_id 
               AND pal_picked.new_canonical_status_code = '7020')
        )) / 3600
    )::numeric, 2) as "Avg Hours",
    
    COUNT(CASE WHEN EXISTS (
        SELECT 1 FROM packages_activity_log pal 
        WHERE pal.package_id = p.package_id 
          AND pal.new_canonical_status_code = '7050'
    ) THEN 1 END) as "Delivered",
    
    ROUND(100.0 * 
        COUNT(CASE WHEN EXISTS (
            SELECT 1 FROM packages_activity_log pal 
            WHERE pal.package_id = p.package_id 
              AND pal.new_canonical_status_code = '7050'
        ) THEN 1 END) / 
        NULLIF(COUNT(*), 0), 
    2) as "Success %"
    
FROM packages p
LEFT JOIN vw_get_shipments s ON p.shipment_id = s.shipment_id
GROUP BY s.province, s.district
ORDER BY "Packages" DESC
LIMIT 50
```

---

## 🔍 **Special Table: vw_get_shipments**

### **What is it?**
- **VIEW** (not a physical table)
- Flattens shipment JSON data into columnar format

### **Original Data Structure:**
```sql
-- shipments table stores address as JSON:
shipments.ship_to_address = {
    "province": "Lima",
    "district": "Lima",
    "address_line_1": "...",
    ...
}
```

### **View Transformation:**
```sql
CREATE VIEW vw_get_shipments AS
SELECT 
    shipment_id,
    ship_to_address->>'province' as province,
    ship_to_address->>'district' as district,
    ship_to_address->>'comuna' as comuna,
    ship_to_address->>'region' as region,
    ...
FROM shipments;
```

### **Why Use the View?**
- ✅ Cleaner queries (no need for `->>'` JSON operators)
- ✅ Standardized column names
- ✅ Better performance (view can be indexed)
- ✅ Easier to maintain

### **Columns Provided:**
- `shipment_id` (PK)
- `province` (extracted from JSON)
- `district` (extracted from JSON)
- `comuna` (extracted from JSON)
- `region` (extracted from JSON)
- `locality` (extracted from JSON)

---

## 📊 **Query Complexity Comparison**

| Panel | Tables | Joins | Subqueries | CTEs | Complexity |
|-------|--------|-------|------------|------|------------|
| 1. Total Packages | 1 | 0 | 0 | 0 | ⭐ Simple |
| 2. Successfully Delivered | 1 | 0 | 0 | 0 | ⭐ Simple |
| 3. Delivery Success Rate | 2 | 0 | 0 | 2 | ⭐⭐ Medium |
| 4. Avg Delivery Time | 2 | 1 | 0 | 1 | ⭐⭐⭐ Complex |
| 5. On-Time Delivery % | 2 | 1 | 0 | 1 | ⭐⭐⭐ Complex |
| 6. Packages by Status | 2 | 1 | 0 | 0 | ⭐⭐ Medium |
| 7. Daily Package Creation | 1 | 0 | 0 | 0 | ⭐ Simple |
| 8. Packages by Carrier | 1 | 0 | 0 | 0 | ⭐ Simple |
| 9. Status Activity Timeline | 2 | 1 | 0 | 0 | ⭐⭐ Medium |
| 10. Delivery Failure Reasons | 2 | 1 | 0 | 0 | ⭐⭐ Medium |
| 11. Geographic Breakdown | 3 | 1 | 3 | 0 | ⭐⭐⭐⭐ Very Complex |

---

## 🎯 **Key Insights**

### **Most Used Tables:**
1. **`packages`** - Used in 9/11 panels (82%)
2. **`packages_activity_log`** - Used in 7/11 panels (64%)
3. **`canonical_status_master`** - Used in 4/11 panels (36%)
4. **`vw_get_shipments`** - Used in 1/11 panels (9%)

### **Most Complex Query:**
**Panel 11 (Geographic Breakdown):**
- 3 tables
- 1 LEFT JOIN
- 3 correlated subqueries
- 4 aggregate functions
- Null handling
- Percentage calculations

### **Simplest Queries:**
- Panel 1, 2, 7, 8 - Single table, no joins

### **Performance Bottlenecks:**
1. **Panel 11** - Multiple subqueries per row (slowest)
2. **Panel 4 & 5** - CTE with CASE aggregations
3. **Panel 9** - Large activity log table

### **Optimization Opportunities:**
1. **Index on:**
   - `packages_activity_log(package_id, new_canonical_status_code)`
   - `packages_activity_log(new_status_occurred_at)`
   - `packages(canonical_status_code)`

2. **Materialized view for Panel 11:**
   ```sql
   CREATE MATERIALIZED VIEW mv_geographic_metrics AS
   -- Panel 11 query here
   -- Refresh daily
   ```

3. **Partitioning:**
   - Partition `packages_activity_log` by month
   - Partition `packages` by created_at

---

## 📚 **Data Dictionary**

### **packages table:**
| Column | Type | Description | Nullable | Used In Panels |
|--------|------|-------------|----------|----------------|
| package_id | VARCHAR | Unique package identifier | NO | All panels |
| shipment_id | VARCHAR | FK to shipments | YES | Panel 11 |
| executor_name | VARCHAR | Carrier/executor name | YES | Panel 8 |
| canonical_status_code | VARCHAR | Current status code | YES | Panel 6 |
| created_at | TIMESTAMPTZ | Package creation time | NO | Panel 7 |

### **packages_activity_log table:**
| Column | Type | Description | Nullable | Used In Panels |
|--------|------|-------------|----------|----------------|
| package_id | VARCHAR | FK to packages | NO | 2,3,4,5,9,10,11 |
| new_canonical_status_code | VARCHAR | Status code after change | YES | 2,4,5,9,10,11 |
| new_status_occurred_at | TIMESTAMPTZ | When status changed | YES | 4,5,9,11 |

### **canonical_status_master table:**
| Column | Type | Description | Nullable | Used In Panels |
|--------|------|-------------|----------|----------------|
| code | VARCHAR | Unique status code (PK) | NO | 6,9,10 |
| es_name | VARCHAR | Spanish description | YES | 6,9,10 |
| en_name | VARCHAR | English description | YES | - |

### **vw_get_shipments view:**
| Column | Type | Description | Nullable | Used In Panels |
|--------|------|-------------|----------|----------------|
| shipment_id | VARCHAR | PK from shipments | NO | Panel 11 |
| province | VARCHAR | Extracted from JSON | YES | Panel 11 |
| district | VARCHAR | Extracted from JSON | YES | Panel 11 |

---

## ⚠️ **Important Notes**

### **Why packages_activity_log Instead of packages?**
- `packages.canonical_status_code` = **CURRENT** status only
- `packages_activity_log` = **COMPLETE HISTORY** of all status changes
- For delivery metrics, we need HISTORICAL data (pickup time, delivery time)

### **NULL Handling Strategy:**
1. **Geography:** `COALESCE(province, 'Unknown')` - Make NULLs visible
2. **Carrier:** `COALESCE(executor_name, 'Unknown')` - Group NULLs
3. **Status:** `LEFT JOIN` - Preserve rows even if no status description
4. **Delivery Time:** Return `NULL` - If not delivered, no avg time (correct!)

### **Aggregate vs. Window Functions:**
- **Used:** `COUNT()`, `AVG()`, `MIN()`, `MAX()` - Aggregate functions
- **Not used:** Window functions (not needed for current metrics)
- **Future:** Consider `ROW_NUMBER()` for latest status ranking

---

**Created by:** Serhafen Data Engineering Team  
**Last Updated:** 2026-01-06  
**Version:** 1.0
