# app/controllers/contents_controller.rb
class ContentsController < ApplicationController
  def show
    @content = Content.find(params[:id])
    @content = fetch_content_from_url(params[:url], params[:type]) if @content.nil? && params[:url].present?

    unless @content
      render plain: 'Content not found', status: :not_found
      return
    end

    fetch_content_data(@content) if @content.data.blank? && @content.url.present?

    if params[:download] && @content.data.present?
      content_type = @content.type.presence || 'application/octet-stream'
      filename = @content.title.present? ? sanitize_filename(@content.title) : 'download'

      send_data Base64.decode64(@content.data),
                type: content_type,
                disposition: 'attachment',
                filename: filename
      return
    end

    respond_to do |format|
      format.html do
        if @content.data.present?
          content_type = @content.type.presence || 'application/octet-stream'
          content_type = 'text/html' if content_type.include?('cda')

          data = Base64.decode64(@content.data)
          data = transfor_cda_to_html(data) if content_type == 'text/html'

          send_data data, type: content_type, disposition: 'inline'
        else
          render plain: 'No content data available', status: :not_found
        end
      end
      format.json { render json: { content: @content } }
    end
  end

  private

  def fetch_content_from_url(url, type)
    content = Content.new(url: url)
    full_url = content.full_url(session[:fhir_server_url])

    unless valid_url?(full_url)
      Rails.logger.error("Invalid URL provided: #{full_url}")
      return nil
    end

    connection = Faraday.new(url: full_url)
    response = connection.get

    content.type = type || response.headers['content-type']

    title = params[:title] || File.basename(URI.parse(full_url).path)
    content.title = title
    content.data = Base64.encode64(response.body)

    content
  rescue StandardError => e
    Rails.logger.error("Error fetching content from URL: #{e.message}")
    nil
  end

  def valid_url?(url)
    allowed_domains = FhirServer.all.map { |server| URI.parse(server.base_url).host }
    uri = URI.parse(url)
    allowed_domains.include?(uri.host)
  rescue URI::InvalidURIError
    false
  end

  def fetch_content_data(content)
    full_url = content.full_url(session[:fhir_server_url])

    unless valid_url?(full_url)
      Rails.logger.error("Invalid URL provided: #{full_url}")
      return nil
    end

    connection = Faraday.new(url: full_url)
    response = connection.get

    content.data = Base64.encode64(response.body)
  rescue StandardError => e
    Rails.logger.error("Error fetching content data: #{e.message}")
  end

  def transfor_cda_to_html(raw_xml)
    doc = Nokogiri::XML(raw_xml)
    xslt = Nokogiri::XSLT(File.read(Rails.root.join('public/CDA.xsl')))

    xslt.transform(doc).to_html
  end

  def sanitize_filename(filename)
    filename.gsub(/[^0-9A-Za-z.-]/, '_')
  end
end
