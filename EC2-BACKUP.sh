#!/bin/sh -
# The "-" says that there are no more shell options; this is a security feature to prevent certain kinds of spoofing attacks.

#===================================================================================#
#       title          :EC2-BACKUP                                                  #
#       description    :Backs up a local directory to an AWS EC2 cloud volume       #
#       author(s)      :Avineshwar; Greg; Sonal;			            #
#       date           :20160410                                                    #
#       maintainer(s)  :Avineshwar Pratap Singh                                     #
#       version        :0.1.2                                                       #
#                                                                                   #
#       P.S. :: Alphabetical order naming system                                    #
#===================================================================================#

###### printhelp function prints the help page ######
# Check for a volume's filesystem (when given as an argument) before moving ahead with the backup.
# When a user gives a volume, give an advisory warning that the chosen method expects a certain filesystem to exist if the
# volume is given by the user in advance. Also, suggest to exit the script (Ctrl+D or option-based) and restart it without any # volume argument specified.
# Post enquiry, if the filesystem doesn't match some minimum filesystem requirement, rollback (or rearrange the script post
# considering every possibility) and exit 1.
# Improve the error messages to actually say specific error. To do that, consider more checks and use them to narrow down the
# possibilities.

###### printhelp function prints the help page ######
printhelp() {
        echo "
     ec2-backup accepts the following command-line flags:

     -h            Print a usage statement and exit.

     -m method     Use the given method to perform the backup.  Valid methods
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
if $EC2_BACKUP_VERBOSE
then
        echo $EC2_BACKUP_VERBOSE is the verbose flag.
        echo "creating a NetBSD instance for dd-based backup..."
fi

# "ami-569ed93c" is the AMI-ID for NetBSD.
aws ec2 run-instances --image-id ami-569ed93c --key-name "$key" --security-groups "$USER-EC2-BACKUP-group" --count 1 "$EC2_BACKUP_FLAGS_AWS" > tee
availability_zone=`cat tee | egrep -o 'us-.{6,7}|eu-.{6,10}|ap-.{11,12}|sa-.{6,7}'`
instance_id=`cat tee | egrep -o '\Wi-.{8}' | egrep -o 'i-.{8}'`
if [ "$avail_zone_of_user_vol" != "$availability_zone" ] && [ "$rollback_vol" != "1" ]
then
        error_differentiator=1
        delete_instance_key_group
        exit 1
fi

}

###### creates an instance for rsync ######
create_rsync_instance () {
if $EC2_BACKUP_VERBOSE
then
        echo "creating an Amazon-Linux instance for rsync-based backup..."
fi

# "ami-22111148" is the AMI-ID for Amazon Linux.
aws ec2 run-instances --image-id ami-22111148 --key-name "$key" --security-groups "$USER-EC2-BACKUP-group" --count 1 "$EC2_BACKUP_FLAGS_AWS" > tee
availability_zone=`cat tee | egrep -o 'us-.{6,7}|eu-.{6,10}|ap-.{11,12}|sa-.{6,7}'`
instance_id=`cat tee | egrep -o '\Wi-.{8}' | egrep -o 'i-.{8}'`

if [ "$avail_zone_of_user_vol" != "$availability_zone" ] && [ "$rollback_vol" != "1" ]
then
        error_differentiator=1
        delete_instance_key_group
        exit 1
fi
}

