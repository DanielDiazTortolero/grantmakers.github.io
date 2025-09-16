#!/usr/bin/env ruby
# Verify which IRS XML files have been processed vs unprocessed

require 'json'
require 'csv'

def verify_processing
  raw_data_dir = 'E:\\Raw IRS data'
  processed_files = []

  puts "================================================================================="
  puts "IRS FOUNDATION DATA PROCESSING VERIFICATION"
  puts "================================================================================="

  # Get all ZIP files
  zip_files = Dir.glob("#{raw_data_dir}/*.zip").sort
  puts "\n📁 ZIP FILES IN RAW DATA DIRECTORY (#{zip_files.size} files):"
  puts "=" * 70

  zip_files.each do |zip_file|
    filename = File.basename(zip_file)
    puts "#{filename}"

    # Check if this file has been extracted (look for extracted directory)
    extracted_dir = "#{raw_data_dir}\\#{filename.gsub('.zip', '')}"

    if Dir.exist?(extracted_dir)
      xml_count = Dir.glob("#{extracted_dir}/**/*.xml").size
      processed_files << filename
      puts "  ✅ EXTRACTED: #{xml_count} XML files"
    else
      puts "  ❌ NOT EXTRACTED"
    end
  end

  puts "\n📊 PROCESSING SUMMARY:"
  puts "=" * 70
  puts "Total ZIP files: #{zip_files.size}"
  puts "Extracted files: #{processed_files.size}"
  puts "Unextracted files: #{zip_files.size - processed_files.size}"

  # Now check what our parser actually processed
  puts "\n🔍 PARSER VERIFICATION:"
  puts "=" * 70

  if File.exist?('foundations_data.json')
    foundations = JSON.parse(File.read('foundations_data.json'))
    puts "Foundations in database: #{foundations.size}"

    total_grants = 0
    foundations.each do |foundation|
      total_grants += foundation['grants'].size if foundation['grants']
    end
    puts "Total grants extracted: #{total_grants}"

    # Check for missing data patterns
    puts "\n⚠️  POTENTIAL ISSUES TO CHECK:"
    puts "=" * 70

    # Check for "SEE SCHEDULE" entries (common placeholder)
    schedule_entries = 0
    foundations.each do |foundation|
      if foundation['grants']
        foundation['grants'].each do |grant|
          if grant['recipient_name']&.upcase&.include?('SEE SCHEDULE')
            schedule_entries += 1
          end
        end
      end
    end
    puts "Grants with 'SEE SCHEDULE' (placeholders): #{schedule_entries}"

    # Check for empty grants
    empty_grants = 0
    foundations.each do |foundation|
      if foundation['grants']
        foundation['grants'].each do |grant|
          if grant['recipient_name'].nil? || grant['recipient_name'].strip.empty?
            empty_grants += 1
          end
        end
      end
    end
    puts "Grants with empty recipient names: #{empty_grants}"

    # Check year distribution
    years = {}
    foundations.each do |foundation|
      if foundation['tax_year_end']
        year = foundation['tax_year_end'][0..3]
        years[year] ||= 0
        years[year] += 1
      end
    end
    puts "\n📅 YEAR DISTRIBUTION:"
    years.sort.each do |year, count|
      puts "  #{year}: #{count} foundations"
    end

  else
    puts "❌ foundations_data.json not found!"
  end

  puts "\n📋 RECOMMENDATIONS:"
  puts "=" * 70
  puts "1. Extract any remaining ZIP files"
  puts "2. Re-run parser on complete dataset"
  puts "3. Check for 'SEE SCHEDULE' placeholder grants"
  puts "4. Verify XML parsing is working correctly"

  if processed_files.size < zip_files.size
    puts "\n⚠️  ACTION NEEDED: Extract these files:"
    (zip_files - processed_files.map{|f| "#{raw_data_dir}\\#{f}"}).each do |unprocessed|
      puts "  - #{File.basename(unprocessed)}"
    end
  end
end

verify_processing

