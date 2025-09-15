#!/bin/bash

# Test accessing Grantmakers.io data via curl
# This mimics the browser request that the website makes

echo "🔍 Testing Grantmakers.io API access via curl..."

# Test the Algolia API directly with proper headers
curl -s -X POST "https://qa1231c5w9-dsn.algolia.net/1/indexes/grantmakers_io/query" \
  -H "Content-Type: application/json" \
  -H "Referer: https://www.grantmakers.io/" \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
  -H "X-Algolia-API-Key: 96a419d65f67ff3b4c54939f8e90c220" \
  -H "X-Algolia-Application-Id: QA1231C5W9" \
  -d '{
    "query": "",
    "hitsPerPage": 5,
    "attributesToRetrieve": [
      "objectID",
      "organization_name",
      "grantee_name",
      "grant_amount",
      "grant_purpose"
    ]
  }' | jq '.'

echo ""
echo "💡 If this works, we can use curl to extract the data!"
echo "💡 If it fails, we might need to use browser automation or contact Grantmakers.io for API access"
