# app/helpers/content_helper.rb
module ContentHelper
  def content_type_badge(content_type)
    content_type = content_type.presence || 'application/octet-stream'

    badge_color = case content_type
                  when 'application/pdf' then 'red'
                  when 'text/plain' then 'gray'
                  when 'text/html' then 'orange'
                  when %r{^image/} then 'green'
                  when 'application/json', 'application/fhir+json' then 'yellow'
                  when 'application/xml', 'text/xml' then 'blue'
                  when 'application/cda+xml' then 'purple'
                  when 'application/jws' then 'indigo'
                  else 'gray'
                  end

    badge_text = case content_type
                 when 'application/pdf' then 'PDF'
                 when 'text/plain' then 'TEXT'
                 when 'text/html' then 'HTML'
                 when %r{^image/} then 'IMAGE'
                 when 'application/json', 'application/fhir+json' then 'JSON'
                 when 'application/xml', 'text/xml' then 'XML'
                 when 'application/cda+xml' then 'CDA'
                 when 'application/jws' then 'JWS'
                 else content_type.split('/').last.upcase
                 end

    content_tag(:span, badge_text,
                class: "bg-#{badge_color}-100 text-#{badge_color}-800 text-xs font-medium px-2 py-0.5 rounded-full")
  end

  def format_xml_content(xml_content, is_cda = false)
    doc = Nokogiri::XML(xml_content) { |config| config.noblanks }
    is_cda ? doc.to_xml(indent: 4) : doc.to_xml(indent: 2)
  rescue StandardError => e
    xml_content
  end

  def parse_jws_content(jws_content)
    # JWS consists of three parts: header.payload.signature
    parts = jws_content.split('.')

    if parts.length != 3
      return {
        parsed_successfully: false,
        error: 'Invalid JWS format. Expected 3 parts separated by periods.'
      }
    end

    # Decode the header (first part)
    header_json = Base64.urlsafe_decode64(parts[0])
    header = JSON.parse(header_json)

    # Decode the payload (second part)
    payload_json = Base64.urlsafe_decode64(parts[1])
    payload = JSON.parse(payload_json)

    # The signature (third part) is typically not displayed in human-readable form

    {
      parsed_successfully: true,
      header: header,
      payload: payload,
      header_formatted: JSON.pretty_generate(header),
      payload_formatted: JSON.pretty_generate(payload),
      raw: jws_content
    }
  rescue StandardError => e
    {
      parsed_successfully: false,
      error: e.message,
      raw: jws_content
    }
  end

  def parse_cda_document(xml_content)
    doc = Nokogiri::XML(xml_content)
    xslt = Nokogiri::XSLT(File.read(Rails.root.join('public/CDA.xsl')))

    xslt.transform(doc).to_html
  end
end
