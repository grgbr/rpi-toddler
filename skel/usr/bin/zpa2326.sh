#!/bin/sh -e

devname=zpa2326

# The base sysfs directory where IIO devices and triggers are located
base=/sys/bus/iio/devices

usage()
{
	echo "Usage: $(basename $0) [OPTIONS]"
	echo "where OPTIONS"
	echo "      -m MODE run in specified mode"
	echo "      -t MSEC sample with a MSEC millisecondes period"
	echo "      -h      this message"
	echo "where MODE"
	echo "      direct  direct sampling through sysfs"
	echo "      loop    tight loop triggered sampling"
	echo "      trigger hrtimer triggered sampling"
	echo "      buffer  software buffered sampling"
	exit $1
}

# Instantiate tight loop trigger and return its index in the global trigger
# space
trig_create_loop()
{
	local devno=$1
	local trigname="loop-dev$devno"
	local trigno

	mkdir -p /config/iio/triggers/loop/$trigname

	trigno=$(lsiio | sed -n \
	         "/^Trigger.*$trigname/s/Trigger \([0-9]\+\): $trigname/\1/p")
	trigno=$((trigno))

	echo $trigno
}

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

mode="direct"
msec=0
while getopts "m:t:h" opt; do
	case $opt in
	m)  mode=$OPTARG;;
	t)  msec=$OPTARG;;
	h)  usage "0";;
	\?) usage "1";;
	esac
done

# Disable buffered sampling first to allow sampling setup
echo 0 > $dev/buffer/enable
echo "" > $dev/trigger/current_trigger

# If available, select the system monotonic timestamping clock for dates
if test -f $dev/current_timestamp_clock; then
	echo monotonic > $dev/current_timestamp_clock
fi

if test "$mode" = "direct"; then
	press_scale=$(cat $dev/in_pressure_scale)
	temp_off=$(cat $dev/in_temp_offset)
	temp_scale=$(cat $dev/in_temp_scale)
	msec=$((msec / 1000))
	if test $msec -le 0; then
		echo "invalid period specified"
		exit 1
	fi
	while test 1; do
		awk "{ printf \"%f \", \$1 * $press_scale }" \
		    $dev/in_pressure_raw
		awk "{ printf \"%f\n\", (\$1 + $temp_off) * $temp_scale }" \
		    $dev/in_temp_raw
		sleep $msec
	done
elif test "$mode" =  "loop"; then
	exec iio_generic_buffer -a -N $devno -T $(trig_create_loop "$devno") \
	                        -l 2 -c -1
elif test "$mode" = "trigger"; then
	if test $msec -le 0; then
		echo "invalid period specified"
		exit 1
	fi
	exec iio_generic_buffer -a -N $devno \
	                        -T $(trig_create_hrtimer "$devno" "$((1000 / $msec))") \
	                        -l 2 -c -1
elif test "$mode" = "buffer"; then
	exec iio_generic_buffer -a -N $devno -g -l 2 -c -1
else
	echo "invalid mode specified"
	exit 1
fi

# Run an everlasting sampling process using the above trigger.
# -a enable all channels
# -N <IIO device id of barometer device>
# -T <IIO trigger id of barometer device>
# -l <kernel to user buffer depth in # of complete samples>
# -c <# of sampling loops before exit>
