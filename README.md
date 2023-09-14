# rdfportal


## Installation

```bash
$ ./bin/setup
```


## Configuration

To set environment variables referenced by endpoint configuration, use `$HOME/.rdfportal/config`. 

```bash
$ cat $HOME/.rdfportal/config
RDFPORTAL_VIRTUOSO_PASSWORD=changeme
```


## Usage

```bash
$ rdfportal -h
Commands:
  rdfportal generate [SUBCOMMAND]  # Commands for generator
  rdfportal help [COMMAND]         # Describe available commands or one specific command
  rdfportal load <CONFIG>          # Load datasets to working directory
  rdfportal publish <CONFIG>       # Publish working directory to new release
  rdfportal setup <CONFIG>         # Setup working directory
  rdfportal status <CONFIG>        # Show status
  rdfportal stop <CONFIG>          # Stop server for working directory
```

### `setup`

The setup command initializes a new database to load datasets.
A working directory (`{.directory.prefix}/endpoints/working/{.name}`) is created and an empty database will be created.

### `load`

The load command loads datasets listed in `.load.datasets` into the database.

For each dataset definition, a table of correspondence between file glob patterns and graph names
(`{.directory.prefix}/datasets/<dataset_name>/graph.tsv`) is required.

Loads the target file into a named graph based on the definition in `graph.tsv`.

```
pattern	graph
latest/**/*.ttl	http://example.com/graph
```

### `publish`

The publish command creates a date directory in the release directory and copies only the necessary files from 
the working directory. If you wish to perform additional processing after this, you can define it in `publish.steps`.

#### Available actions

| action | description          |
|--------|----------------------|
| script | execute shell script |

Variables set by `environments` in the step are available in the script. The following variables are set automatically.

- `RDFPORTAL_PUBLISH_ENDPOINT_NAME`: `.name` in the config
- `RDFPORTAL_PUBLISH_LATEST_RELEASE`: absolute path to latest release


# Examples

endpoint.yml

```yaml
---
name: example

directory:
  prefix: /data/rdfportal # required

database:
  adapter: virtuoso
  host: localhost # optional
  password: <%= ENV.fetch('RDFPORTAL_VIRTUOSO_PASSWORD') %> # optional
  options:
    bin: /opt/virtuoso-opensource/bin/virtuoso-t
    ini_template: /data/rdfportal/virtuoso.ini.template
    cors: true            # optional
    federated_query: true # optional
    text_index: false     # optional
  environment: # optional
    load:
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
    - name: hgnc

publish: # optional
  steps:
    - action: script
      file: /data/rdfportal/publish.sh
      environments:
        FOO: bar
```


1. Run the following commands to initialize working directory and setup an empty database.

    ```bash
    $ rdfportal setup endpoint.yml
    ```

2. To perform load,

    ```bash
    $ rdfportal load endpoint.yml
    ```

3. Finally, publish new version

    ```bash
    $ rdfportal publish endpoint.yml
    ```


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


## Code of Conduct

Everyone interacting in the VariantRepository project's codebases, issue trackers, chat rooms and mailing lists is 
expected to follow the [code of conduct](https://github.com/rdfportal/rdfportal/blob/main/CODE_OF_CONDUCT.md).
