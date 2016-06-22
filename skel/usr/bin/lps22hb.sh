#!/bin/sh

devno=0
trigno=0

# The base sysfs directory where IIO devices and triggers are located
base=/sys/bus/iio/devices
dev=$base/iio:device$devno

# Disable buffered sampling first to allow sampling setup
echo 0 > $dev/buffer/enable

# Enable sampling channels: a complete sample will contain pressure, temperature
# and date.
echo 1 > $dev/scan_elements/in_pressure_en
echo 1 > $dev/scan_elements/in_temp_en
echo 1 > $dev/scan_elements/in_timestamp_en

# Setup sampling frequency to 75 Hz
echo 75 > $dev/sampling_frequency

# Run an everlasting sampling process using the default device's hardware
# trigger
# -N <IIO device id of barometer device>
# -T <IIO trigger id of barometer device>
# -l <kernel to user buffer depth in # of complete samples>
# -c <# of sampling loops before exit>
iio_generic_buffer -N devno -T trigno -l 2 -c -1
