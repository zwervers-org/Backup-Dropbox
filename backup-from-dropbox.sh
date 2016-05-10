#!/bin/bash

# Backup script for camera upload of Dropbox.
#
# Script stores the pictures on the NAS and deletes the pictures older as Remove-date
#
#
# All output is directed to an external file.  At the end of this function, an e-mail is sent to:
# backups@IP
#
# This e-mail contains all the output this would give normally on the stderr/stdout.
#
# Last modified: 12-04-2016

# Day of the month
DAY=`date +%d`

# Month of the year
MONTH=`date +%m`

YEAR=`date +%Y`

# Month for new month check (save alway two new backups
RDATE=`date -d 'now - 31 days' +%m`

# Backup directory to download files in (2011/08/31 for 08.31.2011)
#BKDIR="/mnt/WD_public/Shared\ Pictures/"
BKDIR="/mnt/photo/test/"

# Directories in Dropbox with the files to backup (Photo) and the directory to tempory backup
#DBPHOTODIR="'Camera Uploads'"
DBPHOTODIR="Test download"
DBBKDIR="Photo Backup"

# Backup log file
BKLOG="/backups/$YEAR/$MONTH/"

#Set error counter to 0
ECOUNT=0

#DIRARR=($BKDIR, $BKLOG, $MapContent)
mkdir -p $BKLOG
mkdir -p $BKDIR

# File for saving DB list of files in map
MapContent=$BKLOG"$DAY.info"

# Make log file
BKLOG=$BKLOG"$DAY.log"

# Since we send this through e-mail, start the e-mail stuff
TO="root@zwerver.org"
FROM="Backups <backups@zwerver.org>"
SBJECT="Generated backup report Camera Upload DropBox on $YEAR.$MONTH.$DAY"


#----------------NO CHANGES BELOW NEEDED----------------
# Make sure files are generated
touch $BKLOG
touch $MapContent

#Start log file
echo "To: $TO" > $BKLOG
echo "From: $FROM" >> $BKLOG
echo "Subject: $SBJECT\n" >> $BKLOG

echo ">> Backup for: $YEAR.$MONTH.$DAY started @ `date +%H:%M:%S`\n" >> $BKLOG

# Put pictures per year in right tempory backup directory in Dropbox
 a= echo `/Dropbox-Uploader/dropbox_uploader.sh list "$DBPHOTODIR" >> $MapContent`
   #Check for error
   ERROR=`echo -n "$a" | regex \.\.\.\s+FAILED`
   if [ $ERROR ]; then
      EINFO[$ECOUNT]=`echo $(head -n 1 $a)`
      echo "->> Error: ${EINFO[$ECOUNT]}D\n" >> $BKLOG
      ECOUNT=$((ECOUNT+1))
   fi

 COUNTFILES=`wc -l < $MapContent`
  echo "Dropbox files in list : $COUNTFILES\n" >> $BKLOG

#set startrow and counter for reading filename data
COUNTER=1
SROW=2

if [ $COUNTFILES -gt 1 ] ; then
#read file name data into array
  while IFS='' read LINE || [[ -n "$LINE" ]]; do
   if [ $COUNTER -ge $SROW ]; then
        FNAME[$COUNTER]=`echo $LINE | awk '{printf $3" "$4}'`
        FDATE[$COUNTER]=`echo $LINE | awk '{printf $3}'`
        echo "Save info for ${FNAME[$COUNTER]} with date: ${FDATE[$COUNTER]}\n" >> $BKLOG
   fi

   COUNTER=$((COUNTER+1))

  done < $MapContent
fi

#use filename data from array to copy files to temp directory
COUNTER=$SROW

