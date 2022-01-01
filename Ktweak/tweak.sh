#!/bin/sh
# Written by Draco -- Edited for Nord N10 by Nylar357 (github.com/nylar357)

renice -n -18 -u root system wifi radio u0_a193
# terminal feedback
echo "renicing..."

# Maximum unsigned integer size in C
UINT_MAX="4294967295"

# Duration in nanoseconds of one scheduling period
SCHED_PERIOD="$((1 * 1000 * 1000))"

# How many tasks should we have at a maximum in one scheduling period
SCHED_TASKS="10"

write() {
	# Bail out if file does not exist
	[[ ! -f "$1" ]] && return 1

	# Make file writable in case it is not already
	chmod +w "$1" 2> /dev/null

	# Write the new value and bail if there's an error
	if ! echo "$2" > "$1" 2> /dev/null
	then
		echo "Failed: $1 → $2"
		return 1
	fi

	# Log the success
	echo "$1 → $2"
}

# Check for root permissions and bail if not granted
if [[ "$(id -u)" -ne 0 ]]
then
	echo "No root permissions. Exiting."
	exit 1
fi

# Detect if we are running on Android
grep -q android /proc/cmdline && ANDROID=true

# Log the date and time for records sake
echo "Time of execution: $(date)"
echo "Branch: master"

# Sync to data in the rare case a device crashes
sync

# We need to execute this multiple times because
# sched_downmirate must be less than sched_upmigrate, and
# sched_upmigrate must be greater than sched_downmigrate
[[ "$ANDROID" == true ]] && for _ in $(seq 2)
do
	# Migrate tasks down at this much load
	write /proc/sys/kernel/sched_downmigrate "80 80"
	write /proc/sys/kernel/sched_group_downmigrate 80

	# Migrate tasks up at this much load
	write /proc/sys/kernel/sched_upmigrate "80 80"
	write /proc/sys/kernel/sched_group_upmigrate 80
done

# Limit max perf event processing time to this much CPU usage
write /proc/sys/kernel/perf_cpu_time_max_percent 5

# Do not group task groups automatically
write /proc/sys/kernel/sched_autogroup_enabled 0

# Execute child process before parent after fork
write /proc/sys/kernel/sched_child_runs_first 1

# Preliminary requirement for the following values
write /proc/sys/kernel/sched_tunable_scaling 0

# Reduce the maximum scheduling period for lower latency
write /proc/sys/kernel/sched_latency_ns "$SCHED_PERIOD"

# Schedule this ratio of tasks in the guarenteed sched period
write /proc/sys/kernel/sched_min_granularity_ns "$((SCHED_PERIOD / SCHED_TASKS))"

# Require preeptive tasks to surpass half of a sched period in vmruntime
write /proc/sys/kernel/sched_wakeup_granularity_ns "$((SCHED_PERIOD / 2))"

# Reduce the frequency of task migrations
write /proc/sys/kernel/sched_migration_cost_ns 5000000

# Always allow sched boosting on top-app tasks
[[ "$ANDROID" == true ]] && write /proc/sys/kernel/sched_min_task_util_for_colocation 0

# Improve real time latencies by reducing the scheduler migration time
write /proc/sys/kernel/sched_nr_migrate 8

# Disable scheduler statistics to reduce overhead
write /proc/sys/kernel/sched_schedstats 0

# Disable unnecessary printk logging
write /proc/sys/kernel/printk_devkmsg off

# Start non-blocking writeback later
write /proc/sys/vm/dirty_background_ratio 10

# Start blocking writeback later
write /proc/sys/vm/dirty_ratio 30

# Require dirty memory to stay in memory for longer
write /proc/sys/vm/dirty_expire_centisecs 3000

# Run the dirty memory flusher threads less often
write /proc/sys/vm/dirty_writeback_centisecs 3000

# Disable read-ahead for swap devices
write /proc/sys/vm/page-cluster 0

# Update /proc/stat less often to reduce jitter
write /proc/sys/vm/stat_interval 10

# Swap to the swap device at a fair rate
write /proc/sys/vm/swappiness 60

# Allow more inodes and dentries to be cached
write /proc/sys/vm/vfs_cache_pressure 60

# Enable Explicit Congestion Control
write /proc/sys/net/ipv4/
_ecn 1

# Enable fast socket open for receiver and sender
write /proc/sys/net/ipv4/tcp_fastopen 3

# Disable SYN cookies
write /proc/sys/net/ipv4/tcp_syncookies 0

# leave it to ex kernel manager

# Always return success, even if the last write fails
exit 0
