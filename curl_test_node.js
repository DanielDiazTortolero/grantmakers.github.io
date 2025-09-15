const https = require('https');

console.log('🔍 Testing Grantmakers.io API access via HTTPS request...');

// Prepare the request data
const postData = JSON.stringify({
    query: '',
    hitsPerPage: 5,
    attributesToRetrieve: [
        'objectID',
        'organization_name',
        'grantee_name',
        'grant_amount',
        'grant_purpose'
    ]
});

const options = {
    hostname: 'qa1231c5w9-dsn.algolia.net',
    port: 443,
    path: '/1/indexes/grantmakers_io/query',
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
        'Referer': 'https://www.grantmakers.io/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'X-Algolia-API-Key': '96a419d65f67ff3b4c54939f8e90c220',
        'X-Algolia-Application-Id': 'QA1231C5W9'
    }
};

const req = https.request(options, (res) => {
    console.log(`Status: ${res.statusCode}`);
    console.log(`Headers:`, res.headers);

    let data = '';
    res.on('data', (chunk) => {
        data += chunk;
    });

    res.on('end', () => {
        try {
            const jsonData = JSON.parse(data);
            console.log('✅ API Response:');
            console.log(`📊 Total grants: ${jsonData.nbHits?.toLocaleString() || 'Unknown'}`);
            console.log(`📄 Total pages: ${jsonData.nbPages || 'Unknown'}`);

            if (jsonData.hits && jsonData.hits.length > 0) {
                console.log('🎯 Sample grants:');
                jsonData.hits.forEach((grant, index) => {
                    console.log(`${index + 1}. ${grant.organization_name} → ${grant.grantee_name} ($${grant.grant_amount})`);
                });
                console.log('\n🎉 SUCCESS! We can access the grant data!');
                console.log('💡 Now we can build the full extraction script.');
            } else {
                console.log('⚠️ No hits returned, but API is accessible');
            }
        } catch (e) {
            console.log('📄 Raw response:', data);
        }
    });
});

req.on('error', (e) => {
    console.error('❌ Request failed:', e.message);
});

req.write(postData);
req.end();
