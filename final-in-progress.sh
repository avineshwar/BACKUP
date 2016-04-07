# this is the "almost" base script. I will update it for at least one method in some time.

while getopts 'hm:v:' flag; do
        case ${flag} in
                m)
                      #  egrep -o '([0-9a-fA-F][0-9a-fA-F]:){4,5}([0-9a-fA-F][0-9a-fA-F])'
                      #  exit 0
                      #  #doesn't works correctly on OmniOS. After fixing, check for other OSes too.
                ;;
                h)      echo hello. This is help.
                ;;
                v)      volume_id="${OPTARG}"
                        if [ ! -z $avineshwar ]
                        then
                                echo reachable code.
                        fi
                        echo $avineshwar was the argument

                ;;
                *)
                        echo Wrong flag chosen.
                        exit 1
                ;;
        esac
done
