class RenameClientSecretDigestToClientSecret < ActiveRecord::Migration[7.1]
  def change
    rename_column :fhir_servers, :client_secret_digest, :client_secret
  end
end
