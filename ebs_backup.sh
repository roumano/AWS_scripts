#!/bin/bash


function usage {
	echo -e "
   $(basename $0) \033[1m--action backup|delete\033[0m [--instance \033[1minstanceID\033[0m] [--debug] [--monochrome] [--region region]
     - \033[1minstanceID\033[0m   Specify Instance ID to backup [available only with --action backup]
     - \033[4mregion\033[0m       Change default region
     - \033[4mage\033[0m       	  Age in day for deleting backup [available only with --action delete]
     - \033[4mfilters\033[0m      Specify witch server with tag-value we will backup (default : prod*)
     - \033[4mdebug\033[0m        Debug mode will not delete temp file
     - \033[4mmonochrome\033[0m   Disable color mode in output
     - \033[4mdry-run\033[0m      Only show what will be done
	"
}



function backup_ebs () {
    
    instances=$(aws ec2 describe-instances ${extra_args} --filters "Name=tag-value,Values=${filters:-prod*}" | jq -r ".Reservations[].Instances[].InstanceId")

    for instance in ${instances}
    do  
		if [[ -n ${instanceID} ]] && [[ ${instance} != "${instanceID}" ]] ; then continue ; fi
        volumes=$(aws ec2 describe-volumes ${extra_args} --filter Name=attachment.instance-id,Values=${instance} | jq -r ".Volumes[].VolumeId")
        
        for volume in ${volumes}
        do
            echo Creating snapshot for ${Red}${volume}${ResetColor} :
            if [ "${DRY}" ] ; then
                echo "aws ec2 create-snapshot ${extra_args} --volume-id ${volume} --description \"ebs-backup-script\""
            else
                aws ec2 create-snapshot ${extra_args} --volume-id ${volume} --description "ebs-backup-script"
	    fi	
        done

    done
}


function delete_snapshots () {
    
    for snapshot in $(aws ec2 describe-snapshots ${extra_args} --filters Name=description,Values=ebs-backup-script | jq ".Snapshots[].SnapshotId")
    do
        SNAPSHOTDATE=$(aws ec2 describe-snapshots ${extra_args} --filters Name=snapshot-id,Values=$snapshot | jq -r ".Snapshots[].StartTime")
        STARTDATE=$(date +%s)
        ENDDATE=$(date -d ${SNAPSHOTDATE%T*} +%s)
        INTERVAL=$[ (STARTDATE - ENDDATE) / (60*60*24) ]

        if (( ${INTERVAL} >= ${AGE} ));
        then
            echo "Deleting snapshot --> ${Red}${snapshot}${ResetColor}"
            if [ "${DRY}" ] ; then
                echo "aws ec2 delete-snapshot ${extra_args} --snapshot-id ${snapshot}"
            else
                aws ec2 delete-snapshot ${extra_args} --snapshot-id $snapshot}"
            fi
        fi

    done
}
DRY=0
while [ $# -ne 0 ]
do
	case $1 in
	-h|-H|help|-help|-HELP)
		usage; exit
		;;
	--instance|-instance|-i)	instanceID=${2};	shift;	shift;;
	--region|-r)			region=${2};		shift;	shift;;
	--age|-age)			AGE=${2};		shift;	shift;;
	--action|-action|-a)		ACTION=${2};		shift;	shift;;
	--filters|-filters|-f)		filters="${2}";		shift;	shift;;
	--monochrome|-monochrome|-m)	monochrome='true';	shift;;
	--dry-run|-dry-run|-dry|-d)		DRY="1";			shift;;

	*) usage; exit 1;;
	esac
done
if [[ -n "${region}" ]] ; then
	extra_args="--region $region"
else
	extra_args=" "
fi

if [[ -z ${ACTION} ]] ; then
    usage
    exit 1
fi
if [[ ${ACTION} == "delete" ]] && [[ -z ${AGE} ]] ; then
	usage
    exit 1
fi

# Monochrome version
if [ "${monochrome}" == "true" ] ; then
	Red='';Green='';Yellow='';Blue='';BlueCyan='';offbold=bold=''
else
# Color Version
	#+ Mode normal
	ResetColor="$(tput sgr0)"
	# "Surligné(bold)
	bold=$(tput smso)
	# "Non-Surligné(offbold)
	offbold=$(tput rmso)
	# Couleurs + Gras
	Red="$(tput bold ; tput setaf 1)"
	Green="$(tput bold ; tput setaf 2)"
	Yellow="$(tput bold ; tput setaf 3)"
	Blue="$(tput bold ; tput setaf 4)"
	BlueCyan="$(tput bold ; tput setaf 6)"
fi


case ${ACTION} in  
    "backup")
            backup_ebs ;;
    "delete")
            delete_snapshots ;;
    *) usage; exit 1

esac