###### Rollbacker ######
delete_instance_key_group () {
if $EC2_BACKUP_VERBOSE
then
if [ "$error_differentiator" = "1" ]
then
        echo "Error. Availability zones differ. Script is rolling back."
        echo "Roll back will take 60 seconds."
        echo "$availability_zone was the availability zone of the instance."
        echo "$avail_zone_of_user_vol is the availability zone of the volume."
        aws ec2 terminate-instances --instance-id "$instance_id" > /dev/null
        echo "$? is the return code for instance termination. It should be 0."
        sleep_counter=1
        state=$(aws ec2 describe-instances --instance-id "$instance_id" | egrep "(\"Name\": \"\w+\")"|cut -d '"' -f4)
        instance_status_check="terminated"
        while [ "$state" != "$instance_status_check" ]
        do
                state=$(aws ec2 describe-instances --instance-id "$instance_id" | egrep "(\"Name\": \"\w+\")"|cut -d '"' -f4)
                sleep 10
                sleep_counter=$(( sleep_counter + 1 ))
        done
		sleep_counter=$(( sleep_counter * 10 ))
        echo "slept for "$sleep_counter" seconds"
        echo "current state is: "$state""
        # sleep 160
        # this sleep is necesary for the security group to believe that the instance is gone for good (i.e., its status is terminated).
        if [ "$rollback_sg" = "1" ]
        then
                # delete the sg and key (if created).
                aws ec2 delete-security-group --group-name "$USER-EC2-BACKUP-group"
                #>/dev/null 2>&1
                echo "$? is the return code for security-group deletion. It should be 0."
        fi
        if [ "$rollback_key" = "1" ]
        then
                aws ec2 delete-key-pair --key-name "$key" >/dev/null 2>&1
                echo "$? is the return code for key deletion from EC2."
                rm -f "$key".pem
                echo "$? is the return code for key deletion locally."
        fi
else
        # we are here for cleanup post a successful backup session.
        aws ec2 terminate-instances --instance-id "$instance_id" >/dev/null
        echo "$? is the return code for instance termination. It should be 0."
        sleep_counter=1
        state=$(aws ec2 describe-instances --instance-id "$instance_id" | egrep "(\"Name\": \"\w+\")"|cut -d '"' -f4)
        instance_status_check="terminated"
        while [ "$state" != "$instance_status_check" ]
        do
                state=$(aws ec2 describe-instances --instance-id "$instance_id" | egrep "(\"Name\": \"\w+\")"|cut -d '"' -f4)
                sleep 10
                sleep_counter=$(( sleep_counter + 1 ))
        done
        sleep_counter=$(( sleep_counter * 10 ))
        echo "slept for "$sleep_counter" seconds"
        echo "current state is: "$state""
        # sleep 60
        # this sleep is necesary for the security group to believe that the instance is gone for good (i.e., its status is terminated).
        if [ "$rollback_sg" = "1" ]
        then
                aws ec2 delete-security-group --group-name "$USER-EC2-BACKUP-group"
                #>/dev/null 2>&1
                echo "$? is the return code for security-group deletion. It should be 0."
        fi
        if [ "$rollback_key" = "1" ]
        then
                aws ec2 delete-key-pair --key-name "$key" >/dev/null 2>&1
                echo "$? is the return code for key deletion from EC2. It should be 0."
                rm -f $key.pem
                echo "$? is the return code for key deletion locally. It should be 0."
        fi
fi

### non-verbose counterpart ###
else
if [ "$error_differentiator" = "1" ]
then
        aws ec2 terminate-instances --instance-id "$instance_id" > /dev/null
        sleep_counter=1
        state=$(aws ec2 describe-instances --instance-id "$instance_id" | egrep "(\"Name\": \"\w+\")"|cut -d '"' -f4)
        instance_status_check="terminated"
        while [ "$state" != "$instance_status_check" ]
        do
                state=$(aws ec2 describe-instances --instance-id "$instance_id" | egrep "(\"Name\": \"\w+\")"|cut -d '"' -f4)
                sleep 10
                sleep_counter=$(( sleep_counter + 1 ))
        done
		sleep_counter=$(( sleep_counter * 10 ))
        # sleep 160
        # this sleep is necesary for the security group to believe that the instance is gone for good (i.e., its status is terminated).
        if [ "$rollback_sg" = "1" ]
        then
                # delete the sg and key (if created).
                aws ec2 delete-security-group --group-name "$USER-EC2-BACKUP-group"
                #>/dev/null 2>&1
        fi
        if [ "$rollback_key" = "1" ]
        then
                aws ec2 delete-key-pair --key-name "$key" >/dev/null 2>&1
                rm -f "$key".pem
        fi
else
        # we are here for cleanup post a successful backup session.
        aws ec2 terminate-instances --instance-id "$instance_id" >/dev/null
        sleep_counter=1
        state=$(aws ec2 describe-instances --instance-id "$instance_id" | egrep "(\"Name\": \"\w+\")"|cut -d '"' -f4)
        instance_status_check="terminated"
        while [ "$state" != "$instance_status_check" ]
        do
                state=$(aws ec2 describe-instances --instance-id "$instance_id" | egrep "(\"Name\": \"\w+\")"|cut -d '"' -f4)
                sleep 10
                sleep_counter=$(( sleep_counter + 1 ))
        done
        sleep_counter=$(( sleep_counter * 10 ))
        # sleep 60
        # this sleep is necesary for the security group to believe that the instance is gone for good (i.e., its status is terminated).
        if [ "$rollback_sg" = "1" ]
        then
                aws ec2 delete-security-group --group-name "$USER-EC2-BACKUP-group"
                #>/dev/null 2>&1
        fi
        if [ "$rollback_key" = "1" ]
        then
                aws ec2 delete-key-pair --key-name "$key" >/dev/null 2>&1
                rm -f $key.pem
        fi
fi
fi
}
###### Rollbacker (with volume deletion for failures during backup) ######
# not being used for now.
delete_instance_key_group_volume () {
aws ec2 terminate-instances --instance-id "$instance_id" >/dev/null

if $EC2_BACKUP_VERBOSE
then
        echo "$? is the return code for instance termination. It should be 0."
fi

sleep 60
# this sleep is necessary for the security group to believe that the instance is gone for good (i.e., its status is terminated).
if [ "$rollback_sg" = 1 ]
then
        aws ec2 delete-security-group --group-name "$USER-EC2-BACKUP-group" >/dev/null 2>&1
        if $EC2_BACKUP_VERBOSE
        then
                echo "$? is the return code for group deletion. It should be 0."
        fi
fi
if [ "$rollback_key" = "1" ]
then
        aws ec2 delete-key-pair --key-name "$key" >/dev/null 2>&1
        if $EC2_BACKUP_VERBOSE
        then
                echo "$? is the return code for key pair deletion. It should be 0."
        fi
        rm -f "$key".pem
        if $EC2_BACKUP_VERBOSE
        then
                echo "$? is the return code for key deletion locally. It should be 0."
        fi
fi
if [ "$rollback_vol" = "1" ]
then
        aws ec2 delete-volume --volume-id "$volume_id" >/dev/null 2>&1
        if $EC2_BACKUP_VERBOSE
        then
                echo "$? is the return code for tool-created volume deletion. It should be 0."
        fi
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
                        *)      echo "Bad argument -m method \n Valid options are dd or rsync.\n" usage; exit 1;;
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
elif [ ! -d "$dir_to_backup" ] #&& [ "$dir_to_backup" != "/" ]
then
        echo "$dir_to_backup is not an existing directory"
        exit 1
