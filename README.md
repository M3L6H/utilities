# Git Add Commit Push

![release badge](https://github.com/m3l6h/utilities/actions/workflows/release.yml/badge.svg?branch=gacp)

A utility that combines `git add`, `git commit`, and `git push` into one
command.

## Usage

Run `gacp` with the `-m` flag to provide a commit message. If no files are
specified, it runs `git add .` by default. Otherwise it will add the files
specified to the commit.

Configure with `gacp config`. You can configure the file limit `gacp` will
abort at by running `gacp config -l <new limit>`. You can also configure
whether or not `gacp` should automatically update with
`gacp config -u <true/false>`. You can even do both at the once by passing both
`-l` and `-u` flags.

Update `gacp` by running `gacp update`. This will fetch and install the latest
version of `gacp`, if it is applicable.

## .gacprc

As of `v1.0.0`, `gacp` now looks for and recognizes a `gacprc` file. This is a
json-formatted file that allows users to specify pre-stage and pre-commit hooks.
By default `gacp` looks for `.gacprc`, but alternate configuration files can be
specified by passing the `-c <config file>` parameter.

To prevent `gacp` from using a configuration file, the `-C` flag can be passed.

### Schema

The `.gacprc` file follows a simple schema outlined below.

```json
{
  "pre-stage": [
    {
      "action": "insert",
      "file": "<FILEPATH>",
      "line": "<LINE TO INSERT AT>",
      "content": {
        "template": "<TEMPLATE>",
        "variables": [
          {
            "name": "<VARNAME>",
            "command": "<COMMAND TO RUN TO GET VALUE>"
          }
        ]
      }
    }
  ],
  "pre-commit": [
    {
      "action": "validate",
      "command": "<COMMAND TO RUN TO VALIDATE BEFORE COMMITTING>"
    }
  ]
}
```

#### Template

Templates in the `.gacprc` schema follow a simple pattern. Variables are
identified with `<>` angle brackets. Special variables have their name preceeded
by an `_`. Special variables will be automatically substituted by `gacp`. Other
variables will require an accompanying variable in the `variables` section.

Currently supported special variables are:
- `_msg`: The commit message passed to `gacp`

A typical template might look like:

```json
{
  "template": "<date> - <_msg>\n",
  "variables": [
    {
      "name": "date",
      "command": "date"
    }
  ]
}
```

And when run with `gacp -m "My commit"` would result in something along the
lines of

```
Thu Jun 24 14:39:46 PDT 2021 - My commit
```
