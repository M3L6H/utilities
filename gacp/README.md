# Git Add Commit Push

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

Configure `gacp` by running it with the `-g` flag. As of now, the only thing
that can be configured is the file limit `gacp` will abort at. This can be
configured by running `gacp -gl <new limit>`.