fi

###### Determine backup volume size if a volume was not specified. ######
if [ -z "$volume_id" ]
then
        backup_volume_size=`du -s $dir_to_backup 2>/dev/null | cut -f1`
        backup_volume_size=`echo $(($backup_volume_size * 2))`
        backup_volume_size=`echo $(($backup_volume_size / 1024))`
        backup_volume_size=`echo $(($backup_volume_size / 1024))`
        backup_volume_size=`echo $(($backup_volume_size + 2))`
fi

###### Print out parameter settings if verbose option set ######
if $EC2_BACKUP_VERBOSE
then
        printf "\n\nEC2-BACKUP has been invoked with the following options:\n"
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
        ### MODIFY "$USER-EC2-BACKUP-key" TO SOMETHING ELSE HERE TO CREATE A KEY WITH A DIFFERENT NAME" ###
        aws ec2 create-key-pair --key-name "$USER-EC2-BACKUP-key" --query 'KeyMaterial' --output text > "$USER-EC2-BACKUP-key".pem && chmod 400 "$USER-EC2-BACKUP-key".pem >/dev/null 2>&1
        if [ $(echo $?) != 0 ]
        then
                rollback_key=0
                echo "key is already existing. Edit the script for compatibility or remove that key from EC2, please."
                exit 1
        else
                rollback_key=1
                echo "key created"
                #echo "the key material is this:"
                #cat $USER-EC2-BACKUP-key.pem
                key="$USER-EC2-BACKUP-key"
                #; echo $?
        fi
