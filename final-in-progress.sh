# this is the "almost" base script. I will update it for at least one method in some time.

# SET VARIABLES
verbose=$EC2_BACKUP_VERBOSE
key=$EC2_BACKUP_FLAGS_SSH
instance_type=$EC2_BACKUP_FLAGS_AWS

# for now.
dir_to_backup="$PWD"

# dir_to_backup="$1"

backup_volume_size=`du -s $dir_to_backup 2>/dev/null | cut -f1`
backup_volume_size=`echo $(($backup_volume_size * 2))`
backup_volume_size=`echo $(($backup_volume_size / 1024))`
backup_volume_size=`echo $(($backup_volume_size / 1024))`
backup_volume_size=`echo $(($backup_volume_size + 1))`

if [ -z "key" ]
then
		aws ec2 create-key-pair --key-name $USER-EC2-BACKUP-key --query 'KeyMaterial' --output text > $USER-EC2-BACKUP-key.pem && chmod 400 $USER-EC2-BACKUP-key.pem; echo $?
		key=$USER-EC2-BACKUP-key; echo $?
		aws ec2 create-security-group --group-name $USER-EC2-BACKUP-group --description "EC2-BACKUP-tool" > /dev/null && aws ec2 authorize-security-group-ingress --group-name $USER-EC2-BACKUP-group --port 22 --protocol tcp --cidr 0.0.0.0/0 > /dev/null
		
		# create security group as well.
		# use "&&" or ";" if making sure the first command exited successfully, is necessary.
		# "&&" won't let the second command execute if, the first one fails.
		aws ec2 create-security-group --group-name $USER-EC2-BACKUP-group --description "EC2-BACKUP-tool" > /dev/null && aws ec2 authorize-security-group-ingress --group-name $USER-EC2-BACKUP-group --port 22 --protocol tcp --cidr 0.0.0.0/0 > /dev/null
echo $?
else
fi

while getopts 'hm:v:' flag; do
        case ${flag} in
                h)      # This should go first.
                        echo hello. This is help.
                        exit 0
                ;;
                
				m)		method="${OPTARG}"
						if [ "$method" == "dd" -o -z "$method" ]
						then
								# done above. dir_to_backup="$1"
								# spinning a NetBSD instance.
								aws ec2 run-instances --image-id ami-569ed93c --key-name $key --security-groups $USER-EC2-BACKUP-group --count 1 $EC2_BACKUP_FLAGS_AWS > tee
								availability_zone=`cat tee | egrep -o 'us-.{6,7}|eu-.{6,10}|ap-.{11,12}|sa-.{6,7}'`
								instance_id=`cat tee | egrep -o '\Wi-.{8}' | egrep -o 'i-.{8}'`
								volume_id=`aws ec2 create-volume --size $backup_volume_size --volume-type gp2 --availability-zone $availability_zone | egrep -o 'vol-.{8}'`
								aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/sdf > /dev/null
								echo "Going to sleep"
								sleep 225
								echo "Woke up"
								# fetch public-ip/public-dns to log in"
								public_ip=$(aws ec2 describe-instances --output text | egrep $instance_id | cut -f16)
								ssh -o StrictHostKeyChecking=no -i $key.pem root@$public_ip "back_vol=`dmesg|tail - 1 | cut -d : -f1` ; mkdir /mnt/mount_point ; newfs /dev/r$back_vola ; mount /dev/$back_vola /mnt/mount_point/"								
								tar zvcf - $dir_to_backup | ssh -o StrictHostKeyChecking=no -i $key.pem root@$public_ip "back_vol=`dmesg|tail - 1 | cut -d : -f1` ; dd of=/dev/$back_vol" | 2>/dev/null
						fi
								echo $?
								exit 0
                        # methods should go in here. follow every acceptable check.
                ;;
                
                v)      volume_id="${OPTARG}"
                        if [ ! -z "$volume_id" ]
                        then
                                echo "reachable code."
                        fi
                        echo "$volume_id was the argument"
                ;;

                *)
                        echo Wrong flag chosen.
                        exit 1
                ;;
        esac
done
exit 0
