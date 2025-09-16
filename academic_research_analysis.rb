#!/usr/bin/env ruby
# Analyze academic and research grants to find scientists and researchers

require 'json'

def is_academic_research?(purpose)
  return false if purpose.nil? || purpose.strip.empty?

  purpose = purpose.strip.upcase

  # Look for research, academic, scientific keywords
  research_keywords = [
    'RESEARCH', 'SCIENCE', 'SCIENTIFIC', 'ACADEMIC', 'STUDY', 'LABORATORY',
    'MEDICAL', 'BIOLOGY', 'CHEMISTRY', 'PHYSICS', 'MATHEMATICS', 'ENGINEERING',
    'TECHNOLOGY', 'INNOVATION', 'DISCOVERY', 'EXPERIMENT', 'ANALYSIS',
    'INVESTIGATION', 'DEVELOPMENT', 'CLINICAL', 'PHARMACEUTICAL', 'BIOTECH',
    'NEUROSCIENCE', 'GENETICS', 'CANCER', 'DISEASE', 'VACCINE', 'TREATMENT',
    'CURE', 'THERAPY', 'DIAGNOSIS', 'PREVENTION', 'PUBLIC HEALTH',
    'ENVIRONMENTAL', 'CLIMATE', 'SUSTAINABILITY', 'ECOLOGY', 'CONSERVATION',
    'STEM', 'GRADUATE', 'DOCTORAL', 'POSTDOCTORAL', 'PHD', 'FELLOWSHIP',
    'SCHOLARSHIP', 'AWARD', 'GRANT', 'FUNDING', 'ENDOWMENT', 'PROFESSOR',
    'FACULTY', 'ACADEMIC', 'UNIVERSITY', 'COLLEGE', 'INSTITUTE'
  ]

  research_keywords.any? { |keyword| purpose.include?(keyword) }
end

def is_likely_scientist?(name, purpose)
  return false if name.nil? || purpose.nil?

  # If purpose suggests research/academic work
  return true if is_academic_research?(purpose)

  # Check if recipient is at a research institution
  research_institutions = [
    'UNIVERSITY', 'COLLEGE', 'INSTITUTE', 'LABORATORY', 'RESEARCH CENTER',
    'MEDICAL CENTER', 'HOSPITAL', 'CLINIC', 'ACADEMY OF', 'NATIONAL',
    'FOUNDATION', 'INSTITUTE', 'CENTER FOR'
  ]

  name_upcase = name.upcase
  return true if research_institutions.any? { |inst| name_upcase.include?(inst) }

  false
end

# Load the foundation data
puts "Loading foundation data..."
foundations = JSON.parse(File.read('foundations_data.json'))

academic_grants = []
scientists_found = 0

# Find academic/research grants
foundations.each do |foundation|
  if foundation['grants']
    foundation['grants'].each do |grant|
      recipient_name = grant['recipient_name']&.strip
      purpose = grant['purpose']&.strip

      if recipient_name && purpose
        if is_academic_research?(purpose) || is_likely_scientist?(recipient_name, purpose)
          academic_grants << {
            'foundation' => foundation['name'],
            'recipient' => recipient_name,
            'purpose' => purpose,
            'amount' => grant['amount_paid'],
            'foundation_state' => foundation['address']&.dig('state'),
            'foundation_city' => foundation['address']&.dig('city')
          }
          scientists_found += 1
        end
      end
    end
  end
end

puts "\n" + "="*80
puts "ACADEMIC & RESEARCH GRANT ANALYSIS"
puts "="*80

puts "\n📊 SUMMARY:"
puts "Total Academic/Research Grants Found: #{scientists_found.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse}"
puts "Percentage of Total Grants: #{(scientists_found.to_f / 24110 * 100).round(1)}%"

puts "\n🏆 TOP RESEARCH FUNDING FOUNDATIONS:"
research_counts = academic_grants.group_by { |g| g['foundation'] }
                                 .transform_values(&:size)
                                 .sort_by { |foundation, count| -count }
                                 .first(15)

research_counts.each_with_index do |(foundation, count), index|
  puts "#{index + 1}. #{foundation}: #{count} research grants"
end

puts "\n🔬 SAMPLE RESEARCH GRANTS:"
academic_grants.first(20).each_with_index do |grant, index|
  puts "#{index + 1}. #{grant['recipient']}"
  puts "   Purpose: #{grant['purpose']}"
  puts "   Amount: $#{grant['amount'].to_s.reverse.scan(/\d{3}|.+/).join(",").reverse}"
  puts "   From: #{grant['foundation']} (#{grant['foundation_city']}, #{grant['foundation_state']})"
  puts ""
end

puts "\n📈 RESEARCH AREAS BREAKDOWN:"
purposes = academic_grants.map { |g| g['purpose'] }.compact.reject(&:empty?)
purpose_counts = purposes.group_by(&:itself).transform_values(&:size).sort_by { |purpose, count| -count }

puts "Top Research Purposes:"
purpose_counts.first(15).each_with_index do |(purpose, count), index|
  puts "#{index + 1}. #{purpose}: #{count} grants"
end

puts "\n💰 RESEARCH GRANT SIZE DISTRIBUTION:"
amounts = academic_grants.map { |g| g['amount'] }.compact.select { |a| a.is_a?(Integer) && a > 0 }
if amounts.any?
  puts "Average Research Grant: $#{ (amounts.sum.to_f / amounts.size).round.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse }"
  puts "Largest Research Grant: $#{ amounts.max.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse }"
  puts "Smallest Research Grant: $#{ amounts.min.to_s.reverse.scan(/\d{3}|.+/).join(",").reverse }"
  puts "Median Research Grant: $#{ amounts.sort[amounts.size / 2].to_s.reverse.scan(/\d{3}|.+/).join(",").reverse }"
end

puts "\n🌍 GEOGRAPHIC DISTRIBUTION OF RESEARCH GRANTS:"
states = academic_grants.map { |g| g['foundation_state'] }.compact.reject(&:empty?)
state_counts = states.group_by(&:itself).transform_values(&:size).sort_by { |state, count| -count }

puts "States with Most Research Funding:"
state_counts.first(10).each_with_index do |(state, count), index|
  puts "#{index + 1}. #{state}: #{count} research grants"
end

