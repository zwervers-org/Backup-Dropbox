# Backup from Dropbox to your computer

This BASH script is written because the need of downloading files from Dropbox to a local NAS or HDD so the Dropbox is not running out of memory. 

To work with this script you have to download and install the latest version of Dropbox Upload from GitHub. This version has to be changed to get all motivication data from Dropbox so the script can work properly.


<h2>Dropbox Upload changes</h2>

<h3>Steps</h3>
<ul>
<li>Open de dropbox-uploader.sh file into your favorite editor</li>
<li>Look for the following Function: <i>List</i></li>
<li>Replace this function with:</br>
#List remote directory
#$1 = Remote directory
function db_list
{
    local DIR_DST=$(normalize_path "$1")

    print " > Listing \"$DIR_DST\"... "
    $CURL_BIN $CURL_ACCEPT_CERTIFICATES -L -s --show-error --globoff -i -o "$RESPONSE_FILE" "$API_METADATA_URL/$ACCESS_LEVEL/$(urlencode "$DIR_DST")?oauth_c$
    check_http_response

    #Check
    if grep -q "^HTTP/1.1 200 OK" "$RESPONSE_FILE"; then

        local IS_DIR=$(sed -n 's/^\(.*\)\"contents":.\[.*/\1/p' "$RESPONSE_FILE")

        #It's a directory
        if [[ $IS_DIR != "" ]]; then

            print "DONE\n"

            #Extracting directory content [...]
            #and replacing "}, {" with "}\n{"
            #I don't like this piece of code... but seems to be the only way to do this with SED, writing a portable code...
            local DIR_CONTENT=$(sed -n 's/.*: \[{\(.*\)/\1/p' "$RESPONSE_FILE" | sed 's/}, *{/}\
{/g')

            #Converting escaped quotes to unicode format
            echo "$DIR_CONTENT" | sed 's/\\"/\\u0022/' > "$TEMP_FILE"

            #Extracting files and subfolders
            rm -fr "$RESPONSE_FILE"
            while read -r line; do

                local FILE=$(echo "$line" | sed -n 's/.*"path": *"\([^"]*\)".*/\1/p')
                local IS_DIR=$(echo "$line" | sed -n 's/.*"is_dir": *\([^,]*\).*/\1/p')
                local SIZE=$(convert_bytes $(echo "$line" | sed -n 's/.*"bytes": *\([0-9]*\).*/\1/p'))
                local MODIFIED=$(echo "$line" | sed -n 's/.*"modified": *"\([^"]*\):.*/\1/p')

                echo -e "$FILE>$IS_DIR;$SIZE[$MODIFIED" >> "$RESPONSE_FILE"

            done < "$TEMP_FILE"

            #Looking for the biggest file name
            #to calculate the padding to use
            local padding=0
            while read -r line; do
                local FILE=${line%>*}
                local METAS=${line##*;}
                local SIZE=${METAS%[*}

                if [[ ${#SIZE} -gt $padding ]]; then
                    padding=${#SIZE}
                fi
            done < "$RESPONSE_FILE"

            #For each entry, printing directories...
            while read -r line; do

                local FILE=${line%>*}
                local META=${line##*>}
                local METAS=${line##*;}
                local TYPE=${META%;*}
                local SIZE=${METAS%[*}
                local MODIFIED=${META#*[}

                #Removing unneeded /
                FILE=${FILE##*/}

                if [[ $TYPE == "true" ]]; then
                    FILE=$(echo -e "$FILE")
                    $PRINTF " [D] %-${padding}s %-${padding}s %s\n" "$SIZE" "$FILE" "$MODIFIED"
                fi

            done < "$RESPONSE_FILE"

            #For each entry, printing files...
            while read -r line; do

                local FILE=${line%>*}
                local META=${line##*>}
                local METAS=${line##*;}
                local TYPE=${META%;*}
                local SIZE=${METAS%[*}
                local MODIFIED=${META#*[}

                #Removing unneeded /
                FILE=${FILE##*/}

                if [[ $TYPE == "false" ]]; then
                    FILE=$(echo -e "$FILE")
                if [[ $TYPE == "false" ]]; then
                    FILE=$(echo -e "$FILE")
                    $PRINTF " [F] %-${padding}s %-${padding}s %s\n" "$SIZE" "$FILE" "$MODIFIED"
                fi

            done < "$RESPONSE_FILE"

        #It's a file
        else
            print "FAILED: $DIR_DST is not a directory!\n"
            ERROR_STATUS=1
        fi

    else
        print "FAILED\n"
        ERROR_STATUS=1
    fi
}
</br>
This wil place the modification information into the list function

<li>The Drobpox sh script has to be places in the local forlder: /DropboxUpload/dropbox-uploader.sh >>> Or change the base dir in the sh script</li>
</ul>

<h2>File changes for your maps</h2>
In the first part of the download script you see verious variables, please change these variables if needed to the specific locations in Dropbox and you local storage.
