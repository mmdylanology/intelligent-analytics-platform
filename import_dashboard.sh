#!/bin/bash
# Import Last Mile Ecommerce Dashboard to Grafana via API

GRAFANA_URL="http://localhost:3001"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"
DASHBOARD_FILE="last-mile-ecommerce-dashboard.json"

echo "🚀 Importing Last Mile Ecommerce Dashboard to Grafana..."
echo ""

# Check if dashboard file exists
if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "❌ Error: $DASHBOARD_FILE not found!"
    echo "Run: python3 generate_dashboard.py first"
    exit 1
fi

# Prepare JSON for import (wrap dashboard in required format)
IMPORT_JSON=$(cat "$DASHBOARD_FILE" | jq '{dashboard: ., overwrite: true, inputs: []}')

# Import via API
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_USER:$GRAFANA_PASS" \
  -d "$IMPORT_JSON" \
  "$GRAFANA_URL/api/dashboards/import")

# Check response
if echo "$RESPONSE" | jq -e '.uid' > /dev/null 2>&1; then
    DASHBOARD_UID=$(echo "$RESPONSE" | jq -r '.uid')
    DASHBOARD_URL=$(echo "$RESPONSE" | jq -r '.url')
    
    echo "✅ Dashboard imported successfully!"
    echo ""
    echo "📊 Dashboard UID: $DASHBOARD_UID"
    echo "🔗 Dashboard URL: $GRAFANA_URL$DASHBOARD_URL"
    echo ""
    echo "🎉 Open in browser: $GRAFANA_URL$DASHBOARD_URL"
else
    echo "❌ Import failed!"
    echo "Response: $RESPONSE"
    echo ""
    echo "💡 Try manual import:"
    echo "   1. Open $GRAFANA_URL"
    echo "   2. Go to Dashboards → Import"
    echo "   3. Upload $DASHBOARD_FILE"
    exit 1
fi
