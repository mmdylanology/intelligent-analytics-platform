# 🔍 Last Mile Dashboard - Data Analysis & Grafana Implementation Gap

## 📊 **Current State Analysis**

### **1. Streamlit Dashboard** (Current Production)
**Repo:** `serhafen-ops-dashboard`  
**Branch:** `feat/refactor-lastmile`  
**Last Commit:** `bc48519` - "feat: refactor project and last mile page" (Dec 29, 2025)

### **2. Grafana Dashboard** (Work in Progress)
**Location:** `/grafana-setup/last-mile-ecommerce-dashboard.json`  
**Status:** ⚠️ **INCOMPLETE & USING WRONG QUERIES**

---

## 🚨 **Critical Issues Found**

### **Issue 1: Wrong Database View**
**Streamlit uses:**
```sql
SELECT p.*, s.province, s.district, s.region
FROM public.packages p
LEFT JOIN public.vw_get_shipments s ON p.shipment_id = s.shipment_id
```

**Grafana currently uses:**
```sql
SELECT * FROM packages p
LEFT JOIN shipments s ON p.shipment_id = s.shipment_id
WHERE s.ship_to_address->>'province' ... -- ❌ WRONG!
```

**Problem:** 
- ✅ `vw_get_shipments` is a VIEW that extracts province/district from JSON
- ❌ Grafana is trying to access JSON fields directly (which may not work correctly)

### **Issue 2: Missing Materialized View**
**Streamlit documentation mentions:** `mvw_package_activity` (materialized view)  
**Status:** Not confirmed if this view exists in database  
**Impact:** May affect performance for historical data queries

### **Issue 3: Wrong Column Names**
| Streamlit Uses | Grafana Uses | Status |
|----------------|-------------|--------|
| `package_id` | `package_id` | ✅ |
| `tracking_number` | ❌ Not used | ⚠️ Missing |
| `canonical_status_code` | `canonical_status_code` | ✅ |
| `destination_country` | `destination_country` | ✅ |
| `latest_status` | `latest_status` | ✅ |
| `partner_name` | ❌ Not used | ⚠️ Missing |
| `master_awb_no` | ❌ Not used | ⚠️ Missing |

### **Issue 4: Hardcoded Values in Grafana**
**Current Grafana queries have placeholders:**
```sql
-- ❌ WRONG: Hardcoded fake data
SELECT 95.74 as "% ON TIME"
SELECT 'Fuera de Tiempo' as metric, 50 as value
```

**Should be:** Real calculations based on milestones

---

## 📋 **Data Dependencies Analysis**

### **✅ Available Directly from Database:**
1. ✅ Raw package data (`packages` table)
2. ✅ Shipment address data (`shipments.ship_to_address` JSON or `vw_get_shipments` view)
3. ✅ Status codes and mappings (`canonical_status_master`, `status_mappings`)
4. ✅ Executor status updates (`executor_status_updates` table)
5. ✅ Geographic data (province, district from `vw_get_shipments`)

### **❌ NOT Available Directly (Requires Python/SQL Processing):**

#### **1. Milestone Timestamps** 
**Streamlit calculates:**
- `lm_created` - Latest timestamp where status code = 7000
- `lm_accepted` - Latest timestamp where status code = 7005
- `lm_picked` - Latest timestamp where status code = 7020
- `lm_delivered` - Latest timestamp where status code = 7050
- `lm_failed` - Latest timestamp where status codes IN (7055, 7060, 7065)

**Grafana needs:** Complex SQL to extract these

#### **2. Location Classification**
**Streamlit logic:**
```python
LOCAL_REGIONS = {
    'CL': ['SANTIAGO', 'REGIÓN METROPOLITANA', 'METROPOLITANA'],
    'PE': ['LIMA', 'LIMA METROPOLITANA']
}

if country == 'CL' and region in LOCAL_REGIONS['CL']:
    return 'Local'
else:
    return 'Interior'
```

**Grafana needs:** CASE statement replication

#### **3. All Rate Metrics**
- **Success Rate:** `(lm_delivered_count / lm_created_count) * 100`
- **Failed Rate:** `(lm_failed_count / lm_created_count) * 100`
- **On-Time Rate:** `COUNT(packages where (lm_delivered - lm_picked) <= 48 hours) / total_delivered * 100`
- **Acceptance Rate:** `(lm_accepted / lm_created) * 100`

#### **4. P95 Metrics**
- Delivery time hours: `(lm_delivered - lm_picked).total_seconds() / 3600`
- P95 calculation: `PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY delivery_time_hours)`
- Grouped by courier and location type

---

## 🛠️ **Required Fixes for Grafana Dashboard**

### **Fix 1: Use Correct View**
```sql
-- REPLACE ALL queries that access province/district:
SELECT 
    p.package_id,
    p.destination_country,
    p.executor_name,
    p.canonical_status_code,
    p.latest_status,
    p.created_at,
    s.province,
    s.district,
    s.region
FROM packages p
LEFT JOIN vw_get_shipments s ON p.shipment_id = s.shipment_id
WHERE p.created_at BETWEEN $__timeFrom() AND $__timeTo()
```

### **Fix 2: Create Milestone Extraction Queries**

