#!/bin/sh
# Author: Marguerite Su <i@marguerite.su>, dzmanto <dzmanto@hotmail.com>
# License: GPL-3.0
# Description: Download Bing Wallpaper of the Day and set it as your Linux Desktop.
# https://github.com/marguerite/linux-bing-wallpaper

# global options

# $bing is needed to form the fully qualified URL for
# the Bing pic of the day
bing="www.bing.com"

# The idx parameter determines where to start from. 0 is the current day,
# 1 the previous day, etc.
idx="0"

# $xmlURL is needed to get the xml data from which
# the relative URL for the Bing pic of the day is extracted
xmlURL="http://www.bing.com/HPImageArchive.aspx?format=xml&idx=$idx&n=1&mkt=$mkt"

# Set picture options
# Valid options are: none,wallpaper,centered,scaled,stretched,zoom,spanned
picOpts="stretched"

# The file extension for the Bing pic
picExt=".jpg"

contains() {
    local value=$(eval "echo \$$#")
    count=1
    for i in $*
    do
        if [ "$i" = "$value" -a $count -lt $# ]; then
            echo "y"
            return 0
        fi
 	count=$(expr $count + 1)
    done
    echo "n"
    return 1
}


checkdep() {
	tool=$(which $1)
	if [ ! -x "$tool" ]; then
		echo "Linux-bing-wallpaper depends on $1."
		echo "Install $1, please."
		echo "Exit."
		exit 1
	fi
}

ctfn () {
	tfnns=$(mktemp /tmp/bing_wallpaper_XXXXXX)
	tfn="$tfnns$picExt"
	mv "$tfnns" "$tfn"
	echo "$tfn"
}

detectDE() {
    # see https://bugs.freedesktop.org/show_bug.cgi?id=34164
    unset GREP_OPTIONS

    uname -a | grep -i darwin 2>&1 >/dev/null && DE="mac";

    if [ -n "${XDG_CURRENT_DESKTOP}" ]; then
      case "${XDG_CURRENT_DESKTOP}" in
         'GNOME')
           DE="gnome"
           ;;
         'KDE')
           DE="kde"
           ;;
         'LXDE')
           DE="lxde"
           ;;
         'LXQt')
           DE="lxqt"
           ;;
         'MATE')
           DE="mate"
           ;;
         'XFCE')
           DE="xfce"
           ;;
         'X-Cinnamon')
           DE="cinnamon"
           ;; 
      esac
    fi

    if [ x"$DE" = x"" ]; then
      # classic fallbacks
      if [ x"$KDE_FULL_SESSION" = x"true" ]; then DE="kde";
      elif [ x"$GNOME_DESKTOP_SESSION_ID" != x"" ]; then DE="gnome";
      elif [ x"$MATE_DESKTOP_SESSION_ID" != x"" ]; then DE="mate";
      elif `dbus-send --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.GetNameOwner string:org.gnome.SessionManager > /dev/null 2>&1` ; then DE="gnome";
      elif xprop -root _DT_SAVE_MODE 2> /dev/null | grep ' = \"xfce4\"$' >/dev/null 2>&1; then DE="xfce";
      elif xprop -root 2> /dev/null | grep -i '^xfce_desktop_window' >/dev/null 2>&1; then DE="xfce";
      fi
    fi

    if [ x"$DE" = x"" ]; then
      # fallback to checking $DESKTOP_SESSION
     case "$DESKTOP_SESSION" in
         'gnome')
           DE="gnome"
           ;;
         'LXDE'|'Lubuntu')
           DE="lxde"
           ;;
         'MATE')
           DE="mate"
           ;;
         'xfce'|'xfce4'|'Xfce Session')
           DE="xfce"
           ;;
      esac
    fi

    if [ x"$DE" = x"gnome" ]; then
      # gnome-default-applications-properties is only available in GNOME 2.x
      # but not in GNOME 3.x
      which gnome-default-applications-properties > /dev/null 2>&1  || DE="gnome3"
    fi
    
    echo $DE
}

checkdep "curl"
checkdep "egrep"

