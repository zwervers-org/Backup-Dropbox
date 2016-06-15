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
# Last modified: 25-05-2016

# Set time info in variable
SEC=`date +%S`
DAY=`date +%d`
MONTH=`date +%m`
YEAR=`date +%Y`

# Remove the picture from Dropbox before this month
RMONTH=`date -d 'now - 62 days' +%m`

# Backup directory to download files in localy
 #BKDIR="/mnt/WD_public/Shared\ Pictures/"
 BKDIR="/mnt/photo/"

# Directories in Dropbox with the files to backup (Photo) and the directory to tempory backup
 DBPHOTODIR="'Camera Uploads'"
 #DBPHOTODIR="Test download"
 #DBBKDIR="Photo Backup"

# Location of Dropbox Uploader script
 DBUPLOAD="/Dropbox-Uploader"
# Regex info to get errors from Dropbox Upload --> Check if it is Done / all other is fail
 REGEXDONE="\.\.\.\s+DONE"
 REGEXSKIP="\s+Skipping"
# DropboxUploader script using for folder/file indication
 FOLDERID="D"
 FILEID="F"

#Set error counter to 0
 ECOUNT=0

# Make log files
 # Backup log files directory
  BKLOGDIR="/mnt/DBdownload/$YEAR/$MONTH/"
 # General log file
  BKLOG="$BKLOGDIR$DAY.log"
 # Location for saving Dropbox meta info of files in map
  MAPCONTENTDIR="$BKLOGDIR$DAY"

# Since we send this through e-mail, start the e-mail stuff
 TO="root@zwerver.org"
 FROM="Backups <backups@zwerver.org>"
 SBJECT="Generated backup report Camera Upload DropBox on $YEAR.$MONTH.$DAY"



#------------------NO CHANGES BELOW NEEDED--------------------------------------------------------------------------------

#Make sure directories are generated
 mkdir -p $BKLOGDIR
 mkdir -p $BKDIR
 mkdir -p $MAPCONTENTDIR

# Make sure files are generated
 touch $BKLOG

# Set startrow from Dropbox-output files
 SROW=2

#Start log file
 echo "To: $TO" >> $BKLOG
 echo "From: $FROM" >> $BKLOG
 echo "Subject: $SBJECT\n" >> $BKLOG

 echo ">> Backup for: $YEAR.$MONTH.$DAY started @ `date +%H:%M:%S`\n" >> $BKLOG


#-----------------Load functions to execute--------------------------------------------------------------------------------

# Function to look for errors add using the Dropbox Uploader script
 #$1 = type of function to check error information
 #$2 = Error information
 #Return: 0=true || 1=false
	function ErrorCheck {
		echo -e "Type: $1"
		echo -e "Error: $2"

		case $1 in
			list)
				local ERROR=`echo -n "$2" | egrep "$REGEXDONE"`
				if [ "$ERROR" ]; then
					#EINFO[$ECOUNT]=`echo $(head -n 1 $1)`
					EINFO[$ECOUNT]="$2"
					echo "->> Error: ${EINFO[$ECOUNT]}" >> $BKLOG
					ECOUNT=$((ECOUNT+1))
					return 0
				else
					return 1
				fi
			;;
			copy)
				local ERROR=`echo -n "$2" | egrep "$REGEXDONE"`
				local ERROR2=`echo -n "$2" | egrep "$REGEXSKIP"`
				if [ "$ERROR" ] || [ "$ERROR2" ]; then
					EINFO[$ECOUNT]="$2"
					#echo "- File $DBFILE has given an error\n" >> $BKLOG
					echo "->> Error: ${EINFO[$ECOUNT]}" >> $BKLOG
					ECOUNT=$((ECOUNT+1))
					return 0
				else
					return 1
				fi
			;;
			*)
				EINFO[$ECOUNT]=`echo "No error type given\n Error string is: $2"`
				echo "--> Error: ${EINFO[$ECOUNT]}"
				ECOUNT=$((ECOUNT+1))
				return 0
			;;
		esac
	}

#copy photos to the local directory
  #$1 = path in Dropbox
  #$2 = Filename (include path) of the file to be copied
  #$3 = Modification date
  #Return: 0=true || 1=false
	function CopyToLocal {
		local DBFILE="$1/$2"

		echo -e "Path: $1"
		echo -e "File: $2"
		echo -e "Mod: $3"

	  #Get month from modification date
		local MYEAR=`date --date="$3" +%Y`
		local MMONTH=`date --date="$3" +%m`
	  #Make a new local directory for the mont if needed
		local LOCALDIR="$BKDIR/$MYEAR/$MMONTH"
		mkdir -p $LOCALDIR

	  #Download file from the directory in Dropbox to local backup directory
		SD=$( { time "$DBUPLOAD"/dropbox_uploader.sh -s download "$DBFILE" "$LOCALDIR/$2"; } 2>&1 )

	  #Check for error
		ERRORLINE=`echo -n "$SD" | grep ">"`
		if ErrorCheck "copy" "$ERRORLINE"; then
		  #Extract time info
			SD=`echo -n "$SD" | grep real `
			DMIN=`echo -n "$SD" | awk '{printf substr($2,0,2)}'`
			DSEC=`echo -n "$SD" | awk '{printf substr($2,3)}'`

			echo -e "-->Downloaded ($2) from Dropbox ($1) to local directory ($LOCALDIR) in $DMINm $DSEC\n" >> $BKLOG
			return 0

		else
			return 1
		fi
	}

