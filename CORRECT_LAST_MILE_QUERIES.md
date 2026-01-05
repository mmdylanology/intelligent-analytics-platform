# ✅ CORRECT Last Mile Dashboard Queries for Grafana

## 🎯 **Data Source Understanding** (From Senior)

### **Table Hierarchy:**
```
shipments (master)
 └── packages (child - MAIN DATA)
      ├── packages_activity_log (captures all changes)
      └── executor_status_updates (partner/executor status changes)
```

### **Key Reference Tables:**
1. **canonical_status_master** - All standardized last mile codes defined by business
2. **status_mappings** - Canonical to last mile partner status mappings per country  
3. **peru_ubigeo** - Geography reference table (currently Peru only)
4. **vw_get_shipments** - View that extracts province/district from JSON

---

## 📊 **Status Code Mapping** (from DB)

### **Last Mile Status Codes:**
| Code | Spanish Name | English Name | Meaning |
|------|-------------|--------------|---------|
| 7010 | LLEGO_A_ALMACEN_SH | ARRIVED_IN_SH_WH | Arrived in Serhafen warehouse |
| 7015 | SALIDA_HUB_SERHAFEN | DEPARTED_SERHAFEN_HUB | Departed from hub |
| 7020 | ARRIBO_HUB_ULTIMA_MILLA | ARRIVED_AT_LAST_MILE_HUB | Arrived at last mile hub |
| 7025 | SALIDA_HUB_ULTIMA_MILLA | DEPARTED_LAST_MILE_HUB | Departed last mile hub |
| 7028 | EN_TRANSITO | IN_TRANSIT | In transit |
| 7030 | ARRIBO_ULTIMA_ESTACION_DE_ENTREGA | ARRIVED_AT_FINAL_DELIVERY_STATION | At final station |
| 7035 | SALIDA_ULTIMA_ESTACION_DE_ENTREGA | DEPARTED_FINAL_DELIVERY_STATION | Left final station |
| 7040 | EN_REPARTO | ON_ROUTE_FOR_DELIVERY | Out for delivery |
| **7050** | **ENTREGADO** | **DELIVERED** | **✅ Successfully delivered** |
| 7060 | NO_ENTREGADO | NOT_DELIVERED | Not delivered |
| 7070 | ENTREGADO_EN_OFICINA | DELIVERED_AT_PICKUP_OFFICE | Delivered at office |
| 7080 | NO_ENTREGADO_EN_OFICINA | NOT_DELIVERED_AT_PICKUP_OFFICE | Not delivered at office |
| 7090 | DEVUELTO_HUB_SERHAFEN | RETURNED_TO_SERHAFEN_HUB | Returned to hub |
| 8000 | ENVIO_INICIADO | LM_SHIPMENT_INITIATED | Shipment initiated |
| 8005 | ENVIO_CREADO_EN_SOCIO | PARTNER_SHIPMENT_CREATED | Created with partner |
| 8015 | LIBERADO_DE_ADUANA | CUSTOMS_CLEARED | Customs cleared |

### **Failure/Not Delivered Codes:**
| Code | Spanish Name | English Name |
|------|-------------|--------------|
| 5523 | NO_FUE_POSIBLE_CONTACTAR_AL_DESTINATARIO | RECIPIENT_UNCONTACTABLE |
| 5524 | EL_DESTINATARIO_NO_SE_ENCONTRABA_EN_EL_DOMICILIO | RECIPIENT_NOT_AT_HOME |
| 5525 | LA_DIRECCION_DE_ENTREGA_ES_INCORRECTA | DELIVERY_ADDRESS_IS_INCORRECT |
| 5530 | RETRASO_EN_LA_ENTREGA | DELIVERY_DELAY |
| 6043 | ERROR_EN_LA_CLASIFICACION | SORTING_ERROR |

---

## ✅ **CORRECT Queries for Grafana Panels**

### **1. Total Packages**
```sql
SELECT COUNT(DISTINCT package_id) as value
FROM packages
WHERE created_at BETWEEN $__timeFrom() AND $__timeTo()
  AND ('${carrier:csv}' = '' OR COALESCE(executor_name, 'Unknown') IN (${carrier:singlequote}))
```

### **2. Total Delivered Packages**
```sql
SELECT COUNT(DISTINCT package_id) as value
FROM packages_activity_log
WHERE new_canonical_status_code = '7050'  -- DELIVERED
  AND new_status_occurred_at BETWEEN $__timeFrom() AND $__timeTo()
```

### **3. Delivery Success Rate (%)**
```sql
WITH total_packages AS (
    SELECT COUNT(DISTINCT package_id) as total
    FROM packages
    WHERE created_at BETWEEN $__timeFrom() AND $__timeTo()
),
delivered_packages AS (
    SELECT COUNT(DISTINCT package_id) as delivered
    FROM packages_activity_log
    WHERE new_canonical_status_code = '7050'
      AND new_status_occurred_at BETWEEN $__timeFrom() AND $__timeTo()
)
SELECT 
    ROUND(100.0 * delivered / NULLIF(total, 0), 2) as value
FROM total_packages, delivered_packages
```

