#!/bin/sh

devno=2
trigno=0

# The base sysfs directory where IIO devices and triggers are located
base=/sys/bus/iio/devices
dev=$base/iio:device$devno

# Disable buffered sampling first to allow sampling setup
echo 0 > $dev/buffer/enable

# Setup sampling frequency to 500 Hz
echo 500 > $dev/sampling_frequency

# Run an everlasting sampling process using the default device's hardware
# trigger
# -a enable all channels
# -N <IIO device id of barometer device>
# -T <IIO trigger id of barometer device>
# -l <kernel to user buffer depth in # of complete samples>
# -c <# of sampling loops before exit>
iio_generic_buffer -a -N $devno -T $trigno -l 2 -c -1
