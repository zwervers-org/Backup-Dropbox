# Backup from Dropbox to your computer

This BASH script is written because the need of downloading files from Dropbox to a local NAS or HDD so the Dropbox is not running out of memory. 

To work with this script you have to download and install the latest version of Dropbox Upload from GitHub. This version has to be changed to get all motivication data from Dropbox so the script can work properly.


<h2>Dropbox Upload changes</h2>

<h3>Steps</h3>
<ul>
<li>Open de dropbox-uploader.sh file into your favorite editor</li>
<li>Look for the following Function: <i>List</i></li>
<li>Replace this function with the function listed in <i>List-replace</i>
</br>
This wil place the modification information into the list function

<li>The Drobpox sh script has to be places in the local forlder: /DropboxUpload/dropbox-uploader.sh >>> Or change the base dir in the sh script</li>
</ul>

<h2>File changes for your maps</h2>
In the first part of the download script you see verious variables, please change these variables if needed to the specific locations in Dropbox and you local storage.
