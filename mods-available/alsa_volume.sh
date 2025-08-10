mod_format=${volume_format:-%s}
mod_intervals=${volume_update_interval:-1}:volume
mod_functions="volume volume_trigger"
mod_variable=volume

_vol_time=0
_vol_interval=${mod_intervals%:*}
_vol_pre=${volume_prefix:-vol:}
_vol_suffix=${volume_suffix:- }

volume() {
	if [ "$_vol_time" -le 0 ]; then
		volume=
		return
	fi

	_vol_time=$((_vol_time - _vol_interval))
}

volume_trigger() {
	_vol_time=$_vol_interval
	volume="$_vol_pre$(amixer sget Master | awk -F'[][]' '
		/%/ {
			print $(NF-1) == "off" ? "MM" : $2
		}'
	)$_vol_suffix"
}