### **4. Packages by Status (Current State)**
```sql
SELECT 
    csm.es_name as status,
    COUNT(DISTINCT p.package_id) as value
FROM packages p
LEFT JOIN canonical_status_master csm ON p.canonical_status_code = csm.code
WHERE p.created_at BETWEEN $__timeFrom() AND $__timeTo()
  AND ('${carrier:csv}' = '' OR COALESCE(p.executor_name, 'Unknown') IN (${carrier:singlequote}))
GROUP BY csm.es_name, csm.code
ORDER BY value DESC
```

### **5. Top 10 Delivery Failure Reasons** (CORRECTED!)
```sql
SELECT 
    csm.es_name as reason,
    COUNT(DISTINCT pal.package_id) as packages
FROM packages_activity_log pal
JOIN canonical_status_master csm ON pal.new_canonical_status_code = csm.code
WHERE pal.new_canonical_status_code IN (
    '5523',  -- Recipient uncontactable
    '5524',  -- Recipient not at home
    '5525',  -- Incorrect delivery address
    '5530',  -- Delivery delay
    '6043',  -- Sorting error
    '7060',  -- Not delivered
    '7080'   -- Not delivered at office
)
  AND pal.new_status_occurred_at BETWEEN $__timeFrom() AND $__timeTo()
GROUP BY csm.es_name, csm.code
ORDER BY packages DESC
LIMIT 10
```

### **6. Average Delivery Time (Hours)**
```sql
WITH delivery_times AS (
    SELECT 
        p.package_id,
        MIN(CASE WHEN pal.new_canonical_status_code = '7020' THEN pal.new_status_occurred_at END) as picked_time,
        MIN(CASE WHEN pal.new_canonical_status_code = '7050' THEN pal.new_status_occurred_at END) as delivered_time
    FROM packages p
    JOIN packages_activity_log pal ON p.package_id = pal.package_id
    WHERE p.created_at BETWEEN $__timeFrom() AND $__timeTo()
    GROUP BY p.package_id
)
SELECT 
    ROUND(AVG(EXTRACT(EPOCH FROM (delivered_time - picked_time)) / 3600)::numeric, 2) as avg_hours
FROM delivery_times
WHERE picked_time IS NOT NULL AND delivered_time IS NOT NULL
```

### **7. On-Time Delivery Rate (within 48 hours)**
```sql
WITH delivery_times AS (
    SELECT 
        p.package_id,
        MIN(CASE WHEN pal.new_canonical_status_code = '7020' THEN pal.new_status_occurred_at END) as picked_time,
        MIN(CASE WHEN pal.new_canonical_status_code = '7050' THEN pal.new_status_occurred_at END) as delivered_time
    FROM packages p
    JOIN packages_activity_log pal ON p.package_id = pal.package_id
    WHERE p.created_at BETWEEN $__timeFrom() AND $__timeTo()
    GROUP BY p.package_id
    HAVING MIN(CASE WHEN pal.new_canonical_status_code = '7020' THEN pal.new_status_occurred_at END) IS NOT NULL
      AND MIN(CASE WHEN pal.new_canonical_status_code = '7050' THEN pal.new_status_occurred_at END) IS NOT NULL
)
SELECT 
    ROUND(100.0 * 
        COUNT(*) FILTER (WHERE EXTRACT(EPOCH FROM (delivered_time - picked_time)) / 3600 <= 48) / 
        NULLIF(COUNT(*), 0), 
    2) as on_time_rate
FROM delivery_times
```

### **8. Packages by Location (Local vs Interior)**
```sql
SELECT 
    CASE 
        WHEN p.destination_country = 'CL' AND UPPER(s.region) IN ('SANTIAGO', 'REGIÓN METROPOLITANA', 'METROPOLITANA') THEN 'Local'
        WHEN p.destination_country = 'PE' AND UPPER(s.region) IN ('LIMA', 'LIMA METROPOLITANA') THEN 'Local'
        WHEN p.destination_country IN ('CL', 'PE') THEN 'Interior'
        ELSE 'Desconocido'
    END as location_type,
    COUNT(DISTINCT p.package_id) as packages
FROM packages p
LEFT JOIN vw_get_shipments s ON p.shipment_id = s.shipment_id
WHERE p.created_at BETWEEN $__timeFrom() AND $__timeTo()
  AND ('${carrier:csv}' = '' OR COALESCE(p.executor_name, 'Unknown') IN (${carrier:singlequote}))
GROUP BY location_type
```

