#!/bin/sh -e

devname=icm20608

# The base sysfs directory where IIO devices and triggers are located
base=/sys/bus/iio/devices

# Return  Find corresponding trigger number
trig_get_hw()
{
	local devno=$1
	local devname=$2
	local trigname="devname-dev$devno"
	local trigno

	trigno=$(lsiio | sed -n \
	         "/^Trigger.*$trigname/s/Trigger \([0-9]\+\): $trigname/\1/p")
	echo $((trigno))
}

# Find IIO device number
devfilt="/^Device.*$devname/s/Device \([0-9]\+\): $devname/\1/ p"
devno=$(($(lsiio | sed -n "$devfilt")))
dev=$base/iio:device$devno

# Disable buffered sampling first to allow sampling setup
echo 0 > $dev/buffer/enable

# If available, select the system monotonic timestamping clock for dates
if test -f $dev/current_timestamp_clock; then
	echo monotonic > $dev/current_timestamp_clock
fi

# Setup sampling frequency to 500 Hz
echo 500 > $dev/sampling_frequency

# Run an everlasting sampling process using the default device's hardware
# trigger
# -a enable all channels
# -N <IIO device id of barometer device>
# -T <IIO trigger id of barometer device>
# -l <kernel to user buffer depth in # of complete samples>
# -c <# of sampling loops before exit>
iio_generic_buffer -a -N $devno -T $(trige_get_hw "$devno" "$devname") -l 2 \
                   -c -1
