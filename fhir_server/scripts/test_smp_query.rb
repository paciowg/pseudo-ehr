#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

if ARGV.length < 2
  puts "Usage: ruby test_smp_query.rb <patient_json_file> <server_url>"
  puts "Example: ruby test_smp_query.rb patient.json http://localhost:8081/fhir"
  exit 1
end

patient_file = ARGV[0]
server_url = ARGV[1].chomp('/')

unless File.exist?(patient_file)
  puts "Error: File #{patient_file} not found."
  exit 1
end

begin
  patient_json = JSON.parse(File.read(patient_file))
rescue JSON::ParserError => e
  puts "Error parsing JSON from #{patient_file}: #{e.message}"
  exit 1
end

# Wrap the patient in a Parameters resource as required by the $smp-query operation
parameters = {
  "resourceType" => "Parameters",
  "parameter" => [
    {
      "name" => "patient",
      "resource" => patient_json
    }
  ]
}

uri = URI.parse("#{server_url}/$smp-query")
http = Net::HTTP.new(uri.host, uri.port)

# Handle HTTPS if the server URL uses it
if uri.scheme == 'https'
  http.use_ssl = true
end

request = Net::HTTP::Post.new(uri.request_uri)
request.content_type = 'application/fhir+json'
request.body = parameters.to_json

begin
  response = http.request(request)
  
  puts "HTTP Status: #{response.code} #{response.message}"
  
  if response.body && !response.body.empty?
    begin
      parsed_response = JSON.parse(response.body)
      puts "Response Body (JSON):"
      puts JSON.pretty_generate(parsed_response)
    rescue JSON::ParserError
      puts "Response Body (Raw):"
      puts response.body
    end
  else
    puts "Empty response body."
  end
rescue StandardError => e
  puts "An error occurred during the request: #{e.message}"
end
