require_relative 'testing'

WAIT = 5

#####################################################################
# Cleanup
#####################################################################

puts "\n--- Cleanup ---"

sparql ['public'], <<SPARQL
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
DELETE WHERE { <http://example.org/test-basic-1> ?p ?o }
SPARQL

sleep WAIT

#####################################################################
# Insert -> verify appears in search
#####################################################################

puts "\n--- Insert and search ---"

run_test(0, "no results before insert") {
  res = elastic '/documents/search?filter[title]=giraffes', ['public']
  res["count"]
}

sparql ['public'], <<SPARQL
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX dc:   <http://purl.org/dc/elements/1.1/>
PREFIX mu:   <http://mu.semte.ch/vocabularies/core/>
INSERT DATA {
  <http://example.org/test-basic-1> a foaf:Document;
    dc:title "giraffes";
    dc:description "A document about silly Goats.";
    mu:uuid "basic-009".
}
SPARQL

sleep WAIT

run_test(1, "document appears after insert") {
  res = elastic '/documents/search?filter[title]=giraffes', ['public']
  res["count"]
}

#####################################################################
# Delete -> verify removed from search
#####################################################################

puts "\n--- Delete and verify removal ---"

sparql ['public'], <<SPARQL
DELETE WHERE {
  <http://example.org/test-basic-1> ?p ?o
}
SPARQL

sleep WAIT

run_test(0, "document gone after delete") {
  res = elastic '/documents/search?filter[title]=giraffes', ['public']
  res["count"]
}

puts "\nAll tests passed!"
