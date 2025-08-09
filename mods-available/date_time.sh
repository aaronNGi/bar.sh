mod_format=${date_format:- %s }
mod_intervals=${date_update_interval:-60}:date_time
mod_functions=date_time
mod_variable=date

date_time() {
	date=$(date +"${date_display_format:-%a-%d %H:%M}")
}
