# app/controllers/contents_controller.rb
class ContentsController < ApplicationController
  def show
    # Find the content by ID from the Content.all collection
    @content = Content.all.find { |c| c.id == params[:id] }

    # If content not found, check if we have URL to fetch from
    @content = fetch_content_from_url(params[:url], params[:type]) if @content.nil? && params[:url].present?

    # If content still not found, return 404
    unless @content
      render plain: 'Content not found', status: :not_found
      return
    end

    # If content has URL but no data, fetch the data
    fetch_content_data(@content) if @content.data.blank? && @content.url.present?

    # Handle download request
    if params[:download]
      send_data Base64.decode64(@content.data),
                type: @content.type,
                disposition: 'attachment',
                filename: sanitize_filename(@content.title)
      return
    end

    # Render content based on type
    respond_to do |format|
      format.html do
        # Send the content data directly to the browser
        send_data Base64.decode64(@content.data), type: @content.type, disposition: 'inline'
      end
      format.json { render json: { content: @content } }
    end
  end

  private

  def fetch_content_from_url(url, type)
    # Create a new Content instance with data from URL

    connection = Faraday.new(url: url)
    response = connection.get

    # Determine content type if not provided
    content_type = type || response.headers['content-type']

    # Create a title from the URL if not provided
    title = params[:title] || File.basename(URI.parse(url).path)

    # Create new Content instance (will be automatically added to Content.all)
    Content.new(
      title: title,
      type: content_type,
      data: Base64.encode64(response.body),
      url: url
    )
  rescue StandardError => e
    Rails.logger.error("Error fetching content from URL: #{e.message}")
    nil
  end

  def fetch_content_data(content)
    # Fetch data from content URL if available

    connection = Faraday.new(url: content.url)
    response = connection.get

    # Update content with fetched data
    content.instance_variable_set(:@data, Base64.encode64(response.body))
  rescue StandardError => e
    Rails.logger.error("Error fetching content data: #{e.message}")
  end

  def sanitize_filename(filename)
    # Remove invalid characters from filename
    filename.gsub(/[^0-9A-Za-z.-]/, '_')
  end
end
