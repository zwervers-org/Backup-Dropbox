#!/bin/bash

# Sript for exchance quality pictures from Canada to supplier
#
# This script reads the pictures from a Dropbox directory and copies it to the right directory of the supplier.
# When movement is finished the script send a email with the sharelink to the supplier's contact
#
# All output is directed to an external file.  At the end of this function, an e-mail is sent to:
# webmaster@ip
#
# Last modified: 21-06-2016

# Test variable: 0=true -> test this script && 1=false -> do not test
TEST=0

# Set time info in variable
SEC=`date +%S`
DAY=`date +%d`
MONTH=`date +%m`
YEAR=`date +%Y`

# Quality picture directory to move files from
 if [ $TEST -eq 0 ]; then
	QUALITYDIR="TEST/Quality Control"
 else
	QUALITYDIR="Quality"
 fi
# Regex info for getting the supplier name from the directory
 REGEXSUPPLIER="([A-Za-z\s]*)\b"
# Remove files from quality directory that are made earlier than
 QRMONTH=`date -d 'now - 62 days' +%m`

# Main directorie in Dropbox were the supplier's directories are located
 if [ $TEST -eq 0 ]; then
	MSUPPLIERDIR="TEST/"
 else
	MSUPPLIERDIR="/"
 fi
# Remove files from supplier's directory that are made earlier than
 SRMONTH=`date -d 'now - 62 days' +%m`

# Location of Dropbox Uploader script
 DBUPLOAD="/Dropbox-Uploader"
# Regex info to get errors from Dropbox Uploader --> Check if it is Done / all other is fail
 REGEXDONE="\.\.\.\s+DONE"
 REGEXSKIP="\s+Skipping"
# DropboxUploader script using for folder/file indication
 FOLDERID="D"
 FILEID="F"

# Make log files
 # Backup log files directory
  BKLOGDIR="/var/log/qcscript/"
 # Tempory local directory
  LOCALTEMP="$BKLOGDIR/tempory/"
 # General log file
  BKLOG="$BKLOGDIR$YEAR$MONTH$DAY.log"
 # Location for saving Dropbox meta info of files in map
  MAPCONTENTDIR="$BKLOGDIR$YEAR$MONTH$DAY"

# Since we send this through e-mail, start the e-mail stuff
 TO="webmaster@zwerver.local"
 FROM="QC <qc@zwerver.local>"
 SBJECT="Generated report for `$(basename "$0")` on DropBox $YEAR.$MONTH.$DAY"

#------------------NO CHANGES BELOW NEEDED--------------------------------------------------------------------------------

#Set error counter to 0
 ECOUNT=0

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

 echo ">>  Moveing quality pictures from $QUALITYDIR to supplier's private directory | started @ `date +%H:%M:%S`\n" >> $BKLOG


#-----------------Load functions to execute--------------------------------------------------------------------------------

# Function to look for errors add using the Dropbox Uploader script
 #$1 = type of function to check error information
 #$2 = Error information
 #Return: 0=true || 1=false
	function ErrorCheck {
		case $1 in
			list|copy|move|delete)
				local ERROR=`echo -n "$2" | egrep "$REGEXDONE"`
				if [ "$ERROR" ]; then
					EINFO[$ECOUNT]="$2"
					ECOUNT=$((ECOUNT+1))
					return 0
				else
					return 1
				fi
			;;
			upload|download)
				local ERROR=`echo -n "$2" | egrep "$REGEXDONE"`
				local ERROR2=`echo -n "$2" | egrep "$REGEXSKIP"`
				if [ "$ERROR" ] || [ "$ERROR2" ]; then
					EINFO[$ECOUNT]="$2"
					ECOUNT=$((ECOUNT+1))
					return 0
				else
					return 1
				fi
			;;
			*)
				EINFO[$ECOUNT]=`echo "No error type given\n Error string is: $2"`
				ECOUNT=$((ECOUNT+1))
				return 0
			;;
		esac
		if [ $TEST -eq 0 ]; then
			echo "Error in/output:"
			echo -e "--> type: $1"
			echo -e "--> info: $2"
			echo -e "-->  out: ${EINFO[$ECOUNT]}"
		fi
	}

