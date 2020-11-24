#!/bin/bash

# version 0.1

# This is a adapted script based on tur-antileech
# This script activates on a specific flag
# But can check for the presence of another flag to allow again

#--[ Settings ]---------------------------------------------------#

# set -x

LOG=/ftp-data/logs/antileech.log
FILEDATE=/bin/file_date
DATEBIN=""

## MUSIC
FLAG1_REQUIRE="K|N"
FLAG1_EXCEPTION="M"
FLAG1_WORKIN="\\/today-mp3\\/|\\/mp3\\/|\\/today-flac\\/|\\/flac\\/"
## ISO
FLAG2_REQUIRE="M|N"
FLAG2_EXCEPTION="K"
FLAG2_WORKIN="\\/apps\\/|\\/games\\/|\\/mdvdr\\/|\\/mvid\\/|\\/tv\\/|\\/tv-hd\\/|\\/x264-sd\\/"

IGNOREDIR="\\/pre\\/|\\/staff\\/"
#IGNOREFLAGS="1"
IGNOREFLAGS=""
IGNOREFILES="\\.nfo$|\\.txt$"
IGNOREGRP=TRUE

BLOCKTIME="30"
BLOCKMSG="This release is only %OLD% minutes old. You wont be able to leech it for another %LEFT% mins, leecher."

#--[ Script Start ]-----------------------------------------------#

filename="$(echo "$1" | cut -d ' ' -f2)"
curuser="$USER"

if [ -z "$DATEBIN" ]; then
  DATEBIN="date"
fi

## Is LOG enabled? Check if we can write to it.
if [ "$LOG" ]; then
  if [ ! -w "$LOG" ]; then
    echo "AntiLeech Error. LOG is defined as $LOG but I cant write to that file. Create it and set 766 perms on it."
    exit 1
  fi
fi

proc_log() {
  if [ "$LOG" ]; then
    echo "$($DATEBIN "+%a %b %e %T %Y") ${USER} - ${*}" >> $LOG
  fi
}
proc_log "1: $1, 2: $2, 3: $3, filename: $filename, pwd: $PWD"
if [ "${filename:0:1}" == "/" ] ; then
  WORKIN_PATH=$filename
else
  WORKIN_PATH=$PWD
fi
proc_log "WORKIN_PATH ${WORKIN_PATH}"

FLAG1_FOUND=0
## If WORKIN is set, check if we are in a dir we should run in.
if [ "$FLAG1_WORKIN" ] ; then
  if grep -q -E "$FLAG1_WORKIN" <<< "$WORKIN_PATH"; then
     FLAG1_FOUND=1
  fi
fi

FLAG2_FOUND=0
## If WORKIN is set, check if we are in a dir we should run in.
if [ "$FLAG2_WORKIN" ] ; then
  if grep -q -E "$FLAG2_WORKIN" <<< "$WORKIN_PATH"; then
     FLAG2_FOUND=1
  fi
fi

proc_log "FLAG1 - $FLAG1_FOUND, FLAG2 - $FLAG2_FOUND"

if [ "$FLAG1_FOUND" = "0" ] && [ "$FLAG2_FOUND" = "0" ] ; then
  proc_log "Not running in $WORKIN_PATH. Not in any WORKIN paths."
  exit 0
fi

if [ "$FLAG1_FOUND" = "1" ] ; then
  if ! grep -q -E "$FLAG1_REQUIRE" <<< "$FLAGS"; then
    proc_log "Not running in $WORKIN_PATH - $USER has flags $FLAGS and only $FLAG1_REQUIRE are checked - FLAG1."
    exit 0
  else
    if grep -q -E "$FLAG1_EXCEPTION" <<< "$FLAGS"; then
      proc_log "Not running in $WORKIN_PATH - $USER has flags $FLAGS, but was excluded based on $FLAG1_EXCEPTION - FLAG1."
      exit 0
    fi
  fi
fi


