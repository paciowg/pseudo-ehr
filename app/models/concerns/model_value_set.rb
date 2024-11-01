# app/models/concerns/model_value_set.rb
module ModelValueSet
  extend ActiveSupport::Concern

  def self.excel_file_path(file_name)
    Rails.root.join('app', 'data', file_name)
  end

  def self.get_excel_data(file_name)
    excel_file_path = excel_file_path(file_name)
    excel_to_hash(excel_file_path)
  end

  def self.excel_to_hash(file_path)
    workbook = Roo::Excelx.new(file_path)
    header = workbook.row(1)
    data = []

    (2..workbook.last_row).each do |row_number|
      row = Hash[header.zip(workbook.row(row_number))]
      data << row
    end

    Hash[data.map { |row| [row['Code']&.strip, row['Display']&.strip] }]
  end

  OBSERVATION_PFE_DOMAIN_DISPLAY = get_excel_data('observation-pfe-domain.xlsx').freeze
  OBSERVATION_CATEGORY_DISPLAY = get_excel_data('us-core-observation-category.xlsx').freeze
  OBSERVATION_INTERNAL_CATEGORY_DISPLAY = {
    'clinical-test, functional-status' => 'Clinical Test & Functional Status',
    'functional-status, survey' => 'Survey & Functional Status',
    'cognitive-status, survey' => 'Survey & Cognitive Status',
    'activity' => 'Activity',
    'laboratory' => 'Laboratory'
  }.freeze
end