else
        rollback_key=0
        # If the key flag was set, check if the identity_file flag is set
        flag=$(echo "$EC2_BACKUP_FLAGS_SSH" | cut -d " " -f1)
        key=$(echo "$EC2_BACKUP_FLAGS_SSH" | cut -d " " -f2)
        if [ "$flag" != -i ]
        then
                echo "EC2_BACKUP_FLAGS_SSH must set the identity file flag. Any other flags are not supported."
                exit 1
        fi

        # Check if the keyfile is valid
        if [ -e "$key" ]
        then
                echo "EC2_BACKUP_FLAGS_SSH environment variable set with an invalid or non-readable keyfile"
                exit 1
        fi

        # If verbose option is set dusplay flag info
        if $EC2_BACKUP_VERBOSE
        then
                echo "\nEC2_BACKUP_FLAGS_AWS: $EC2_BACKUP_FLAGS_AWS"
                         "EC2_BACKUP_FLAGS_SSH: $EC2_BACKUP_FLAGS_SSH"
                echo "keyfile found at $key"
        fi
fi

###### Create security group ######
### MODIFY "$USER-EC2-BACKUP-group" TO SOMETHING ELSE HERE TO CREATE A GROUP WITH A DIFFERENT NAME" ###
aws ec2 create-security-group --group-name "$USER-EC2-BACKUP-group" --description "EC2-BACKUP-tool" >/dev/null 2>&1
if [ $? != "0" ]
then
        rollback_sg=0
        echo "Error creating the security group with name $USER-EC2-BACKUP-group"
        delete_instance_key_group
        exit 1
        if [ "$rollback_key" = "1" ]
        then
                aws ec2 delete-key-pair --key-name "$key" >/dev/null 2>&1
                echo "$? is the return code for key deletion from EC2."
                rm -f $key.pem
                echo "$? is the return code for key deletion locally."
        fi
        exit 1
else
        rollback_sg=1
        aws ec2 authorize-security-group-ingress --group-name "$USER-EC2-BACKUP-group" --port 22 --protocol tcp --cidr 0.0.0.0/0 >/dev/null 2>&1
fi

# Verbose print sg info
if $EC2_BACKUP_VERBOSE
then
        echo "Created security group"
        echo "  Group name: $USER-EC2-BACKUP-group"
        echo "  Port: 22"
        echo "  Protocol: TCP"
        echo "  CIDR IP range: 0.0.0.0/0" # it should be restricted only to the current public IP
fi

###### Instance creation & volume creation (if not provided) ######