# Function use the Dropbox_Uploader script with integrated error checker
  #$1 = Type of use
  #$2 = Source
  #[$3 = Target]
  #[$4 = Special options]
	function DropboxScript {
		echo -e "Dropbox script" >> $BKLOG
		if [ $TEST -eq 0 ]; then
			echo -e "DropboxScript input:"
			echo -e "-->    Type: $1"
			echo -e "-->  Source: $2"
			echo -e "-->  Target: $3"
			echo -e "--> Options: $4"
		fi

	  #Excecute the function
		SD=$( { time "$DBUPLOAD"/dropbox_uploader.sh "$4" "$1" "$2" "$3"; } 2>&1 )

	  #Check for error
		ERRORLINE=`echo -n "$SD" | grep ">"`
		if ErrorCheck "$1" "$ERRORLINE"; then
		  #Extract time info
			SD=`echo -n "$SD" | grep real `
			DMIN=`echo -n "$SD" | awk '{printf substr($2,0,2)}'`
			DSEC=`echo -n "$SD" | awk '{printf substr($2,3)}'`

			if [ -z $3 ]; then
				echo -e "-->$1ed from source ($1) in $DMINm $DSEC\n" >> $BKLOG

			else
				echo -e "-->$1ed from source ($1) to ($3) in $DMINm $DSEC\n" >> $BKLOG
			fi

			return 0

		else
			return 1
		fi
	}

#move photos to the supplier's directory
  #$1 = Sourcepath in Dropbox
  #$2 = Filename of the file to be moved
  #$3 = Supplier's name (extracted form directory name)
  #$4 = Shipment information (extract from directory name)
  #$5 = Arrival date (extract form directory)
  #Return: 0=true || 1=false
	function MoveToSupplier {
		echo -e "Move to supplier" >> $BKLOG
		if [ $TEST -eq 0 ]; then
			echo -e "MoveToSupplier input:"
			echo -e "-->     Source path: $1"
			echo -e "-->       File name: $2"
			echo -e "--> Supplier's name: $3"
			echo -e "-->    Arrival date: $4"
		fi
		local DBFILE="$1/$2"

	 #Get month from modification date
	   local AYEAR=`date --date="$5" +%Y`
	   local AMONTH=`date --date="$5" +%m`

	  #Move the file from the source directory to the suppliers directory in Dropbox
		if DropboxScript "move" "$DBFILE" "$SUPPLIERDIR/$3/$AYEAR/$AMONTH/$4/$2" "-s" ; then
			echo -e "-->Moved ($2) from source ($1) to supplier's directory ($3) in $DMINm $DSEC\n" >> $BKLOG
			return 0
		else
			echo -e "Problem moving ${DBFILE}" >> $BKLOG
			return 1
		fi
	}

#Remove files from Dropbox arrived earlier than the RMONTH
 #$1 = Source/Supplier's directory name that has to be checked
 #$2 = Filename/directory to be checked
 #$3 = Modification date of the file/directory
	function CheckRemoveFiles {
		echo -e "Check remove files" >> $BKLOG
		local DBFILE="$1/$2"
		
		if [ $TEST -eq 0 ]; then
			echo -e "Check remove files input:"
			echo -e "---Source:       $1"
			echo -e "---Filename:     $2"
			echo -e "---Modification: $3"
		fi
		
	 #Get month from modification date
	   local MYEAR=`date --date="$3" +%Y`
	   local MMONTH=`date --date="$3" +%m`
	 #Check if it is a supplier's directory or quality directory
	   if [ $1 == $QUALITYDIR ]; then
		RMONTH=$QRMONTH
	   else
		RMONTH=$SRMONTH
	   fi

		if [ $MYEAR -lt $YEAR ] || [ $MMONTH -le $RMONTH ]; then
			if [ $TEST -eq 0 ]; then
			  #Move file to other dropbox folder for backup
				SD=$( DropboxScript "move" "$DBFILE" "/test" "-s" )
			else
			  #Remove file/directy from folder for dropbox
				SD=$( DropboxScript "delete" "$DBFILE" )
			fi

		     #Remove the file from the source directory in Dropbox
			if [ $SD -eq 0 ]; then
				echo -e "-->Removed ($2) from source ($1) in $DMINm $DSEC\n" >> $BKLOG
				return 0
			else
				echo -e "Problem removing ${DBFILE}" >> $BKLOG
				return 1
			fi

		else
			echo "-->Skipped for remove ($2) from Dropbox ($1) it is modified on: $3\n" >> $BKLOG
			return 0
		fi
	}

