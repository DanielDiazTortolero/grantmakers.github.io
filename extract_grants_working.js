const https = require('https');
const fs = require('fs');
const path = require('path');

class GrantDataExtractor {
    constructor() {
        this.allGrants = [];
        this.batchSize = 1000; // Algolia's max per request
        this.delay = 200; // 200ms delay between requests to avoid rate limits
        this.outputDir = 'grant_data';
        this.totalGrants = 5372457; // From our test
        this.totalPages = Math.ceil(this.totalGrants / this.batchSize);
    }

    async createOutputDirectory() {
        if (!fs.existsSync(this.outputDir)) {
            fs.mkdirSync(this.outputDir, { recursive: true });
        }
    }

    makeAPIRequest(page = 0) {
        return new Promise((resolve, reject) => {
            const postData = JSON.stringify({
                query: '',
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
                let data = '';

                res.on('data', (chunk) => {
                    data += chunk;
                });

                res.on('end', () => {
                    try {
                        const jsonData = JSON.parse(data);

                        if (res.statusCode === 200) {
                            resolve({
                                grants: jsonData.hits || [],
                                totalHits: jsonData.nbHits || 0,
                                page: jsonData.page || page,
                                processingTimeMS: jsonData.processingTimeMS || 0
                            });
                        } else {
                            reject(new Error(`HTTP ${res.statusCode}: ${data}`));
                        }
                    } catch (e) {
                        reject(new Error(`JSON parse error: ${e.message}`));
                    }
                });
            });

            req.on('error', (e) => {
                reject(e);
            });

            req.write(postData);
            req.end();
        });
    }

    async saveBatchToFile(batch, pageNumber) {
        const filename = `grants_batch_${pageNumber.toString().padStart(4, '0')}.json`;
        const filepath = path.join(this.outputDir, filename);

        const batchData = {
            metadata: {
                page: pageNumber,
                batch_size: batch.length,
                extracted_at: new Date().toISOString(),
                total_grants_so_far: this.allGrants.length,
                api_processing_time: batch.processingTimeMS
            },
            grants: batch.grants
        };

        fs.writeFileSync(filepath, JSON.stringify(batchData, null, 2));
        console.log(`💾 Saved batch ${pageNumber} (${batch.grants.length} grants) to ${filename}`);
    }

