require_relative 'testing'

WAIT = Integer(ENV.fetch('WAIT', '10'))

#####################################################################
# Cleanup
#####################################################################

puts "\n--- Cleanup ---"

%w[
  http://example.org/test-qt-doc-1
  http://example.org/test-qt-doc-2
  http://example.org/test-qt-doc-3
  http://example.org/test-qt-doc-4
  http://example.org/test-qt-concept-1
  http://example.org/test-qt-concept-2
].each do |uri|
  sparql ['public'], "DELETE WHERE { <#{uri}> ?p ?o }"
end

sleep WAIT

#####################################################################
# Insert test data
#####################################################################

puts "\n--- Inserting test data ---"

sparql ['public'], <<SPARQL
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX dc:   <http://purl.org/dc/elements/1.1/>
PREFIX ext:  <http://mu.semte.ch/vocabularies/ext/>
PREFIX mu:   <http://mu.semte.ch/vocabularies/core/>
INSERT DATA {
  <http://example.org/test-qt-doc-1> a foaf:Document;
    dc:title "Elasticsearch Query Testing";
    dc:description "Document about testing query types in elasticsearch";
    ext:status "published";
    ext:priority 10;
    mu:uuid "qt-doc-001".

  <http://example.org/test-qt-doc-2> a foaf:Document;
    dc:title "Fuzzy Matching Exploration";
    dc:description "How fuzzy matching works for approximate search";
    ext:status "draft";
    ext:priority 20;
    mu:uuid "qt-doc-002".

  <http://example.org/test-qt-doc-3> a foaf:Document;
    dc:title "Wildcard Pattern Guide";
    dc:description "Using wildcards and regular expressions in queries";
    ext:status "published";
    ext:priority 30;
    mu:uuid "qt-doc-003".

  <http://example.org/test-qt-doc-4> a foaf:Document;
    dc:title "Prefix Search Handbook";
    dc:description "A handbook for prefix-based search techniques";
    ext:status "archived";
    ext:priority 5;
    mu:uuid "qt-doc-004".
}
SPARQL

sparql ['public'], <<SPARQL
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX dct:  <http://purl.org/dc/terms/>
PREFIX mu:   <http://mu.semte.ch/vocabularies/core/>
INSERT DATA {
  <http://example.org/test-qt-concept-1> a skos:Concept;
    skos:prefLabel "Query Testing"@en;
    skos:prefLabel "Query Testen"@nl;
    dct:source "test-dataset";
    <http://vocab-server.com/tagLabel> "search queries filters";
    mu:uuid "qt-concept-001".

  <http://example.org/test-qt-concept-2> a skos:Concept;
    skos:prefLabel "Approximate Matching"@en;
    dct:source "test-dataset";
    <http://vocab-server.com/tagLabel> "fuzzy approximate";
    mu:uuid "qt-concept-002".
}
SPARQL

sleep WAIT

#####################################################################
# :phrase: - phrase match
#####################################################################

puts "\n--- :phrase: filter ---"

run_test(1, "phrase 'Query Testing' matches 1 doc") {
  res = elastic '/documents/search?filter[:phrase:title]=Elasticsearch+Query', ['public']
  res["count"]
}

run_test(0, "phrase 'Query Elasticsearch' wrong order matches 0") {
  res = elastic '/documents/search?filter[:phrase:title]=Query+Elasticsearch', ['public']
  res["count"]
}

#####################################################################
# :phrase_prefix: - phrase prefix match
#####################################################################

puts "\n--- :phrase_prefix: filter ---"

run_test(1, "phrase_prefix 'Elasticsearch Qu' matches 1 doc") {
  res = elastic '/documents/search?filter[:phrase_prefix:title]=Elasticsearch+Qu', ['public']
  res["count"]
}

run_test(1, "phrase_prefix 'Prefix Search Hand' matches 1 doc") {
  res = elastic '/documents/search?filter[:phrase_prefix:title]=Prefix+Search+Hand', ['public']
  res["count"]
}

#####################################################################
# :fuzzy: - fuzzy match
#####################################################################

puts "\n--- :fuzzy: filter ---"

run_test(1, "fuzzy 'Elastcsearch' (typo) matches 1 doc") {
  res = elastic '/documents/search?filter[:fuzzy:title]=Elastcsearch', ['public']
  res["count"]
}

run_test(1, "fuzzy 'Wilcard' (typo) matches 1 doc") {
  res = elastic '/documents/search?filter[:fuzzy:title]=Wilcard', ['public']
  res["count"]
}

#####################################################################
# :prefix: - prefix query (on keyword field)
#####################################################################

puts "\n--- :prefix: filter ---"

run_test(2, "prefix status=pub matches 2 docs (published)") {
  res = elastic '/documents/search?filter[:prefix:status]=pub', ['public']
  res["count"]
}

run_test(1, "prefix status=dra matches 1 doc (draft)") {
  res = elastic '/documents/search?filter[:prefix:status]=dra', ['public']
  res["count"]
}

