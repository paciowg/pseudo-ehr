# factories/fhir_servers.rb
FactoryBot.define do
  factory :fhir_server do
    sequence(:name) { |n| "FhirServer#{n}" }
    sequence(:base_url) { |n| "https://fhir-server#{n}.com" }
    authenticated_access { [true, false].sample }
    client_id { "ClientID#{rand(1000)}" }
    client_secret { "ClientSecret#{rand(1000)}" }
    authorization_url { "https://authorization-url#{rand(1000)}.com" }
    token_url { "https://token-url#{rand(1000)}.com" }
    scope { "scope#{rand(1000)}" }

    trait :with_authenticated_access do
      authenticated_access { true }
    end

    trait :without_authenticated_access do
      authenticated_access { false }
      client_id { nil }
      client_secret { nil }
      authorization_url { nil }
      token_url { nil }
      scope { nil }
    end
  end
end
