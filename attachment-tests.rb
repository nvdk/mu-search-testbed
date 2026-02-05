require_relative 'testing'

WAIT = 5

#####################################################################
# Cleanup
#####################################################################

puts "\n--- Cleanup ---"

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-report-1> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-report-2> ?p ?o }
SPARQL

sleep WAIT

#####################################################################
# Insert test data
#####################################################################

puts "\n--- Inserting test data ---"

# Report with file attachment
sparql ['public'], <<SPARQL
PREFIX dc:   <http://purl.org/dc/elements/1.1/>
PREFIX ext:  <http://mu.semte.ch/vocabularies/ext/>
PREFIX mu:   <http://mu.semte.ch/vocabularies/core/>
INSERT DATA {
  <http://example.org/test-report-1> a ext:Report;
    dc:title "Migration Strategy Report";
    ext:file <share://test-files/sample-report.txt>;
    mu:uuid "report-001".
}
SPARQL

# Report without file attachment
sparql ['public'], <<SPARQL
PREFIX dc:   <http://purl.org/dc/elements/1.1/>
PREFIX ext:  <http://mu.semte.ch/vocabularies/ext/>
PREFIX mu:   <http://mu.semte.ch/vocabularies/core/>
INSERT DATA {
  <http://example.org/test-report-2> a ext:Report;
    dc:title "Xylocarpa Analysis Report";
    mu:uuid "report-002".
}
SPARQL

sleep WAIT

#####################################################################
# Attachment: search by title (basic sanity)
#####################################################################

puts "\n--- Attachment: title search ---"

run_test(1, "report found by title=Migration") {
  res = elastic '/reports/search?filter[title]=Migration', ['public']
  res["count"]
}

run_test(1, "report found by title=Xylocarpa") {
  res = elastic '/reports/search?filter[title]=Xylocarpa', ['public']
  res["count"]
}

run_test(2, "both reports found by title=Report") {
  res = elastic '/reports/search?filter[title]=Report', ['public']
  res["count"]
}

#####################################################################
# Attachment: search by file content
#####################################################################

puts "\n--- Attachment: file content search ---"

run_test(1, "file content search for 'microservice' matches report with attachment") {
  res = elastic '/reports/search?filter[file.content]=microservice', ['public']
  res["count"]
}

run_test(1, "file content search for 'Kubernetes' matches report with attachment") {
  res = elastic '/reports/search?filter[file.content]=Kubernetes', ['public']
  res["count"]
}

run_test(1, "file content search for 'Xylocarpa' matches report with attachment") {
  res = elastic '/reports/search?filter[file.content]=Xylocarpa', ['public']
  res["count"]
}

run_test(0, "file content search for 'nonexistentword' matches nothing") {
  res = elastic '/reports/search?filter[file.content]=nonexistentword', ['public']
  res["count"]
}

#####################################################################
# Attachment: file content excluded from _source
#####################################################################

puts "\n--- Attachment: _source exclusion ---"

run_test(true, "file content is excluded from search results") {
  res = elastic '/reports/search?filter[title]=Migration', ['public']
  # The result should have the report but without file.content in attributes
  report = res["data"].first
  attrs = report["attributes"]
  !attrs.key?("file")
}

#####################################################################
# Cleanup
#####################################################################

puts "\n--- Cleanup ---"

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-report-1> ?p ?o }
SPARQL

sparql ['public'], <<SPARQL
DELETE WHERE { <http://example.org/test-report-2> ?p ?o }
SPARQL

puts "\nAll tests passed!"