if [ "$FLAG2_FOUND" = "1" ] ; then
  if ! grep -q -E "$FLAG2_REQUIRE" <<< "$FLAGS"; then
    proc_log "Not running in $WORKIN_PATH - $USER has flags $FLAGS and only $FLAG2_REQUIRE are checked. - FLAG2"
    exit 0
  else
    if grep -q -E "$FLAG2_EXCEPTION" <<< "$FLAGS"; then
      proc_log "Not running in $WORKIN_PATH - $USER has flags $FLAGS, but was excluded based on $FLAG2_EXCEPTION. - FLAG2"
      exit 0
    fi
  fi
fi

## If BLOCKTIME is set, can we execute file_date ?
if [ "$BLOCKTIME" ]; then
  if [ ! -x "$FILEDATE" ]; then
    if [ ! -e "$FILEDATE" ]; then
      proc_log "Error. Can not find file_date in $FILEDATE - Allowing download."
      exit 0
    else
      proc_log "Error. Cant execute FILEDATE ($FILEDATE). Check perms on it - Allowing download."
      exit 0
    fi
  fi
fi

if [ "$IGNOREGRP" = "TRUE" ]; then
  if [ "$GROUP" ]; then
    # if [ "`echo "$WORKIN_PATH" | egrep "[-\_\.]$GROUP\/|[-\_\.]$GROUP$"`" ]; then
    if grep -q -E "[-\\_\\.]$GROUP\\/|[-\\_\\.]$GROUP$" <<< "${WORKIN_PATH}"; then
      proc_log "Not running in $WORKIN_PATH - $USER's primary group is $GROUP which matches release."
      exit 0
    fi
  fi
fi

## If IGNOREDIR is set, check if were in an ignored dir.
if [ "$IGNOREDIR" ]; then
  if grep -q -E "$IGNOREDIR" <<< "$WORKIN_PATH"; then
    proc_log "Not running in $WORKIN_PATH. Set as ignored dir in IGNOREDIR ($IGNOREDIR)."
    exit 0
  fi
fi

## Is IGNOREFILES set? If so, check if the file about to be downloaded is excluded.
if [ "$IGNOREFILES" ]; then
  if grep -q -E "$IGNOREFILES" <<< "$filename"; then
    proc_log "Not running on $filename. Excluded file in IGNOREFILES ($IGNOREFILES)."
    exit 0
  fi
fi

## Check if the user has an excluded flag.
if [ "$IGNOREFLAGS" ]; then
  if grep -q -E "${IGNOREFLAGS}" <<< "${FLAGS}"; then
    proc_log "Skipping check for user $curuser. He has excluded flag"
    exit 0
  fi
fi

## Procedure for calculating time difference.
proc_calctime() {
  MINDIFF=0

  ((DIFF=NOWTIMES-RELTIMES))
  if [ $DIFF -lt 0 ]; then
    ((DIFF=DIFF*-1))
  fi

  ((MINDIFF=DIFF/60))
}

proc_cookies() {
  if [ "$MINDIFF" ]; then
    # BLOCKMSG="$( echo "$BLOCKMSG" | sed -e "s/%OLD%/$MINDIFF/g" )"
    BLOCKMSG="${BLOCKMSG//%OLD%/${MINDIFF}}"
    LEFT=$((BLOCKTIME-MINDIFF))
  fi
  if [ "$LEFT" ]; then
    # BLOCKMSG="$( echo "$BLOCKMSG" | sed -e "s/%LEFT%/$LEFT/g" )"
    BLOCKMSG="${BLOCKMSG//%LEFT%/${LEFT}}"
  fi
}

RELTIME=$(${FILEDATE} "${WORKIN_PATH}")

RELTIMES=$($DATEBIN -d "$RELTIME" +%s)
NOWTIMES=$($DATEBIN +%s)

proc_calctime

## If the release isnt old enough yet...
if [ "$MINDIFF" -le "$BLOCKTIME" ]; then
  proc_cookies
  echo -e "553$BLOCKMSG"
  proc_log "Denying download of $filename in $WORKIN_PATH. Only $MINDIFF minutes old."
  exit 1
fi

if [ "$MINDIFF" ]; then
  proc_log "Allowing download of $filename in $WORKIN_PATH - $MINDIFF minutes old."
else
  proc_log "Allowing download of $filename in $WORKIN_PATH - All checks passed."
fi

exit 0
