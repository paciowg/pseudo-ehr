# frozen_string_literal: true

# app/controllers/pdfs_controller.rb
class PdfsController < ApplicationController
  def show
    connection = Faraday.new(url: session[:fhir_server_url])
    response = connection.get("/Binary/#{params[:binary_id]}")
    send_data response.body, filename: 'document.pdf', type: 'application/pdf', disposition: 'inline'
  end
end
