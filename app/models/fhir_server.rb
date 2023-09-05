# frozen_string_literal: true

# FhirServer Model: save fhir server info with client credentials to authenticate to fhir server.
class FhirServer < ApplicationRecord
  before_save :clean_attributes
  # bcrypt method to encrypt client_secret
  has_secure_password :client_secret, validations: false

  # Validations
  validates :base_url, uniqueness: true, presence: true
  validates :name, presence: true
  validates :client_id, :client_secret, :authorization_url, :token_url, :scope, presence: true,
                                                                                if: :authenticated_access?

  # Custom validation for authenticated access
  validate :ensure_client_credentials_present

  private

  def ensure_client_credentials_present
    cred_check = [
      client_id,
      client_secret,
      authorization_url,
      token_url,
      scope
    ].any?(&:blank?)
    return unless authenticated_access? && cred_check

    errors.add(:authenticated_access, 'requires client_id, client_secret, token_url and scope to be present')
  end

  def clean_attributes
    self.base_url = base_url&.strip&.chomp('/')
    self.name = name&.strip
    self.client_id = client_id&.strip
    self.client_secret = client_secret&.strip
    self.authorization_url = authorization_url&.strip&.chomp('/')
    self.token_url = token_url&.strip&.chomp('/')
    self.scope = scope&.strip
  end
end
