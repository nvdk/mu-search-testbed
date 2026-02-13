# mu-search-testbed

Integration test suite for [mu-search](https://github.com/mu-semtech/mu-search), validating full-text search capabilities over RDF data using Elasticsearch.
NOTE: most of the test scenarios were generated with an LLM, don't trust them blindly!

## Architecture

The testbed spins up a microservices stack via Docker Compose:

```
Virtuoso (RDF triplestore)
        |
   Delta Notifier (change detection)
        |
   mu-search (indexing orchestrator)
       / \
Elasticsearch   Apache Tika
(search backend) (attachment extraction)
```

### Services

| Service            | Image                               | Purpose                                         |
|--------------------|-------------------------------------|-------------------------------------------------|
| **triplestore**    | `redpencil/virtuoso`                | RDF triple store (SPARQL endpoint)              |
| **database**       | `semtech/sparql-parser`             | SPARQL endpoint with authorization              |
| **delta-notifier** | `nvdk/mu-delta-notifier`            | Detects RDF changes and notifies mu-search      |
| **search**         | mu-search (built from source)       | Orchestrates indexing and serves search queries |
| **elasticsearch**  | `semtech/mu-search-elastic-backend` | Full-text search backend                        |
| **tika**           | `apache/tika`                       | Extracts text content from file attachments     |

## Prerequisites

- Docker & Docker Compose
- A local clone of [mu-search](https://github.com/mu-semtech/mu-search) at `../` (the search service is built from source)

## Getting Started

Start the stack:

```bash
docker compose up -d
```

Wait for all services to be healthy, then run the tests via a Docker container on the compose network:

```bash
docker run --rm \
  --network mu-search-testbed_default \
  -e ELASTIC_URL=http://search:80 \
  -e SPARQL_URL=http://database:8890/sparql \
  -v "$(pwd)":/tests -w /tests \
  ruby:3.2 ruby basic-tests.rb
```

Replace `basic-tests.rb` with any of the other test files as needed.

If you have Ruby installed locally, you can also run the tests directly against the exposed ports:

```bash
ruby basic-tests.rb
ruby field-type-tests.rb
ruby attachment-tests.rb
ruby composite-nested-tests.rb
```

## Test Suites

### basic-tests.rb

Tests index invalidation and automatic updates. Inserts and deletes RDF data, then verifies that search results update accordingly in both manual and automatic update modes.

### field-type-tests.rb

Validates search behavior across different Elasticsearch field types:

- **Text** -- full-text search, phrase matching, multi-field queries
- **Keyword** -- exact-match filtering (e.g. status, dataset source)
- **Integer** -- range queries with `:gte:`, `:lt:`, `:gt:` operators
- **Language-string** -- multi-language support (`prefLabel.en`, `prefLabel.nl`, `prefLabel.fr`)

### attachment-tests.rb

Tests file content extraction and indexing via Apache Tika. Verifies that text content from attached files (e.g. `sample-report.txt`) is searchable, and that file content is excluded from the `_source` response to avoid exposing large blobs.

### composite-nested-tests.rb

Tests advanced indexing features:

- **Nested objects** -- one-to-one relationships (e.g. document with an author) indexed as nested Elasticsearch objects, searchable via dot notation (`author.fullname`)
- **Composite indexes** -- virtual indexes that merge multiple RDF types (e.g. a "dossier" combining `foaf:Document` and `schema:CreativeWork`) into a single searchable endpoint

## Configuration

| Path                               | Description                                                        |
|------------------------------------|--------------------------------------------------------------------|
| `config/config.json`               | mu-search index definitions, field mappings, and analyzer settings |
| `config/delta/rules.js`            | Delta notification routing rules                                   |
| `config/authorization/config.lisp` | SPARQL endpoint access control                                     |
| `config/virtuoso/virtuoso.ini`     | Virtuoso triplestore settings                                      |

### Indexed Types

Defined in `config/config.json`:

| Type              | RDF Class             | Fields                                                                                  |
|-------------------|-----------------------|-----------------------------------------------------------------------------------------|
| **document**      | `foaf:Document`       | title (text), description (text), status (keyword), priority (integer), author (nested) |
| **concept**       | `skos:Concept`        | prefLabel (language-string), sourceDataset (keyword), tagLabels (text)                  |
| **creative-work** | `schema:CreativeWork` | name (text), description (text)                                                         |
| **report**        | `ext:Report`          | title (text), file (attachment)                                                         |
| **dossier**       | composite             | Merges document + creative-work                                                         |

