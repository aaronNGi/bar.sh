mod_format=${backlight_format:-%s}
mod_intervals=${backlight_update_interval:-1}:backlight
mod_functions="backlight backlight_trigger"
mod_variable=backlight

_bl_time=0
_bl_interval=${mod_intervals%:*}
_bl_path=${backlight_path:-/sys/class/backlight/intel_backlight}
_bl_pre=${backlight_prefix:-backlight:}
_bl_suffix=${backlight_suffix:- }

sysread "$_bl_path/max_brightness" _bl_max 

backlight() {
	if [ "$_bl_time" -le 0 ]; then
		backlight=
		return
	fi

	_bl_time=$((_bl_time - _bl_interval))
}

backlight_trigger() {
	_bl_time=$_bl_interval
	read -r _bl_brightness <"$_bl_path/brightness"
	sysread "$_bl_path/brightness" _bl_brightness 
	backlight="$_bl_pre$((_bl_brightness * 100 / _bl_max))%$_bl_suffix"
}
