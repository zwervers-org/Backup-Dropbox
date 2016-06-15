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

# Month for new month check (saves always to new backups)
RDATE=`date -d 'now - 62 days'`

# Backup directory to download files in localy
 #BKDIR="/mnt/WD_public/Shared\ Pictures/"
 BKDIR="/mnt/photo/test/"

# Directories in Dropbox with the files to backup (Photo) and the directory to tempory backup
 #DBPHOTODIR="'Camera Uploads'"
 DBPHOTODIR="Test download"
 DBBKDIR="Photo Backup"

# Location of Dropbox Uploader script
 DBUPLOAD="/Dropbox-Uploader"
# Regex info to get errors from Dropbox Upload
 REGEX="\.\.\.\s+FAILED"
# Indications de Dropb Uploader script using for folder/file indication
 FOLDERID="D"
 FILEID="F"

#Set error counter to 0
 ECOUNT=0

# Make log files
 # Backup log files directory
  BKLOGDIR="/home/pi/backup/$YEAR/$MONTH/"
 # General log file
  BKLOG="$BKLOGDIR$DAY.log"
 # Location for saving Dropbox meta info of files in map
  MAPCONTENTDIR="$BKLOGDIR$DAY"

# Since we send this through e-mail, start the e-mail stuff
 TO="root@zwerver.org"
 FROM="Backups <backups@zwerver.org>"
 SBJECT="Generated backup report Camera Upload DropBox on $YEAR.$MONTH.$DAY"


#----------------NO CHANGES BELOW NEEDED----------------

#Make sure directories are generated
 mkdir -p $BKLOGDIR
 mkdir -p $BKDIR

# Make sure files are generated
 touch $BKLOG

# Set startrow from Dropbox-output files
 SROW=2

#Start log file
 echo "To: $TO" >> $BKLOG
 echo "From: $FROM" >> $BKLOG
 echo "Subject: $SBJECT\n" >> $BKLOG

 echo ">> Backup for: $YEAR.$MONTH.$DAY started @ `date +%H:%M:%S`\n" >> $BKLOG

# Function to look for errors add using the Dropbox Uploader script
 #$1 = type of function to check error information
 #$2 = Error information
 #Return: 0=true || 1=false
	function ErrorCheck {
		echo -e "$1: $1"
		echo -e "$2: $2"
		
		case $1 in
			list)
				local ERROR=`echo -n "$2" | egrep "$REGEX"`
				if [ !"$ERROR" ]; then
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
				local ERROR=`echo -n "$2" | egrep "$REGEX"`
				echo $ERROR
				if [ !"$ERROR" ]; then
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
				echo "->> Error: ${EINFO[$ECOUNT]}"
				ECOUNT=$((ECOUNT+1))
				return 0
			;;
		esac
	}

# Read map content for the map
	function ReadDBMap {
	    echo $DBPHOTODIR >> $DBSUBDIR
		
	    while IFS=',' read -r DIRNAME READCOUNT; do
			local DBDIRNAME=$(echo $DBPHOTODIR | tr -d ' ')
	        local MAPCONTENT="$MAPCONTENTDIR/$DBDIRNAME.content"
	        touch $MAPCONTENT
			
			echo -e $DIRNAME
			
	        a=$("$DBUPLOAD"/dropbox_uploader.sh list "$DIRNAME" >> "$MAPCONTENT")
	        
    		#Check for error
    		if ErrorCheck "list" $(head -n 1 "$MAPCONTENT"); then
    			COUNTFILES=$(wc -l < "$MAPCONTENT")
    			echo -e "Need to read $COUNTFILES lines in directory $1" >> $BKLOG
		
        		#read file name data into variable
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
							if CopyToLocal "$DBDIRNAME" "$FNAME" "$MDATE"; then
								echo -e "Check removal of ${FNAME} with modification date: ${MDATE}" >> $BKLOG
								echo -e "Check modification ${FNAME}"
								CheckRemoveFile "$DBDIRNAME" "$FNAME" "$MDATE"
							
							else
								echo -e "Problem downloading ${FNAME}"
							
							fi
        			
        				elif [ $TYPE == $FOLDERID ]; then
        					echo -e "New folder detected: $FNAME" >> $BKLOG
        					echo -e "Directory ${FNAME}"
							echo -e "${FNAME}" >> $DBSUBDIR
							
        				else
        					echo -e "Type ($TYPE) not recongiced\n
								--Further information:\n
								--Size: $SIZE\n--FNAME: $FNAME\n
								--MDATE: $MDATE"  >> $BKLOG
							echo -e "Type ($TYPE) problem"
        				fi
        			fi
        		done < "$MAPCONTENT"		
			else
				echo "- FAILED to load list for $1\n" >> $BKLOG
				return 1 #return false
			fi
		done < "$DBSUBDIR"
	}

