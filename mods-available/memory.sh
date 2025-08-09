mod_format=${memory_format:- mem:%s%% }
mod_intervals=${memory_update_interval:-8}:memory
mod_functions="memory"
mod_variable=memory

memory() {
	_memtotal= _memavail=

	# Loop until $_memtotal and $_memavail are set. We want to
	# discard the third column so we split it into _.
	while read -r _name _val _; do
		case $_name in
			MemTotal:) _memtotal=$_val ;;
			MemAvailable:) _memavail=$_val ;;
		esac
		[ "$_memavail" ] && [ "$_memtotal" ] && break
	done </proc/meminfo

	memory=$((100 * (_memtotal - _memavail) / _memtotal))
}
