#!/bin/bash

TOUCH=$(which gtouch || which touch)
DATE=$(which gdate || which date)

depth=${1:-3}
for day in {0..100}; do 
  newtime=$($DATE -d "2023-06-01 + $day days" +'%Y-%m-%d') 
  mult=$(( 1 + $RANDOM % 1)) 
  offset=$(( 1 + $RANDOM % 1 )) 
  avg=$(( 1 + $RANDOM % 10 )) 
  # echo "$offset * $avg + $mult" 
  callpday=$(( $offset * $avg + $mult + 1 )) 
  echo "# Create $callpday calls" 

  for call in $(seq 1 $callpday); do
    echo "# Call # $call"
    rfile=$(( 1+ $RANDOM % 10))
    uuid=$(uuid) 
    uuidno=$(echo $uuid | sed 's/-//g') 
    udir=$uuid
    uuid2=$(uuid)
    uuid3=$(uuid)
    ## emulate minio directory depth
    if [[ $depth -gt 0 ]]; then
      for idx in $(seq 1 $depth); do 
	echo "## DEPTH: $idx"
        udir=${uuidno:$cnt:2}/$udir
        cnt+=2
      done
    fi
    cnt=0
    dcmd="find $udir -exec $TOUCH -d \"$newtime\" \{\} \\;"
    mkdir -p $udir

    for participant in {0..1}; do
	pdir="$udir/${uuid2}_participant_${participant}.raw"
	pdir2="$pdir/$uuid3"
	mkdir -p $pdir2

	dd if=/dev/zero of=${pdir}/xl.meta count=$(( 1+ $RANDOM % 100)) bs=1024 >/dev/null 2>&1 
    	for fileno in $(seq 1 $rfile); do
      		of=${pdir2}/part.$fileno
      		dd if=/dev/zero of=$of count=$(( 1+ $RANDOM % 100)) bs=1024 >/dev/null 2>&1 
    	done
    done
## SAMPLE: /media/rbv-data/conversa-minio-pvc-9021f994-813e-4ffc-ba13-1b395536abc6/default/
## D: UUID: 3dc99cb6-98d7-4ba0-a807-662767387910/
## D: UUID2_PARTICIPANT_[0-9].raw: 3dc99cb6-98d7-4ba0-a807-662767387910_participant_0.raw
##   F: xl.meta  
## D UUID3: ce8eb351-f804-4a21-a33a-bda80ebcdd23
##   F: part.1
    
    echo "## TOUCH $dcmd" 
    eval "$dcmd" || echo "Failed to update $udir" 
    ls -ld $udir
  done
done
