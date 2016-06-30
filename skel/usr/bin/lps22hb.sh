#!/bin/sh

devname=lps22hb

# The base sysfs directory where IIO devices and triggers are located
base=/sys/bus/iio/devices

# Instantiate hrtimer trigger and return its index in the global trigger space
trig_create_hrtimer()
{
	local devno=$1
	local hz=$2
	local trigname="hrtimer-dev$devno"
	local trigno

	mkdir -p /config/iio/triggers/hrtimer/$trigname

	trigno=$(lsiio | sed -n \
	         "/^Trigger.*$trigname/s/Trigger \([0-9]\+\): $trigname/\1/p")
	trigno=$((trigno))

	echo $hz > $base/trigger$trigno/sampling_frequency

	echo $trigno
}

# Find IIO device
devfilt="/^Device.*$devname/s/Device \([0-9]\+\): $devname/\1/ p"
devno=$(($(lsiio | sed -n "$devfilt")))
dev=$base/iio:device$devno

# Disable buffered sampling first to allow sampling setup
echo 0 > $dev/buffer/enable

# If available, select the system monotonic timestamping clock for dates
if test -f $dev/current_timestamp_clock; then
	echo monotonic > $dev/current_timestamp_clock
fi

# Run an everlasting sampling process using the above trigger.
# -a enable all channels
# -N <IIO device id of barometer device>
# -T <IIO trigger id of barometer device>
# -l <kernel to user buffer depth in # of complete samples>
# -c <# of sampling loops before exit>
iio_generic_buffer -a -N $devno -T $(trig_create_hrtimer "$devno" "75") -l 2 \
                   -c -1
