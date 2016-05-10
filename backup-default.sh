#!/bin/sh

# Backup script for this server.
#
# Backups are stored in /backups/year/month/day/sd[ab].tar.gz
#
# For example, for backup on 07/31/2042 on both sda & sdb, the files will be:
# /backups/2011/07/31/sda.tar.gz
# /backups/2011/07/31/sdb.tar.gz
#
# Script also checks if we are on a new month.  If so, backs up previous month's backups to (then deletes old month's backup folder):
# /backup/year/month.tar.gz
#
# Backups are done via DRIVE & BACKUP arrays.  SDAEX is an array specific to /dev/sda, due to extensive excludes needed
#
# All output is directed to an external file.  At the end of this function, an e-mail is sent to:
# backups@IP
#
# This e-mail contains all the output this would give normally on the stderr/stdout.
#
# Last modified: 08/31/2011

# Day of the month
DAY=`date +%d`

# Month of the year
MONTH=`date +%m`

YEAR=`date +%Y`

# Month for new month check (save alway two new backups
NewMONTH=`date -d 'now - 15 days' +%m`

# Backup directory to use (2011/08/31 for 08.31.2011)
BKDIR="/backups/$YEAR/$MONTH/$DAY"

# make directories if they are not exists
if [ ! -d "$BKDIR" ]; then
	mkdir -p $BKDIR
fi

# Backup log file
BKLOG="/backups/$YEAR/$MONTH/$DAY.log"

# Array position (default to 0 always)
ARRPOS=0

# What drives to backup (will be name of .tar.gz file)
DRIVE=('Backups')

# What to back up for each of the drives
BACKUP=('/backups/' )

# What to exclude
SDAEX=('./$YEAR/')

# Make sure file is generated
touch $BKLOG

# Since we send this through e-mail, start the e-mail stuff
To="backups@example.org"
#From="Backups <backups@example.org>"
Sbject="Generated backup report for `hostname` on $YEAR.$MONTH.$DAY"

echo "To: $To" > $BKLOG
echo "From: $From" >> $BKLOG
echo -e "Subject: $Sbject\n" >> $BKLOG

#Start log file
echo -e ">> Backup for: $YEAR.$MONTH.$DAY started @ `date +%H:%M:%S`\n" >> $BKLOG

# Checks to see if month is same as 8 day's ago (new month check), and if so, backs up the last month's backups
#if [ "$DAY" == "01" ]; then
if [ ! $MONTH == $NewMONTH ]; then
	M=`echo -n $MONTH | awk '{printf substr($1,2)}'`
	let OLD=$M-1

	echo "- New month detected." >> $BKLOG
        echo "  - New month: $MONTH | Old month:$NewMONTH" >> $BKLOG
	echo "   + Remove dir on Pi: /backups/$YEAR/$OLD" >> $BKLOG

	rm -rf /backups/$YEAR/$OLD

	if [ ! -d "/backups/$YEAR/$OLD" ]; then
		echo "    = /backups/$YEAR/$OLD was deleted from pi." >> $BKLOG
	else
		echo "    = /backups/$YEAR/$OLD was not deleted from pi." >> $BKLOG
	fi

	echo "   + Remove dir on Dropbox: /backups/$YEAR/$OLD" >> $BKLOG

        dlt=$( { /Dropbox-Uploader/dropbox_uploader.sh delete $BKDIR/$YEAR/$OLD; } 2>&1 )
        dltCheck=$( { echo "${dlt##*... }"; } 2>&1 )
        if [ $dltCheck == "DONE" ]; then
                echo "    = /backups/$YEAR/$OLD was deleted from Dropbox." >> $BKLOG
        else
                echo "    = /backups/$YEAR/$OLD was not deleted from Dropbox." >> $BKLOG
        fi

else
	echo "- $MONTH == $NewMONTH > there is no new month detected.\n" >> $BKLOG
fi

# If directory don't exist, make it...(kind of pointless to keep, but hey)
if [ ! -d "$BKDIR" ]; then
	echo "- Creating new backup directory..." >> $BKLOG
	echo "    + Directory: $BKDIR" >> $BKLOG
	SD=$( { time mkdir -p "$BKDIR"; } 2>&1 )
	SD=`echo -n "$SD" | grep real`
	MIN=`echo -n "$SD" | awk '{printf substr($2,0,2)}'`
	SEC=`echo -n "$SD" | awk '{printf substr($2,3)}'`
	echo -e "- done [ $MIN SEC ].\n" >> $BKLOG
fi

# Cycle through each drive and back up each
for d in "${DRIVE[@]}"; do
	echo "- Backing up drive $d" >> $BKLOG

	# By default, at least don't backup lost+found directories
	EX="--exclude=lost+found"

	# If we are backing up drive 1 (/dev/sda), there's to exclude
	if [ $d == "mmc" ]; then
		for e in "${SDAEX[@]}"; do
			EX="`echo -n $EX` --exclude=$e"

		done
	fi
	 echo "- exclude: $EX" >> $BKLOG

        # Following directories are included
        for f in "${BACKUP[@]}"; do
	        IN="`echo -n $IN` $f"
        done
         echo "- included: $IN" >> $BKLOG


	# Do the magic work and display some cool info
#	SD=$( { time tar -cpPzf $BKDIR/$d.tar.gz $EX ${BACKUP[$ARRPOS]}; } 2>&1 )
	SD=$( { time tar -cpPzf $BKDIR/$d.tar.gz $EX $IN; } 2>&1 )
#echo "$SD after execution"
	SD=`echo -n "$SD" | grep real`
#echo "$SD after grep"
	MIN=`echo -n "$SD" | awk '{printf substr($2,0,2)}'`
	SEC=`echo -n "$SD" | awk '{printf substr($2,3)}'`

	SD=$(ls -liha $BKDIR/$d.tar.gz)
	SIZE=`echo -n $SD | awk '{printf $6}'`

	echo "- File size: $SIZE" >> $BKLOG
	echo -e "- Finished in $MIN $SEC\n" >> $BKLOG

	#Upload file to dropbox
	SD=$( { time /Dropbox-Uploader/dropbox_uploader.sh upload $BKDIR/$d.tar.gz $BKDIR/$d.tar.gz; } 2>&1 )
	SD=`echo -n "$SD" | grep real `
	UMIN=`echo -n "$SD" | awk '{printf substr($2,0,2)}'`
	USEC=`echo -n "$SD" | awk '{printf substr($2,3)}'`

	echo -e "- Uploaded file to Dropbox in $UMIN $USEC\n" >> $BKLOG

#	let ARRPOS++
done

echo -e "Directory stats:\n`ls -liha $BKDIR`\n" >> $BKLOG

echo -e "!! Backup log file can be located at $BKLOG\n" >> $BKLOG

echo ">> Backup for: $YEAR.$MONTH.$DAY finished @ `date +%H:%M:%S`" >> $BKLOG

# Mail this script out...ssmtp for GMail accounts, otherwise change for appropriate MTA
# /usr/sbin/ssmtp -t < $BKLOG
mutt -s "$Sbject" $To < $BKLOG