# Resize the pictures when they are to big
 #$1 = Source directory name that has to be checked
 #$2 = Filename to be checked
	function ResizePictures {
		echo -e "Resize Pictures" >> $BKLOG
		local DBFILE="$1/$2"
	   
		if [ $TEST -eq 0 ]; then
			echo -e "Resize pictures input:"
			echo -e "---Source:   $1"
			echo -e "---Filename: $2"
		fi

	  #Move the file from the source directory to local tempory directory
		if DropboxScript "download" "$DBFILE" "$LOCALTEMP" ; then
			echo -e "-->downloaded ($2) from source ($1) to local directory ($LOCALTEMP/$2) in $DMINm $DSEC\n" >> $BKLOG
		    #Check size of the file with max pixels
		      #Get size with PHP-script
			DIMENTION=`php -r "print_r(getimagesize('$LOCALTEMP/$2'));"`
			if [ -z $DIMENTION ]; then
				echo "File ($2) is no image" >> $BKLOG
				exit 1
			fi

			if [ $TEST -eq 0 ]; then
				echo "Dimentions are: ${DIMENTION[@]}"
			fi
			local WIDTH=${DIMENTION[0]}
			local HEIGHT=${DIMENTION[1]}

			if [ $WIDTH -gt $MAXPIX ]; then
			    #Resize picture to max pixels with ImageImagick
				convert -resize y1048 "$LOCALTEMP/$2" "$LOCALTEMP/$2"
			elif [ $HEIGHT -gt $MAXPIX ]; then
			    #Resize picture to max pixels with ImageImagick
                                convert -resize x1048 "$LOCALTEMP/$2" "$LOCALTEMP/$2"
			fi

		      #Get size with PHP-script
			DIMENTION=`php -r "print_r(getimagesize('$LOCALTEMP/$2'));"`
			if [ $TEST -eq 0 ]; then
				echo -e "Dimentions are: ${DIMENTION[@]}"
			fi
			local WIDTH2=${DIMENTION[0]}
			local HEIGHT2=${DIMENTION[1]}

			if [ $WIDTH2 -le $MAXPIX ] || [ $HEIGHT2 -le $MAXPIX ] then
			    #Upload file to same directory and overwrite the existing file
				if DropboxScript "upload" "$LOCALTEMP/$2" "$DBFILE" ; then
					echo -e "-->uploaded ($2) from source ($LOCALTEMP) to dropbox directory ($1) in $DMINm $DSEC\n" >> $BKLOG
					return 0
				else
					echo -e "Problem uploading ${DBFILE}" >> $BKLOG
					return 1
				fi
			else
				echo -e "There is a problem with resizeing the image ($LOCALTEMP/$2)" >> $BKLOG
				return 1
			fi
		else
			echo -e "Problem downloading ${DBFILE}" >> $BKLOG
			return 1
		fi
	}

#-----------------Start with execute functions--------------------------------------------------------------------------------

# Read maps in Quality information directory

