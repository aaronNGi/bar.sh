# bar.sh

A simple script to feed statusbars.

## Description

bar.sh is a simple, modular and efficient POSIX shell script with
minimal use of sub-processes. It is controlled via named pipe instead of
signals and simply prints the bar content to stdout. The individual bar
modules can run at different update intervals or be updated via named
pipe.

## Preview

    cpu:34C  fan:0rpm  mem:20%  wifi:82%  bat:48% 20%+  Jan-01  12:00

## Details

After initial setup, bar.sh only calls date(1) every minute, while all
other bar modules use shell built-ins only.

It avoids external commands by using sysfs and procfs, which make it
more of a linux statusbar, in it's default configuration. However, it's
rather easy to rewrite the different modules for other OSes like *BSD.

The various bar modules update at different time intervals but can also
be individually triggered to update via named pipe.

Each of the bar modules has it's own function. The function has to set a
variable with the modules information, which is then used when the bar
is updated by printing to stdout.

bar.sh reads space separated function names from a FIFO and then runs
them. For example, this can be used to refresh the bar after resume from
sleep via acpi script or to immediately refresh a volume module via
volume hotkeys.

There are 4 special functions:

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
pretty inefficient, because a new process has to be spawned everytime
the bar updates, it is recommended to compile a [little C
program](https://wiki.archlinux.org/title/Dwm#Conky_statusbar) from the
Arch Wiki. It reads from stdin and updates the DWM statusbar everytime a
line is read.

## Configuration

To configure bar.sh, the `bar` directory should be copied from the
install location to either `/etc` or to `$HOME/.config`
(`$XDG_CONFIG_HOME` is also honored). There is an example config which
has to be renamed to `bar.rc`.

The following order is used when searching for the config file and
directory of enabled modules:

1. `$XDG_CONFIG_HOME/bar` or `$HOME/.config/bar` if `$XDG_CONFIG_HOME`
   is empty or unset
2. `$HOME/.local/etc/bar`
3. `/etc/bar`
4. `/usr/local/etc/bar`

The module directory can also be set in `bar.rc`.

### Enabling or disabling modules

Bar modules can be enabled/disabled by adding or removing symlinks from
the directory `mods-enabled.d`. Only files with an .sh ending will be
loaded.

The modules are loaded in alphabetical order, so the bar can be
reordered by changing the filenames in `mods-enabled.d`.

bar.sh ships with a set of default modules in the `mods-available`
directory. However, modules can be placed anywhere.

### Changing module attributes

The interval and output format of every module can be changed in
`bar.rc`. The file `bar.rc.example` has all available settings.

## Creating a module

A module script should have the following variables:

* `mod_format`: printf format string including at most one placeholder
  like `%s`, `%02d` etc.
* `mod_intervals`: space separated list of interval:function
  pairs, determining at which interval which function should be called.
  Functions with an interval have to be listed in `mod_functions` too
* `mod_functions`: space separated list of functions which should
  be callable at an interval or by writing it's name to the FIFO.
  Helper functions don't need to be added here
* `mod_variable`: the variable name which holds the data to be
  placed into the `mod_format`'s placeholder

It's possible to create modules which don't update periodically. In that
case `mod_intervals` can be omitted or left empty. While pretty useless,
a static module can be created which has no `mod_variable` and no
placeholder in `mod_format`.

It makes sense to set the variables to config variables first, with a
fallback in case the config variable is missing:

    mod_format=${foobar_format:-foo:%s}

That way the module can simply be customized in the config file.

A function has to be present in the script file, which sets the variable
listed in `mod_variable`.

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

The statusbar should now show something like:

     foo:one  cpu:34C  fan:0rpm  wifi:82  bat:48% 20%+  Jan-01  12:00 

Every two seconds the value will toggle between one and two but the
change can also be triggered by writing to the FIFO:

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

The time it takes a module to complete will skew all other intervals.
