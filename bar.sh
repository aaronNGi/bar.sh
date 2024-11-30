#!/bin/sh
#
# A simple statusbar script.
# Usage: bar.sh | your_statusbar

main() {
	load_config
	load_modules
	eval "update() { printf '$format\n' $variables; }"
	set_sleep_time $intervals
	make_fifo "$fifo_path" || exit
	trap exit INT HUP TERM
	trap 'rm -- "$fifo_path"; kill 0' EXIT
	emitter "$intervals" >"$fifo_path" &
	child_pid=$!
	format=$bar_prefix${format:-bar.sh}$bar_suffix
	read_fifo <"$fifo_path"
}

die() {
	exit_code=$1
	shift
	info "$*"
	exit "$exit_code"
}

info() {
	printf '%s: %s\n' "${0##*/}" "$*" >&2
}

emitter() {
	every() {
		case $(( seconds % $1 )) in 0)
			printf '%s\n' "$2"
		esac
	}

	seconds=0
	# Split the intervals into separate arguments so we can call
	# every() for each interval.
	set -- $1

	while :; do
		for i do
			# Split an interval like 4:foo into separate
			# arguments for every().
			every "${i%:*}" "${i#*:}"
		done
		echo update
		sleep "$sleep_time"
		seconds=$((seconds + sleep_time))
	done
}

read_fifo() {
	# Read function names from stdin. Multiple functions per line,
	# space separated, are allowed.
	while read -r line; do
		for i in $line; do
			run_func "$i"
		done
	done
}

run_func() {
	case $1 in
		update)
			update
		;;
		update_all)
			for i in $functions; do "$i"; done
			update
		;;
		reload)
			# Kill the previous trigger_func() child
			# process.  Otherwise we will have two, after
			# executing ourselves.
			kill "$child_pid"

			# Close old stdin (fifo) in case the fifo path
			# changed.
			exec <&-
			rm -- "$fifo_path"

			exec "$0"
		;;
		*)
			# Surround by spaces so we only match full
			# words. This is to prevent being able to run
			# foo, when there is a foobar in the functions
			# variable.
			case " $functions " in *" $1 "*) "$1"; esac
		;;
	esac
}

load_config() {
	# Default values.
	fifo_path=${TMPDIR:-/tmp}/bar-$(id -u)
	mod_separator="  "
	bar_prefix=" "
	bar_suffix=" "

	unset conf_found mod_dir

	# Config file and modules dir precedence.
	for i in \
		"${XDG_CONFIG_HOME:-$HOME/.config}" \
		"$HOME"/.local/etc \
		/etc \
		/usr/local/etc
	do
		conf=$i/bar/bar.conf
		mod=$i/bar/mods-enabled.d

		if [ -z "$conf_found" ] && [ -r "$conf" ]; then
			conf_found=$conf
		fi

		if [ -z "$mod_dir" ] && [ -d "$mod" ]; then
			mod_dir=$mod
		fi

		# Bail if we already found both files.
		if [ "$conf_found" ] && [ "$mod_dir" ]; then
			break
		fi
	done

	# Source the config.
	if [ "$conf_found" ]; then
		. "$conf_found" ||
			die 1 "Error in config $conf_found"
	fi

	unset i conf conf_found mod
}

load_modules() {
	unset format functions intervals variables

	for i in "$mod_dir"/*.sh; do
		if ! [ -e "$i" ]; then
			info "No modules found in $mod_dir"
			break
		fi

		unset mod_format mod_functions mod_intervals mod_variable

		set -e
		if ! . "$i"; then
			info "Error while sourcing module $i"
			set +e
			continue
		fi
		set +e

		case $mod_variable in [!_a-zA-Z]*|*[!_a-zA-Z0-9]*)
			info "Error: invalid mod_variable" \
				"'$mod_variable' in $i"
			continue
		esac

		if [ "$mod_format" ] && [ "$mod_variable" ]; then
			format=$format${format:+$mod_separator}$mod_format
			variables="$variables \"\$$mod_variable\""
		fi
		[ "$mod_functions" ] &&
			functions="$functions $mod_functions"
		[ "$mod_functions" ] && [ "$mod_intervals" ] &&
			intervals="$intervals $mod_intervals"
	done

	unset i mod_format mod_functions mod_intervals mod_variable
}

make_fifo() {
	if ! [ -p "$1" ]; then
		mkfifo -m600 -- "$1"
	else
		chmod 600 -- "$1"
	fi
}

set_sleep_time() {
	sleep_time=

	for i do
		i=${i%%:*}

		if ! [ "$sleep_time" ] || [ "$i" -lt "$sleep_time" ]; then
			sleep_time=$i
		fi
	done
	unset i

	sleep_time=${sleep_time:-10}
}

sysread() {
	[ -e "$1" ] && read -r "$2" <"$1"
}

main "$@"
