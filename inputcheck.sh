#!/bin/sh

printhelp(){
	echo "
     ec2-backup accepts the following command-line flags:

     -h 	   Print a usage statement and exit.

     -m method	   Use the given method to perform the backup.	Valid methods
		   are 'dd' and 'rsync'; default is 'dd'.

     -v volume-id  Use the given volume instead of creating a new one.

     -d directory  Backup the given directory (default is current)
	"
	exit 0;
}

usage() {
	echo usage: `basename $0` '[-h] [-m method] [-v volume-id] directory'
	exit 1
}



checkvolume () {
	if [ -z "$volume_id" ]
	then
		echo "-v invoked with no parameter value"; usage; exit 1
	fi
	aws ec2 describe-volumes --volume-id $volume_id 1>/dev/null 2>/dev/null
    if [ $(echo $?) != 0 ]
    then
    	echo "$volume_id does not exist"
    	exit 1
    fi
}

verbose='true'
key=$EC2_BACKUP_FLAGS_SSH
instance_type=$EC2_BACKUP_FLAGS_AWS

while [ $# -gt 0 ] 
do
	case $1 in
		-h) printhelp;;
		-m) 
			case $2 in
			dd) method="$2"; shift; shift;;
			rsync) method="$2"; shift; shift;;
			-*) echo "-m invoked with no parameter value"; usage; exit 1;;
			*) 	echo "Bad argument -m method \n Valid options are dd or rsync.\n" usage; exit 1;;
			esac
			;;
		-v) 
			case $2 in
			-*) echo "-v invoked with no parameter value"; usage; exit 1;;
			*) volume_id="$2"; checkvolume; shift; shift;;
			esac
			;;
		-*) usage;;
		 *) 
		 	if [ $# -gt 1 ] 
		 	then
		 		echo "Directory must be the last line item."; usage
		 	else
		 		$dir_to_backup=$1
		 	fi
		 	;;
	esac
done


if [ -z "$dir_to_backup" ]
    then
    	echo "No directory specified"
    	usage
    	exit 1
fi	

# Print out parameter settings if verbose option set
if [ $verbose = 'true' ]
then
	echo "EC2-BACKUP has been invoked with the following options:"
	echo "Directory to backup = $dir_to_backup"

	if [ -z "$method" ]
	then
		echo "Method = dd (default)"
	else
		echo "Method = $method"
	fi

	if [ -z "$volume_id" ]
	then
		echo "Backup volume unspecified, one will be created."
	else
		echo "Backup Volume = $volume_id" 
	fi
fi

# Check value of the EC2_BACKUP_FLAGS_SSH environment variable. If the flag is not set create a keypair
if [ -z "$EC2_BACKUP_FLAGS_SSH" ]
then
	aws ec2 create-key-pair --key-name $USER-EC2-BACKUP-key --query 'KeyMaterial' --output text > $USER-EC2-BACKUP-key.pem 2>/dev/null && chmod 400 $USER-EC2-BACKUP-key.pem
	if [ $(echo $?) != 0 ]
	then
		rollback_key=0
		echo "Key is already existing. Edit the script for compatibility or remove that key from EC2, please."
		exit 1
	else
		rollback_key=1
		echo "key created"
		key_file=$USER-EC2-BACKUP-key; echo $?
	fi
else
	rollback_key=0
	# If the key flag was set, check if the identity_file flag is set
	if echo "$EC2_BACKUP_FLAGS_SSH" | grep -q "[-i\s+\w+]"
	then
		key_file=$(echo $EC2_BACKUP_FLAGS_SSH | tr -s ' ' | cut -d " " -f2)
	else
		echo "EC2_BACKUP_FLAGS_SSH must set the identity file flag only"
		exit 1
	fi

	# Check if key file exists and is readable
	if [ -e "$key_file" ]
	then
		if [ $verbose = 'true' ]
		then
			echo "EC2_BACKUP_FLAGS_SSH environment variable set too $EC2_BACKUP_FLAGS_SSH"
			echo "Keyfile found at $key_file"
		fi
	else
		echo "EC2_BACKUP_FLAGS_SSH environment variable set with an invalid or non-readable keyfile"
		exit 1
	fi
fi

exit 0
