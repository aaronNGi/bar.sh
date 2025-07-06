# bar.sh

A simple script to feed statusbars.

## Description

bar.sh is a simple, modular and efficient POSIX shell script with
minimal use of sub-processes. It is controlled via named pipe instead of
signals and simply prints the bar content to stdout. The individual bar
modules can run at different update intervals or be updated
asynchronously via named pipe.

## Preview

    cpu:34C  fan:0rpm  mem:20%  wifi:82%  bat:48% 20%+  Jan-01  12:00

## Details

In it's main loop, bar.sh only calls date(1) every minute, while all
other bar modules use shell built-ins only.

It avoids external commands by using sysfs and procfs wherever possible,
which make it more of a linux statusbar, in it's default configuration.
However, it's rather easy to rewrite the different modules for other
OSes like *BSD.

The various bar modules update at different time intervals but can also
be individually triggered to update via named pipe.

Every bar modules defines it's own function. The function has to set a
variable with the modules information, which is then used when the bar
is updated by printing to stdout.

bar.sh reads space separated function names from a named pipe and then
runs them. For example, this can be used to refresh the bar after resume
from sleep, via acpi script, or to immediately refresh a volume module
via volume hotkeys.

There are 4 built-in functions:

* `exit`: causes the script to exit
* `reload`: reloads the script by executing itself
* `update`: updates the bar (printing a new line to stdout)
* `update_all`: first runs all bar modules functions and then `update`

## Installation

Just run `install.sh`.

It honors the `$PREFIX` variable, which will default to `/usr/local` for
the root user or `$HOME/.local` for normal users.

## Usage

    bar.sh | some_statusbar

### Updating the DWM statusbar

Instead of setting the statusbar content with `xsetroot`, which is
pretty inefficient, because a new process has to be spawned every time
the bar updates, it is recommended to compile a [little C
program](https://wiki.archlinux.org/title/Dwm#Conky_statusbar) from the
Arch Wiki. It reads from stdin and updates the DWM statusbar every time
a line is read.

## Configuration

To configure bar.sh, the `bar` directory should be copied from the
install location to either `/etc` or to `$HOME/.config`
(`$XDG_CONFIG_HOME` is honored). There is an example config which has to
be copied to `bar.rc`.

The following order is used when searching for the directory containing
the `bar.rc` and enabled modules directory:

1. `$XDG_CONFIG_HOME/bar` or `$HOME/.config/bar` if `$XDG_CONFIG_HOME`
   is empty or unset
2. `$HOME/.local/etc/bar`
3. `/etc/bar`
4. `/usr/local/etc/bar`

The path to the modules enabled directory can be changed in `bar.rc`.

### Enabling or disabling modules

Bar modules can be enabled/disabled by adding or removing symlinks from
the directory `mods-enabled.d`. All files with an .sh ending will be
loaded.

The modules are loaded in alphabetical order, so the bar can be
reordered by simply changing the filenames in `mods-enabled.d`.

bar.sh ships with a set of default modules in the `mods-available`
directory. However, modules can be placed anywhere and then symlinked in
`mods-enabled.d`.

### Changing module attributes

The interval and output format of every module can be changed in
`bar.rc`. The file `bar.rc.example` has all available settings.

## Module spec

A module script should have the following variables:

* `mod_format`: printf format string including at most one placeholder
  like `%s`, `%02d` etc.
* `mod_intervals`: space separated list of interval:function
  pairs, determining at which interval which function should be called.
  Functions with an interval have to be listed in `mod_functions` too
* `mod_functions`: space separated list of functions which should
  be callable at an interval or by writing it's name to the named pipe.
  Module internal helper functions don't need to be added to the
  variable
* `mod_variable`: the variable name which holds the data to be
  placed into the `mod_format`'s placeholder

It's possible to create modules which don't update periodically. In that
case, `mod_intervals` can be omitted or left empty.

In order for users to be able to customize modules via `bar.rc`, modules
should use parameter expansion. When setting their internal module
variables, variables from `bar.rc` should be used as value. A default
value can be supplied, in case the variable is not in `bar.rc`:

    mod_format=${foo_format:-foo:%s}

So here we set the modules format to the config variable `foo_format`,
with a fallback value of "foo:%s", in case `foo_format` is unset or null
(empty).

A module needs to store the modules output in a variable and then supply
the name of that variable in `mod_variable`:

    mod_variable=foo_var

To be able to update the value in the bar output (via named pipe or
automatically at a certain interval), it has to have an update function.
The update function needs to be listed within the space-separated
variable `mod_functions`:

    mod_functions=foo_func

The function `foo_func()` should set the value of the variable
`foo_var`.

If a module should update periodically, it needs to set an
interval:function pair, within the space-separated variable
`mod_intervals`. Just like `mod_format`, modules should use parameter
expansion for the interval, to make it configurable in `bar.rc`:

    mod_intervals="${foo_interval:-2}:foo_func"

So by default, this results in `foo_func()` to be run every 2 seconds,
but can be changed in `bar.rc`, using the variable `foo_interval`.

## Module tutorial

An example module file called `onetwo.sh`:

    mod_format=${onetwo_format:-foo:%s}
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

To enable `onetwo.sh` and place it at the front of the bar:

    ln -s ../mods-available/onetwo.sh \
    	~/.config/bar/mods-enabled/00-onetwo.sh

Now bar.sh has to be reloaded. Given your user id is 1000:

    echo reload >/tmp/bar-1000

bar.sh should now output something like:

     foo:one  cpu:34C  fan:0rpm  wifi:82%  bat:48% 20%+  Jan-01  12:00 

Every two seconds the value will alternate between one and two. The
change can also be triggered by writing to the named pipe:

    echo onetwo update >/tmp/bar-1000

If `update` is omitted, the new value will be shown at the next cycle.
The time between cycles is determined by the module with the shortest
interval. So, if a function is triggered, which would otherwise only
update every minute, and there are functions which run at an interval of
1 second, the new value of the every minute function will be visible
after at most 1 second.

It's also possible to update all modules at once:

    echo update_all >/tmp/bar-1000

## Known problems

The time it takes a module to complete, will skew all other intervals.
However, perfect precision is hardly needed.
