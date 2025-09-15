const algoliasearch = require('algoliasearch');
const fs = require('fs');
const path = require('path');

// Algolia credentials from the codebase
const ALGOLIA_APP_ID = 'QA1231C5W9';
const ALGOLIA_SEARCH_KEY = '96a419d65f67ff3b4c54939f8e90c220';
const ALGOLIA_INDEX = 'grantmakers_io';

// Initialize Algolia client (v4 syntax - matches original code)
const client = algoliasearch(ALGOLIA_APP_ID, ALGOLIA_SEARCH_KEY);
const index = client.initIndex(ALGOLIA_INDEX);

class GrantDataExtractor {
    constructor() {
        this.allGrants = [];
        this.batchSize = 1000; // Algolia's max per request
        this.delay = 1000; // 1 second delay between requests to avoid rate limits
        this.outputDir = 'grant_data';
    }

    async createOutputDirectory() {
        if (!fs.existsSync(this.outputDir)) {
            fs.mkdirSync(this.outputDir, { recursive: true });
        }
    }

    async getTotalCount() {
        console.log('🔍 Getting total number of grants...');
        const results = await index.search('', {
            hitsPerPage: 1,
            attributesToRetrieve: [],
            attributesToHighlight: []
        });

        const totalCount = results.nbHits;
        console.log(`📊 Found ${totalCount.toLocaleString()} total grants`);
        return totalCount;
    }

    async extractGrantsBatch(page = 0) {
        try {
            const results = await index.search('', {
                page: page,
                hitsPerPage: this.batchSize,
                attributesToRetrieve: [
                    'objectID',
                    'organization_name',
                    'grantee_name',
                    'grantee_city',
                    'grantee_state',
                    'grant_amount',
                    'grant_purpose',
                    'tax_period',
                    'ein',
                    'url',
                    'pdf_url'
                ]
            });

            return {
                grants: results.hits,
                totalPages: results.nbPages,
                currentPage: results.page,
                totalHits: results.nbHits
            };
        } catch (error) {
            console.error(`❌ Error fetching page ${page}:`, error.message);
            return null;
        }
    }

    async saveBatchToFile(batch, pageNumber) {
        const filename = `grants_batch_${pageNumber.toString().padStart(4, '0')}.json`;
        const filepath = path.join(this.outputDir, filename);

        const batchData = {
            metadata: {
                page: pageNumber,
                batch_size: batch.length,
                extracted_at: new Date().toISOString(),
                total_grants_so_far: this.allGrants.length
            },
            grants: batch
        };

        fs.writeFileSync(filepath, JSON.stringify(batchData, null, 2));
        console.log(`💾 Saved batch ${pageNumber} (${batch.length} grants) to ${filename}`);
    }

    async saveAllGrantsToFile() {
        const allGrantsFile = path.join(this.outputDir, 'all_grants.json');
        const metadata = {
            total_grants: this.allGrants.length,
            extracted_at: new Date().toISOString(),
            source: 'Grantmakers.io Algolia Index',
            fields: [
                'objectID', 'organization_name', 'grantee_name', 'grantee_city',
                'grantee_state', 'grant_amount', 'grant_purpose', 'tax_period',
                'ein', 'url', 'pdf_url'
            ]
        };

        const fullData = {
            metadata: metadata,
            grants: this.allGrants
        };

        fs.writeFileSync(allGrantsFile, JSON.stringify(fullData, null, 2));
        console.log(`📦 Saved all ${this.allGrants.length.toLocaleString()} grants to all_grants.json`);

        // Also create a compressed version
        const compressedFile = path.join(this.outputDir, 'all_grants_min.json');
        fs.writeFileSync(compressedFile, JSON.stringify(fullData));
        console.log(`🗜️  Saved compressed version to all_grants_min.json`);
    }

