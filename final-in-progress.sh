# this is the "almost" base script. I will update it for at least one method in some time.

while getopts 'hm:v:' flag; do
        case ${flag} in
                m)
                        # methods should go in here. follow every acceptable check.
                ;;
                h)      # This should go first.
                        echo hello. This is help.
                        exit 0
                ;;
                
                v)      volume_id="${OPTARG}"
                        if [ ! -z "$volume_id" ]
                        then
                                echo "reachable code."
                        fi
                        echo "$volume_id was the argument"
                        exit 0
                ;;

                *)
                        echo Wrong flag chosen.
                        exit 1
                ;;
        esac
done
exit 0
