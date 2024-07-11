# rdfportal


## Installation

```bash
$ ./bin/setup
```


## Configuration

### Environment variables

To set environment variables referenced by endpoint configuration, use `$HOME/.rdfportal/config`.
This file is created by `./bin/setup`.

```bash
$ cat $HOME/.rdfportal/config
RDFPORTAL_CONFIG_DIR=
RDFPORTAL_ENDPOINTS_DIR=
RDFPORTAL_DATASETS_DIR=
RDFPORTAL_VIRTUOSO_PASSWORD=
```

#### `RDFPORTAL_CONFIG_DIR`

```
.
├── datasets
│   ├── dataset1
│   │   ├── dataset.yml
│   │   └── graph.tsv
│   ├── dataset2
│   │   ├── dataset.yml
│   │   └── graph.tsv
│   └── :
│       :
└── endpoints
    └── primary.yml
```

#### `RDFPORTAL_ENDPOINTS_DIR`

This directory contains the database files for the triple store

#### `RDFPORTAL_DATASETS_DIR`

This directory contains RDF data retrieved by `dataset.yml`. 
Data not defined by dataset.yml can also be placed manually.

### Configuration file

#### `datasets/<dataset name>/dataset.yml`

1. The most basic method of data retrievable via HTTP.

   ```yaml
   rdf:
     locations:
       - location: https://www.w3.org/1999/02/22-rdf-syntax-ns
         output: rdf.ttl
         options:
           http:
             headers:
               accept: text/turtle
   ```

2. Interpolate environment variable values to URLs.

   ```yaml
   go:
      locations:
         - location: https://data.bioontology.org/ontologies/GO/download?apikey=%{bioportal_api_key}
           output: go.xml
           parameters:
              bioportal_api_key:
                 env: RDFPORTAL_BIOPORTAL_API_KEY
   ```

3. Interpolate regular expression matches from directory indexes to URLs.

   ```yaml
   mesh:
     locations:
       - location: https://nlmpubs.nlm.nih.gov/projects/mesh/rdf/%{version}
         recursive: true
         includes:
           - "*.nt.gz"
           - "*.ttl"
         parameters:
           version:
             location: https://nlmpubs.nlm.nih.gov/projects/mesh/rdf/
             type: directory
             match: /\d{4}/
             sort: numerical
             order: desc
   ```

4. Single dataset

   The top-level key name creates a sub directory under the dataset directory.
   If there is only one dataset, the key name can be blank.

   ```yaml
   '':
     - location: https://ddbj.nig.ac.jp/ontologies/nucleotide.ttl
   ```

#### `datasets/<dataset name>/graph.tsv`

For each datases, a table of correspondence between file glob patterns and graph names is required.

| pattern                                           | graph                               |
|---------------------------------------------------|-------------------------------------|
| &lt;dataset name&gt;/rdf/latest/*.ttl             | http://example.com/graph/rdf        |
| &lt;dataset name&gt;/go/latest/*.xml              | http://example.com/graph/go         |
| &lt;dataset name&gt;/mesh/latest/mesh.nt.gz       | http://example.com/graph/mesh       |
| &lt;dataset name&gt;/mesh/latest/vocabulary_*.ttl | http://example.com/graph/mesh/vocab |
| &lt;dataset name&gt;/mesh/latest/void_*.ttl       | http://example.com/graph/mesh/void  |

#### `endpoints/<endpoint name>.yml`

```yaml
name: example

database:
  adapter: virtuoso
  host: localhost
  password: <%= ENV.fetch('RDFPORTAL_VIRTUOSO_PASSWORD') %>
  options:
    bin: /opt/homebrew/bin/virtuoso-t
    ini_template: $HOME/.rdfportal/virtuoso.ini.template # change path to template file or copy to here
    cors: true
    federated_query: true
    text_index: false
  environment:
    load:
      Database:
        DatabaseFile: virtuoso.db
        ErrorLogFile: virtuoso.log
        LockFile: virtuoso.lck
        TransactionFile: virtuoso.trx
        xa_persistent_file: virtuoso.pxa
      TempDatabase:
        DatabaseFile: virtuoso-temp.db
        TransactionFile: virtuoso-temp.trx
      Parameters:
        ServerPort: 1111
        NumberOfBuffers: 170000
        MaxDirtyBuffers: 130000
      HTTPServer:
        ServerPort: 8890

load:
  snapshots: true
  parallel: 5
  datasets:
    - name: <dataset name>

publish: # optional
   steps:
      - action: script
        file: path/to/script
        environments:
           FOO: bar
```


## Usage

```bash
$ rdfportal -h
Commands:
  rdfportal fetch <endpoint name>    # Fetch datasets
  rdfportal generate [SUBCOMMAND]    # Commands for generator
  rdfportal help [COMMAND]           # Describe available commands or one specific command
  rdfportal load <endpoint name>     # Load datasets to working directory
  rdfportal publish <endpoint name>  # Publish working directory to new release
  rdfportal setup <endpoint name>    # Setup working directory
  rdfportal status <endpoint name>   # Show status
  rdfportal stop <endpoint name>     # Stop server for working directory
```

### 1. `fetch`

For datasets listed in `.load.datasets`, if `dataset.yml` exists,
this command checks if the remote files have been updated and downloads latest files.

### 2. `setup`

This command initializes a new database to load datasets into working directory.

### 3. `load`

This command loads datasets listed in `.load.datasets` into the database.
Loads the target file into a named graph based on the definition in `graph.tsv`.

### 4. `publish`

This command creates a date directory in the release directory and copies only the necessary files from 
the working directory. If you wish to perform additional processing after this, you can define it in `publish.steps`.

#### Available actions

| action | description          |
|--------|----------------------|
| script | execute shell script |

Variables set by `environments` in the step are available in the script. The following variables are set automatically.

- `RDFPORTAL_PUBLISH_ENDPOINT_NAME`: `.name` in the config
- `RDFPORTAL_PUBLISH_LATEST_RELEASE`: absolute path to latest release


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


## Code of Conduct

Everyone interacting in the VariantRepository project's codebases, issue trackers, chat rooms and mailing lists is 
expected to follow the [code of conduct](https://github.com/rdfportal/rdfportal/blob/main/CODE_OF_CONDUCT.md).
