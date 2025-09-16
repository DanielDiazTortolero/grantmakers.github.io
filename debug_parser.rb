#!/usr/bin/env ruby
require 'nokogiri'

# Debug script to understand IRS XML structure

xml_file = 'E:\irs_sample\2023_TEOS_XML_01A\202300109349100000_public.xml'
puts "Reading file: #{xml_file}"

begin
  doc = Nokogiri::XML(File.read(xml_file))

  # Check for different namespace approaches
  puts "\n=== Testing different XPath approaches ==="

  # Try without namespace
  return_type = doc.at_xpath('//ReturnTypeCd')
  puts "Without namespace: #{return_type&.text}"

  # Try with IRS namespace
  return_type_ns = doc.at_xpath('//irs:ReturnTypeCd', 'irs' => 'http://www.irs.gov/efile')
  puts "With IRS namespace: #{return_type_ns&.text}"

  # Try searching in all namespaces
  return_types = doc.xpath('//*[local-name()="ReturnTypeCd"]')
  puts "All ReturnTypeCd elements: #{return_types.map(&:text)}"

  # Check if we have the expected structure
  filer = doc.at_xpath('//Filer')
  puts "Filer element found: #{!filer.nil?}"

  if filer
    ein = filer.at_xpath('.//EIN')
    puts "EIN found: #{ein&.text}"
  end

  # Check document root
  puts "\nDocument root: #{doc.root.name}"
  puts "Document namespaces: #{doc.root.namespaces}"

rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace
end
