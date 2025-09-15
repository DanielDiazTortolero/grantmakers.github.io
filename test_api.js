const algoliasearch = require('algoliasearch');

// Algolia credentials from the codebase
const ALGOLIA_APP_ID = 'QA1231C5W9';
const ALGOLIA_SEARCH_KEY = '96a419d65f67ff3b4c54939f8e90c220';
const ALGOLIA_INDEX = 'grantmakers_io';

// Initialize Algolia client (v4 syntax - matches original code)
const client = algoliasearch(ALGOLIA_APP_ID, ALGOLIA_SEARCH_KEY);
const index = client.initIndex(ALGOLIA_INDEX);

async function testConnection() {
    console.log('🔍 Testing Algolia API connection...');

    try {
        const results = await index.search('', {
            hitsPerPage: 5,
            attributesToRetrieve: [
                'objectID',
                'organization_name',
                'grantee_name',
                'grant_amount',
                'grant_purpose'
            ]
        });

        console.log('✅ Connection successful!');
        console.log(`📊 Total grants in index: ${results.nbHits.toLocaleString()}`);
        console.log(`📄 Total pages: ${results.nbPages}`);
        console.log(`🎯 Sample grants:`);

        results.hits.forEach((grant, index) => {
            console.log(`${index + 1}. ${grant.organization_name} → ${grant.grantee_name} ($${grant.grant_amount})`);
        });

        return results;
    } catch (error) {
        console.error('❌ Connection failed:', error.message);
        console.error('Full error:', error);
        return null;
    }
}

testConnection();