#remove files from Dropbox modified earlier than the RMONTH
 #$1 = Folder name were Dropbox files are located
 #$2 = Filename to be checked
 #$3 = Modification date of the file
	function CheckRemoveFile {
	   local DBFILE="$1/$2"

	 #Get month from modification date
	   local MYEAR=`date --date="$3" +%Y`
	   local MMONTH=`date --date="$3" +%m`

		if [ $MYEAR -le $YEAR ] || [ $MMONTH -le $RMONTH ]; then
		  #Move file to other dropbox folder for backup
			SD=$( { time "$DBUPLOAD"/dropbox_uploader.sh delete "$DBFILE" ; } 2>&1 )

		  #Check for error
			ERRORLINE=`echo -n "$SD" | grep ">"`
			if ErrorCheck "copy" "$ERRORLINE"; then
			  #Extract time info
				SD=`echo -n "$SD" | grep real`
				DMIN=`echo -n "$SD" | awk '{printf substr($2,0,2)}'`
				DSEC=`echo -n "$SD" | awk '{printf substr($2,3)}'`

				echo "-->Removed ($2) from Dropbox ($1) in $DMINm $DSEC\n" >> $BKLOG

				return 0

			else
				return 1
			fi

		else
			echo "-->Skipped for remove ($2) from Dropbox ($1) it is modified on: $3\n" >> $BKLOG
			return 0
		fi
	}

#-----------------Start with execute functions--------------------------------------------------------------------------------

# Read map content for the map
    DBDIRNAME=$(echo $DBPHOTODIR | tr -d ' ')
    DBSUBDIR="$MAPCONTENTDIR/$DBDIRNAME.sub"
    touch $DBSUBDIR
    echo $DBPHOTODIR >> $DBSUBDIR

    while IFS=',' read -r DIRNAME READCOUNT; do
	SUBDIRNAME=$(echo $DIRNAME | tr -d ' ' | tr '/' '_')
        MAPCONTENT="$MAPCONTENTDIR/$SUBDIRNAME.content"
        touch $MAPCONTENT

        a=$("$DBUPLOAD"/dropbox_uploader.sh list "$DIRNAME" >> "$MAPCONTENT")

       #Check for error
	HEADROW=`head -n 1 "$MAPCONTENT"`
    	if ErrorCheck "list" "$HEADROW"; then
    		COUNTFILES=$(wc -l < "$MAPCONTENT")
    		echo -e "Need to read $COUNTFILES lines in directory $DIRNAME" >> $BKLOG

       		#read file name data into variable
		COUNTER=1
       		while IFS=']' read -r TYPE SIZE FNAME MDATE; do
       			if [ $COUNTER -ge $SROW ]; then
       				#Erase first character '[' from the value
       				TYPE=$(echo $TYPE | cut -c 2-)
       				SIZE=$(echo $SIZE | cut -c 2-)
       				FNAME=$(echo $FNAME | cut -c 2-)
       				MDATE=$(echo $MDATE | cut -c 2-)

       			#Put info into array
       				if [ $TYPE == $FILEID ]; then
       					echo -e "Download ${FNAME} with modification date: ${MDATE}" >> $BKLOG
       					echo -e "Download ${FNAME}"
					if CopyToLocal "$DIRNAME" "$FNAME" "$MDATE" ; then
							echo -e "Check removal of ${FNAME} with modification date: ${MDATE}" >> $BKLOG
							echo -e "Check modification ${FNAME}"
							CheckRemoveFile "$DIRNAME" "$FNAME" "$MDATE"

					else
							echo -e "Problem downloading ${FNAME}"

					fi

       				elif [ $TYPE == $FOLDERID ]; then
     					echo -e "New folder detected: $FNAME" >> $BKLOG
       					echo -e "Directory ${FNAME}"
					echo -e "$DIRNAME/$FNAME" >> $DBSUBDIR

       				else
       					echo -e "Type ($TYPE) not recongiced\n
							--Further information:\n
							--Size: $SIZE\n--FNAME: $FNAME\n
							--MDATE: $MDATE"  >> $BKLOG
					echo -e "Type ($TYPE) problem"
       				fi
       			fi
			COUNTER=$((COUNTER+1))
       		done < "$MAPCONTENT"
		else
			echo "- FAILED to load list for $DIRNAME\n" >> $BKLOG
		fi
	done < "$DBSUBDIR"

#-----------------End the log file-----------------------------------------------------------------------------------------

 #Display local directory info
	echo -e "Directory on with files: $BKDIR" >> $BKLOG
	echo -e "Directory stats:\n`ls -liha $BKDIR`\n" >> $BKLOG

  echo "!! Backup log file can be located at $BKLOG" >> $BKLOG

  echo ">> Backup for: $DBDIR finished @ `date +%H:%M:%S`" >> $BKLOG

 #Display error during execution
	if [ "${#EINFO[@]}" -gt 0 ]; then
		echo "Error overview during this proces:" >> $BKLOG
		for er in "${!EINFO[@]}"; do
			echo "--> ${EINFO[er]}" >> $BKLOG
		done

		echo "${EINFO[@]}" >> $BKLOG
	fi

 #remove MapContent files = not needed
 #Display removing files
	echo -e "Removing following files\n`ls -liha $BKDIR | grep .content`\n" >> $BKLOG
	rm "$MAPCONTENTDIR/*.content"
	echo -e "Removing following files\n`ls -liha $BKDIR | grep .sub`\n" >> $BKLOG
	rm "$MAPCONTENTDIR/*.sub"


 # Mail this script out...ssmtp for GMail accounts, otherwise change for appropriate MTA
 # /usr/sbin/ssmtp -t < $BKLOG
	mutt -s "$Sbject" $To < $BKLOG