    async extractAllGrants() {
        console.log('🚀 Starting Grantmakers.io data extraction...\n');

        await this.createOutputDirectory();

        // Get total count first
        const totalCount = await this.getTotalCount();
        const totalPages = Math.ceil(totalCount / this.batchSize);

        console.log(`📋 Will extract data in ${totalPages} batches of ${this.batchSize} grants each`);
        console.log(`⏱️  Estimated time: ~${Math.ceil(totalPages * (this.delay / 1000) / 60)} minutes\n`);

        // Extract all grants
        for (let page = 0; page < totalPages; page++) {
            console.log(`📥 Extracting batch ${page + 1}/${totalPages} (Page ${page})`);

            const batchResult = await this.extractGrantsBatch(page);

            if (batchResult && batchResult.grants.length > 0) {
                this.allGrants.push(...batchResult.grants);
                await this.saveBatchToFile(batchResult.grants, page);

                // Progress update every 10 batches
                if ((page + 1) % 10 === 0) {
                    console.log(`📈 Progress: ${this.allGrants.length.toLocaleString()}/${totalCount.toLocaleString()} grants extracted`);
                }
            } else {
                console.log(`⚠️  Skipping empty or failed batch ${page}`);
            }

            // Rate limiting delay (except for last batch)
            if (page < totalPages - 1) {
                console.log(`⏳ Waiting ${this.delay}ms before next request...`);
                await this.sleep(this.delay);
            }
        }

        // Save complete dataset
        console.log('\n💾 Saving complete dataset...');
        await this.saveAllGrantsToFile();

        console.log('\n✅ Extraction complete!');
        console.log(`📊 Total grants extracted: ${this.allGrants.length.toLocaleString()}`);
        console.log(`📁 Data saved to: ${this.outputDir}/`);
        console.log(`\n🎯 You now have access to every documented private grant!`);

        return this.allGrants;
    }

    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    // Method to extract grants with specific filters
    async extractFilteredGrants(filters = {}) {
        console.log('🔍 Extracting filtered grants...', filters);

        const searchParams = {
            hitsPerPage: this.batchSize,
            attributesToRetrieve: [
                'objectID', 'organization_name', 'grantee_name', 'grantee_city',
                'grantee_state', 'grant_amount', 'grant_purpose', 'tax_period',
                'ein', 'url', 'pdf_url'
            ]
        };

        // Add filters if provided
        if (filters.minAmount) {
            searchParams.numericFilters = [`grant_amount>=${filters.minAmount}`];
        }
        if (filters.maxAmount) {
            searchParams.numericFilters = searchParams.numericFilters || [];
            searchParams.numericFilters.push(`grant_amount<=${filters.maxAmount}`);
        }
        if (filters.state) {
            searchParams.facetFilters = [`grantee_state:${filters.state}`];
        }
        if (filters.funderName) {
            searchParams.query = filters.funderName;
        }

        try {
            const results = await index.search(filters.query || '', searchParams);
            console.log(`📊 Found ${results.nbHits.toLocaleString()} grants matching filters`);

            return {
                grants: results.hits,
                totalCount: results.nbHits,
                filters: filters
            };
        } catch (error) {
            console.error('❌ Error with filtered search:', error.message);
            return null;
        }
    }

    // Method to get foundation profiles data
    async extractFoundationProfiles() {
        console.log('🏢 Extracting foundation profiles...');

        const profilesIndex = client.initIndex('grantmakers_profiles');

        try {
            const results = await profilesIndex.search('', {
                hitsPerPage: this.batchSize,
                attributesToRetrieve: [
                    'ein', 'organization_name', 'city', 'state', 'assets', 'revenue',
                    'giving', 'tax_period', 'url', 'pdf_url'
                ]
            });

            console.log(`📊 Found ${results.nbHits.toLocaleString()} foundation profiles`);
            return results.hits;
        } catch (error) {
            console.error('❌ Error extracting foundation profiles:', error.message);
            console.log('💡 Note: Foundation profiles might be in a separate index or require different credentials');
            return null;
        }
    }
}

// Usage examples and main execution
async function main() {
    const extractor = new GrantDataExtractor();

    console.log('🎯 Grantmakers.io Data Extraction Tool');
    console.log('=====================================\n');

    // Option 1: Extract ALL grants (recommended for your use case)
    console.log('📋 Starting full grant dataset extraction...');
    await extractor.extractAllGrants();

    // Option 2: Extract filtered grants (uncomment to use)
    /*
    console.log('\n🔍 Example: Extracting grants over $1M...');
    const largeGrants = await extractor.extractFilteredGrants({
        minAmount: 1000000
    });

    if (largeGrants) {
        fs.writeFileSync(
            path.join(extractor.outputDir, 'large_grants.json'),
            JSON.stringify(largeGrants, null, 2)
        );
        console.log(`💾 Saved ${largeGrants.grants.length} large grants`);
    }
    */

    // Option 3: Extract foundation profiles (uncomment to use)
    /*
    console.log('\n🏢 Extracting foundation profiles...');
    const profiles = await extractor.extractFoundationProfiles();
    if (profiles) {
        fs.writeFileSync(
            path.join(extractor.outputDir, 'foundation_profiles.json'),
            JSON.stringify(profiles, null, 2)
        );
        console.log(`💾 Saved ${profiles.length} foundation profiles`);
    }
    */

    console.log('\n🎉 Data extraction complete! Check the grant_data/ folder for your files.');
}

// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}

module.exports = GrantDataExtractor;
