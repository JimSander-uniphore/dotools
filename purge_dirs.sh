#!/bin/bash

# preview recovered size of directories and delete
# Intended for use with pvc directories
# by default runs in preview, re3
# e.g. -d /media/rbv-data/conversa-minio-pvc-9021f994-813e-4ffc-ba13-1b395536abc6/default"


DAYS=45
SLEEP=5

DRYRUN="true"
PROG=$(basename $0)
SPROG=${PROG%%.sh}
OUTPUT="$HOME/${SPROG}.out"
LOG="/var/log/${SPROG}.log"
TLOG="/tmp/${SPROG}$$.log"
REMOVE="/tmp/${SPROG}$$_remove.log"

trap "rm -f $TLOG $OUTPUT ${OUTPUT}_2 $REMOVE" 0 1 15
rm $TLOG $OUTPUT $REMOVE >/dev/null 2>&1

Usage (){
cat <<EOU

  $PROG [-e] [-a <AgeInDays>] -d <top level directory>
  - Will find directories modifed older than AgeInDays (Default: $DAYS)
  - Must specify -e to perform deletes, otherwise is a dryrun/report
  - Logs written to $LOG

  Args:
  -a : Number of Days
  -d : Top Level directory to search
  -e : Executes deletes
  -s : Wait seconds between find and execute (default: $SLEEP)

EOU
exit 1
}  # Usage

STAT=$(which gstat 2>/dev/null || which stat 2>/dev/null)


while getopts "a:ed:hs:" opt; do
  case "$opt" in
    a) DAYS=${OPTARG};;
    d) DIR=${OPTARG};;
    e) unset DRYRUN;;
    s) SLEEP=${OPTARG};;
    h|*) Usage;;
  esac
done

[[ -z "$DIR" ]] && Usage "Must specify path: -p <directory>"

cd $DIR || { echo "Can't change to $DIR"; exit 1; }

if [[ -n "$DRYRUN" ]]; then 
  printf "## DRYRUN " 
  ACTION="DRYRUN"
else
  printf "## EXEC_DELETE "
fi
sleep $SLEEP  ## override with `-s 0`

if [[ -n "$(echo $DIR | grep '\-minio\-pvc\-')" ]]; then # special case for minio
	find $DIR -type d -mtime +$DAYS -name "*.raw" -exec dirname {} \; >${OUTPUT}_2
	sort ${OUTPUT}_2 | uniq | \
		while read dir; do stat --printf "%n %Y %y\n" $dir; done > $OUTPUT
else
	find $DIR -maxdepth 4 -type d -mtime +$DAYS -exec $STAT --printf "%n %Y %y\n" {} \; > $OUTPUT
fi

[[ -f "$OUTPUT" && -s "$OUTPUT" ]] || { echo "## No files found"; exit 0; } 

BEG_PURGE=$(printf "\n##%s BEG_PURGE: $(date +%Y-%m-%d_%H%M) DIR_SIZE:%-s \n" "$ACTION" "$(du -sh $DIR)") 
echo $BEG_PURGE | tee $TLOG

# Get disk usage for each directory 
awk '{ fp=$1; dt=$3; ducmd="du -s \"" fp "\"" ; ducmd | getline dsz; close(ducmd);
  printf("%s %s\n",dsz,dt); }' $OUTPUT | \
  while read sz fp dt; do

    [[ "$DIR" = "$fp" ]] && { echo "## SKIP PARENT"; next; }

    (( szall += sz )) && (( fpcount++ ))

    printf "## TODELETE: date=%s sz=%d szall=%d fpcount=%d fp=%s\n" "$dt" "$sz" "$szall" "$fpcount" "$fp"
      
done | tee $TLOG

if [[ -n "$DRYRUN" ]]; then 
  echo $BEG_PURGE
  awk '
    END{ 
      split($5,s,"="); split($6,f,"="); 
      sz=s[2]; fc=f[2];
      u="B"; div=1;
      if (sz > 1000) { u="MB"; div=1000}
      if (sz > 1000000 ) { u="GB"; div=100000 }
      if (fc == 0 ){ fc=1; }
      printf("## DRYRUN SUMMARY: Total%s:%.2f AvgByteSize:%d Count:%d\n", u, sz/div,sz/fc,fc);  
    }' $TLOG
    
  else
    echo "$BEG_PURGE" >> $LOG
cp $TLOG /tmp/TLOG
    # EXECUTE DELETES
    awk '{ split($4,sz,"="); split($7,fp,"="); printf("%s %s\n",fp[2],sz[2]); }' $TLOG |\
    while read fp sz; do
      if [[ -d "$fp"  ]]; then
        rm -rf $fp && printf "##REMOVED: %4d %s\n"  "$sz" "$fp" || echo "##FAILREMOVE $fp"
      else 
        echo "##NODIR: $fp"
      fi
    done | tee $REMOVE ## NOT saved to LOG

  awk -v du="$(du -sh $DIR)" -v dt="$(date +%Y-%m-%d_%H%M)" \
    '{ if ($1 ~ /##REMOVED:/){ sz+=$2; fp++; } else { fail++; }; }
    END{ 
      u="B"; div=1;
      if (sz > 1000) { u="MB"; div=1000}
      if (sz > 1000000 ) { u="GB"; div=100000 }
      printf("## END_PURGE: %s DIR_SIZE:%-s PurgeTotal%s:%.2f AvgByteSize:%d Count:%d Fails:%d\n", dt,du, u, sz/div,sz/fp,fp,fail); 
    }' $REMOVE | tee -a $LOG
fi

