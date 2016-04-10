#!/bin/sh

dir_to_backup="$3"

### IS FOR THE HEADING.
## IS THE STATEMENT AND,
# IS THE STATEMENT CONTINUED.


### TO IMPLEMENT:
## POSSIBLE REGEX (FOR KEY VARIABLE)
# myregex="-i\s+~\/.\w{3}\/\w+"
# x="-i     ~/.abc/adsajdjla"
# if [[ $x =~ [^$myregex] ]]; then echo hello; fi
## IF A USER GIVES A VOLUME, IT HAS TO CHECK WHETHER IT IS POSSIBLE TO FIT THE GIVEN PATH. IF NOT, EXIT 1.
## WHEN THE VOLUME ID IS PROVIDED, IT HAS TO FOLLOW ITS REGEX, SHOULD ALWAYS BE THE FOURTH ARGUMENT.
## MANY OTHER THINGS TO FIX. NOTED IN ANOTHER FILE.
## IF A VOLUME ID IS PROVIDED, BEFORE FORMATTING IT, TRY TO CHECK FOR A FILESYSTEM IN THAT AND ACCORDINGLY EITHER FORMAT IT OR DIRECTLY MOUNT AND USE IT.
## CHECK IF THE KEY IS HAVING 400 PERMISSIONS OR NOT; IF NOT, SLEEP FOR A MINUTE TO GIVE USER A CHANCE TO FIX IT BEFORE EXITING.
## WE CAN ALSO TEMPORARILY CHANGE IT AND ROLL IT BACK.

### EXTRAS:
## INTERRUPTS. IF GIVEN, SHOULD GIVE RISE TO ROLLBACK. ALTERNATIVELY, A WARNING AND A ROLLBACK. MAYBE SOMETHING LIKE CREATING A FILE SOMEWHERE WHICH GETS CREATED WITH CERTAIN INFORMATION
# IF AN INTERRUPT IS RECEIVED AS A LOG FOR THE SCRIPT OWNER TO CHECK WHETHER THE SCRIPT WAS DISTURB DURING THE PROCESS.


echo "Failures are with exit code 1 and success with 0"
echo "number of arguments is/are $#"
echo "Right now, the assumption says that the user is going to enter arguments in a described correct order"
echo "That means, expected number of argument can be 3 or 5"
echo "For 3 arguments, it can be \"-m dd/rsync dir_to_backup\""
echo "For 5 arguments, it can be \"-m dd/rsync -v an_existing_volume_id_here dir_to_backup\""
echo "This script will try to handle other kind of errors upto some extent"
echo "Whenever there is something to test, use exit 0 just after that/before that (depends what you are looking for)."

if [ "$dir_to_backup" == "-v" -o "$dir_to_backup" == "-m" -o "$dir_to_backup" == "-h" ]
then
	dir_to_backup="$5"
	if [ ! -z "$dir_to_backup" ]
	then
		echo $dir_to_backup is the directory to backup.
	else
		exit 1
	fi
else
	echo $dir_to_backup is the directory to backup.
fi
#exit 0
while getopts 'hm:v:' flag; do
        case ${flag} in
                h)      # This should go first.
                        echo hello. This is help.
                        exit 0
                ;;
                
				                
                v)      volume_id="${OPTARG}"
                        echo "$volume_id was the argument"
                ;;

		m)		method="${OPTARG}"
						if [ "$method" == "dd" -o -z "$method" ]
						then
								# SET VARIABLES
verbose=$EC2_BACKUP_VERBOSE
key=$EC2_BACKUP_FLAGS_SSH
instance_type=$EC2_BACKUP_FLAGS_AWS

echo $?
echo "$dir_to_backup is the path to backup"
echo $?
backup_volume_size=`du -s $dir_to_backup 2>/dev/null | cut -f1`
echo $?
backup_volume_size=`echo $(($backup_volume_size * 2))`
echo $?
backup_volume_size=`echo $(($backup_volume_size / 1024))`
echo $?
backup_volume_size=`echo $(($backup_volume_size / 1024))`
echo $?
backup_volume_size=`echo $(($backup_volume_size + 2))`
echo $?

if [ -z "$key" ]
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
			key=$USER-EC2-BACKUP-key; echo $?
		fi
		# create security group as well.
		# use "&&" or ";" if making sure the first command exited successfully, is necessary.
		# "&&" won't let the second command execute if, the first one fails.
		aws ec2 create-security-group --group-name $USER-EC2-BACKUP-group --description "EC2-BACKUP-tool" &>/dev/null
		if [ $(echo $?) != 0 ]
		then
			rollback_sg=0
			echo "Error creating the security group with name $USER-EC2-BACKUP-group."
			if [ "$rollback_key" == 1 ]
			then
				aws ec2 delete-key-pair --key-name $key &>/dev/null
				echo "$? is the return code for key deletion from EC2."
				rm -f $key.pem
				echo "$? is the return code for key deletion locally."
			fi
			exit 1
		else
			rollback_sg=1
			echo "SG is fine. Continuing..."
			aws ec2 authorize-security-group-ingress --group-name $USER-EC2-BACKUP-group --port 22 --protocol tcp --cidr 0.0.0.0/0 2>/dev/null
			echo $?
		fi
