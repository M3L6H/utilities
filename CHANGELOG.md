# Changelog

### -- v1.1.0 --
Add pretty printing

### -- v1.0.4 --
Actually fix insertions of lines via pre-stage hooks

### -- v1.0.3 --
Fix trailing newlines getting trimmed

### -- v1.0.2 --
Add null check to hooks

### -- v1.0.1 --
Fix illegal byte sequence error on OSX

### -- v1.0.0 --
Add ability for gacp to recognize and parse a `gacprc` file which allows users to specify pre-stage and pre-commit hooks to further automate their workflows

Printing the CHANGELOG has been disabled. `gacp -c <config file>` now specifies the optional path to a `gacprc` file

`gacp -C` prevents `gacp` from looking for a `gacprc` file

### -- v0.4.8 --
Fix bug with regex comparison when pulling jq

### -- v0.4.7 --
Pull appropriate version of jq based on OS

### -- v0.4.6 --
Update tmpdir to support Mac OSX

### -- v0.4.5 --
Add .app to the data folder

### -- v0.4.4 --
Interpret color codes with less

### -- v0.4.3 --
Pipe version listing into less

### -- v0.4.2 --
Fix copy in reinstall.sh

### -- v0.4.1 --
When listing versions, highlight the installed version in green

### -- v0.4.0 --
Add uninstall subcommand

### -- v0.3.10 --
Remove debugging echo

### -- v0.3.9 --
Make -v check remote

### -- v0.3.8 --
Fix error after auto update trigger

### -- v0.3.7 --
Actually add yellow to gacp

### -- v0.3.6 --
Fix upgrade.sh

### -- v0.3.5 --
Fix infinite loop when auto-updating

### -- v0.3.4 --
Trim version in update error message and add color to it

### -- v0.3.3 --
Add auto-update functionality

### -- v0.3.2 --
Update upgrade and downgrade scripts with absolute path to data

### -- v0.3.1 --
Add check to prevent "upgrading" to the version already installed

### -- v0.3.0 --
Add update subcommand

### -- v0.2.1 --
Add -y flag to the installer

### -- v0.2.0 --
Migrate config to a subcommand

### -- v0.1.2 --
Fix shebang in reinstall.sh and uninstall.sh

### -- v0.1.1 --
Fix error message when trying to install gacp while it is already installed

### -- v0.1.0 --
Initial release
