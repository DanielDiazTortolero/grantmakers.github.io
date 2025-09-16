#!/usr/bin/env ruby
# Analyze grant recipient data from the foundation database

require 'json'

def is_named_recipient?(name)
  return false if name.nil? || name.strip.empty?

  name = name.strip.upcase

  # Exclude generic entries
  return false if name.include?('SEE SCHEDULE') ||
                  name.include?('SCHEDULE ATTACHED') ||
                  name.include?('ATTACHED') ||
                  name.include?('VARIOUS') ||
                  name.include?('MULTIPLE') ||
                  name.include?('SCHEDULE') ||
                  name.include?('ORGANIZATION') ||
                  name.include?('FOUNDATION') ||
                  name.include?('ASSOCIATION') ||
                  name == 'NONE' ||
                  name == 'N/A' ||
                  name.length < 3

  # Must have at least one space (likely first + last name)
  return name.include?(' ')
end

# Load the foundation data
puts "Loading foundation data..."
foundations = JSON.parse(File.read('foundations_data.json'))

total_foundations = foundations.size
foundations_with_grants = 0
total_grants = 0
named_recipient_grants = 0
generic_grants = 0

# Analyze each foundation's grants
foundations.each do |foundation|
  if foundation['grants'] && !foundation['grants'].empty?
    foundations_with_grants += 1

    foundation['grants'].each do |grant|
      total_grants += 1

      recipient_name = grant['recipient_name']&.strip

      if recipient_name.nil? || recipient_name.empty?
        # No recipient name
      elsif is_named_recipient?(recipient_name)
        named_recipient_grants += 1
      else
        generic_grants += 1
      end
    end
  end
end

puts "\n" + "="*60
puts "GRANT RECIPIENT ANALYSIS"
puts "="*60

puts "\n📊 OVERVIEW:"
puts "Total Foundations: #{total_foundations.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse}"
puts "Foundations with Grants: #{foundations_with_grants.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse}"
puts "Foundations without Grants: #{(total_foundations - foundations_with_grants).to_s.reverse.scan(/\d{3}|.+/).join(",").reverse}"

puts "\n🎯 GRANT BREAKDOWN:"
puts "Total Grants: #{total_grants.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse}"
puts "Named Recipient Grants: #{named_recipient_grants.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse}"
puts "Generic/Anonymous Grants: #{generic_grants.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse}"

percentage_named = (named_recipient_grants.to_f / total_grants * 100).round(1)
puts "Named Recipients: #{percentage_named}%"

puts "\n🏆 TOP FOUNDATIONS BY NAMED RECIPIENTS:"
top_foundations = foundations.select { |f| f['grants'] }
                           .map { |f| [f['name'], f['grants'].select { |g| is_named_recipient?(g['recipient_name']) }.size] }
                           .select { |name, count| count > 0 }
                           .sort_by { |name, count| -count }
                           .first(10)

top_foundations.each_with_index do |foundation, index|
  name, count = foundation
  puts "#{index + 1}. #{name}: #{count} named recipients"
end

puts "\n🔬 SAMPLE NAMED RECIPIENTS:"
sample_recipients = []
foundations.each do |foundation|
  if foundation['grants']
    foundation['grants'].each do |grant|
      if is_named_recipient?(grant['recipient_name'])
        sample_recipients << {
          'foundation' => foundation['name'],
          'recipient' => grant['recipient_name'],
          'purpose' => grant['purpose'],
          'amount' => grant['amount_paid']
        }
      end
    end
  end
  break if sample_recipients.size >= 10
end

sample_recipients.first(10).each_with_index do |grant, index|
  puts "#{index + 1}. #{grant['recipient']} - #{grant['purpose']} ($#{grant['amount'].to_s.reverse.scan(/\d{3}|.+/).join(",").reverse})"
  puts "   From: #{grant['foundation']}"
end