### **9. Geographic Breakdown Table** (with drill-down)
```sql
SELECT 
    COALESCE(s.province, 'Unknown') as "Province",
    COALESCE(s.district, '(Empty)') as "District",
    COUNT(DISTINCT p.package_id) as "Packages",
    ROUND(AVG(EXTRACT(EPOCH FROM (p.latest_status_occurred_at - p.created_at))/3600)::numeric, 2) as "Avg Hours",
    COUNT(CASE WHEN p.canonical_status_code = '7050' THEN 1 END) as "Delivered",
    ROUND(100.0 * COUNT(CASE WHEN p.canonical_status_code = '7050' THEN 1 END) / NULLIF(COUNT(*), 0), 2) as "Success %"
FROM packages p
LEFT JOIN vw_get_shipments s ON p.shipment_id = s.shipment_id
WHERE p.created_at BETWEEN $__timeFrom() AND $__timeTo()
  AND ('${carrier:csv}' = '' OR COALESCE(p.executor_name, 'Unknown') IN (${carrier:singlequote}))
  AND ('${province:csv}' = '' OR s.province IN (${province:singlequote}) OR s.province IS NULL)
  AND ('${district:csv}' = '' OR s.district IN (${district:singlequote}) OR s.district IS NULL)
GROUP BY s.province, s.district
ORDER BY "Packages" DESC
LIMIT 50
```

### **10. Daily Package Creation Trend**
```sql
SELECT 
    DATE_TRUNC('day', created_at) as time,
    COUNT(DISTINCT package_id) as packages
FROM packages
WHERE created_at BETWEEN $__timeFrom() AND $__timeTo()
  AND ('${carrier:csv}' = '' OR COALESCE(executor_name, 'Unknown') IN (${carrier:singlequote}))
GROUP BY time
ORDER BY time
```

### **11. Packages by Carrier**
```sql
SELECT 
    COALESCE(executor_name, 'Unknown') as carrier,
    COUNT(DISTINCT package_id) as packages
FROM packages
WHERE created_at BETWEEN $__timeFrom() AND $__timeTo()
GROUP BY executor_name
ORDER BY packages DESC
```

### **12. Package Status Timeline (Activity over time)**
```sql
SELECT 
    DATE_TRUNC('day', pal.new_status_occurred_at) as time,
    csm.es_name as status,
    COUNT(*) as changes
FROM packages_activity_log pal
LEFT JOIN canonical_status_master csm ON pal.new_canonical_status_code = csm.code
WHERE pal.new_status_occurred_at BETWEEN $__timeFrom() AND $__timeTo()
  AND pal.new_canonical_status_code IS NOT NULL
GROUP BY time, csm.es_name
ORDER BY time, changes DESC
```

---

## 🔧 **Dashboard Variables Configuration**

### **carrier** (Multi-select)
```sql
SELECT DISTINCT COALESCE(executor_name, 'Unknown') as __text, executor_name as __value
FROM packages
ORDER BY 1
```

### **province** (Multi-select, depends on carrier)
```sql
SELECT DISTINCT province as __text, province as __value
FROM packages p
LEFT JOIN vw_get_shipments s ON p.shipment_id = s.shipment_id
WHERE ('${carrier:csv}' = '' OR COALESCE(p.executor_name, 'Unknown') IN (${carrier:singlequote}))
  AND s.province IS NOT NULL
ORDER BY 1
```

### **district** (Multi-select, depends on province)
```sql
SELECT DISTINCT district as __text, district as __value
FROM packages p
LEFT JOIN vw_get_shipments s ON p.shipment_id = s.shipment_id
WHERE ('${carrier:csv}' = '' OR COALESCE(p.executor_name, 'Unknown') IN (${carrier:singlequote}))
  AND ('${province:csv}' = '' OR s.province IN (${province:singlequote}))
  AND s.district IS NOT NULL
ORDER BY 1
```

---

## ⚠️ **Known Issues & Fixes**

### **Issue 1: Wrong Failure Reasons**
**WRONG (Current):**
- Shows "PARTNER_SHIPMENT_CREATION_FAILED" ❌
- Shows "PARTNER_SHIPMENT_CREATED" ❌

These are SYSTEM statuses, NOT delivery failures!

**CORRECT:**
- Use codes: 5523, 5524, 5525, 5530, 6043, 7060, 7080
- These are actual delivery failure reasons

### **Issue 2: Hardcoded Values**
**Replace ALL panels with hardcoded data:**
- "% ON TIME" → Use On-Time Delivery Rate query
- "% IN FULL" → Calculate from actual deliveries
- Static bar charts → Use real milestone counts

### **Issue 3: Geographic Filtering**
**Use:** `vw_get_shipments` view columns (province, district)  
**NOT:** `ship_to_address->>'province'` JSON access

---

**Generated:** 2026-01-06  
**Based on:** Direct database schema analysis + Senior's guidance