    async saveAllGrantsToFile() {
        const allGrantsFile = path.join(this.outputDir, 'all_grants.json');
        const metadata = {
            total_grants: this.allGrants.length,
            extracted_at: new Date().toISOString(),
            source: 'Grantmakers.io Algolia API',
            fields: [
                'objectID', 'organization_name', 'grantee_name', 'grantee_city',
                'grantee_state', 'grant_amount', 'grant_purpose', 'tax_period',
                'ein', 'url', 'pdf_url'
            ],
            extraction_method: 'HTTPS API with browser headers',
            api_endpoint: 'https://qa1231c5w9-dsn.algolia.net/1/indexes/grantmakers_io/query'
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

    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    async extractAllGrants(startPage = 0, maxPages = null) {
        console.log('🚀 Starting Grantmakers.io data extraction...\n');

        await this.createOutputDirectory();

        const pagesToExtract = maxPages || this.totalPages;
        const endPage = Math.min(startPage + pagesToExtract, this.totalPages);

        console.log(`📋 Extracting pages ${startPage} to ${endPage - 1} (${pagesToExtract} pages)`);
        console.log(`📊 Expected total grants: ${this.totalGrants.toLocaleString()}`);
        console.log(`⏱️  Estimated time: ~${Math.ceil(pagesToExtract * (this.delay / 1000) / 60)} minutes\n`);

        let consecutiveErrors = 0;
        const maxConsecutiveErrors = 5;

        // Extract grants page by page
        for (let page = startPage; page < endPage; page++) {
            try {
                console.log(`📥 Extracting page ${page + 1}/${this.totalPages} (Page ${page})`);

                const batchResult = await this.makeAPIRequest(page);

                if (batchResult && batchResult.grants.length > 0) {
                    this.allGrants.push(...batchResult.grants);
                    await this.saveBatchToFile(batchResult, page);
                    consecutiveErrors = 0; // Reset error counter

                    // Progress update every 50 batches
                    if ((page + 1) % 50 === 0) {
                        const progressPercent = ((page + 1) / this.totalPages * 100).toFixed(1);
                        console.log(`📈 Progress: ${progressPercent}% (${this.allGrants.length.toLocaleString()}/${this.totalGrants.toLocaleString()} grants)`);
                    }
                } else {
                    console.log(`⚠️  Empty result for page ${page}, skipping...`);
                }

            } catch (error) {
                consecutiveErrors++;
                console.error(`❌ Error on page ${page}:`, error.message);

                if (consecutiveErrors >= maxConsecutiveErrors) {
                    console.log(`🚨 Too many consecutive errors (${consecutiveErrors}), stopping extraction`);
                    break;
                }
            }

            // Rate limiting delay (except for last page)
            if (page < endPage - 1) {
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

    // Extract a sample of grants for testing
    async extractSampleGrants(sampleSize = 1000) {
        console.log(`🎯 Extracting ${sampleSize} sample grants for testing...`);

        await this.createOutputDirectory();

        const pagesNeeded = Math.ceil(sampleSize / this.batchSize);
        const grants = [];

        for (let page = 0; page < pagesNeeded && grants.length < sampleSize; page++) {
            try {
                const batchResult = await this.makeAPIRequest(page);
                if (batchResult && batchResult.grants) {
                    grants.push(...batchResult.grants);
                }
            } catch (error) {
                console.error(`❌ Error getting sample page ${page}:`, error.message);
                break;
            }

            if (page < pagesNeeded - 1) {
                await this.sleep(this.delay);
            }
        }

        // Save sample to file
        const sampleFile = path.join(this.outputDir, 'sample_grants.json');
        const sampleData = {
            metadata: {
                sample_size: Math.min(grants.length, sampleSize),
                extracted_at: new Date().toISOString(),
                source: 'Grantmakers.io API Sample'
            },
            grants: grants.slice(0, sampleSize)
        };

        fs.writeFileSync(sampleFile, JSON.stringify(sampleData, null, 2));
        console.log(`💾 Saved ${sampleData.grants.length} sample grants to sample_grants.json`);

        return sampleData.grants;
    }
}

// Command line interface
async function main() {
    const extractor = new GrantDataExtractor();

    console.log('🎯 Grantmakers.io Data Extraction Tool');
    console.log('=====================================\n');

    // Parse command line arguments
    const args = process.argv.slice(2);
    const command = args[0];

    if (command === 'sample' || command === '--sample') {
        const sampleSize = parseInt(args[1]) || 1000;
        console.log(`📋 Extracting ${sampleSize} sample grants...`);
        await extractor.extractSampleGrants(sampleSize);
    } else if (command === 'full' || command === '--full') {
        const startPage = parseInt(args[1]) || 0;
        const maxPages = args[2] ? parseInt(args[2]) : null;
        console.log(`📋 Starting full extraction from page ${startPage}${maxPages ? ` (max ${maxPages} pages)` : ''}...`);
        await extractor.extractAllGrants(startPage, maxPages);
    } else {
        console.log('📋 No command specified, extracting sample of 1000 grants...');
        await extractor.extractSampleGrants(1000);
        console.log('\n💡 Usage:');
        console.log('  node extract_grants_working.js sample [size]  # Extract sample');
        console.log('  node extract_grants_working.js full [start_page] [max_pages]  # Extract all');
        console.log('\n🎯 To extract ALL grants, run: node extract_grants_working.js full');
    }

    console.log('\n🎉 Data extraction complete! Check the grant_data/ folder for your files.');
}

// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}

module.exports = GrantDataExtractor;
