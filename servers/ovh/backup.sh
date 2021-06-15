#!/bin/bash
set -e
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Necesita ejecutar como root"
    exit
fi

TRG="/var/backups/ovh"

if [ ! -d "$TRG" ]; then
  if [ ! $(getent group rootbackup) ]; then
    groupadd rootbackup
  fi
  mkdir -p "$TRG"
  chown root:rootbackup "$TRG"
  chmod 750 "$TRG"
fi

DATE=$(date +%Y-%m-%d)

echo "tar $DATE-files.tar.gz"
tar -czpf "$TRG/$DATE-files.tar.gz" /usr/share/nginx/www/ /etc/nginx/ /root/ /etc/cron* /etc/mysql /root/p.gpg /usr/bin/gpgnano /var/spool/cron/crontabs/
echo "USERS GRANTS - > users_grants.sql"
pt-show-grants | gzip -9 > "$TRG/$DATE-users_grants.sql.gz"
DBS=($(mysql -N -e "show databases;"))
for DB in "${DBS[@]}"; do
   if [[ ! $DB =~ ^(mysql|information_schema|performance_schema)$ ]]; then
      echo "mysqldump $DB"
      mysqldump --opt --add-drop-database --skip-comments --databases --routines "$DB" | gzip -9 > "$TRG/$DATE-$DB.sql.gz"
   fi
done
find "$TRG" -type f -mtime +15 -exec rm {} \;
tree "$TRG"
