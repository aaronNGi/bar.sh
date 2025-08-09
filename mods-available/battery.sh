mod_format=${battery_format:- bat:%s }
mod_intervals="${battery_update_interval:-8}:battery 1:battery_blink"
mod_functions="battery battery_blink"
mod_variable=battery

# When the charge percentage of all batteries combined falls below this
# value, the battery status on the bar will blink.
battery_warn_threshold=${battery_warn_threshold:-10}

# The battery module will show an appended - for discharging batteries
# and a + for charging ones. The entire battery status will blink, when
# all batteries combined charge percentage drops below
# $battery_warn_threshold.
battery() {
	battery_val=
	_total_capacity=0

	for _bat in /sys/class/power_supply/BAT?; do
		! [ -e "$_bat" ] &&
			break

		read -r _status <"$_bat/status"
		read -r _capacity <"$_bat/capacity"

		_total_capacity=$((_total_capacity + _capacity))
		
		# Charging batteries will get a + appended, discharging
		# ones a -. Unused batteries get nothing.
		case $_status in
			Charging) _char=+ ;;
			Discharging) _char=- ;;
			*) _char= ;;
		esac

		battery_val=$battery_val${battery_val:+ }$_capacity%$_char
	done

	# Don't warn when we don't have any batteries or are still above
	# the threshold.
	if
		[ -z "$battery_val" ] ||
		[ "$_total_capacity" -gt "$battery_warn_threshold" ]
	then
		battery=$battery_val
		battery_warn=false
	else
		battery_warn=true
	fi
}

battery_blink() {
	"$battery_warn" || return

	# Alternate between a string of spaces and the battery value.
	case $battery in
		" "*) battery=$battery_val ;;
		*) battery=$(printf '%*s' "${#battery_val}" "") ;;
	esac
}
