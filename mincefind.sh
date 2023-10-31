#!/usr/bin/env bash
figlet -S -f fraktur mince
figlet -S -f fraktur find

echo "==========="
echo "by gabriela"
echo "moonsmoker@protonmail.com"
printf "===========\n"

RATE=10000
RUN_DATE=$(date +"%H-%M-%b-%d")

function init()
{
  if [ -d "./mutdata" ]; then

    echo -e "[\e[31mLOG\e[0m] Moving data into backup." 

    if [ ! -d "./backup" ]; then
      mkdir ./backup
    else
      mkdir ./backup/backup-"$RUN_DATE"
      mv ./mutdata/logs/* ./backup/backup-"$RUN_DATE"
    fi
  else
    mkdir ./mutdata
  fi

  if [ ! -d "./database" ]; then
    echo "First time setup, creating SQLite database folder..."
    mkdir ./database
    sqlite3 ./database/mincefind_data.sql "CREATE TABLE IPS 
    (IP STRING PRIMARY KEY,  
    IS_ONLINE BIT, 
    CONFIRMED_SERVER BIT, 
    PINGED_AT VARCHAR,
    VERSION VARCHAR,
    MOTD VARCHAR,  
    MAX_PLAYERS INT,
    ONLINE_PLAYERS INT
    MODS VARCHAR
    VISITED BIT); 
    " 
  fi

  echo -e "[LOG] $RUN_DATE\n" >> ./mutdata/logs/scan-log.txt
}

function scan() 
{ 
  mkdir -p ./mutdata/logs/scan-"$RUN_DATE"/
  touch ./mutdata/logs/scan-"$RUN_DATE"/scan.txt
  masscan --resume ./paused.conf --excludefile ./masscan-exclusion.txt --rate $RATE -p 25565 -oGH ./mutdata/logs/scan-"$RUN_DATE"/scan.txt 50.20.206.245/6
}

function clean()
{ 
  cat ./mutdata/logs/scan-"$RUN_DATE"/scan.txt | awk {'print $4'} > ./mutdata/logs/scan-"$RUN_DATE"/cleaned.txt
  sed -i '1,2d' ./mutdata/logs/scan-"$RUN_DATE"/cleaned.txt
  sed -i '$d' ./mutdata/logs/scan-"$RUN_DATE"/cleaned.txt
}

function check_status()
{
  IP=$1
  STAT=$(curl https://api.mcstatus.io/v2/status/java/"$IP":25565)
  IS_ONLINE=$(echo $STAT | jq -r '.online')
  VERSION=$(echo $STAT | jq -r '.version.name_clean')
  MOTD=$(echo $STAT | jq -r '.motd.clean' |  tr -d '"' | tr -d "'")
  MAX_PLAYERS=$(echo $STAT | jq -r ".players.max")
  ONLINE_PLAYERS=$(echo $STAT | jq -r ".players.online")
  MODS=$(echo $STAT | jq -r ".mods")

  if [ "$IS_ONLINE" = "true" ]; then
    sqlite3 ./database/mincefind_data.sql "
      INSERT INTO IPS VALUES (
      '$IP', 
      1,
      1,
      '$(date +"%s-%k-%F")',
      '$VERSION',
      '$MOTD',
      '$MAX_PLAYERS',
      '$ONLINE_PLAYERS',
      '$MODS',
      0);
    " 
  else
    sqlite3 ./database/mincefind_data.sql "
      INSERT INTO IPS VALUES (
      '$IP',
      0,
      0,
      '$(date +"%s-%k-%F")',
      'NULL',
      'NULL',
      'NULL',
      'NULL',
      'NULL',
      0);
    "
  fi
}

function iterate_ips()
{
  COUNTER=0
  while read -r line; 
  do
      (( COUNTER++ ))
      echo $COUNTER > ./mutdata/logs/scan-"$RUN_DATE"/line.txt
      check_status "$line"
  done < "./mutdata/logs/scan-$RUN_DATE/cleaned.txt"
}

init
scan
clean
iterate_ips
