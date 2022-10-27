#!/bin/bash

# Legyujtott informaciokat adatbazisba mentjuk

update_ended=$(cat $tmpfile | grep -E "\[FATAL\]|\[SUCCESS\]")

if [ ! -z "$update_ended" ]; then # ha befejezodott a feladat
    logTid $tid "$update_ended"
    if [ $(echo $update_ended | grep "\[FATAL\]" | wc -l) -eq 0 ]; then
        changeTidState $tid 0
    else
        changeTidState $tid 1
    fi
    sqlQuery "INSERT INTO tasks (cid, sid, jid, parent, content, expireon, schedule, notsimultaneous) VALUES ('$cid', NULL, '5', '$newparent-5', '', '$expireon', '$now', 0);" # megnezzuk, hogy most mi az OS verzio
    sqlQuery "INSERT INTO tasks (cid, sid, jid, parent, content, expireon, schedule, notsimultaneous) VALUES ('$cid', NULL, '8', '$newparent-8', '', '$expireon', '$now',0 );" # megnezzuk, hogy most hogy all a patch szint
    endTask $tid
    exit 0
fi

# ha nem fejezodott be, akkor lementjuk a mostani kimenetet az adatbazisba, es megnezzuk, hol fog tartani par perc mulva
exitstatus=$(cat $tmpfile)
logTid $tid "$exitstatus"
retryTask $tid 300

exit 0