#copy photos to the local directory
  #$1 = path in Dropbox
  #$2 = Filename (include path) of the file to be copied
  #$3 = Modification date
  #Return: 0=true || 1=false
	function CopyToLocal {
		local DBFILE="$1\$2"
				
	  #Get month from modification date
		local MYEAR=`date --date="$3" '%Y'`
		local MMONTH=`date --date="$3" '%m'`
	  #Make a new local directory for the mont if needed
		local LOCALDIR="$BKDIR\$MYEAR\$MMONTH"
		mkdir -p $LOCALDIR
		
		#Download file from the directory in Dropbox to local backup directory
		SD=$( { time "$DBUPLOAD"/dropbox_uploader.sh -s download "$DBFILE" "$LOCALDIR"; } 2>&1 )
		
		#Check for error
		ERRORLINE=`echo -n "$SD" | grep ">"`
		if ErrorCheck "copy" "$ERRORLINE"; then
			#Extract time info
			SD=`echo -n "$SD" | grep real `
			DMIN=`echo -n "$SD" | awk '{printf substr($2,0,2)}'`
			DSEC=`echo -n "$SD" | awk '{printf substr($2,3)}'`

			echo -e "Downloaded ($2) from Dropbox ($1) to local directory ($LOCALDIR) in $DMINm $DSEC\n" >> $BKLOG
			return 0
		
		else
			return 1
		fi
	}
	
#use filename data from array to move files to year folder in DropBox temp directory
 #$1 = Folder name were Dropbox files are located
 #$2 = Filename to be checked
 #$3 = Modification date of the file
	function EraseFiles {
	   local COUNTER=$SROW
	   local DBFILE="$1\$2"
	   local MDATE=$3
	   local RMONTH=`date --date="$RDATE" '%m'`
	 
	 #Get month from modification date
	   local MYEAR=`date --date="$MDATE" '%Y'`
	   local MMONTH=`date --date="$MDATE" '%m'`
		
		if [ $FYEAR -le $YEAR ] || [ $FMONTH -le $RMONTH ]; then
				#Move file to other dropbox folder for backup
	#           SD=$( { time "$DBUPLOAD"/dropbox_uploader.sh delete "$DBFILE" ; } 2>&1 )
				SD=$( { time "$DBUPLOAD"/dropbox_uploader.sh copy "$DBFILE" "$DBBKDIR/$FYEAR/" ; } 2>&1 )

				#Check for error
				if [ !ErrorCheck "copy" $SD ]; then
					#Extract time info
					SD=`echo -n "$SD" | grep real `
					DMIN=`echo -n "$SD" | awk '{printf substr($2,0,2)}'`
					DSEC=`echo -n "$SD" | awk '{printf substr($2,3)}'`

					#echo "Removed ($2) from Dropbox ($1) in $DMINm $DSEC\n" >> $BKLOG
					echo "PrankRemoved ($2) from Dropbox ($1) in $DMINm $DSEC\n" >> $BKLOG
					
					return 0
				
				else
					return 1
				fi

			else
				echo "- File $DBFILE not copied\n" >> $BKLOG
			fi

		COUNTER=$((COUNTER+1))
		done
	}

