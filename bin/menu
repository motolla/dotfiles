#!/bin/bash
#
simple=$(echo -e "Movies\nMusic\nProject" | dmenu -c -i -l 3)
# Simple Config
movie_dir="/media/void/Movies/"
music_dir="/media/void/Music/"
project_dir="$HOME/Project/"

case $simple in
  Movies)exa "$movie_dir" | dmenu -c -l 12 | xargs -r -I {} mpv "$movie_dir"'{}' > /dev/null ;;
  Music) exa "$music_dir" | dmenu -c -l 12 | xargs -r -I {} mpv "$music_dir"'{}' > /dev/null ;;
  Project) exa "$project_dir" | dmenu -c -l 6 | xargs -r -I {} st -e nvim "$project_dir"'{}' ;;
esac


