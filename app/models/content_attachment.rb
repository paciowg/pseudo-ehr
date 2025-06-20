# app/models/content_attachment.rb
# ContentAttachment Model
class ContentAttachment
  attr_accessor :id, :title, :type, :data, :url, :creation_date

  def initialize(title: nil, type: nil, data: nil, url: nil, creation_date: nil)
    @id = SecureRandom.hex(16)
    @title = title.presence || 'Attachment'
    @type = type
    @data = data
    @url = url
    @creation_date = creation_date

    self.class.all << self
  end

  # Returns the full URL, resolving relative URLs using the FHIR server URL
  def full_url(fhir_server_url = nil)
    return nil if url.blank?

    if !url.match?(%r{^(http|https)://}) && url.match?(%r{^[A-Za-z]+/[A-Za-z0-9\-.]+$})
      base_url = fhir_server_url.presence || Rails.application.config.fhir_server_url
      base_url = base_url.chomp('/')
      return "#{base_url}/#{url}"
    end

    url
  end

  class << self
    def all
      @all ||= []
    end

    def find(id)
      all.find { |c| c.id == id }
    end
  end
end