if $EC2_BACKUP_VERBOSE
then
        if [ "$method" = "dd" ] || [ -z "$method" ]
        then
                #### verbose starts ####
                if [ -z "$volume_id" ]
                then
                        rollback_vol=1
                        echo "$key is my key"

                        create_dd_instance
                        sleep 225
                        volume_id=$(aws ec2 create-volume --size $backup_volume_size --volume-type gp2 --availability-zone $availability_zone | egrep -o 'vol-.{8}')
                        echo "$volume_id is ID of the newly volume ($availability_zone is the zone)."
                        sleep 45
                        aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/sdf >/dev/null
                        echo "Created volume is now attached to the instance with id $instance_id"
                        sleep 45 # necessary to make the volume accessible post attachment.
                        public_ip=$(aws ec2 describe-instances --output text | egrep $instance_id | cut -f16)
                        echo "$public_ip is the public IP address of the created instance."
                        # ssh -o StrictHostkeyChecking=no -i $key.pem root@$public_ip "/sbin/newfs /dev/xbd3a && mkdir /mnt/mount_point && /sbin mount /dev/xbd3a /mnt/mount_point" 2>/dev/null
                        # echo "Backup volume filesystem: Unix FFS"
                else
                        avail_zone_of_user_vol=$(aws ec2 describe-volumes --output text | grep $volume_id | cut -f2)
                        create_dd_instance
                        sleep 225
                        aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/sdf 2>/dev/null
                        echo "Volume is now attached to the instance with id $instance_id"
                        sleep 45 # necessary to make the volume accessible post attachment.
                        public_ip=$(aws ec2 describe-instances --output text | egrep $instance_id | cut -f16)
                        fs_check=$(ssh -o StrictHostkeyChecking=no -i $key.pem root@$public_ip "file -s /dev/xbd3a" | cut -d ' ' -f2)
                        if [ "$fs_check" = "data" ]
                        then
                                echo "The volume is raw. Using it now."
                                #ssh -o StrictHostkeyChecking=no -i $key.pem root@$public_ip "/sbin/newfs /dev/xbd3a && mkdir /mnt/mount_point && /sbin/mount /dev/xbd3a /mnt/mount_point"

                        else
                                echo "The volume is not raw. Hoping it to be a supported one."
                                ssh -o StrictHostkeyChecking=no -i $key.pem root@$public_ip "mkdir /mnt/mount_point && /sbin/mount /dev/xbd3a /mnt/mount_point"
                                if [ $(echo $?) != 0 ]
                                then
                                        echo "Unsupported filesystem is present on the volume. Rolling back and exiting..."
                                        delete_instance_key_group
                                        exit 1
                                fi
                        fi
                fi
        else
                if [ "$method" = "rsync" ]
                then
                        if [ -z "$volume_id" ]
                        then
                                rollback_vol=1
                                create_rsync_instance
                                echo "done creating the instance"

                                # Wait loop for instance spooling
                                sleep 225
                                volume_id=$(aws ec2 create-volume --size $backup_volume_size --volume-type gp2 --availability-zone $availability_zone | egrep -o 'vol-.{8}')
                                sleep 45
                                aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/sdf >/dev/null

                                sleep 45
                                public_ip=$(aws ec2 describe-instances --output text | egrep $instance_id | cut -f16)
                                back_vol=$(ssh -o StrictHostkeyChecking=no -i $key.pem ec2-user@$public_ip "/bin/dmesg|grep xvdf|grep 3156|cut -c 29-32")
                                ssh -o StrictHostkeyChecking=no -i $key.pem ec2-user@$public_ip "sudo mkfs -t ext4 /dev/xvdf && sudo mkdir /mnt/backupdir && sudo mount /dev/sdf /mnt/backupdir"
                        else
                                avail_zone_of_user_vol=$(aws ec2 describe-volumes --output text | grep $volume_id | cut -f2)
                                create_rsync_instance
                                sleep 225
                                aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/sdf >/dev/null
                                sleep 45 # necessary to make the volume accessible post attachment.
                                public_ip=$(aws ec2 describe-instances --output text | egrep $instance_id | cut -f16)
                                back_vol=$(ssh -o StrictHostkeyChecking=no -i $key.pem ec2-user@$public_ip "/bin/dmesg|grep xvdf|grep 3156|cut -c 29-32")
                                fs_check=$(ssh -o StrictHostkeyChecking=no -i $key.pem ec2-user@$public_ip "sudo file -s /dev/xvdf" | cut -d ' ' -f2)
                                if [ "$fs_check" = "data" ]
                                then
                                        ssh -o StrictHostkeyChecking=no -i $key.pem ec2-user@$public_ip "sudo mkfs -t ext4 /dev/xvdf && sudo mkdir /mnt/backupdir && sudo mount /dev/sdf /mnt/backupdir"
                                else
                                        ssh -o StrictHostkeyChecking=no -i $key.pem ec2-user@$public_ip "sudo mkdir /mnt/backupdir && sudo mount /dev/sdf /mnt/backupdir"
                                fi
                        fi
                fi
        fi      #### verbose ends ####
