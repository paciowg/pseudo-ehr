#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

if ARGV.length < 2
  puts "Usage: ruby test_smp_submit.rb <bundle_json_file> <server_url>"
  puts "Example: ruby test_smp_submit.rb bundle.json http://localhost:8081/fhir"
  exit 1
end

bundle_file = ARGV[0]
server_url = ARGV[1].chomp('/')

unless File.exist?(bundle_file)
  puts "Error: File #{bundle_file} not found."
  exit 1
end

begin
  bundle_json = JSON.parse(File.read(bundle_file))
rescue JSON::ParserError => e
  puts "Error parsing JSON from #{bundle_file}: #{e.message}"
  exit 1
end

# Wrap the bundle in a Parameters resource as required by the $smp-submit operation
parameters = {
  "resourceType" => "Parameters",
  "parameter" => [
    {
      "name" => "smp-medication-data",
      "resource" => bundle_json
    }
  ]
}

uri = URI.parse("#{server_url}/$smp-submit")
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
