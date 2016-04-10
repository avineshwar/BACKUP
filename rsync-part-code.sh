
#This is the basic rsync part, modifications are required to complete it and attach it to the main final script.
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
								# spinning a Amazon Linux instance we already have rsync installed in this.
								# As we have the Privilege to spin any instance we have considered amazon Linux
								# Or else we have to check if rsync is installed or not.
								#cmd_check "rsync" "ERROR: rsync utility not found" \
								#"rsync utility found installed..." "RSYNC_CMD"

								aws ec2 run-instances --image-id ami-22111148 --key-name $key --security-groups $USER-EC2-BACKUP-group --count 1 $EC2_BACKUP_FLAGS_AWS > tee
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
								back_vol=$(ssh -o StrictHostKeyChecking=no -i $key.pem ec2-user@$public_ip "/bin/dmesg|grep xvdf|grep 3156|cut -c 29-32")
								echo $?
								if [ $(echo $?) != 0 ]
								then
        							echo "exit code is not 0"
        							exit 1
								ssh -o StrictHostKeyChecking=no -i $key.pem ec2-user@$public_ip "sudo mkfs -t ext4 /dev/xvdf"
								echo $?
								if [ $(echo $?) != 0 ]
								then
        							echo "exit code is not 0"
        							exit 1
								ssh -o StrictHostKeyChecking=no -i $key.pem ec2-user@$public_ip "sudo mkdir /mnt/backupdir"
								echo $?
								if [ $(echo $?) != 0 ]
								then
        							echo "exit code is not 0"
        							exit 1
								ssh -o StrictHostKeyChecking=no -i $key.pem ec2-user@$public_ip "sudo mount /dev/sdf /mnt/backupdir"
								echo $?
								if [ $(echo $?) != 0 ]
								then
        							echo "exit code is not 0"
        							exit 1
								#The test was done in many ways few of them to was to undertand what is the difference we see when we use one option and when we dont use.
								#For example when we used -R we were to obtain the complete the structure of the source.
								#In this case we dont need this but if the user wants the complete structure we can impliment.
								#File of any size is being transferred was tested.
								rsync -avzre "ssh -o StrictHostKeyChecking=no -i $key.pem" --rsync-path="sudo rsync" $dir_to_backup ec2-user@$public_ip:/mnt/backupdir &>/dev/null
								# output suppressing might be required (something more than just removing "v"). Please check for every command.
						fi
								echo $?
								ssh -o StrictHostKeyChecking=no -i $key.pem root@$public_ip "/bin/umount /mnt/backupdir"
								echo $?
								if [ $(echo $?) != 0 ]
								then
        							echo "exit code is not 0"
        							exit 1
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