else
                #### non-verbose part ####
        if [ -z "$method" ] || [ "$method" = "dd" ]
        then
                if [ -z "$volume_id" ]
                then
                        rollback_vol=1
                        create_dd_instance
                        sleep 225

                        volume_id=$(aws ec2 create-volume --size $backup_volume_size --volume-type gp2 -availability-zone $availability_zone | egrep -o 'vol-.{8}')
                        sleep 45
                        aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/sdf >/dev/null

                        # Enter wait loop while volume is attaching
                        sleep 45

                        public_ip=$(aws ec2 describe-instances --output text | egrep $instance_id | cut -f16)
                        #ssh -o StrictHostkeyChecking=no -i $key.pem root@$public_ip "/sbin/newfs /dev/xbd3a && mkdir /mnt/mount_point && /sbin/mount /dev/xbd3a /mnt/mount_point"
                else
                        avail_zone_of_user_vol=$(aws ec2 describe-volumes --output text | grep $volume_id | cut -f2)
                        create_dd_instance
                        sleep 225
                        aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/sdf >/dev/null
                        sleep 45 # necessary to make the volume accessible post attachment.
                        public_ip=$(aws ec2 describe-instances --output text | egrep $instance_id | cut -f16)
                        fs_check=$(ssh -o StrictHostkeyChecking=no -i $key.pem root@$public_ip "file -s /dev/xbd3a" | cut -d ' ' -f2)
                        if [ "$fs_check" = "data" ]
                        then
                                echo # ssh -o StrictHostkeyChecking=no -i $key.pem root@$public_ip "/sbin/newfs /dev/xbd3a && mkdir /mnt/mount_point && /sbin/mount /dev/xbd3a /mnt/mount_point"

                        else
                                echo # ssh -o StrictHostkeyChecking=no -i $key.pem root@$public_ip "mkdir /mnt/mount_point && /sbin/mount /dev/xbd3a /mnt/mount_point"
                        fi
                fi
        else
                if [ "$method" = "rsync" ]
                then
                        if [ -z "$volume_id" ]
                        then
                                rollback_vol=1
                                create_rsync_instance
                                sleep 225
                                volume_id=$(aws ec2 create-volume --size $backup_volume_size --volume-type gp2 --availability-zone $availability_zone | egrep -o 'vol-.{8}')
                                sleep 45
                                aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/sdf >/dev/null
                                sleep 45 # necessary to make the volume accessible post attachment.
                                public_ip=$(aws ec2 describe-instances --output text | egrep $instance_id | cut -f16)
                                back_vol=$(ssh -o StrictHostkeyChecking=no -i $key.pem ec2-user@$public_ip "/bin/dmesg|grep xvdf|grep 3156|cut -c 29-32")
                                ssh -o StrictHostkeyChecking=no -i $key.pem ec2-user@$public_ip "sudo mkfs -t ext4 /dev/xvdf && sudo mkdir /mnt/backupdir && sudo mount /dev/sdf /mnt/backupdir"
                        else
                                avail_zone_of_user_vol=$(aws ec2 describe-volumes --output text | grep $volume_id | cut -f2)
                                create_dd_instance
                                sleep 225
                                aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/sdf >/dev/null
                                sleep 45 # necessary to make the volume accessible post attachment.
                                public_ip=$(aws ec2 describe-instances --output text | egrep $instance_id | cut -f16)
                                back_vol=$(ssh -o StrictHostkeyChecking=no -i $key.pem ec2-user@$public_ip "/bin/dmesg|grep xvdf|grep 3156|cut -c 29-32")
                                fs_check=$(ssh -o StrictHostkeyChecking=no -i $key.pem ec2-user@$public_ip "sudo file -s /dev/xvdf" | cut -d ' ' -f2)
                                if [ "$fs_check" = "data" ]
                                then
                                        ssh -o StrictHostkeyChecking=no -i $key.pem ec2-user@$public_ip "sudo mkfs -t ext4 /dev/xvdf && sudo mkdir /mnt/backupdir && sudo mount /dev/sdf /mnt/backupdir"
                                else
                                        ssh -o StrictHostkeyChecking=no -i $key.pem ec2-user@$public_ip "sudo mkdir /mnt/backupdir && sudo mount /dev/sdf /mnt/backupdir"
                                fi
                        fi
                fi
        fi
fi
###### Backup Method = dd ######