echo "return code $?"
else
		rollback_key=0
		# If we are here, this means key variable is not empty (i.e., $EC2_BACKUP_FLAGS_SSH is set), it HAS TO BE in the following format "~/.ssh/any-key-name" with 400 permission set such that, "~/.ssh/" has to be the path, however, "~" means the home directory. Script will fail if it is not followed (exactly, crisply).
		# We can throw this as an advisory in help. 
		aws ec2 create-security-group --group-name $USER-EC2-BACKUP-group --description "EC2-BACKUP-tool" &>/dev/null
		if [ $(echo $?) != "0" ]
		then
			echo "Error creating the security group with name $USER-EC2-BACKUP-group."
			exit 1
		else
			echo "It is fine. Continue."
			aws ec2 authorize-security-group-ingress --group-name  --port 22 --protocol tcp --cidr 0.0.0.0/0 2>/dev/null
			echo $?
		fi
fi
# exit 0
								
								# done above. dir_to_backup="$1"
								# spinning a NetBSD instance.
								aws ec2 run-instances --image-id ami-569ed93c --key-name $key --security-groups $USER-EC2-BACKUP-group --count 1 $EC2_BACKUP_FLAGS_AWS > tee
								echo $?
								availability_zone=`cat tee | egrep -o 'us-.{6,7}|eu-.{6,10}|ap-.{11,12}|sa-.{6,7}'`
								echo $?
								instance_id=`cat tee | egrep -o '\Wi-.{8}' | egrep -o 'i-.{8}'`
								echo $?
								echo "$volume_id is the volume id just before checking"
								if [ -z "$4" ]
								then
									volume_id=`aws ec2 create-volume --size $backup_volume_size --volume-type gp2 --availability-zone $availability_zone | egrep -o 'vol-.{8}'`
								else
									volume_id="$4"
									echo "$volume_id is the volume id after checking the argument. It's assumed to be valid."
									avail_zone_of_user_vol=$(aws ec2 describe-volumes --output text | grep vol-266b0b8e | cut -f2)
									if [ "$avail_zone_of_user_vol" != "$availability_zone" ]
									then
										echo "Error. Availability zones differ. Script is rolling back."
										echo "Roll back will take 60 seconds."
										echo "$availability_zone was of the instance."
										echo "$avail_zone_of_user_vol is of the volume."
										aws ec2 terminate-instances --instance-id $instance_id > /dev/null
										echo "$? is the return code for instance termination"
										echo "Instance is terminated."
										sleep 60
										if [ "$rollback_sg" == 1 ]
										then
											# delete the sg and key (if created).
											aws ec2 delete-security-group --group-name $USER-EC2-BACKUP-group &>/dev/null
											echo "$? is the return code for sg deletion."
										fi
										if [ "$rollback_key" == 1 ]
										then
											aws ec2 delete-key-pair --key-name $key &>/dev/null
											echo "$? is the return code for key deletion from EC2."
											rm -f $key.pem
											echo "$? is the return code for key deletion locally."
										fi
										exit 1
									fi
									
									
								fi								
								echo $?
								echo "Going to sleep"
								sleep 225
								echo $?
								echo "Woke up"
								aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/sdf > /dev/null
								echo $?
								# fetch public-ip/public-dns to log in"
								# sleep is necesary after attaching the volume to give it some time to become visible.
								sleep 30
								echo $?
								public_ip=$(aws ec2 describe-instances --output text | egrep $instance_id | cut -f16)
								echo $?
								ssh -o StrictHostKeyChecking=no -i $key.pem root@$public_ip "/sbin/newfs /dev/xbd3a && mkdir /mnt/mount_point && /sbin/mount /dev/xbd3a /mnt/mount_point"
								#  && back_vol=`dmesg|tail - 1 | cut -d : -f1` ; mkdir /mnt/mount_point ; newfs /dev/r$back_vola ; mount /dev/$back_vola /mnt/mount_point/"								
								echo $?
								tar zvcf - $dir_to_backup | ssh -o StrictHostKeyChecking=no -i $key.pem root@$public_ip "dd of=/mnt/mount_point/tarfile" &>/dev/null 
								# output suppressing might be required (something more than just removing "v"). Please check for every command.
						fi
								echo $?
								ssh -o StrictHostKeyChecking=no -i $key.pem root@$public_ip "/sbin/umount /mnt/mount_point"
								echo $?
								aws ec2 terminate-instances --instance-id $instance_id > /dev/null
								echo "$? is the return code for instance termination. If a new security group was added, it will be deleted too (and the key, if it was newly created). Checking, please wait..."
								if [ "$rollback_sg" == 1 ]
								then
									echo "Starting the group and/or key deletion process."
									sleep 60
									# delete the sg and key (if created).
									aws ec2 delete-security-group --group-name $USER-EC2-BACKUP-group &>/dev/null
									echo "$? is the return code for sg deletion."
								fi
								if [ "$rollback_key" == 1 ]
								then
									aws ec2 delete-key-pair --key-name $key &>/dev/null
									echo "$? is the return code for key deletion from EC2."
									rm -f $key.pem
									echo "$? is the return code for key deletion locally."
								fi
								echo "Backup volume is $volume_id (Instance is terminated)."
								exit 0
                        # methods should go in here. follow every acceptable check.
                	;;

                *)
                        echo Wrong flag chosen.
                        exit 1
                ;;
        esac
done
exit 0
