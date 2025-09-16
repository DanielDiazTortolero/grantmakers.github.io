#!/usr/bin/env ruby
# IRS 990-PF XML Parser for Foundation Data
# Extracts foundation information from IRS XML files

require 'nokogiri'
require 'json'
require 'csv'

class IRSFoundationParser
  def initialize(xml_directory)
    @xml_directory = xml_directory
    @foundations = []
  end

  def parse_all_files
    puts "Starting to parse IRS XML files from #{@xml_directory}"

    Dir.glob(File.join(@xml_directory, "**", "*.xml")).each do |xml_file|
      begin
        puts "Processing: #{File.basename(xml_file)}"
        parse_file(xml_file)
      rescue => e
        puts "Error processing #{xml_file}: #{e.message}"
      end
    end

    puts "Completed parsing. Found #{@foundations.size} foundations."
  end

  def parse_file(xml_file)
    doc = Nokogiri::XML(File.read(xml_file))

    # Define namespace for IRS XML
    ns = { 'irs' => 'http://www.irs.gov/efile' }

    # Only process 990-PF forms (private foundations)
    return_type = doc.at_xpath('//irs:ReturnTypeCd', ns)&.text
    return unless return_type == '990PF'

    foundation = extract_foundation_data(doc, ns)
    return if foundation.nil?

    @foundations << foundation
  end

  def extract_foundation_data(doc, ns)
    foundation = {}

    # Basic foundation information
    foundation['ein'] = doc.at_xpath('//irs:Filer/irs:EIN', ns)&.text
    foundation['name'] = doc.at_xpath('//irs:Filer/irs:BusinessName/irs:BusinessNameLine1Txt', ns)&.text

    # Address information
    address = {}
    address['line1'] = doc.at_xpath('//irs:Filer/irs:USAddress/irs:AddressLine1Txt', ns)&.text
    address['city'] = doc.at_xpath('//irs:Filer/irs:USAddress/irs:CityNm', ns)&.text
    address['state'] = doc.at_xpath('//irs:Filer/irs:USAddress/irs:StateAbbreviationCd', ns)&.text
    address['zip'] = doc.at_xpath('//irs:Filer/irs:USAddress/irs:ZIPCd', ns)&.text
    foundation['address'] = address

    # Officer information
    officer = {}
    officer['name'] = doc.at_xpath('//irs:BusinessOfficerGrp/irs:PersonNm', ns)&.text
    officer['title'] = doc.at_xpath('//irs:BusinessOfficerGrp/irs:PersonTitleTxt', ns)&.text
    officer['phone'] = doc.at_xpath('//irs:BusinessOfficerGrp/irs:PhoneNum', ns)&.text
    foundation['officer'] = officer

    # Financial information
    financials = {}
    financials['assets_eoy_fmv'] = doc.at_xpath('//irs:FMVAssetsEOYAmt', ns)&.text&.to_i
    financials['total_assets_boy'] = doc.at_xpath('//irs:TotalAssetsBOYAmt', ns)&.text&.to_i
    financials['total_assets_eoy'] = doc.at_xpath('//irs:TotalAssetsEOYAmt', ns)&.text&.to_i
    financials['total_grants_paid'] = doc.at_xpath('//irs:TotalGrantOrContriPdDurYrAmt', ns)&.text&.to_i
    foundation['financials'] = financials

    # Tax period
    foundation['tax_year_end'] = doc.at_xpath('//irs:TaxPeriodEndDt', ns)&.text
    foundation['tax_year_begin'] = doc.at_xpath('//irs:TaxPeriodBeginDt', ns)&.text

    # Additional foundation details
    foundation['formation_date'] = doc.at_xpath('//irs:FormationDt', ns)&.text
    foundation['state_of_formation'] = doc.at_xpath('//irs:StateOfFormationCd', ns)&.text

    # Purpose and mission
    foundation['primary_purpose'] = doc.at_xpath('//irs:PrimaryExemptPurposeTxt', ns)&.text
    foundation['mission'] = doc.at_xpath('//irs:MissionDesc', ns)&.text

    # Website and contact
    foundation['website'] = doc.at_xpath('//irs:WebsiteAddressTxt', ns)&.text

    # Governance details
    governance = {}
    governance['board_members'] = doc.at_xpath('//irs:GoverningBodyCnt', ns)&.text&.to_i
    governance['independent_directors'] = doc.at_xpath('//irs:IndependentVotingMemberCnt', ns)&.text&.to_i
    foundation['governance'] = governance

    # Extract grant information (Section 17 and other grant data)
    foundation['grants'] = extract_grants(doc, ns)

    foundation
  end

  def extract_grants(doc, ns)
    grants = []

    # Find all grant recipient entries from Section 17
    doc.xpath('//irs:RecipientTable', ns).each do |recipient|
      grant = {}

      # Extract recipient information
      grant['recipient_name'] = recipient.at_xpath('.//irs:RecipientPersonNm', ns)&.text ||
                               recipient.at_xpath('.//irs:RecipientBusinessName/irs:BusinessNameLine1Txt', ns)&.text

      grant['recipient_type'] = recipient.at_xpath('.//irs:RecipientTypeTxt', ns)&.text

      # Address information
      grant_address = {}
      grant_address['line1'] = recipient.at_xpath('.//irs:RecipientUSAddress/irs:AddressLine1Txt', ns)&.text
      grant_address['city'] = recipient.at_xpath('.//irs:RecipientUSAddress/irs:CityNm', ns)&.text
      grant_address['state'] = recipient.at_xpath('.//irs:RecipientUSAddress/irs:StateAbbreviationCd', ns)&.text
      grant_address['zip'] = recipient.at_xpath('.//irs:RecipientUSAddress/irs:ZIPCd', ns)&.text
      grant['address'] = grant_address

      # Contact information
      grant['phone'] = recipient.at_xpath('.//irs:RecipientPhoneNum', ns)&.text
      grant['email'] = recipient.at_xpath('.//irs:RecipientEmailAddressTxt', ns)&.text

      # Grant details
      grant['purpose'] = recipient.at_xpath('.//irs:GrantOrContributionPurposeTxt', ns)&.text
      grant['amount_paid'] = recipient.at_xpath('.//irs:Amt', ns)&.text&.to_i || 0
      grant['cash_grant'] = recipient.at_xpath('.//irs:CashGrantAmt', ns)&.text&.to_i || 0
      grant['non_cash_assistance'] = recipient.at_xpath('.//irs:NonCashAssistanceAmt', ns)&.text&.to_i || 0

      # Additional Section 17 details
      grant['relationship'] = recipient.at_xpath('.//irs:RelationshipToRcpntByOfficer', ns)&.text
      grant['foreign_recipient'] = recipient.at_xpath('.//irs:ForeignRecipientInd', ns)&.text == 'true'
      grant['us_recipient'] = recipient.at_xpath('.//irs:USRecipientInd', ns)&.text == 'true'

      grants << grant unless grant['recipient_name'].nil? && grant['amount_paid'] == 0
    end

    # Also check for grants listed in other sections
    doc.xpath('//irs:GrantOrContributionPdDurYrGrp', ns).each do |grant_group|
      grant = {}

      grant['recipient_name'] = grant_group.at_xpath('.//irs:RecipientPersonNm', ns)&.text ||
                               grant_group.at_xpath('.//irs:RecipientBusinessName/irs:BusinessNameLine1Txt', ns)&.text

      grant['purpose'] = grant_group.at_xpath('.//irs:GrantOrContributionPurposeTxt', ns)&.text
      grant['amount_paid'] = grant_group.at_xpath('.//irs:Amt', ns)&.text&.to_i || 0

      grants << grant unless grant['recipient_name'].nil? && grant['amount_paid'] == 0
    end

    grants
  end

  def save_to_json(filename = 'foundations.json')
    File.write(filename, JSON.pretty_generate(@foundations))
    puts "Saved #{@foundations.size} foundations to #{filename}"
  end

  def save_to_csv(filename = 'foundations.csv')
    return if @foundations.empty?

    CSV.open(filename, 'w') do |csv|
      # Header row
      csv << ['EIN', 'Foundation Name', 'City', 'State', 'Officer Name', 'Officer Title',
              'Assets FMV', 'Total Grants Paid', 'Tax Year End', 'Grant Recipients Count',
              'Website', 'Board Members', 'Primary Purpose', 'State of Formation']

      @foundations.each do |foundation|
        csv << [
          foundation['ein'],
          foundation['name'],
          foundation['address']&.dig('city'),
          foundation['address']&.dig('state'),
          foundation['officer']&.dig('name'),
          foundation['officer']&.dig('title'),
          foundation['financials']&.dig('assets_eoy_fmv'),
          foundation['financials']&.dig('total_grants_paid'),
          foundation['tax_year_end'],
          foundation['grants']&.size || 0,
          foundation['website'],
          foundation['governance']&.dig('board_members'),
          foundation['primary_purpose'],
          foundation['state_of_formation']
        ]
      end
    end

    puts "Saved #{@foundations.size} foundations to #{filename}"
  end

  def get_foundations_count
    @foundations.size
  end

  def get_sample_foundation
    @foundations.first
  end
end

# Usage example
if __FILE__ == $0
  if ARGV.empty?
    puts "Usage: ruby irs_xml_parser.rb <xml_directory>"
    puts "Example: ruby irs_xml_parser.rb 'E:\\Raw IRS data'"
    exit 1
  end

  xml_directory = ARGV[0]
  parser = IRSFoundationParser.new(xml_directory)

  puts "Starting IRS Foundation Data Extraction..."
  parser.parse_all_files

  puts "\nExtracted #{parser.get_foundations_count} foundations"

  # Save results to E drive
  parser.save_to_json('E:\foundation_data\foundations_data.json')
  parser.save_to_csv('E:\foundation_data\foundations_summary.csv')

  # Show sample
  if sample = parser.get_sample_foundation
    puts "\nSample Foundation:"
    puts JSON.pretty_generate(sample)
  end
end
