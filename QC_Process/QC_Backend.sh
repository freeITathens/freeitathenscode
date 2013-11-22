#/bin/bash
set -u

type dialog &>/dev/null || {
  echo "The 'dialog' program must be installed for the QC script to work, but it is not.";
  exit 1;
}

if test -z "$DISPLAY"
then export DISPLAY=:0
fi


#create log file
rm QC.log* 2> /dev/null
touch QC.log

# volunteers will return any CDs in the drive to the refurb room
eject /dev/sr0

#optical drives
QCVAR=$(ls /sys/block/ | grep sr | wc -l)
if test $QCVAR -eq 1
then echo "PASSED  : CD/DVD drive test" >> QC.log
elif test $QCVAR -gt 1
then echo "PROBLEM : CD/DVD drive test. Too many optical drives exist!" >> QC.log
elif test $QCVAR -lt 1
then echo "PROBLEM : CD/DVD drive test. Add an optical drive!" >> QC.log
fi

#hdd
QCVAR=$(ls /sys/block/ | grep sd[a-z] | wc -l)
if test $QCVAR -eq 1
then echo "PASSED  : Hard drive test." >> QC.log
elif test $QCVAR -gt 1
then echo "WARNING : Hard drive test. Check that there is only one hard drive." >> QC.log
elif test $QCVAR -lt 1
then echo "PROBLEM : Hard drive test. Something went wrong with the test!" >> QC.log
fi

#network
QCVAR=$(ls /sys/class/net | grep eth | wc -l)
if test $QCVAR -lt 1
then echo "PROBLEM : Network card test. There is no network card!" >> QC.log
elif test $QCVAR -gt 1
then echo "PROBLEM : Network card test. There are too many network cards!" >> QC.log
else
echo "PASSED  : Network card test." >> QC.log
fi

#modem detection
QCVAR=$(lspci | grep -i Modem | wc -l)
if test $QCVAR -ge 1
then echo "PROBLEM : Modem test. Remove a modem from the computer!" >> QC.log
else echo "PASSED  : Modem test." >> QC.log
fi

#sound
QCVAR=$(ls /sys/class/sound/ | grep card | wc -l)
if test $QCVAR -lt 1
then echo "PROBLEM : Sound card test. There is no sound card!" >> QC.log
elif test $QCVAR -gt 1
then echo "WARNING : Sound card test. Check that there is only one sound card." >> QC.log
else
echo "PASSED  : Sound card test." >> QC.log
fi

#video
QCVAR=$(ls /sys/class/graphics/ | grep fb[0-9] | wc -l)
if test $QCVAR -lt 1
then echo "PROBLEM : Video card test. Something went wrong with the test!" >> QC.log
elif test $QCVAR -gt 1
then echo "PROBLEM : Video card test. There are too many video cards in the computer!" >> QC.log
else
echo "PASSED  : Video card test." >> QC.log
fi

#resolution
QCVAR=$(xrandr | grep '1024x768')
if test -z "$QCVAR"
then echo "PROBLEM : Video resolution test. Resolution must be at least 1024x768!" >> QC.log
else
echo "PASSED  : Video resolution test." >> QC.log
fi

#usb
QCVAR=$(ls /sys/bus/usb/devices | wc -l)
if test $QCVAR -lt 1
then echo "PROBLEM : USB port test. There are no USB ports!" >> QC.log
else
echo "PASSED  : USB port test." >> QC.log
fi

#users
QCVAR=$(ls /home | wc -l)
if test $QCVAR -lt 1
then echo "PROBLEM : User count. Something is wrong with this test!" >> QC.log
elif test $QCVAR -gt 1
then echo "PROBLEM : User count. There is more than one user account!" >> QC.log
else
echo "PASSED  : User count test." >> QC.log
fi

#edubuntu
QCVAR=$(dpkg --list 'ubuntu-edu*' | grep ii | wc -l)
if test $QCVAR -lt 4
then echo "PROBLEM : Edubuntu. Install educational software!" >> QC.log
elif test $QCVAR -gt 4
then echo "PROBLEM : Edubuntu. Something is wrong with this test!" >> QC.log
else
echo "PASSED  : Edubuntu test." >> QC.log
fi

#restricted extras
QCVAR=$(dpkg --list 'ubuntu-restricted-extras' | grep ii | wc -l)
if test $QCVAR -ne 1
then echo "PROBLEM : Restricted extras test. Install restricted extras!" >> QC.log
else echo "PASSED  : Restricted extras test." >> QC.log
fi

#CPU speed
QCVAR=$(awk '/MHz/ {print $4; exit}' /proc/cpuinfo)
LEN=$(expr match $QCVAR '[0-9]*')
QCVAR=${QCVAR:0:$LEN}
if test $QCVAR -lt 650
then echo "PROBLEM : CPU clockspeed test. Recycle this computer!" >> QC.log
else
    echo "PASSED  : CPU clockspeed test." >> QC.log
fi

PROCESSORS=$(grep 'physical id' /proc/cpuinfo | sort -u | wc -l)
CORES=$(grep 'core id' /proc/cpuinfo | sort -u | wc -l)

if test $PROCESSORS -gt 1 -o $CORES -gt 1
then
    FS_LOW_VALUE=70000
    FS_HIGH_VALUE=1000000
    FS_TEXT="80GB to 1TB"
    # up to 128MB of shared memory for video
    RAM_LOW_VALUE=$(expr 1920 \* 1024)
    RAM_HIGH_VALUE=$(expr 2048 \* 1024)
    RAM_TEXT="2048MB"
else
    FS_LOW_VALUE=5001
    FS_HIGH_VALUE=80000
    FS_TEXT="10 to 80GB"
    # up to 32MB of shared memory for video
    RAM_LOW_VALUE=$(expr 480 \* 1024)
    RAM_HIGH_VALUE=$(expr 512 \* 1024)
    RAM_TEXT="512MB"
fi

#filesystem size
QCVAR=$(df -m / | awk '/dev/ {print $4}')
if test $QCVAR -lt "$FS_LOW_VALUE" -o $QCVAR -gt "$FS_HIGH_VALUE"
then echo "PROBLEM : Free space test. Hard drive should be $FS_TEXT." >> QC.log
else echo "PASSED  : Free space test." >> QC.log
fi

#RAM
QCVAR=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if test $QCVAR -lt $RAM_LOW_VALUE
then echo "PROBLEM : Memory test. Add more so you have $RAM_TEXT." >> QC.log
elif test $QCVAR -gt $RAM_HIGH_VALUE
then echo "WARNING : Memory test. Remove some so you have $RAM_TEXT." >> QC.log
else
echo "PASSED  : Memory test." >> QC.log
fi

# this file will exist if the user is running the QC script
# again after it hung during the 3D test
if [ -e ~/Desktop/3D_Test_Started ]
then
    echo "PROBLEM  : 3D stability test. Replace video card or disable 3D" >> QC.log
else
    echo "10 second long 3D test started" | tee ~/Desktop/3D_Test_Started
    # run a 3D screensaver in a window for 10 seconds then stop it
    /usr/lib/xscreensaver/antspotlight -window &
    PID=$!
    sleep 10
    kill $PID
    # if the computer doesnt hang, it passes
    rm  ~/Desktop/3D_Test_Started
    echo "PASSED  : 3D stability test." >> QC.log
fi

# sort to make problems more visible
sort -r QC.log > QC.sorted.log

#output log to dialog box for ease of reading
dialog --title "Free IT Athens Quality Control Test Results" --textbox QC.sorted.log 17 80
clear
