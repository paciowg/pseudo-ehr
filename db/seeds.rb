# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

FhirServer.create(
  [
    { name: 'MiHIN server', base_url: 'https://gw.interop.community/MiHIN/open' },
    { name: 'MaxMD FHIR Server', base_url: 'https://qa-rr-fhir2.maxmddirect.com' },
    { name: 'HAPI Test Server', base_url: 'http://hapi.fhir.org/baseR4' }
  ]
)
