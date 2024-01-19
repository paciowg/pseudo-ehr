# frozen_string_literal: true

# app/models/concerns/model_value_set.rb
module ModelValueSet
  extend ActiveSupport::Concern

  OBSERVATION_PFE_DOMAIN_DISPLAY = get_excel_data('observation-pfe-domain.xlsx').freeze
  OBSERVATION_CATEGORY_DISPLAY = get_excel_data('us-core-observation-category.xlsx').freeze

  OBSERVATION_INTERNAL_CATEGORY_DISPLAY = {
    'clinical-test, functioning' => 'Clinical Test & Functioning',
    'functioning, survey' => 'Survey & Functioning',
    'activity' => 'Activity'
  }.freeze

  private

  def excel_file_path(file_name)
    Rails.root.join('app', 'data', file_name)
  end

  def get_excel_data(file_name)
    excel_file_path = excel_file_path(file_name)
    excel_to_hash(excel_file_path)
  end

  def excel_to_hash(file_path)
    workbook = Roo::Excelx.new(file_path)
    header = workbook.row(1)
    data = []

    (2..workbook.last_row).each do |row_number|
      row = Hash[header.zip(workbook.row(row_number))]
      data << row
    end

    Hash[data.map { |row| [row['Code']&.strip, row['Display']&.strip] }]
  end
end