for DBFILE in "${FNAME[@]}"; do
   #Get month from filedate
   FYEAR=`echo "${FDATE[$COUNTER]}" | awk '{printf substr($1,0,5)}'`

   #Move file to other dropbox folder for backup
   SD=$( { time /Dropbox-Uploader/dropbox_uploader.sh copy "$DBPHOTODIR/$DBFILE" "$DBBKDIR/$FYEAR/$DBFILE" ; } 2>&1 )

   #Check for error
   ERROR=`echo -n "$SD" | \.\.\.\ FAILED`
   if [ n "$SD" | \.\.\.\ FAILED` ]; then
	EINFO[$ECOUNT]=`echo $SD`
	echo "- File $DBFILE has given an error\n" >> $BKLOG
        echo "-- Error: ${EINFO[$ECOUNT]}D\n" >> $BKLOG
        ECOUNT=$((ECOUNT+1))
   fi

   #Extract time info
   SD=`echo -n "$SD" | grep real `
   DMIN=`echo -n "$SD" | awk '{printf substr($2,0,2)}'`
   DSEC=`echo -n "$SD" | awk '{printf substr($2,3)}'`

   echo "- File $DBFILE copied in $DMIN $DSEC to $DBBKDIR/$YEAR\n" >> $BKLOG

   COUNTER=$((COUNTER+1))
done

#stop the running script to debug first part
#exit 1

#remove MapContent file = not needed
echo -e "Remove map content file $MapContent for directory: $DBPHOTO" >> $BKLOG
rm $MapContent

#Download file from the tempory backup directory in Dropbox to local backup directory

 SD=$( { time /Dropbox-Uploader/dropbox_uploader.sh -s download "$DBBKDIR" "$BKDIR"; } 2>&1 )
 #Check for error
 ERROR=`echo -n "$SD" | regex \.\.\.\s+FAILED`
 if [ $ERROR ]; then
     EINFO[$ECOUNT]=`echo $SD`
     echo "-->> Error: ${EINFO[$ECOUNT]}D\n" >> $BKLOG
     ECOUNT=$((ECOUNT+1))
 fi

 #Extract time info
 SD=`echo -n "$SD" | grep real `
 DMIN=`echo -n "$SD" | awk '{printf substr($2,0,2)}'`
 DSEC=`echo -n "$SD" | awk '{printf substr($2,3)}'`

 echo -e "- Downloaded tempory backup files to Backup-directory in $DMIN $DSEC\n" >> $BKLOG

#Display directory info
 echo -e "Directory on with files: $BKDIR" >> $BKLOG
 echo -e "Directory stats:\n`ls -liha $BKDIR`\n" >> $BKLOG

#stop the running script to debug second part
#exit 1

# Check if files can be removed from Dropbox
 touch $MapContent
 a= echo `/Dropbox-Uploader/dropbox_uploader.sh list "$DBPHOTODIR" >> $MapContent`
   #Check for error
   ERROR=`echo -n "$a" | regex \.\.\.\s+FAILED`
   if [ $ERROR ]; then
      EINFO[$ECOUNT]=`echo $(head -n 1 $a)`
      echo "- File $DBFILE has given an error\n" >> $BKLOG
      echo "-- Error: ${EINFO[$ECOUNT]}D\n" >> $BKLOG
      ECOUNT=$((ECOUNT+1))
   fi

 COUNTFILES=`wc -l < $MapContent`
  echo "Dropbox files in list : $COUNTFILES\n" >> $BKLOG

#set startrow and counter for reading filename data
COUNTER=1
SROW=2

if [ $COUNTFILES -ge $SROW ] ; then
#read file name data into array
  while IFS='' read LINE || [[ -n "$LINE" ]]; do
   if [ $COUNTER -ge $SROW ]; then
        FNAME[$COUNTER]=`echo $LINE | awk '{printf $3" "$4}'`
        FDATE[$COUNTER]=`echo $LINE | awk '{printf $3}'`
        echo "Save info for ${FNAME[$COUNTER]} with date: ${FDATE[$COUNTER]}\n" >> $BKLOG
   fi

   COUNTER=$((COUNTER+1))

  done < $MapContent
fi

#use filename data from array to copy files to temp directory
COUNTER=$SROW
for DBFILE in "${FNAME[@]}"; do
	#Get month from filedate
	FMONTH=`echo "${FDATE[$COUNTER]}" | awk '{printf substr($1,6,2)}'`
	FYEAR=`echo "${FDATE[$COUNTER]}" | awk '{printf substr($1,0,5)}'`
	if [ $FYEAR -le $YEAR ] || [ $FMONTH -le $RDATE ]; then
	   #Move file to other dropbox folder for backup
#           SD=$( { time /Dropbox-Uploader/dropbox_uploader.sh delete "$DBFILE" ; } 2>&1 )
           SD=$( { time /Dropbox-Uploader/dropbox_uploader.sh copy "$DBPHOTODIR/$DBFILE" "$DBBKDIR/$FYEAR/$DBFILE" ; } 2>&1 )

	   #Check for error
	   ERROR=`echo -n "$SD" | regex \.\.\.\s+FAILED`
	   if [ $ERROR ]; then
	        EINFO[$ECOUNT]=`echo $SD`
	        echo "- File $DBFILE has given an error\n" >> $BKLOG
	        echo "-- Error: ${EINFO[$ECOUNT]}D\n" >> $BKLOG
	        ECOUNT=$((ECOUNT+1))
	   fi

	   #Extract time info
           SD=`echo -n "$SD" | grep real `
           DMIN=`echo -n "$SD" | awk '{printf substr($2,0,2)}'`
           DSEC=`echo -n "$SD" | awk '{printf substr($2,3)}'`

	   echo "- File $DBFILE copied in $DMIN $DSEC to $DBBKDIR/$YEAR\n" >> $BKLOG
	else
	   echo "- File $DBFILE not copied\n" >> $BKLOG

	fi

   COUNTER=$((COUNTER+1))
done

#stop the running script to debug third part
#exit 1

#remove MapContent file = not needed
echo -e "Remove map content file from: $MapContent" >> $BKLOG
rm $MapContent

#for $counter<=$countfile; do
#	a = `echo -n /Dropbox-Uploader/dropbox_uploader.sh list $DBDIR | awk 'FNR == $counter {printf $3}'`
#	$counter++
#done

#for $counter <= $countfile ; do
#	#echo -e "Date for: `$e[@] `" >>  $BKLOG
#        FileName = `echo -n /Dropbox-Uploader/dropbox_uploader.sh list $DBDIR | awk 'FNR == $counter {printf $3}'
#	FileDate = `echo -n /Dropbox-Uploader/dropbox_uploader.sh list $DBDIR | awk 'FNR == $counter {printf $3}'
#	echo -e "Date for: `FileDate `" >>  $BKLOG
#	if [FileDate 
#done

#	if [ ! $MONTH == $NewMONTH ]; then
#		M=`echo -n $MONTH | awk '{printf substr($1,2)}'`
#		let OLD=$M-1
#
#	echo "- New month detected." >> $BKLOG
#			echo "  - New month: $MONTH | Old month:$NewMONTH" >> $BKLOG
#		echo "   + Remove dir on Pi: /backups/$YEAR/$OLD" >> $BKLOG
#
#		rm -rf /backups/$YEAR/$OLD
#
#		if [ ! -d "/backups/$YEAR/$OLD" ]; then
#			echo "    = /backups/$YEAR/$OLD was deleted from pi." >> $BKLOG
#		else
#			echo "    = /backups/$YEAR/$OLD was not deleted from pi." >> $BKLOG
#		fi
#
#		echo "   + Remove dir on Dropbox: /backups/$YEAR/$OLD" >> $BKLOG
#
#		SD=$( { time /Dropbox-Uploader/dropbox_uploader.sh delete $BKDIR/$OLD; } 2>&1 )
#
#			if [ ! `/Dropbox-Uploader/dropbox_uploader.sh list "$BKDIR/$YEAR" | grep -Fxq $OLD` ]; then
#					echo "    = /backups/$YEAR/$OLD was deleted from Dropbox." >> $BKLOG
#			else
#					echo "    = /backups/$YEAR/$OLD was not deleted from Dropbox." >> $BKLOG
#			fi
#
#		SD=`echo -n "$SD" | grep real`
#		MIN=`echo -n "$SD" | awk '{printf substr($2,0,2)}'`
#		SEC=`echo -n "$SD" | awk '{printf substr($2,3)}'`
#		echo -e "- done [ $MIN $SEC ].\n" >> $BKLOG
#	else
#		echo "- $MONTH == $NewMONTH > there is no new month detected.\n" >> $BKLOG
#	fi

#End the log file
echo "!! Backup log file can be located at $BKLOG\n" >> $BKLOG

echo ">> Backup for: $DBDIR finished @ `date +%H:%M:%S`\n" >> $BKLOG

echo "Error overview during this proces:\n" >> $BKLOG
echo ${EINFO[@]}

# Mail this script out...ssmtp for GMail accounts, otherwise change for appropriate MTA
# /usr/sbin/ssmtp -t < $BKLOG
#mutt -s "$Sbject" $To < $BKLOG