if [ -z "$method" ] || [ "$method" = "dd" ]
then
        if $EC2_BACKUP_VERBOSE
        then
                tar vcf - $dir_to_backup | ssh -o StrictHostkeyChecking=no -i $key.pem root@$public_ip "dd of=/dev/xbd3d conv=noerror,sync"
                #2>/dev/null
                if [ $(echo $?) != 0 ]
                then
                        echo "dd was not 100% successful for the given path."
                        echo "Backup is done for accessible portions only (as the program was not invoked with administrative privileges)."
                        echo "Please wait..."
                        # ssh -o StrictHostkeyChecking=no -i $key.pem root@$public_ip "/sbin/umount /mnt/mount_point"
                        delete_instance_key_group
                        exit 1
                else
                        echo "Backup finished successfully."
                        #ssh -o StrictHostkeyChecking=no -i $key.pem root@$public_ip "/sbin/umount /mnt/mount_point"
                        #echo "unmounted the volume."
            fi
        else
                tar vcf - $dir_to_backup | ssh -o StrictHostkeyChecking=no -i $key.pem root@$public_ip "dd of=/dev/xbd3d conv=noerror,sync" >/dev/null 2>&1
                if [ $(echo $?) != 0 ]
                then
                        echo "Exit status: 1. Please wait..."
                        # ssh -o StrictHostkeyChecking=no -i $key.pem root@$public_ip "/sbin/umount /mnt/mount_point"
                        delete_instance_key_group
                        exit 1
                else
                        echo # ssh -o StrictHostkeyChecking=no -i $key.pem root@$public_ip "/sbin/umount /mnt/mount_point"
            fi
        fi
fi
#echo "Backup finished without any error(s). Backup volume has the volume-id $volume_id"
#echo "Deleting the intermediate creation(s) (security group and/or key)."
#echo "It will take upto 60 seconds. Started..."
#delete_instance_key_group
#echo "Bbye."
#exit 0

###### Backup Method = rsync ######
if [ "$method" = "rsync" ]
then
        if $EC2_BACKUP_VERBOSE
        then
                rsync -avzre "ssh -o StrictHostkeyChecking=no -i $key.pem" --rsync-path="sudo rsync" $dir_to_backup ec2-user@$public_ip:/mnt/backupdir >/dev/null 2>&1
                if [ $(echo $?) != 0 ]
                then
                        echo "Rsync was not 100% successful for the given path."
                        echo "Backup is done for accessible portions only (as the program was not invoked with administrative priviliges)."
                        echo "Please wait..."
                        delete_instance_key_group
                        exit 1
                else
                        ssh -o StrictHostkeyChecking=no -i $key.pem ec2-user@$public_ip "sudo /bin/umount -f /mnt/backupdir"
                        echo "unmounted the volume."
            fi
        else
                rsync -avzre "ssh -o StrictHostkeyChecking=no -i $key.pem" --rsync-path="sudo rsync" $dir_to_backup ec2-user@$public_ip:/mnt/backupdir >/dev/null 2>&1
                if [ $(echo $?) != 0 ]
                then
                        echo "Exit status: 1. Please wait..."
                        ssh -o StrictHostkeyChecking=no -i $key.pem ec2-user@$public_ip "sudo /bin/umount -f /mnt/backupdir"
                        delete_instance_key_group
                        exit 1
                else
                        ssh -o StrictHostkeyChecking=no -i $key.pem ec2-user@$public_ip "sudo /bin/umount -f /mnt/backupdir"
            fi
        fi
fi

###### Clean up and exit ######
#aws ec2 delete-security-group --group-name "$USER-EC2-BACKUP-group" >/dev/null 2>&1
#aws ec2 delete-key-pair --key-name "$key" >/dev/null 2>&1
if $EC2_BACKUP_VERBOSE
then
        echo "Backup finished. Backup volume has the volume-id $volume_id"
        echo "Deleting the intermediate creation(s) (security group and/or key)."
        echo "It will take upto 60 seconds. Started..."
fi
delete_instance_key_group
echo "$volume_id"

exit 0
