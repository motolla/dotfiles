#!/bin/sh

if [ -d /etc/X11/xinit/xinitrc.d ]; then
    for f in /etc/X11/xinit/xinitrc.d/*; do
        [ -x "$f" ] && . "$f"
    done
    unset f
fi

if test -z "$DBUS_SESSION_BUS_ADDRESS" ; then
    # if not found, launch a new one
    eval `dbus-launch --sh-syntax --exit-with-session`
    echo "D-Bus per-session daemon address is: $DBUS_SESSION_BUS_ADDRESS"
fi


# cursor
xsetroot -cursor_name left_ptr

# audio
pipewire &
pipewire-pulse &

# status bar
slstatus &

# compositor
picom --experimental-backends &

# background
feh --bg-fill /media/void/dot/wall/gruvlinux.png &

exec dbus-run-session dwm
