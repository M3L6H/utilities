# Git Add Commit Push

![release badge](https://github.com/m3l6h/utilities/actions/workflows/release.yml/badge.svg?branch=gacp)

A utility that combines `git add`, `git commit`, and `git push` into one
command.

There are two scripts bundled with this, `install.sh` and `uninstall.sh`. They
each respectively install and uninstall the `gacp` utility.

An additional `reinstall.sh` script has been included which replaces the utility
but does not remove its data folder. This is useful for updating the app without
removing its configuration.

## Usage

Run `gacp` with the `-m` flag to provide a commit message. If no files are
specified, it runs `git add .` by default. Otherwise it will add the files
specified to the commit.

Configure with `gacp config`. You can configure the file limit `gacp` will abort at by running `gacp config -l <new limit>`. You can also configure whether or not `gacp` should automatically update with `gacp config -u <true/false>`. You can even do both at the once by passing both `-l` and `-u` flags.

Update `gacp` by running `gacp update`. This will fetch and install the latest
version of `gacp`, if it is applicable.
