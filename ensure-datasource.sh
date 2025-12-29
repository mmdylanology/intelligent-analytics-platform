#!/bin/bash

# Ensure datasource exists after Grafana starts
# Run this after docker-compose up

echo "⏳ Waiting for Grafana to be ready..."
sleep 5

echo "🔍 Checking if datasource exists..."
DATASOURCE_EXISTS=$(curl -s -X GET http://admin:admin@localhost:3001/api/datasources/uid/PB28DCAEFB3F86196 | jq -r '.id // empty')

if [ -z "$DATASOURCE_EXISTS" ]; then
  echo "📡 Creating Nucleo Postgres datasource..."
  curl -s -X POST http://admin:admin@localhost:3001/api/datasources \
    -H "Content-Type: application/json" \
    -d '{
      "uid": "PB28DCAEFB3F86196",
      "name": "Nucleo Postgres",
      "type": "postgres",
      "access": "proxy",
      "url": "serhafen-db-postgres-staging.cluster-chgg2qqoy9y6.us-east-1.rds.amazonaws.com:5432",
      "database": "nucleo",
      "user": "postgres",
      "secureJsonData": {
        "password": "d0=JIim46R6:dLg$KW"
      },
      "jsonData": {
        "sslmode": "disable",
        "postgresVersion": 1400,
        "timescaledb": false,
        "database": "nucleo"
      },
      "isDefault": true
    }' > /dev/null
  echo "✅ Datasource created"
else
  echo "✅ Datasource already exists (ID: $DATASOURCE_EXISTS)"
fi

echo "🧪 Testing connection..."
HEALTH=$(curl -s -X GET http://admin:admin@localhost:3001/api/datasources/uid/PB28DCAEFB3F86196/health | jq -r '.status')

if [ "$HEALTH" = "OK" ]; then
  echo "✅ Database connection OK!"
  echo "🌐 Open http://localhost:3001/d/shipment-ops-001/shipment-operations"
else
  echo "❌ Connection failed: $HEALTH"
  echo "Check logs: docker-compose logs grafana"
fi