#use filename data from array to copy files to temp directory
 #$1 = Dropbox directory name (could be sub-dir from DropBox Backup DIRectory)
 #Required: $DBBKDIR as tempory DropBox directory
	function FilesToTemp {
		local DBDIRNAME=$(echo $1 | tr -d ' ') #DirName without spaces

		for DBFILE in "${FNAME[@]}"; do
			#Get year from filedate
			local FYEAR=`echo "${FDATE[$COUNTER]}" | awk '{printf substr($1,13,5)}'`

			#Move file to other dropbox folder for backup
			local SD=$( { time /Dropbox-Uploader/dropbox_uploader.sh copy "$1/$DBFILE" "$DBBKDIR/$FYEAR/$DBFILE" ; } 2>&1 )

			#Check for error
			ERRORLINE=`echo -n "$SD" | grep ">"`
			if ErrorCheck "copy" "$ERRORLINE" ; then
				#Extract time info
				SD=`echo -n "$SD" | grep real `
				DMIN=`echo -n "$SD" | awk '{printf substr($2,0,2)}'`
				DSEC=`echo -n "$SD" | awk '{printf substr($2,3)}'`

				echo "- File $DBFILE copied in $DMINm $DSEC to $DBBKDIR/$YEAR\n" >> $BKLOG
			else
				echo "- File $DBFILE FAILED to copy to $DBBKDIR/$YEAR\n" >> $BKLOG
			fi
			COUNTER=$((COUNTER+1))
		done
	}
	
#copy photos to the local directory
 #--> Required: DBBBKDIR-> Dropbox Backup Directory && BKDIR-> Local directory to put all files into
	function CopyToLocal2 {
		#Download file from the tempory backup directory in Dropbox to local backup directory
		SD=$( { time /Dropbox-Uploader/dropbox_uploader.sh -s download "$DBBKDIR" "$BKDIR"; } 2>&1 )
		
		#Check for error
		ERRORLINE=`echo -n "$SD" | grep ">"`
		if ErrorCheck "copy" "$ERRORLINE" ; then
			#Extract time info
			SD=`echo -n "$SD" | grep real `
			DMIN=`echo -n "$SD" | awk '{printf substr($2,0,2)}'`
			DSEC=`echo -n "$SD" | awk '{printf substr($2,3)}'`

			echo -e "- Downloaded from tempory backup directory Dropbox to local backup directory in $DMINm $DSEC\n" >> $BKLOG
		fi

		#Display directory info
		echo -e "Directory on with files: $BKDIR" >> $BKLOG
		echo -e "Directory stats:\n`ls -liha $BKDIR`\n" >> $BKLOG
	}

#-----------------Load functions to execute--------------------------------------------------------------------------------
 # First put the files into the temp directory on Dropbox
 #CHECK10=FilesToTemp $DBPHOTODIR

# Second -> copy files to local backup
	#if [ CHECK10 ]; then
	#  CHECK20=CopyToLocal
	#else
	#  echo "There is an error accurt in Check1\n" >> $BKLOG
	#  echo "- Return result Check1: $CHECK10\n" >> $BKLOG
	#  exit 1
	#fi

# Third -> Check if files in Dropbox can be removed =< RDATE

 #MAPCONTENTFILE=ReadDBMap $DBPHOTODIR
 #METAARRAY=LoadMetaInfo DBPHOTODIR $MAPCONTENTFILE


#for $counter<=$countfile; do
#	a=`echo -n /Dropbox-Uploader/dropbox_uploader.sh list $DBDIR | awk 'FNR == $counter {printf $3}'`
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

  #Display directory info
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
	#echo -e "Removing following files\n`ls -liha *.content $BKDIR`\n" >> $BKLOG
	#rm "$MAPCONTENTDIR*.content"


  # Mail this script out...ssmtp for GMail accounts, otherwise change for appropriate MTA
  # /usr/sbin/ssmtp -t < $BKLOG
	#mutt -s "$Sbject" $To < $BKLOG
