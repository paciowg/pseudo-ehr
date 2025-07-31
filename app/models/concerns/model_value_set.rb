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
      row = header.zip(workbook.row(row_number)).to_h
      data << row
    end

    data.to_h { |row| [row['Code']&.strip, row['Display']&.strip] }
  end

  OBSERVATION_PFE_DOMAIN_DISPLAY = get_excel_data('observation-pfe-domain.xlsx').freeze
  OBSERVATION_CATEGORY_DISPLAY = get_excel_data('us-core-observation-category.xlsx').freeze
  OBSERVATION_INTERNAL_CATEGORY_DISPLAY = {
    'clinical-test' => 'Clinical Test',
    'functional-status' => 'Functional Status',
    'cognitive-status' => 'Cognitive Status',
    'survey' => 'Survey'
  }.freeze
end
