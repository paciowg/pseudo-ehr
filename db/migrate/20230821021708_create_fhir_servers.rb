# FhirServers Migration
class CreateFhirServers < ActiveRecord::Migration[7.0]
  def change
    create_table :fhir_servers do |t|
      t.string :base_url
      t.string :name, null: false
      t.string :client_id
      t.string :client_secret_digest
      t.boolean :authenticated_access, default: false, null: false
      t.string :token_url
      t.string :authorization_url
      t.string :scope
      t.string :access_token
      t.string :refresh_token
      t.datetime :access_token_expires_at

      t.timestamps
    end
    add_index :fhir_servers, :base_url, unique: true
  end
end
