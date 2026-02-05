require_relative 'testing'

WAIT = 5

#####################################################################
# Cleanup
#####################################################################

puts "\n--- Cleanup ---"

# Persons
sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-person-1> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-person-2> ?p ?o }
SPARQL

# Documents (nested test)
sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-ndoc-1> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-ndoc-2> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-ndoc-3> ?p ?o }
SPARQL

# Creative works
sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-work-1> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-work-2> ?p ?o }
SPARQL

sleep WAIT

#####################################################################
# Insert test data
#####################################################################

puts "\n--- Inserting test data ---"

# Persons (nested object targets)
sparql ['public'], <<SPARQL
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX mu:   <http://mu.semte.ch/vocabularies/core/>
INSERT DATA {
  <http://example.org/test-person-1> a foaf:Person;
    foaf:name "Zara Nexus";
    mu:uuid "person-001".

  <http://example.org/test-person-2> a foaf:Person;
    foaf:name "Quinn Prism";
    mu:uuid "person-002".
}
SPARQL

# Documents with author links (for nested object tests)
sparql ['public'], <<SPARQL
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX dc:   <http://purl.org/dc/elements/1.1/>
PREFIX ext:  <http://mu.semte.ch/vocabularies/ext/>
PREFIX mu:   <http://mu.semte.ch/vocabularies/core/>
INSERT DATA {
  <http://example.org/test-ndoc-1> a foaf:Document;
    dc:title "Zephyr Report";
    dc:description "Analysis of zephyr metrics";
    ext:status "published";
    ext:priority 1;
    dc:creator <http://example.org/test-person-1>;
    mu:uuid "ndoc-001".

  <http://example.org/test-ndoc-2> a foaf:Document;
    dc:title "Vortex Analysis";
    dc:description "Deep dive into vortex patterns";
    ext:status "draft";
    ext:priority 2;
    dc:creator <http://example.org/test-person-2>;
    mu:uuid "ndoc-002".

  <http://example.org/test-ndoc-3> a foaf:Document;
    dc:title "Quasar Study";
    dc:description "Research on quasar phenomena";
    ext:status "published";
    ext:priority 3;
    mu:uuid "ndoc-003".
}
SPARQL

# Creative works (for composite index tests)
sparql ['public'], <<SPARQL
PREFIX schema: <http://schema.org/>
PREFIX mu:     <http://mu.semte.ch/vocabularies/core/>
INSERT DATA {
  <http://example.org/test-work-1> a schema:CreativeWork;
    schema:name "Zephyr Framework";
    schema:description "A framework for zephyr methodologies";
    mu:uuid "work-001".

  <http://example.org/test-work-2> a schema:CreativeWork;
    schema:name "Nebula Patterns";
    schema:description "Common patterns in nebula systems";
    mu:uuid "work-002".
}
SPARQL

sleep WAIT

#####################################################################
# Nested objects: search by author.fullname
#####################################################################

puts "\n--- Nested objects: author.fullname ---"

run_test(1, "nested author.fullname=Zara matches 1 doc") {
  res = elastic '/documents/search?filter[author.fullname]=Zara', ['public']
  res["count"]
}

run_test(1, "nested author.fullname=Quinn matches 1 doc") {
  res = elastic '/documents/search?filter[author.fullname]=Quinn', ['public']
  res["count"]
}

run_test(1, "nested author.fullname=Nexus matches 1 doc") {
  res = elastic '/documents/search?filter[author.fullname]=Nexus', ['public']
  res["count"]
}

run_test(1, "nested author.fullname=Prism matches 1 doc") {
  res = elastic '/documents/search?filter[author.fullname]=Prism', ['public']
  res["count"]
}

run_test(0, "nested author.fullname=Phantom matches 0 docs") {
  res = elastic '/documents/search?filter[author.fullname]=Phantom', ['public']
  res["count"]
}

#####################################################################
# Nested objects: document without author still searchable by title
#####################################################################

puts "\n--- Nested objects: docs without author ---"

run_test(1, "doc without author found by title=Quasar") {
  res = elastic '/documents/search?filter[title]=Quasar', ['public']
  res["count"]
}

#####################################################################
# Nested objects: multi-field search across title and author
#####################################################################

puts "\n--- Nested objects: multi-field search ---"

run_test(1, "multi-field title,author.fullname=Zara matches 1 doc") {
  res = elastic '/documents/search?filter[title,author.fullname]=Zara', ['public']
  res["count"]
}

run_test(1, "multi-field title,author.fullname=Quasar matches 1 doc") {
  res = elastic '/documents/search?filter[title,author.fullname]=Quasar', ['public']
  res["count"]
}

#####################################################################
# Composite index: search across document + creative-work
#####################################################################

puts "\n--- Composite index: cross-type search ---"

run_test(2, "composite name=Zephyr matches 2 (1 doc + 1 work)") {
  res = elastic '/dossiers/search?filter[name]=Zephyr', ['public']
  res["count"]
}

run_test(1, "composite name=Vortex matches 1 (doc only)") {
  res = elastic '/dossiers/search?filter[name]=Vortex', ['public']
  res["count"]
}

run_test(1, "composite name=Nebula matches 1 (work only)") {
  res = elastic '/dossiers/search?filter[name]=Nebula', ['public']
  res["count"]
}

run_test(1, "composite name=Quasar matches 1 (doc only)") {
  res = elastic '/dossiers/search?filter[name]=Quasar', ['public']
  res["count"]
}

#####################################################################
# Composite index: search by description
#####################################################################

puts "\n--- Composite index: description search ---"

run_test(2, "composite description=zephyr matches 2 (doc + work)") {
  res = elastic '/dossiers/search?filter[description]=zephyr', ['public']
  res["count"]
}

run_test(1, "composite description=nebula matches 1 (work only)") {
  res = elastic '/dossiers/search?filter[description]=nebula', ['public']
  res["count"]
}

run_test(1, "composite description=quasar matches 1 (doc only)") {
  res = elastic '/dossiers/search?filter[description]=quasar', ['public']
  res["count"]
}

#####################################################################
# Composite index: isolation from non-composite types
#####################################################################

puts "\n--- Composite index: type isolation ---"

run_test(0, "composite does not include concept data") {
  res = elastic '/dossiers/search?filter[name]=Gelinkte', ['public']
  res["count"]
}

run_test(0, "creative-work search does not include document data") {
  res = elastic '/creative-works/search?filter[name]=Vortex', ['public']
  res["count"]
}

#####################################################################
# Cleanup
#####################################################################

puts "\n--- Cleanup ---"

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-person-1> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-person-2> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-ndoc-1> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-ndoc-2> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-ndoc-3> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-work-1> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-work-2> ?p ?o }
SPARQL

puts "\nAll tests passed!"
