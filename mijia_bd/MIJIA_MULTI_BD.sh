#!/bin/bash

#extraction du chemin
dir=$(dirname $(readlink -f $0))

# on crée un fichier pour les log
exec &>> $dir/log/mijia_com.log
# chemin de la base de donnée
sqlite_bd="$dir/bd/MIJIA.db"

# on vérifie que l'on est en Root
if [[ $EUID -ne 0 ]];
then
    echo "Ce script doit être exécuté avec les privilèges administrateur"
    exit 1
fi

#function de lecture des donées

add_read()
{
   MACadd="$1"
   LOCadd="$2"

   hciconfig hci0 down
   hciconfig hci0 up

   hnd38=$(timeout 15 gatttool -b $MACadd --char-write-req --handle='0x0038' --value="0100" --listen | grep --max-count=1 "Notification handle")

   if !([ -z "$hnd38" ])
   then
      temperature=${hnd38:39:2}${hnd38:36:2}
      temperature=$((16#$temperature))
      if [ "$temperature" -gt "10000" ];
      then
           temperature=$((-65536 + $temperature))
      fi
      temperature=$(echo "scale=1;$temperature/100" | bc)

      humidity=${hnd38:42:2}
      humidity=$((16#$humidity))

      hnd1b=$(gatttool --device=$MACadd --char-read -a 0x1b)
      # Characteristic value/descriptor: 63
      battery=${hnd1b:33:2}
      battery=$((16#$battery))
      #texte pour le fichier de log
      echo "$(date +"%d/%m/%y %H:%M:%S") - [SUCCES] [$LOCadd]"
        
      sqlite3 $sqlite_bd "insert into ETAT_MODULE (MAC,LOC,TH,HD,BAT,TIME) values (\"$MACadd\",\"$LOCadd\",\"$temperature\",\"$humidity\",\"$battery\",\"$(date +%s)\")"
     
   else
      #texte pour le fichier de log
      echo "$(date +"%d/%m/%y %H:%M:%S") - [ERROR] [$LOCadd]"
   fi

}
# Boucle de la bd MODULE pour lire les valeur
sqlite3 $sqlite_bd "select id from MODULE" | while read prkey; do
   mac=$(sqlite3 $sqlite_bd "select MAC from MODULE where ID=$prkey")
   loc=$(sqlite3 $sqlite_bd "select LOC from MODULE where ID=$prkey")
   #on lance la fonction de lecture
   add_read $mac $loc
   sleep 2
done
