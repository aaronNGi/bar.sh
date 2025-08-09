mod_format=${cpu_temperature_format:- cpu:%sC }
mod_intervals=${cpu_temperature_update_interval:-4}:cputemp
mod_functions=cputemp
mod_variable=cputemp

cpu_temp_path=${cpu_temperature_path:-/sys/class/hwmon/hwmon0/temp1_input}

cputemp() {
	if sysread "$cpu_temp_path" cputemp; then
		cputemp=${cputemp%???}
	else
		cputemp=
	fi
}