# Read the quality directory and make for every arrival directory a .content file -> 
#   -> the .content file is used to move and resize the pictures
#   files in the 'root' of the QualityDir has to be ignored

    DBDIRNAME=$(echo $QUALITYDIR | tr -d ' ')
    DBSUBDIR="$MAPCONTENTDIR/$DBDIRNAME.sub"
    touch $DBSUBDIR
	if [ $TEST -eq 0 ]; then
		echo $DBPHOTODIR >> $DBSUBDIR
	fi

    while IFS=',' read -r DIRNAME READCOUNT; do
	SUBDIRNAME=$(echo $DIRNAME | tr -d ' ' | tr '/' '_')
        MAPCONTENT="$MAPCONTENTDIR/$SUBDIRNAME.content"
        touch $MAPCONTENT

        a=$($DBUPLOAD/dropbox_uploader.sh list "$DIRNAME" >> "$MAPCONTENT")

       #Check for error
	HEADROW=`head -n 1 "$MAPCONTENT"`
    	if ErrorCheck "list" "$HEADROW"; then
    		COUNTFILES=$(wc -l < "$MAPCONTENT")
    		echo -e "Need to read $COUNTFILES lines in directory $DIRNAME" >> $BKLOG

			#read row information into variables
			COUNTER=1
       		while IFS=']' read -r TYPE SIZE FNAME MDATE; do
       			if [ $COUNTER -ge $SROW ]; then
       				#Erase first character '[' from the value
       				TYPE=$(echo $TYPE | cut -c 2-)
       				SIZE=$(echo $SIZE | cut -c 2-)
       				FNAME=$(echo $FNAME | cut -c 2-)
       				MDATE=$(echo $MDATE | cut -c 2-)
					SUBCHECK=$(x//[^/])

       			#Put info into array
       				if [ $TYPE == $FILEID ]; then
						if [ $DIRNAME == $QUALITYDIR ] ; then
							echo -e "Files found in maindirectory -> doing nothing" >> $BKLOG
						elif [ $SUBCHECK -gt 2 ] ; then
							echo -e "Files found in sub-subdirectory -> copy to local -> resize -> upload to supplier's directory (same sub)" >> $BKLOG
							if [ $TEST -eq 0 ]; then
								echo -e "sub-subdirectory found ($DIRNAME)"
							fi
						else
							echo -e "Files found to download -> resize -> upload to supplier's directory"
							if DropboxScript "dowload" "$DIRNAME/$FNAME" "$LOCALTEMP" ; then
								if ResizePictures "$LOCALTEMP" "$FNAME" ; then
								   #Extract Supplier/Container/Arrival information from directory name
								    IFS='-' read SUPPLIER CONTAINERNR ARRIVALDATE << $DIRNAME
									local $SUPPLREG=$(echo -n "$DIRNAME" | egrep "$REGEXSUPPLIER" | cut -c 2-)
									local $SUPPLIERDIR=$(echo $SUPPLIER | cut -c 2-)
									
									if [ $TEST -eq 0 ]; then
										echo -e "Extracted information from $DIRNAME:"
										echo -e "--->Supplier regex: $SUPPLREG"
										echo -e "--->Supplier dir:   $SUPPLIERDIR"
										echo -e "--->Containernr:    $CONTAINERNR"
										echo -e "--->Arrival date:   $ARRIVALDATE"
									fi
									
									if [ $SUPPLREG == $SUPPLIERDIR ]; then
										DropboxScript "upload" "LOCALTEMP/$FNAME" "$SUPPLIERDIR/$CONTAINERNR$ARRIVALDATE/$FNAME" "-s"
									else
										echo -e "Supplier not available in directory name ($DIRNAME)\n Put resized files in quality directory" >> $BKLOG
										DropboxScript "upload" "LOCALTEMP/$FNAME" "$DIRNAME" "-s"
									fi
								fi
							fi
       				elif [ $TYPE == $FOLDERID ]; then
     					echo -e "New folder detected: $FNAME" >> $BKLOG
						echo -e "$DIRNAME/$FNAME" >> $DBSUBDIR

       				else
       					echo -e "Type ($TYPE) not recongiced\n
							--Further information:\n
							--Size: $SIZE\n--FNAME: $FNAME\n
							--MDATE: $MDATE"  >> $BKLOG
       				fi
       			fi
			COUNTER=$((COUNTER+1))
       		done < "$MAPCONTENT"
		else
			echo "- FAILED to load list for $DIRNAME\n" >> $BKLOG
		fi
	done < "$DBSUBDIR"

#-----------------End the log file-----------------------------------------------------------------------------------------

  echo "!! Log file can be located at $BKLOG" >> $BKLOG

  echo ">> Movement for: $QUALITYDIR finished @ `date +%H:%M:%S`" >> $BKLOG

 #Display error during execution
	if [ "${#EINFO[@]}" -gt 0 ]; then
		echo "Error overview during this proces:" >> $BKLOG
		for er in "${!EINFO[@]}"; do
			echo "--> ${EINFO[er]}" >> $BKLOG
		done

		echo "${EINFO[@]}" >> $BKLOG
	fi

if [ $TEST !-eq 0 ]; then
	 #remove MapContent files = not needed
	 #Display removing files
		echo -e "Removing following files\n`ls -liha $MAPCONTENTDIR | grep .content`\n" >> $BKLOG
		rm "$MAPCONTENTDIR/*.content"
		echo -e "Removing following files\n`ls -liha $MAPCONTENTDIR | grep .sub`\n" >> $BKLOG
		rm "$MAPCONTENTDIR/*.sub"

	 # Mail this script out...ssmtp for GMail accounts, otherwise change for appropriate MTA
		mutt -s "$Sbject" -a "$BKLOG" -H "$BKLOG" $To < $BKLOG
fi