require_relative 'testing'

WAIT = 5

#####################################################################
# Cleanup
#####################################################################

puts "\n--- Cleanup ---"

sparql ['public'], <<SPARQL
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
DELETE WHERE { <http://example.org/test-doc-1> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-doc-2> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-doc-3> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-concept-1> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-concept-2> ?p ?o }
SPARQL

sleep WAIT

#####################################################################
# Insert test data
#####################################################################

puts "\n--- Inserting test data ---"

# Documents: text fields (title, description), keyword (status), integer (priority)
sparql ['public'], <<SPARQL
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX dc:   <http://purl.org/dc/elements/1.1/>
PREFIX ext:  <http://mu.semte.ch/vocabularies/ext/>
PREFIX mu:   <http://mu.semte.ch/vocabularies/core/>
INSERT DATA {
  <http://example.org/test-doc-1> a foaf:Document;
    dc:title "Semantic Web Introduction";
    dc:description "An overview of semantic technologies and linked data";
    ext:status "published";
    ext:priority 1;
    mu:uuid "doc-001".

  <http://example.org/test-doc-2> a foaf:Document;
    dc:title "Graph Databases Deep Dive";
    dc:description "Exploring graph-based data models for modern apps";
    ext:status "draft";
    ext:priority 2;
    mu:uuid "doc-002".

  <http://example.org/test-doc-3> a foaf:Document;
    dc:title "Introduction to SPARQL";
    dc:description "A guide to querying linked data with SPARQL";
    ext:status "published";
    ext:priority 3;
    mu:uuid "doc-003".
}
SPARQL

# Concepts: language-string (prefLabel), keyword (sourceDataset), text (tagLabels)
sparql ['public'], <<SPARQL
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX dct:  <http://purl.org/dc/terms/>
PREFIX mu:   <http://mu.semte.ch/vocabularies/core/>
INSERT DATA {
  <http://example.org/test-concept-1> a skos:Concept;
    skos:prefLabel "Linked Data"@en;
    skos:prefLabel "Gelinkte Data"@nl;
    dct:source "dataset-alpha";
    <http://vocab-server.com/tagLabel> "web semantics";
    mu:uuid "concept-001".

  <http://example.org/test-concept-2> a skos:Concept;
    skos:prefLabel "Open Data"@en;
    skos:prefLabel "Donnees ouvertes"@fr;
    dct:source "dataset-beta";
    <http://vocab-server.com/tagLabel> "transparency government";
    mu:uuid "concept-002".
}
SPARQL

sleep WAIT

#####################################################################
# Document type: text fields
#####################################################################

puts "\n--- Document type: text fields ---"

run_test(2, "text search 'Introduction' matches 2 docs") {
  res = elastic '/documents/search?filter[title]=Introduction', ['public']
  res["count"]
}

run_test(1, "text search 'Semantic' matches 1 doc") {
  res = elastic '/documents/search?filter[title]=Semantic', ['public']
  res["count"]
}

run_test(0, "text search 'nonexistent' matches 0 docs") {
  res = elastic '/documents/search?filter[title]=nonexistent', ['public']
  res["count"]
}

run_test(3, "text search 'data' in description matches all 3 docs") {
  res = elastic '/documents/search?filter[description]=data', ['public']
  res["count"]
}

run_test(1, "text search 'semantic technologies' in description matches 1 doc") {
  res = elastic '/documents/search?filter[description]=semantic+technologies', ['public']
  res["count"]
}

run_test(2, "phrase search 'linked data' in description matches 2 docs") {
  res = elastic '/documents/search?filter[:phrase:description]=linked+data', ['public']
  res["count"]
}

run_test(1, "multi-field search 'Semantic' across title,description matches 1 doc") {
  res = elastic '/documents/search?filter[title,description]=Semantic', ['public']
  res["count"]
}

#####################################################################
# Document type: keyword field
#####################################################################

puts "\n--- Document type: keyword field ---"

run_test(2, "keyword :term:status=published matches 2 docs") {
  res = elastic '/documents/search?filter[:term:status]=published', ['public']
  res["count"]
}

run_test(1, "keyword :term:status=draft matches 1 doc") {
  res = elastic '/documents/search?filter[:term:status]=draft', ['public']
  res["count"]
}

run_test(0, "keyword :term:status=pub partial match returns 0") {
  res = elastic '/documents/search?filter[:term:status]=pub', ['public']
  res["count"]
}

#####################################################################
# Document type: integer field
#####################################################################

puts "\n--- Document type: integer field ---"

run_test(2, "range :gte:priority=2 matches 2 docs") {
  res = elastic '/documents/search?filter[:gte:priority]=2', ['public']
  res["count"]
}

run_test(1, "range :lt:priority=2 matches 1 doc") {
  res = elastic '/documents/search?filter[:lt:priority]=2', ['public']
  res["count"]
}

run_test(1, "range :gt:priority=2 matches 1 doc (priority 3 only)") {
  res = elastic '/documents/search?filter[:gt:priority]=2', ['public']
  res["count"]
}

run_test(3, "range :gte:priority=1 matches all 3 docs") {
  res = elastic '/documents/search?filter[:gte:priority]=1', ['public']
  res["count"]
}

#####################################################################
# Concept type: language-string field
#####################################################################

puts "\n--- Concept type: language-string field ---"

run_test(1, "language-string prefLabel.*=Linked matches 1 concept") {
  res = elastic '/concepts/search?filter[prefLabel.*]=Linked', ['public']
  res["count"]
}

run_test(1, "language-string prefLabel.en=Open matches 1 concept") {
  res = elastic '/concepts/search?filter[prefLabel.en]=Open', ['public']
  res["count"]
}

run_test(1, "language-string prefLabel.nl=Gelinkte matches 1 concept") {
  res = elastic '/concepts/search?filter[prefLabel.nl]=Gelinkte', ['public']
  res["count"]
}

run_test(0, "language-string prefLabel.nl=Open matches 0 (wrong language)") {
  res = elastic '/concepts/search?filter[prefLabel.nl]=Open', ['public']
  res["count"]
}

run_test(2, "language-string prefLabel.en=Data matches both concepts") {
  res = elastic '/concepts/search?filter[prefLabel.en]=Data', ['public']
  res["count"]
}

#####################################################################
# Concept type: keyword field
#####################################################################

puts "\n--- Concept type: keyword field ---"

run_test(1, "keyword :term:sourceDataset=dataset-alpha matches 1 concept") {
  res = elastic '/concepts/search?filter[:term:sourceDataset]=dataset-alpha', ['public']
  res["count"]
}

run_test(0, "keyword :term:sourceDataset=dataset partial match returns 0") {
  res = elastic '/concepts/search?filter[:term:sourceDataset]=dataset', ['public']
  res["count"]
}

#####################################################################
# Concept type: text field
#####################################################################

puts "\n--- Concept type: text field ---"

run_test(1, "text search tagLabels=semantics matches 1 concept") {
  res = elastic '/concepts/search?filter[tagLabels]=semantics', ['public']
  res["count"]
}

run_test(1, "text search tagLabels=government matches 1 concept") {
  res = elastic '/concepts/search?filter[tagLabels]=government', ['public']
  res["count"]
}

#####################################################################
# Cross-type isolation: types don't leak into each other
#####################################################################

puts "\n--- Cross-type isolation ---"

run_test(0, "document search does not find concept data") {
  res = elastic '/documents/search?filter[title]=Linked+Data', ['public']
  res["count"]
}

run_test(0, "concept search does not find document data") {
  res = elastic '/concepts/search?filter[tagLabels]=SPARQL', ['public']
  res["count"]
}

#####################################################################
# Cleanup
#####################################################################

puts "\n--- Cleanup ---"

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-doc-1> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-doc-2> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-doc-3> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-concept-1> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-concept-2> ?p ?o }
SPARQL

puts "\nAll tests passed!"
