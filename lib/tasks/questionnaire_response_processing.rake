namespace :fhir do
  desc 'Fetch QR for a patient and generate transaction bundles'
  task :fetch_and_transform_qr, %i[fhir_server patient_id] => :environment do |_, args|
    fhir_server = args[:fhir_server]
    patient_id = args[:patient_id]
    output_dir = Rails.root.join('tmp/fhir_bundles')

    unless fhir_server.present? && patient_id.present?
      abort('❌ Usage: rake fhir:fetch_and_transform_qr[fhir_server,patient_id]')
    end

    client = FhirClientService.new(fhir_server:).client
    query = client.search(FHIR::QuestionnaireResponse, search: { parameters: { patient: patient_id } })
    responses = query.resource&.entry&.map(&:resource) || []

    FileUtils.mkdir_p(output_dir)
    puts "✅ Retrieved #{responses.size} QuestionnaireResponse(s) for Patient/#{patient_id}"

    success_count = 0
    failure_log = []

    responses.each do |qr|
      processor = QuestionnaireResponseProcessor.new(qr.to_hash, fhir_server: fhir_server)
      result = processor.call(submit: false)

      if result.success? && result.bundle
        File.write(output_dir.join("bundle-#{qr.id}.json"), result.bundle.to_json)
        success_count += 1
      else
        failure_log << { id: qr.id, error: result.error.as_json }
      end
    rescue StandardError => e
      failure_log << { id: qr.id, error: e.message }
      next
    end

    puts "✅ Successfully processed #{success_count}/#{responses.size}"
    if failure_log.any?
      puts "⚠️  #{failure_log.size} failed:"
      failure_log.each do |log|
        puts "- QR ID #{log[:id]}: #{log[:error]}"
      end
    end
  end

  desc 'Submit all transaction bundles in tmp/fhir_bundles'
  task :submit_bundles, [:fhir_server] => :environment do |_, args|
    fhir_server = args[:fhir_server]

    abort('❌ Usage: rake fhir:submit_bundles[fhir_server]') if fhir_server.blank?

    client = FhirClientService.new(fhir_server:).client
    input_dir = Rails.root.join('tmp/fhir_bundles')
    bundles = Dir.glob("#{input_dir}/bundle-*.json")

    puts "📦 Submitting #{bundles.size} bundles..."

    success_count = 0
    failure_log = []

    bundles.each do |path|
      bundle = FHIR.from_contents(File.read(path))

      client.begin_transaction
      bundle.entry.each do |entry|
        client.add_transaction_request(
          entry.request.local_method,
          nil,
          entry.resource
        )
      end
      response = client.end_transaction

      if response.code.to_i < 400
        success_count += 1
      else
        failure_log << { file: path, code: response.code, body: response.body }
      end
    rescue StandardError => e
      failure_log << { file: path, error: e.message }
    end

    puts "✅ Submitted #{success_count}/#{bundles.size} bundles successfully"
    if failure_log.any?
      puts "⚠️  #{failure_log.size} failed:"
      failure_log.each do |log|
        puts "- File #{log[:file]}: #{log[:error] || "#{log[:code]} - #{log[:body]}"}"
      end
    end
  end
end
