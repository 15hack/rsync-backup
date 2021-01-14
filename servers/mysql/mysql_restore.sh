#!/bin/bash
PATH=$PATH:/usr/sbin
BACKUPDIR="/var/backups/mysql"

DATE="$1"

function mysqlrestore {
  if [ -z "$DATE" ]; then
    GZ=$(find "$BACKUPDIR" -maxdepth 1 -regextype sed -regex  ".*/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-${1}.sql.gz" | sort | tail -n 1)
  else
    GZ=$(find "$BACKUPDIR" -maxdepth 1 -regextype sed -regex  ".*/${DATE}-${1}.sql.gz" | sort | tail -n 1)
  fi
  if [ ! -z "$GZ" ]; then
    echo "zcat $GZ | mysql"
  fi
}

echo "#!/bin/bash"
echo "# Script para restaurar mysql"
echo "# Revise las sentencias antes de ejecutarlas"
if [ ! -z "$DATE" ]; then
echo "# Se pide restaurar concretamente la fecha $DATE"
fi
DBS=($(find "$BACKUPDIR" -maxdepth 1 -regextype sed -regex  ".*/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[^/]*.sql.gz" -exec basename {} \; | awk '{print substr($0,12, length($0)-12-6)}' | sed '/^users_grants$/d' | sort | uniq))
for DB in "${DBS[@]}"; do
  mysqlrestore "$DB"
done
mysqlrestore "users_grants"