if [ $# -eq 0 ]; then
  # The mkt parameter determines which Bing market you would like to
  # obtain your images from.

  mkt="zh-CN"
  # Try and guess language
  ML=$(echo $LANG | cut -f 1 -d .)
  case $ML in
	'en_US')
	mkt="en-US"
	;;
	'zh_CN')
	mkt="zh-CN"
	;;
	'ja_JP')
	mkt="ja-JP"
	;;
	'en_AU')
	mkt="en-AU"
	;;
	'en_UK')
	mkt="en-UK"
	;;
	'de_CH')
	mkt="de-DE"
	;;
	'de_DE')
	mkt="de-DE"
	;;
	'en_NZ')
	mkt="en-NZ"
	;;
	'en_CA')
	mkt="en-CA"
	;;
  esac
  exitAfterRunning=false

elif [ $# -eq 2 ]; then
  list="de-DE en-AU en-CA en-NZ en-UK en-US ja-JP zh-CN"
  # Valid values are:
  firstpar="$1"
  #inhibit code injection
  firstpar=$(echo "$firstpar" | sed s/[^a-zA-Z-]// )
  if [ "$(contains $list $firstpar)" = "y" ]; then
    mkt=$firstpar
  else
    echo "mkt must be one of the following:"
    printf '%s\n' "$list"
    exit 1
  fi

  if [ "$2" = true ]; then
    exitAfterRunning=true
  else
    exitAfterRunning=false
  fi

else
  echo "Usage: `basename $0` mkt[en-US,zh-CN,ja-JP,en-AU,en-UK,de-DE,en-NZ,en-CA] exitAfterRunning[true,false]"
  exit 1
fi

# Download the highest resolution
while true; do

    picName=""
    picURL=""
    
    for picRes in _1920x1200 _1366x768 _1280x720 _1024x768; do

	# Extract the relative URL of the Bing pic of the day from
	# the XML data retrieved from xmlURL, form the fully qualified
	# URL for the pic of the day, and store it in $picURL
	picURL=$bing$(echo $(curl -H "Content-Type: text/html; charset=UTF-8" -L -s $xmlURL) | egrep -o "<urlBase>(.*)</urlBase>" | cut -d ">" -f 2 | cut -d "<" -f 1)$picRes$picExt


	# set target filename
	tfn=$(ctfn)

	# Download the Bing pic of the day
	curl -H "Content-Type: text/html; charset=UTF-8" -s -o "$tfn" -L "$picURL"

	# Test if download was successful.
	downloadResult=$?
	if [ $downloadResult -ge 1 ]; then
	rm -f "$tfn" && continue
	elif [ ! -s "$tfn" ]; then
	rm -f "$tfn" && continue   
	fi

	if [ -x "/usr/bin/convert" -a -x "/usr/bin/mogrify" ]; then
	title=$(echo $(curl -H "Content-Type: text/html; charset=UTF-8" -L -s $xmlURL) | egrep -o "<copyright>(.*)</copyright>" | cut -d ">" -f 2 | cut -d "<" -f 1 )
	convert "$tfn" -resize 1920x1200 "$tfn"
	convert -background "#00000080" -fill white -gravity center -size 1024 -font "Droid Sans" -pointsize 22 caption:"${title}" "$tfn" +swap -gravity south -composite "$tfn"
	fi
	# Test if it's a pic
	file --mime-type -b "$tfn" | grep "^image/" > /dev/null && break

	rm -f "$tfn"
    done

    if [ $downloadResult -ge 1 ]; then
          echo "Failed to download any picture."
	  echo "Try again in 60 seconds."
          sleep 60
          continue
    fi

    DE=$(detectDE)

    if [ "$DE" = "cinnamon" ]; then
          # Set the Cinnamon wallpaper
          DISPLAY=:0 GSETTINGS_BACKEND=dconf gsettings set org.cinnamon.desktop.background picture-uri '"file://'$tfn'"'

          # Set the Cinnamon wallpaper picture options
          DISPLAY=:0 GSETTINGS_BACKEND=dconf gsettings set org.cinnamon.desktop.background picture-options $picOpts
    elif [ "$DE" = "gnome" ]; then
	checkdep "gconftool"
	# Set the GNOME 2 wallpaper
	gconftool-2 -s -t string /desktop/gnome/background/picture_filename "$tfn"
	
	# Set the GNOME 2 wallpaper picture options
	gconftool-2 -s -t string /desktop/gnome/background/picture_options "$picOpts"
    elif [ "$DE" = "gnome3" ]; then
	checkdep "gsettings"
	# Set the GNOME3 wallpaper
	DISPLAY=:0 GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.background picture-uri '"file://'$tfn'"'

	# Set the GNOME 3 wallpaper picture options
	DISPLAY=:0 GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.background picture-options $picOpts
	gsettings set org.gnome.desktop.background picture-uri '"file://'$tfn'"'
    elif [ "$DE" = "kde" ]; then
	checkdep "xdotool"
	checkdep "gettext"
	LOCALE=$(echo $LANG | sed 's/\..*$//')

	EN_CONSOLE1="Desktop Shell Scripting Console"
	EN_CONSOLE2="Plasma Desktop Shell"

	if [ -n $LOCALE ]; then
		JS_CONSOLE1=$(LANGUAGE=$LOCALE gettext -d plasma-desktop -s "$EN_CONSOLE1")
		JS_CONSOLE2=$(LANGUAGE=$LOCALE gettext -d plasma-desktop -s "$EN_CONSOLE2")
		JS_CONSOLE="$JS_CONSOLE1 – $JS_CONSOLE2"
	else
		JS_CONSOLE="$EN_CONSOLE1 – $EN_CONSOLE2"
	fi

	js=$(mktemp)
	cat << _EOF > $js
var wallpaper = "$tfn";
var activity = activities()[0];
activity.currentConfigGroup = new Array("Wallpaper", "image");
activity.writeConfig("wallpaper", wallpaper);
activity.writeConfig("userswallpaper", wallpaper);
activity.reloadConfig();
_EOF
	qdbus org.kde.plasma-desktop /App local.PlasmaApp.loadScriptInInteractiveConsole "$js" > /dev/null
	xdotool search --name "$JS_CONSOLE" windowactivate key ctrl+e key ctrl+w
	rm -f "$js"

    elif [ "$DE" = "lxqt" ] ; then
      pcmanfm-qt -w "$tfn"
    elif [ "$DE" = "mac" ]; then
	# set target filename 4 mac
	tfnnew=$(ctfn)
	
	mv $tfn $tfnnew
	rm -f $tfnold

	osascript -e 'tell application "Finder" to set desktop picture to POSIX file "'"$tfnnew"'"'
	osafirstResult=$?
	osascript -e 'tell application "System Events" to set picture of every desktop to "'"$tfnnew"'"'
	osasecondResult=$?
	sqlite3 ~/Library/Application\ Support/Dock/desktoppicture.db "update data set value = '$tfnnew'" 2>&1 >/dev/null
	sqliteResult=$?

	tfnold=$tfnnew
    elif [ "$DE" = "mate" ]; then
      checkdep "dconf"
      dconf write /org/mate/desktop/background/picture-filename '"'$tfn'"'
    elif [ "$DE" = "xfce" ]; then
	checkdep "xfconf-query"
	# set to every monitor that contains image-path/last-image
	properties=$(xfconf-query -c xfce4-desktop -p /backdrop -l | grep -e "screen.*/monitor.*image-path$" -e "screen.*/monitor.*/last-image$")

	for property in $properties; do
		xfconf-query -c xfce4-desktop -p $property -s "$tfn"
	done
    fi

    if [ "$exitAfterRunning" = true ] ; then
      # Exit the script
      exit 0
    fi

    # sleep for half a day
    DIFF_TIME=0
    LAST_RUN=$(date +%s)
    LAST_DAY=$(date +%A)
    LAST_HOUR=$(date +%I)
    while [ $DIFF_TIME -lt 43199 ]; do
	NOW=$(date +%s)
	DIFF_TIME=$(expr $NOW - $LAST_RUN)
	sleep 60
    done
done 
