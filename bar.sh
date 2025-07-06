#!/bin/sh
#
# A simple script to feed statusbars.
# Usage: bar.sh | your_statusbar

main() {
	load_config
	load_modules
	format=$bar_prefix${format:-bar.sh}$bar_suffix
	eval "$(gen_emitter_func "$intervals")"
	eval "update() { printf '$format\n' $variables; }"
	make_fifo "$fifo_path" || exit
	trap exit INT HUP TERM
	trap 'rm -- "$fifo_path"; kill 0' EXIT
	emitter "$intervals" >"$fifo_path" &
	child_pid=$!
	read_fifo <"$fifo_path"
}

die() {
	exit_code=$1
	shift
	info "$*"
	exit "$exit_code"
}

gen_emitter_func() {
	awk -v s="$1" 'BEGIN {
		# Clean leading/trailing whitespace.
		gsub(/^ +| +$/, "", s)

		split(s, intervals, /[ :]+/)

		for (i=1; i<=length(intervals); i+=2) {
			# Interval seconds.
			n = intervals[i]

			# Function name.
			f = intervals[i+1]

			# Shortest function interval determines sleep
			# time.
			min = (min==0 || n<min) ? n : min

			# Group functions by interval, so we can update
			# functions with the same interval in a single
			# echo call.
			a[n] = a[n] (length(a[n]) ? " " : "") f
		}

		# Default to 10 seconds sleep time, if no module has an
		# interval (or there are no modules).
		if (!min)
			min = 10

		# Output script for `eval`.
		print "emitter() {"
		print "\tseconds=0"
		print "\twhile :; do"

		fmt = "\t\tcase $((%s %% %d)) in 0) echo \"%s\"; esac\n"
		for (i in a)
			printf fmt, "seconds", i, a[i]

		print "\t\techo update"
		print "\t\tsleep " min
		print "\t\tseconds=$((seconds + " min "))"
		print "\tdone"
		print "}"
	}'
}

info() {
	printf '%s: %s\n' "${0##*/}" "$*" >&2
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
		conf=$i/bar/bar.rc
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

		if [ "$mod_functions" ]; then
			if [ "$mod_intervals" ]; then
				intervals="$intervals $mod_intervals"
			fi

			functions="$functions $mod_functions"
		fi
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
		exit)
			exit
		;;
		update)
			update
		;;
		update_all)
			for i in $functions; do "$i"; done
			update
		;;
		reload)
			# Kill the previous emitter() child process.
			# Otherwise we will have two, after executing
			# ourselves.
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

sysread() {
	[ -e "$1" ] && read -r "$2" <"$1"
}

main "$@"
