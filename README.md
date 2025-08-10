# bar.sh

A simple script to feed statusbars.

## Description

bar.sh is a simple, modular, and efficient POSIX shell script
implemented with minimal use of sub-processes.

### Features

* Portable
* Minimal sub-processes usage
* Configured via a single config file
* Controlled through a named pipe (FIFO)
* Bar content is printed to stdout
* Modules are enabled and ordered via a filesystem-based mechanism
  (mods-enabled.d)
* Individual update intervals per module
* Modules can be triggered to update via IPC (named pipe)
* Support for temporary/ephemeral modules (e.g., backlight/volume popup)
* Built-in commands for exiting or reloading the script

### Preview

    cpu:34C  fan:0rpm  mem:20%  wifi:82%  bat:48% 20%+  Jan-01  12:00

### Details

In its main loop, bar.sh only runs date(1) once per minute. All other
modules rely on shell built-ins (except alsa\_volume, which calls amixer
only when triggered via the pipe).

It avoids external commands by utilizing sysfs and procfs where
possible - making it primarily suited for Linux by default. However,
porting to other systems (e.g., \*BSD) is straightforward by modifying
the modules.

Modules update on different intervals and can also be triggered via the
named pipe.

Each module defines its own function, which sets a variable with the
module's output. When the bar is updated, the variable's content is used
when printing the bar to stdout.

The script reads space-separated function names from the named pipe and
executes them. This allows integration with external events like system
resume or volume key presses.

### Built-in commands

* `exit`: Exits the script
* `reload`: Restarts the script
* `update`: Updates the bar (by printing a fresh line to stdout)
* `update_all`: Runs all module functions, then updates the bar

## Installation

Run `install.sh`.

The script respects the `$PREFIX` variable:

* Defaults to `/usr/local` for root
* Defaults to `$HOME/.local` for non-root users


## Usage

    bar.sh | some_statusbar

### Updating the DWM statusbar

Instead of using xsetroot (which spawns a new process for every update),
it's recommended to compile a [small C
utility](https://wiki.archlinux.org/title/Dwm#Conky_statusbar) from the
Arch Wiki. It reads from `stdin` and updates the DWM status bar
efficiently.

## Configuration

To configure bar.sh, copy the `bar` directory from the install location
to either:

* `/etc/`
* `$XDG_CONFIG_HOME/` (or `$HOME/.config/`)

Copy the example config file to `bar.rc`.

### Configuration search order

The script looks for configuration in this order:

1. `$XDG_CONFIG_HOME/bar` (or `$HOME/.config/bar`)
2. `$HOME/.local/etc/bar`
3. `/etc/bar`
4. `/usr/local/etc/bar`

The path to the enabled modules directory (`mods-enabled.d`) can be
changed in `bar.rc`.

## Managing modules

### Enabling or disabling modules

Modules are enabled by copying or symlinking `.sh` files into the
`mods-enabled.d` directory.

They are loaded in alphabetical order, so reordering is as simple as
renaming files.

Default modules are provided in the `mods-available` directory. Custom
modules can be placed anywhere and symlinked into `mods-enabled.d`.

### Changing module settings

A module's update interval and output format can be configured in
`bar.rc`. See `bar.rc.example` for available options.

## Module specification

Each module script shall define the following variables:

* `mod_format`: A printf format string including at most one placeholder
  like `%s`, `%02d`, etc.
* `mod_intervals`: A space separated list of `interval:function`
  pairs, determining at which interval which function should be called.
  Functions with an interval have to be listed in `mod_functions` too
* `mod_functions`: A space separated list of functions which can
  be triggered periodically or manually, by writing its name to the
  named pipe. Module internal helper functions don't have to be added to
  the variable
* `mod_variable`: The name of the variable containing the module's output
  to be placed into the `mod_format`'s placeholder

Notes:

* Modules can omit `mod_intervals` if they don't need periodic updates
* For user configurability, parameter expansion shall be used when
  setting module variables. Example:

    mod_format=${foo_format:- foo:%s }

This uses the value of `$foo_format` from `bar.rc`, or defaults to `"
foo:%s "` if unset.

Each module shall store its output in a variable and declare the name of
that variable using `mod_variable`:

    mod_variable=foo_var

To update this value - either periodically or via the named pipe - an
update function shall be defined. The name of this function needs to be
listed in the space-separated `mod_functions` variable:

    mod_functions=foo_func

The function `foo_func` is responsible for updating the value of
`foo_var`.

If the module should update automatically at a regular interval, an
`interval:function` pair in `mod_intervals` needs to be defined. Like
other settings, the interval shall use parameter expansion to make it
configurable via `bar.rc`:

    mod_intervals="${foo_interval:-2}:foo_func"

In this example, `foo_func()` runs every 2 seconds by default. This
interval can be customized by setting `foo_interval` in `bar.rc`.

## Module tutorial

Here's a simple module: `onetwo.sh`:

    cat <<-'EOF' >~/.local/etc/bar/mods-available/onetwo.sh
    	mod_format=${onetwo_format:- foo:%s }
    	mod_intervals=${onetwo_update_interval:-2}:onetwo
    	mod_functions=onetwo
    	mod_variable=onetwovar
    	
    	onetwo() {
    	    if [ "$onetwovar" = two ]; then
    	        onetwovar=one
    	    else
    	        onetwovar=two
    	    fi
    	}
    EOF

Enable and position the module at the start of the bar:

    ln -s ../mods-available/onetwo.sh \
        ~/.config/bar/mods-enabled/00-onetwo.sh

Reload `bar.sh`:

    echo reload >/tmp/bar-$(id -u)

Now the output should look like:

    foo:one  cpu:34C  fan:0rpm  wifi:82%  bat:48% 20%+  Jan-01  12:00

Every two seconds, it will alternate between "one" and "two".

To manually trigger an update:

    echo onetwo update >/tmp/bar-$(id -u)

If `update` is omitted, the new value will be displayed in the next cycle.

### Timing notes

The update cycle is paced by the module with the shortest interval. This
means that if a function - normally scheduled to run once per minute -
is manually triggered **without** issuing `update`, its output will
appear on the bar within the next cycle, which could be as soon as one
second later, assuming another module updates every second.

To update all modules immediately:

    echo update_all >/tmp/bar-$(id -u)

To change the module's interval to every second:

    echo "onetwo_update_interval=1" >>~/.config/bar/bar.rc
    echo reload >/tmp/bar-$(id -u)

## Known problems

Long-running modules can delay the entire update loop. For example, if a
module (or a set of modules) takes two seconds to complete, even those
scheduled to run every second will be blocked until the slow modules
finish.
