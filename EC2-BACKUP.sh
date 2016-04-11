#!/bin/sh
#===================================================================================#
#	title          :EC2-BACKUP                                                  #
#	description    :Backs up a local directory to an AWS EC2 cloud volume       #
#	authors        :Avineshwar Pratap Singh; Gregory Basile; Sonal Mehta;       #
#	date           :20160410                                                    #
#	version        :0.1.0							    #
#										    #
#	P.S. :: Alphabetical order naming system                                    #
#===================================================================================#

###### printhelp function prints the help page ######
printhelp() {
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

###### usage function prints the usage message ######
usage() {
	echo "usage: $(basename $0) [-h] [-m method] [-v volume-id] directory"
	exit 1
}

###### checkvolume function checks if a user provided volume exists ######
checkvolume () {
	if [ -z "$volume_id" ]
	then
		echo "-v invoked with no parameter value"; usage; exit 1
	fi
	aws ec2 describe-volumes --volume-id "$volume_id" >/dev/null 2>&1
    if [ $(echo $?) != 0 ]
    then
    	echo "$volume_id is not an existing volume"
    	exit 1
    fi
}

###### creates an instance for dd ######
create_dd_instance () {
# "ami-569ed93c" is the AMI-ID for NetBSD.
aws ec2 run-instances --image-id ami-569ed93c --key-name $key --security-groups $USER_EC2_BACKUP_group --count 1 $EC2_BACKUP_FLAGS_AWS > tee
availability_zone=`cat tee | egrep -o 'us-.{6,7}|eu-.{6,10}|ap-.{11,12}|sa-.{6,7}'`
instance_id=`cat tee | egrep -o '\Wi-.{8}' | egrep -o 'i-.{8}'`
if [ "$avail_zone_of_user_vol" != "$availability_zone" ]
then
	error_differentiator=1
	delete_instance_key_group
	exit 1	
fi

}

###### creates an instance for rsync ######
create_rsync_instance () {
# "ami-22111148" is the AMI-ID for Amazon Linux.
aws ec2 run-instances --image-id ami-22111148 --key-name $key --security-groups $USER_EC2_BACKUP_group --count 1 $EC2_BACKUP_FLAGS_AWS > tee
availability_zone=`cat tee | egrep -o 'us-.{6,7}|eu-.{6,10}|ap-.{11,12}|sa-.{6,7}'`
instance_id=`cat tee | egrep -o '\Wi-.{8}' | egrep -o 'i-.{8}'`
if [ "$avail_zone_of_user_vol" != "$availability_zone" ]
then
	error_differentiator=1
	delete_instance_key_group
	exit 1	
fi

}

###### Rollbacker ######

delete_instance_key_group () {
if [ "$error_differentiator" == 1 ]
then
	echo "Error. Availability zones differ. Script is rolling back."
	echo "Roll back will take 60 seconds."
	echo "$availability_zone was the availability zone of the instance."
	echo "$avail_zone_of_user_vol is the availability zone of the volume."
	aws ec2 terminate-instances --instance-id $instance_id > /dev/null
	echo "$? is the return code for instance termination. It should be 0."
	sleep 60
	# this sleep is necesary for the security group to believe that the instance is gone for good (i.e., its status is terminated).
	if [ "$rollback_sg" == 1 ]
	then
		# delete the sg and key (if created).
		aws ec2 delete-security-group --group-name $USER_EC2_BACKUP_group >/dev/null 2>&1
		echo "$? is the return code for security-group deletion. It should be 0."
	fi
	if [ "$rollback_key" == 1 ]
	then
		aws ec2 delete-key-pair --key-name $key >/dev/null 2>&1
		echo "$? is the return code for key deletion from EC2."
		rm -f $key.pem
		echo "$? is the return code for key deletion locally."
	fi
else		
	# we are here for cleanup post a successful backup session.
	aws ec2 terminate-instances --instance-id $instance_id > /dev/null
	echo "$? is the return code for instance termination. It should be 0."
	sleep 60
	# this sleep is necesary for the security group to believe that the instance is gone for good (i.e., its status is terminated).
	if [ "$rollback_sg" == 1 ]
	then
		aws ec2 delete-security-group --group-name $USER_EC2_BACKUP_group >/dev/null 2>&1
		echo "$? is the return code for security-group deletion. It should be 0."
	fi
	if [ "$rollback_key" == 1 ]
	then
		aws ec2 delete-key-pair --key-name $key >/dev/null 2>&1
		echo "$? is the return code for key deletion from EC2. It should be 0."
		rm -f $key.pem
		echo "$? is the return code for key deletion locally. It should be 0."
	fi
fi
}

###### Rollbacker (with volume deletion for failures during backup) ######

delete_instance_key_group_volume () {
aws ec2 terminate-instances --instance-id $instance_id > /dev/null
echo "$? is the return code for instance termination. It should be 0."
sleep 60
# this sleep is necesary for the security group to believe that the instance is gone for good (i.e., its status is terminated).
if [ "$rollback_sg" == 1 ]
then
	aws ec2 delete-security-group --group-name $USER_EC2_BACKUP_group >/dev/null 2>&1
	echo "$? is the return code for security-group deletion. It should be 0."
fi
if [ "$rollback_key" == 1 ]
then
	aws ec2 delete-key-pair --key-name $key >/dev/null 2>&1
	echo "$? is the return code for key deletion from EC2. It should be 0."
	rm -f $key.pem
	echo "$? is the return code for key deletion locally. It should be 0."
fi
if [ "$rollback_vol" == 1 ]
then
	aws ec2 delete-volume --volume-id "$volume_id" >/dev/null 2>&1
	echo "$? is the return code for tool-created volume deletion. It should be 0."
fi
}

###### Parameter parse ######
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
		 		dir_to_backup=$1; shift
		 	fi
		 	;;
	esac
done

###### Check if directory to backup is a valid directory ######
if [ -z "$dir_to_backup" ]
then
	echo "No directory specified"
	usage
	exit 1
elif [ -d "$dir_to_backup" ] && [ "$dir_to_backup" != "/" ]
then
	echo "$dir_to_backup is not an existing directory"
	exit 1
fi	

###### Determine backup volume size if a volume was not specified. ######
if [ -z "$volume_id" ]
then
	backup_volume_size=$(du -s "$dir_to_backup" 2>/dev/null | cut -f1)
	backup_volume_size=$(($backup_volume_size * 2))
	backup_volume_size=$(($backup_volume_size / 1024))
	backup_volume_size=$(($backup_volume_size / 1024))
	backup_volume_size=$(($backup_volume_size + 2))
fi

###### Print out parameter settings if verbose option set ######
if $EC2_BACKUP_VERBOSE
then
	printf "\nEC2-BACKUP has been invoked with the following options:"
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
		echo "Backup volume size = $backup_volume_size"
	else
		echo "Backup Volume = $volume_id" 
	fi
fi

###### Check value of the EC2_BACKUP_FLAGS_SSH environment variable. If the flag is not set create a keypair ######
if [ -z "$EC2_BACKUP_FLAGS_SSH" ]
then
	aws ec2 create-key-pair --key-name "$USER-EC2-BACKUP-key" --query 'KeyMaterial' --output text > "$USER-EC2-BACKUP-key".pem >/dev/null 2>&1 && chmod 400 "$USER-EC2-BACKUP-key".pem
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
	flag=$(echo "$EC2_BACKUP_FLAGS_SSH" | cut -d " " -f1) 
	key_file=$(echo "$EC2_BACKUP_FLAGS_SSH" | cut -d " " -f2)
	if [ "$flag" != -i ]
	then
		echo "EC2_BACKUP_FLAGS_SSH must set the identity file flag. Any other flags are not supported."
		exit 1
	fi

	# Check if the keyfile is valid
	if [ -e "$key_file" ] 
	then
		echo "EC2_BACKUP_FLAGS_SSH environment variable set with an invalid or non-readable keyfile"
		exit 1
	fi

	# If verbose option is set dusplay flag info
	if $EC2_BACKUP_VERBOSE
	then
		echo "\nEC2_BACKUP_FLAGS_AWS: $EC2_BACKUP_FLAGS_AWS"
			 "EC2_BACKUP_FLAGS_SSH: $EC2_BACKUP_FLAGS_SSH"
		echo "Keyfile found at $key_file"
	fi
fi

###### Create security group ######
aws ec2 create-security-group --group-name "$USER_EC2_BACKUP_group" --description "EC2-BACKUP-tool" 1>/dev/null 2>/dev/null
if [ $? != "0" ]
then
	rollback_sg=0
	echo "Error creating the security group with name $USER_EC2_BACKUP_group."
	if [ "$rollback_key" == 1 ]
	then
		aws ec2 delete-key-pair --key-name "$key" >/dev/null 2>&1
		echo "$? is the return code for key deletion from EC2."
		rm -f $key.pem
		echo "$? is the return code for key deletion locally."
	fi
	exit 1
else
	rollback_sg=1
	aws ec2 authorize-security-group-ingress --group-name "$USER_EC2_BACKUP_group" --port 22 --protocol tcp --cidr 0.0.0.0/0 1>/dev/null 2>/dev/null
fi

# Verbose print sg info
if $EC2_BACKUP_VERBOSE
then
	printf "\nCreated security group"
	echo "Group name: $USER_EC2_BACKUP_group"	
	echo "	Port: 22"
	echo "	Protocol: TCP"
	echo "	CIDR IP range: 0.0.0.0/0"
fi

###### Instance creation & volume creation (if not provided) ######

if [ "$method" == "dd" ]
then
	if [ -z "$volume_id" ]
	then
		rollback_vol=1
		create_dd_instance
		sleep 225
		volume_id=$(aws ec2 create-volume --size $backup_volume_size --volume-type gp2 --availability-zone $availability_zone | egrep -o 'vol-.{8}')
		sleep 30
		aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/sdf >/dev/null
		sleep 30 # necessary to make the volume accessible post attachment.
		public_ip=$(aws ec2 describe-instances --output text | egrep $instance_id | cut -f16)
		ssh -o StrictHostKeyChecking=no -i $key.pem root@$public_ip "/sbin/newfs /dev/xbd3a && mkdir /mnt/mount_point && /sbin/mount /dev/xbd3a /mnt/mount_point"
	else
		avail_zone_of_user_vol=$(aws ec2 describe-volumes --output text | grep $volume_id | cut -f2)
		create_dd_instance
		sleep 225
		aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/sdf >/dev/null
		sleep 30 # necessary to make the volume accessible post attachment.
		public_ip=$(aws ec2 describe-instances --output text | egrep $instance_id | cut -f16)
		ssh -o StrictHostKeyChecking=no -i $key.pem root@$public_ip "/sbin/newfs /dev/xbd3a && mkdir /mnt/mount_point && /sbin/mount /dev/xbd3a /mnt/mount_point"
	fi
else
	if [ "$method" == "rsync" ]
	then
		rollback_vol=1
		create_rsync_instance
		sleep 225
		volume_id=$(aws ec2 create-volume --size $backup_volume_size --volume-type gp2 --availability-zone $availability_zone | egrep -o 'vol-.{8}')
		sleep 30
		aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/sdf >/dev/null
		sleep 30 # necessary to make the volume accessible post attachment.
		public_ip=$(aws ec2 describe-instances --output text | egrep $instance_id | cut -f16)
		back_vol=$(ssh -o StrictHostKeyChecking=no -i $key.pem ec2-user@$public_ip "/bin/dmesg|grep xvdf|grep 3156|cut -c 29-32")
		ssh -o StrictHostKeyChecking=no -i $key.pem ec2-user@$public_ip "sudo mkfs -t ext4 /dev/xvdf && sudo mkdir /mnt/backupdir && sudo mount /dev/sdf /mnt/backupdir"
	else
		avail_zone_of_user_vol=$(aws ec2 describe-volumes --output text | grep $volume_id | cut -f2)
		create_dd_instance
		sleep 225
		aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/sdf >/dev/null
		sleep 30 # necessary to make the volume accessible post attachment.
		public_ip=$(aws ec2 describe-instances --output text | egrep $instance_id | cut -f16)
		back_vol=$(ssh -o StrictHostKeyChecking=no -i $key.pem ec2-user@$public_ip "/bin/dmesg|grep xvdf|grep 3156|cut -c 29-32")
		ssh -o StrictHostKeyChecking=no -i $key.pem ec2-user@$public_ip "sudo mkfs -t ext4 /dev/xvdf && sudo mkdir /mnt/backupdir && sudo mount /dev/sdf /mnt/backupdir"
fi


###### Backup Method = dd ######

if [ "$method" == "dd" -o -z "$method" ]
then
	if [ "$verbose" = 'true' ]
	then
		tar zvcf - $dir_to_backup | ssh -o StrictHostKeyChecking=no -i $key.pem root@$public_ip "dd of=/mnt/mount_point/tarfile" 2>/dev/null
		if [ $(echo $?) != 0 ]
		then
			delete_instance_key_group_volume
			exit 1
		else
			ssh -o StrictHostKeyChecking=no -i $key.pem root@$public_ip "/sbin/umount -f /mnt/mount_point"	
	    fi
	else
		tar zcf - $dir_to_backup | ssh -o StrictHostKeyChecking=no -i $key.pem root@$public_ip "dd of=/mnt/mount_point/tarfile" >/dev/null 2>&1
		if [ $(echo $?) != 0 ]
		then
			delete_instance_key_group_volume
			exit 1
		else
			ssh -o StrictHostKeyChecking=no -i $key.pem root@$public_ip "/sbin/umount -f /mnt/mount_point"
	fi
fi
#echo "Backup finished without any error(s). Backup volume has the volume-id $volume_id"
#echo "Deleting the intermediate creation(s) (security group and/or key)."
#echo "It will take upto 60 seconds. Started..."
#delete_instance_key_group
#echo "Bbye."
#exit 0

###### Backup Method = rsync ######
if [ "$method" == "rsync" ]
then
	if [ "$verbose" = 'true' ]
	then
		rsync -avzre "ssh -o StrictHostKeyChecking=no -i $key.pem" --rsync-path="sudo rsync" $dir_to_backup ec2-user@$public_ip:/mnt/backupdir &>/dev/null
		if [ $(echo $?) != 0 ]
		then
			delete_instance_key_group_volume
			exit 1
		else
			ssh -o StrictHostKeyChecking=no -i $key.pem root@$public_ip "/bin/umount -f /mnt/backupdir"	
	    fi
	else
		rsync -avzroe "ssh -o StrictHostKeyChecking=no -i $key.pem" --rsync-path="sudo rsync" $dir_to_backup ec2-user@$public_ip:/mnt/backupdir >/dev/null 2>&1
		if [ $(echo $?) != 0 ]
		then
			delete_instance_key_group_volume
			exit 1
		else
			ssh -o StrictHostKeyChecking=no -i $key.pem root@$public_ip "/bin/umount -f /mnt/backupdir"
	    fi
	fi    
fi

###### Clean up and exit ######
#aws ec2 delete-security-group --group-name "$USER_EC2_BACKUP_group" >/dev/null 2>&1
#aws ec2 delete-key-pair --key-name "$key" >/dev/null 2>&1
echo "Backup finished without any error(s). Backup volume has the volume-id $volume_id"
echo "Deleting the intermediate creation(s) (security group and/or key)."
echo "It will take upto 60 seconds. Started..."
delete_instance_key_group
echo "Bbye."


exit 0
