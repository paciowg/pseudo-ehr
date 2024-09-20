# app/controllers/pdfs_controller.rb
class PdfsController < ApplicationController
  def show
    connection = Faraday.new(url: session[:fhir_server_url])
    response = connection.get("/Binary/#{params[:binary_id]}")

    temp_file = Tempfile.new(['original', '.pdf'])
    temp_file.binmode
    temp_file.write(response.body)
    temp_file.rewind

    if params[:revoked] == 'true'
      modified_pdf = add_watermark(temp_file.path)
      send_data modified_pdf, filename: "document-#{params[:binary_id]}.pdf", type: 'application/pdf',
                              disposition: 'inline'
    else
      send_data response.body, filename: "document-#{params[:binary_id]}.pdf", type: 'application/pdf',
                               disposition: 'inline'
    end
  ensure
    temp_file.close
    temp_file.unlink
    File.delete('output.pdf') if File.exist?('output.pdf')
  end

  private

  def add_watermark(pdf_path)
    Prawn::Document.generate('output.pdf', template: pdf_path) do |pdf|
      (1..pdf.page_count).each do |page|
        pdf.go_to_page(page)
        pdf.fill_color 'FF0000'
        pdf.font('Helvetica', size: 80)
        pdf.draw_text 'REVOKED', at: [100, 300], rotate: 45, opacity: 0.3
      end
    end
    File.read('output.pdf')
  end
end
