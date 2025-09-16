#!/usr/bin/env ruby
# Extract all IRS XML ZIP files systematically

require 'zip'

def extract_all_zips
  raw_data_dir = 'E:\\Raw IRS data'
  extracted_base_dir = "#{raw_data_dir}\\extracted"

  # Create base extraction directory
  Dir.mkdir(extracted_base_dir) unless Dir.exist?(extracted_base_dir)

  puts "================================================================================="
  puts "EXTRACTING ALL IRS XML ZIP FILES"
  puts "================================================================================="

  # Get all ZIP files
  zip_files = Dir.glob("#{raw_data_dir}/*.zip").sort
  puts "\n📁 Processing #{zip_files.size} ZIP files...\n"

  total_extracted = 0
  total_xml_files = 0

  zip_files.each_with_index do |zip_file, index|
    filename = File.basename(zip_file)
    puts "#{index + 1}/#{zip_files.size}: Extracting #{filename}..."

    begin
      # Create extraction directory for this ZIP
      extract_dir = "#{extracted_base_dir}\\#{filename.gsub('.zip', '')}"
      Dir.mkdir(extract_dir) unless Dir.exist?(extract_dir)

      # Extract the ZIP file
      xml_count = extract_zip(zip_file, extract_dir)
      total_xml_files += xml_count

      puts "  ✅ Extracted: #{xml_count} XML files to #{extract_dir}"
      total_extracted += 1

    rescue => e
      puts "  ❌ Error extracting #{filename}: #{e.message}"
    end
  end

  puts "\n📊 EXTRACTION SUMMARY:"
  puts "=" * 70
  puts "Successfully extracted: #{total_extracted}/#{zip_files.size} ZIP files"
  puts "Total XML files extracted: #{total_xml_files}"
  puts "Extraction directory: #{extracted_base_dir}"

  puts "\n🎯 NEXT STEPS:"
  puts "=" * 70
  puts "1. All ZIP files have been extracted"
  puts "2. Ready to run parser on complete dataset"
  puts "3. Expected: 100,000+ foundations, 1,000,000+ grants"

  return extracted_base_dir
end

def extract_zip(zip_path, extract_path)
  xml_count = 0

  Zip::File.open(zip_path) do |zip_file|
    zip_file.each do |entry|
      if entry.name.end_with?('.xml')
        # Extract XML files
        entry.extract("#{extract_path}\\#{File.basename(entry.name)}")
        xml_count += 1
      end
    end
  end

  return xml_count
end

# Run the extraction
if __FILE__ == $0
  extract_all_zips
end

