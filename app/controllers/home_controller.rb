################################################################################
#
# Home Controller
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

class HomeController < ApplicationController

  #before_action :establish_session_handler, only: [ :index ]

  #-----------------------------------------------------------------------------

  def index
    session[:wakeupsession] = "ok" # using session hash prompts rails session to load\

    # OAuth2 Protocol Authorization Code Grant Type Flow
    @token = params[:token]
    @code = params[:code]
    if @token.present?
      # token is received downstream
    elsif @code.present?
      # puts "in here!"
      @token_params = {:grant_type => 'authorization_code', :code => @code, :redirect_uri => ENV["REDIRECT_URI"]}
      @token_url = Rails.cache.read("token_url")
      @post_url = URI(@token_url)
      @post_url.user = ENV["CLIENT_ID"]
      @post_url.password = ENV["CLIENT_SECRET"]
      @response = Net::HTTP.post_form @post_url, @token_params
        
      @token = JSON.parse(@response.body)["access_token"]
      @base_server_url = Rails.cache.read("base_server_url")
      @client = FHIR::Client.new(@base_server_url)
      @client.set_bearer_token(@token)
    else
      @base_server_url = params[:server_url]
      @client = FHIR::Client.new(@base_server_url)
      Rails.cache.write("base_server_url", params[:server_url], { expires_in: 30.minutes })

      begin
        options = @client.get_oauth2_metadata_from_conformance(false) # seems hapi fhir can't pass strict=true
      rescue Exception => e
        options = {}
      else
      ensure
        puts "capability statement oauth2 options: ", options
      end

      unless options.blank?
        @params = {:response_type => 'code', :client_id => ENV["CLIENT_ID"], :redirect_uri => ENV["REDIRECT_URI"], :scope => ENV["SCOPE"], :state => SecureRandom.uuid, :aud => @base_server_url }
        @authorize_url = options[:authorize_url] + "?" + @params.to_query
        Rails.cache.write("token_url", options[:token_url], { expires_in: 30.minutes })
        Rails.cache.write("authorize_url", options[:authorize_url], { expires_in: 30.minutes })
        redirect_to @authorize_url
        return
      end
      # @client.set_basic_auth("interop_pit", "d6H33sCXII69oGW3uvuwEh2fxiMfuSkobEMq")
      # @client.set_basic_auth("impact-admin", "5af60ce9a59b92b1ed9882ba8a2535791e79238e0205b35efdaaf3b7")
      # @client.security_headers["Authorization"] = @client.security_headers["Authorization"].gsub("\n", "")
    end

    puts "server url: ", Rails.cache.read("base_server_url")
    @SessionHandler = SessionHandler.establish(session.id, Rails.cache.read("base_server_url"), params[:client_id], params[:client_secret], @client)

    # Get list of patients from cached results from server
    @patients = Rails.cache.read("patients")
    @patients = nil
    if @patients.nil?
      # No cached patients, either because it's the first time or the cache
      # has expired.  Make a call to the FHIR server to get the patient list.

      fhir_response = SessionHandler.fhir_client(session.id).search(FHIR::Patient)
      bundle = fhir_response.resource
      @patients = bundle.entry.collect{ |singleEntry| singleEntry.resource } unless bundle.nil?
      # Display the fhir query being run on the UI to help implementers
      @fhir_query = "#{fhir_response.request[:method].capitalize} #{fhir_response.request[:url]}"
      if @patients.nil?
        SessionHandler.disconnect(session.id)

        err = "Connection failed: Ensure provided url points to a valid FHIR server"
        err += " that holds at least one patient"
        redirect_to root_path, flash: { error: err }
      else
        @patients.each do |patient|
          puts patient.id
          puts patient.name.first
        end
        # Cache the results so we don't burden the server.
        Rails.cache.write("patients", @patients, expires_in: 1.hour)
      end
    end
  end

  #-----------------------------------------------------------------------------
  private
  #-----------------------------------------------------------------------------
  
  def establish_session_handler
    if params[:server_url].present?
      session[:wakeupsession] = "ok" # using session hash prompts rails session to load
      SessionHandler.establish(session.id, params[:server_url])
    else
      err = "Please enter a FHIR server address."
      redirect_to root_path, flash: { error: err }
    end
  end

end
