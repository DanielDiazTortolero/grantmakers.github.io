#!/usr/bin/env ruby
# Find individual researchers (people) in grant recipient data

require 'json'

def is_individual_researcher?(name)
  return false if name.nil? || name.strip.empty?

  name = name.strip

  # Skip generic entries
  return false if name.upcase.include?('SEE SCHEDULE') ||
                  name.upcase.include?('SCHEDULE ATTACHED') ||
                  name.upcase.include?('ATTACHED') ||
                  name.upcase.include?('VARIOUS') ||
                  name.upcase.include?('MULTIPLE') ||
                  name.upcase.include?('SCHEDULE') ||
                  name == 'NONE' ||
                  name == 'N/A' ||
                  name.length < 3

  # Skip obvious organizations
  return false if name.upcase.include?('FOUNDATION') ||
                  name.upcase.include?('UNIVERSITY') ||
                  name.upcase.include?('COLLEGE') ||
                  name.upcase.include?('SCHOOL') ||
                  name.upcase.include?('CHURCH') ||
                  name.upcase.include?('HOSPITAL') ||
                  name.upcase.include?('ASSOCIATION') ||
                  name.upcase.include?('INSTITUTE') ||
                  name.upcase.include?('CENTER') ||
                  name.upcase.include?('CLINIC') ||
                  name.upcase.include?('LABORATORY') ||
                  name.upcase.include?('INC') ||
                  name.upcase.include?('LLC') ||
                  name.upcase.include?('CORPORATION') ||
                  name.upcase.include?('COMPANY') ||
                  name.upcase.include?('DEPARTMENT') ||
                  name.upcase.include?('MINISTRY') ||
                  name.upcase.include?('MISSION') ||
                  name.upcase.include?('ACADEMY') ||
                  name.upcase.include?('LIBRARY') ||
                  name.upcase.include?('MUSEUM') ||
                  name.upcase.include?('THEATER') ||
                  name.upcase.include?('ORCHESTRA') ||
                  name.upcase.include?('SYMPHONY')

  # Must look like a person's name (first and last, possibly middle)
  # At least one space, and no more than 4 words
  words = name.split
  return false if words.size < 2 || words.size > 4

  # Each word should be capitalized (proper names)
  words.each do |word|
    return false unless word.match?(/^[A-Z][a-z]+$/) ||
                        word.match?(/^[A-Z][a-z]+-[A-Z][a-z]+$/) || # hyphenated names
                        word.match?(/^[A-Z]\.$/) # initials
  end

  # Should not contain numbers or special characters (except hyphens and periods for initials)
  return false if name.match?(/[^a-zA-Z\s\.-]/)

  return true
end

# Load the foundation data
puts "Loading foundation data..."
foundations = JSON.parse(File.read('E:\foundation_data\foundations_data.json'))

individual_recipients = []
research_grants = 0
total_named_grants = 0

# Find individual researchers
foundations.each do |foundation|
  if foundation['grants']
    foundation['grants'].each do |grant|
      recipient_name = grant['recipient_name']&.strip

      if recipient_name
        total_named_grants += 1

        if is_individual_researcher?(recipient_name)
          research_grants += 1
          individual_recipients << {
            'foundation' => foundation['name'],
            'recipient' => recipient_name,
            'purpose' => grant['purpose'],
            'amount' => grant['amount_paid'],
            'foundation_state' => foundation['address']&.dig('state'),
            'foundation_city' => foundation['address']&.dig('city')
          }
        end
      end
    end
  end
end

puts "\n" + "="*70
puts "INDIVIDUAL RESEARCHER ANALYSIS"
puts "="*70

puts "\n📊 SUMMARY:"
puts "Total Named Recipients: #{total_named_grants.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse}"
puts "Individual Researchers Found: #{research_grants.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse}"
puts "Research Grants Percentage: #{(research_grants.to_f / total_named_grants * 100).round(1)}%"

puts "\n🏆 TOP RESEARCH FUNDING FOUNDATIONS:"
researcher_counts = individual_recipients.group_by { |r| r['foundation'] }
                                         .transform_values(&:size)
                                         .sort_by { |foundation, count| -count }
                                         .first(10)

researcher_counts.each_with_index do |(foundation, count), index|
  puts "#{index + 1}. #{foundation}: #{count} individual researchers"
end

puts "\n🔬 SAMPLE INDIVIDUAL RESEARCHERS:"
individual_recipients.first(15).each_with_index do |recipient, index|
  puts "#{index + 1}. #{recipient['recipient']}"
  puts "   Purpose: #{recipient['purpose'] || 'Not specified'}"
  puts "   Amount: $#{recipient['amount'].to_s.reverse.scan(/\d{3}|.+/).join(",").reverse}"
  puts "   From: #{recipient['foundation']} (#{recipient['foundation_city']}, #{recipient['foundation_state']})"
  puts ""
end

puts "\n📈 RESEARCH AREAS:"
purposes = individual_recipients.map { |r| r['purpose'] }.compact.reject(&:empty?)
purpose_counts = purposes.group_by(&:itself).transform_values(&:size).sort_by { |purpose, count| -count }

puts "Top Research Purposes:"
purpose_counts.first(10).each_with_index do |(purpose, count), index|
  puts "#{index + 1}. #{purpose}: #{count} grants"
end

puts "\n💰 GRANT SIZE DISTRIBUTION:"
amounts = individual_recipients.map { |r| r['amount'] }.compact.select { |a| a.is_a?(Integer) && a > 0 }
if amounts.any?
  puts "Average Grant: $#{ (amounts.sum.to_f / amounts.size).round.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse }"
  puts "Largest Grant: $#{ amounts.max.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse }"
  puts "Smallest Grant: $#{ amounts.min.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse }"
  puts "Median Grant: $#{ amounts.sort[amounts.size / 2].to_s.reverse.scan(/\d{3}|.+/).join(",").reverse }"
end