**Example: LM Created Count**
```sql
SELECT COUNT(DISTINCT p.package_id) as lm_created
FROM packages p
JOIN executor_status_updates esu ON p.package_id = esu.package_id
WHERE esu.canonical_status_code = '7000'
  AND p.created_at >= $__timeFrom()
```

**Example: LM Delivered Count**
```sql
SELECT COUNT(DISTINCT p.package_id) as lm_delivered
FROM packages p
JOIN executor_status_updates esu ON p.package_id = esu.package_id
WHERE esu.canonical_status_code = '7050'
  AND p.created_at >= $__timeFrom()
```

### **Fix 3: Location Classification in SQL**
```sql
SELECT 
    p.package_id,
    CASE 
        WHEN p.destination_country = 'CL' AND s.region IN ('SANTIAGO', 'REGIÓN METROPOLITANA', 'METROPOLITANA') THEN 'Local'
        WHEN p.destination_country = 'PE' AND s.region IN ('LIMA', 'LIMA METROPOLITANA') THEN 'Local'
        WHEN p.destination_country IN ('CL', 'PE') THEN 'Interior'
        ELSE 'Desconocido'
    END as location_type
FROM packages p
LEFT JOIN vw_get_shipments s ON p.shipment_id = s.shipment_id
```

### **Fix 4: On-Time Rate Calculation**
```sql
WITH delivery_times AS (
    SELECT 
        p.package_id,
        MAX(CASE WHEN esu.canonical_status_code = '7020' THEN esu.created_at END) as picked_at,
        MAX(CASE WHEN esu.canonical_status_code = '7050' THEN esu.created_at END) as delivered_at
    FROM packages p
    JOIN executor_status_updates esu ON p.package_id = esu.package_id
    WHERE p.created_at >= $__timeFrom()
    GROUP BY p.package_id
)
SELECT 
    COUNT(*) FILTER (WHERE EXTRACT(EPOCH FROM (delivered_at - picked_at))/3600 <= 48) * 100.0 / NULLIF(COUNT(*), 0) as on_time_rate
FROM delivery_times
WHERE picked_at IS NOT NULL AND delivered_at IS NOT NULL
```

### **Fix 5: Replace All Hardcoded Values**
**Current panels with fake data:**
1. ❌ "% ON TIME" → Use calculation above
2. ❌ "% IN FULL" → Use real data
3. ❌ "Fuera de Tiempo / A Tiempo" bars → Use real milestone comparisons
4. ❌ "Pendiente / Cerrado" → Use actual status counts
5. ❌ "Local vs Nacional" calculations → Use location_type logic

---

## 🎯 **Action Items**

### **For Database Team:**
1. ✅ Confirm `vw_get_shipments` view exists and columns
2. ⚠️ Confirm if `mvw_package_activity` materialized view exists
3. ⚠️ Check if migrations/views are documented

### **For Grafana Implementation:**
1. ❌ **URGENT:** Replace all `ship_to_address->>` JSON queries with `vw_get_shipments` view
2. ❌ Implement milestone extraction using `executor_status_updates` table
3. ❌ Add location classification CASE statements
4. ❌ Replace all hardcoded placeholder values
5. ❌ Implement P95 calculations (percentile queries)
6. ❌ Add proper filtering by province/district using view columns
7. ❌ Test all queries against actual database

### **For Testing:**
1. Compare Grafana metrics with Streamlit metrics side-by-side
2. Validate counts match for:
   - Total packages
   - Delivered packages
   - Failed packages
   - On-time packages
3. Verify geographic filtering (province/district drill-down)
4. Test date range filtering

---

## 📝 **Key Differences: Streamlit vs Grafana**

| Feature | Streamlit | Grafana | Gap |
|---------|-----------|---------|-----|
| **Data Source** | Uses `vw_get_shipments` view | Uses raw JSON access | ❌ Must fix |
| **Milestone Calc** | Python groupby + max() | ❌ Missing | Must implement in SQL |
| **Location Type** | Python function | ❌ Missing | Must use CASE statement |
| **P95 Metrics** | Pandas quantile(0.95) | ❌ Missing | Use PERCENTILE_CONT |
| **On-Time Logic** | Python timedelta check | ❌ Hardcoded 95.74 | Must calculate |
| **Caching** | @st.cache_data (1 hour) | Grafana auto-refresh | ✅ Similar |
| **Filtering** | Streamlit widgets | Grafana variables | ✅ Implemented |

---

## 🚀 **Next Steps**

1. **Verify Database Schema** - Run queries to confirm:
   ```sql
   -- Check if view exists:
   SELECT * FROM information_schema.views WHERE table_name = 'vw_get_shipments';
   
   -- Check view columns:
   SELECT * FROM vw_get_shipments LIMIT 1;
   
   -- Check if mvw_package_activity exists:
   SELECT * FROM information_schema.tables WHERE table_name LIKE '%package_activity%';
   ```

2. **Share senior's feedback** - You mentioned messages from senior, please share those

3. **Rewrite all Grafana queries** - Based on correct schema

4. **Test against database** - Validate all metrics match Streamlit

---

**Created:** 2026-01-06  
**Author:** Based on analysis of serhafen-ops-dashboard and serhafen-nucleo repos
