mod_format=${wifi_format:- wifi:%s%% }
mod_intervals=${wifi_update_format:-4}:wifi
mod_functions=wifi
mod_variable=wifi

wifi() {
	if ! [ -e /proc/net/wireless ]; then
		wifi=
		return
	fi

	{
		# Consume first two lines.
		read -r _; read -r _
		IFS=". " read -r _ _ _link _
	} </proc/net/wireless

	wifi=$((_link * 100 / 70))
}