run_test(1, "prefix status=arch matches 1 doc (archived)") {
  res = elastic '/documents/search?filter[:prefix:status]=arch', ['public']
  res["count"]
}

#####################################################################
# :wildcard: - wildcard query (on keyword field)
#####################################################################

puts "\n--- :wildcard: filter ---"

run_test(2, "wildcard status=pub* matches 2 docs") {
  res = elastic '/documents/search?filter[:wildcard:status]=pub*', ['public']
  res["count"]
}

run_test(1, "wildcard status=*aft matches 1 doc (draft)") {
  res = elastic '/documents/search?filter[:wildcard:status]=*aft', ['public']
  res["count"]
}

run_test(3, "wildcard status=*ed matches 3 docs (published + archived)") {
  res = elastic '/documents/search?filter[:wildcard:status]=*ed', ['public']
  res["count"]
}

#####################################################################
# :regexp: - regexp query (on keyword field)
#####################################################################

puts "\n--- :regexp: filter ---"

run_test(2, "regexp status=pub.* matches 2 docs") {
  res = elastic '/documents/search?filter[:regexp:status]=pub.*', ['public']
  res["count"]
}

run_test(1, "regexp status=d.*t matches 1 doc (draft)") {
  res = elastic '/documents/search?filter[:regexp:status]=d.*t', ['public']
  res["count"]
}

#####################################################################
# :terms: - multiple exact values
#####################################################################

puts "\n--- :terms: filter ---"

run_test(3, "terms status=published,draft matches 3 docs") {
  res = elastic '/documents/search?filter[:terms:status]=published,draft', ['public']
  res["count"]
}

run_test(1, "terms status=archived matches 1 doc") {
  res = elastic '/documents/search?filter[:terms:status]=archived', ['public']
  res["count"]
}

run_test(4, "terms status=published,draft,archived matches all 4") {
  res = elastic '/documents/search?filter[:terms:status]=published,draft,archived', ['public']
  res["count"]
}

#####################################################################
# :fuzzy_phrase: - span_near with fuzzy matching
#####################################################################

puts "\n--- :fuzzy_phrase: filter ---"

run_test(1, "fuzzy_phrase 'Fuzzy Explration' (typo) matches 1 doc") {
  res = elastic '/documents/search?filter[:fuzzy_phrase:title]=Fuzzy+Explration', ['public']
  res["count"]
}

#####################################################################
# Range filters: dual-bound (:gte,lte: etc.)
#####################################################################

puts "\n--- dual-bound range filters ---"

run_test(2, "range gte,lte priority=10,20 matches 2 docs") {
  res = elastic '/documents/search?filter[:gte,lte:priority]=10,20', ['public']
  res["count"]
}

run_test(1, "range gt,lt priority=10,30 matches 1 doc (priority 20)") {
  res = elastic '/documents/search?filter[:gt,lt:priority]=10,30', ['public']
  res["count"]
}

run_test(4, "range gte,lte priority=1,100 matches all 4 docs") {
  res = elastic '/documents/search?filter[:gte,lte:priority]=1,100', ['public']
  res["count"]
}

#####################################################################
# :has: - field existence
#####################################################################

puts "\n--- :has: filter ---"

run_test(4, "has title=true matches all 4 docs") {
  res = elastic '/documents/search?filter[:has:title]=true', ['public']
  res["count"]
}

run_test(4, "has status=true matches all 4 docs") {
  res = elastic '/documents/search?filter[:has:status]=true', ['public']
  res["count"]
}

#####################################################################
# :has-no: - field non-existence
#####################################################################

puts "\n--- :has-no: filter ---"

# documents don't have an author field set in this test data
run_test(4, "has-no author.fullname=true matches 4 docs (no author set)") {
  res = elastic '/documents/search?filter[:has-no:author.fullname]=true', ['public']
  res["count"]
}

#####################################################################
# :query: - query_string (Lucene syntax)
#####################################################################

puts "\n--- :query: filter ---"

run_test(1, "query_string title='Elasticsearch AND Query' matches 1 doc") {
  res = elastic '/documents/search?filter[:query:title]=Elasticsearch+AND+Query', ['public']
  res["count"]
}

run_test(2, "query_string title='Elasticsearch OR Fuzzy' matches 2 docs") {
  res = elastic '/documents/search?filter[:query:title]=Elasticsearch+OR+Fuzzy', ['public']
  res["count"]
}

run_test(3, "query_string title='*ch*' wildcard in query_string matches 3 docs") {
  res = elastic '/documents/search?filter[:query:title]=*ch*', ['public']
  res["count"]
}

#####################################################################
# :sqs: - simple_query_string
#####################################################################

puts "\n--- :sqs: filter ---"

run_test(1, "sqs 'elasticsearch query' matches 1 doc (AND by default)") {
  res = elastic '/documents/search?filter[:sqs:title]=elasticsearch+query', ['public']
  res["count"]
}

