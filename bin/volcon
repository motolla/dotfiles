#!/bin/sh
#
# Audio Output Switcher
l_output=$(pactl list sinks | grep Active | awk '{print $3}')
if [ "$l_output" = "analog-output-speaker" ]; then
    l_output="ﰝ Speaker"
elif [ "$l_output" = "analog-output-headphones" ]; then
    l_output=" Headphones"
else
    l_output="Unknown"
fi
choosen=$(echo "Now: $l_output\n Headphones\nﰝ Speakers\n" | dmenu -c -l 3 -n 1)
if [ "$choosen" = " Headphones" ]; then
    pactl set-sink-port @DEFAULT_SINK@ analog-output-headphones > /dev/null
elif [ "$choosen" = "ﰝ Speakers" ]; then
    pactl set-sink-port @DEFAULT_SINK@ analog-output-speaker > /dev/null
fi
