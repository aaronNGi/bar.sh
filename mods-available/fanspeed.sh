mod_format=${fan_format:-fan:%srpm}
mod_intervals=${fan_update_interval:-4}:fanspeed
mod_functions=fanspeed
mod_variable=fanspeed

fan_speed_path=${fan_speed_path:-/sys/devices/platform/thinkpad_hwmon/hwmon/hwmon5/fan1_input}

fanspeed() {
	if ! sysread "$fan_speed_path" fanspeed; then
		fanspeed=
	fi
}