run_test(2, "sqs 'elasticsearch | fuzzy' (OR) matches 2 docs") {
  res = elastic '/documents/search?filter[:sqs:title]=elasticsearch+|+fuzzy', ['public']
  res["count"]
}

run_test(1, "sqs on multiple fields 'query testing' on title,description") {
  res = elastic '/documents/search?filter[:sqs:title,description]=query+testing', ['public']
  res["count"]
}

#####################################################################
# :common: - deprecated, mapped to match
#####################################################################

puts "\n--- :common: filter (deprecated, mapped to match) ---"

run_test(1, "common 'Elasticsearch' matches 1 doc") {
  res = elastic '/documents/search?filter[:common:title]=Elasticsearch', ['public']
  res["count"]
}

run_test(1, "common with cutoff 'Elasticsearch' still works") {
  res = elastic '/documents/search?filter[:common,0.01:title]=Elasticsearch', ['public']
  res["count"]
}

#####################################################################
# :match: - match query
#####################################################################

puts "\n--- :match: filter ---"

run_test(1, "match 'Elasticsearch' matches 1 doc") {
  res = elastic '/documents/search?filter[:match:title]=Elasticsearch', ['public']
  res["count"]
}

run_test(1, "match 'Elasticsearch Query' matches 1 doc") {
  res = elastic '/documents/search?filter[:match:title]=Elasticsearch+Query', ['public']
  res["count"]
}

run_test(1, "match with minimum_should_match 'Elasticsearch Query Testing' ,2 matches 1") {
  res = elastic '/documents/search?filter[:match,2:title]=Elasticsearch+Query+Testing', ['public']
  res["count"]
}

#####################################################################
# :id: and :uri: syntactic sugar
#####################################################################

puts "\n--- :id: and :uri: sugar ---"

run_test(1, ":id: filter finds doc by uuid") {
  res = elastic '/documents/search?filter[:id:]=qt-doc-001', ['public']
  res["count"]
}

run_test(2, ":id: filter finds multiple docs by uuid") {
  res = elastic '/documents/search?filter[:id:]=qt-doc-001,qt-doc-003', ['public']
  res["count"]
}

run_test(1, ":uri: filter finds doc by URI") {
  res = elastic '/documents/search?filter[:uri:]=http://example.org/test-qt-doc-2', ['public']
  res["count"]
}

#####################################################################
# Combined filters (bool must)
#####################################################################

puts "\n--- Combined filters ---"

run_test(1, "term status=published + range gte priority=20 matches 1 doc (priority 30)") {
  res = elastic '/documents/search?filter[:term:status]=published&filter[:gte:priority]=20', ['public']
  res["count"]
}

run_test(2, "term status=published + range gte priority=10 matches 2 docs") {
  res = elastic '/documents/search?filter[:term:status]=published&filter[:gte:priority]=10', ['public']
  res["count"]
}

#####################################################################
# Pagination
#####################################################################

puts "\n--- Pagination ---"

run_test(4, "page[size]=2 returns 2 results but count is 4") {
  res = elastic '/documents/search?filter[:has:title]=true&page[size]=2', ['public']
  [res["count"], res["data"].length]
  res["count"]
}

run_test(2, "page[size]=2 returns 2 data entries") {
  res = elastic '/documents/search?filter[:has:title]=true&page[size]=2', ['public']
  res["data"].length
}

run_test(2, "page[number]=1&page[size]=2 returns second page with 2 entries") {
  res = elastic '/documents/search?filter[:has:title]=true&page[number]=1&page[size]=2', ['public']
  res["data"].length
}

#####################################################################
# Sort
#####################################################################

puts "\n--- Sort ---"

run_test("qt-doc-004", "sort by priority asc returns lowest first") {
  res = elastic '/documents/search?filter[:has:title]=true&sort[priority]=asc', ['public']
  res["data"].first["id"]
}

run_test("qt-doc-003", "sort by priority desc returns highest first") {
  res = elastic '/documents/search?filter[:has:title]=true&sort[priority]=desc', ['public']
  res["data"].first["id"]
}

#####################################################################
# Collapse UUIDs
#####################################################################

puts "\n--- Collapse UUIDs ---"

run_test(4, "collapse_uuids returns correct count") {
  res = elastic '/documents/search?filter[:has:title]=true&collapse_uuids=true', ['public']
  res["count"]
}

#####################################################################
# Cleanup
#####################################################################

puts "\n--- Cleanup ---"

%w[
  http://example.org/test-qt-doc-1
  http://example.org/test-qt-doc-2
  http://example.org/test-qt-doc-3
  http://example.org/test-qt-doc-4
  http://example.org/test-qt-concept-1
  http://example.org/test-qt-concept-2
].each do |uri|
  sparql ['public'], "DELETE WHERE { <#{uri}> ?p ?o }"
end

puts "\nAll tests passed!"
