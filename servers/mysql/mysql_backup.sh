#!/bin/bash
PATH=$PATH:/usr/sbin
MAXDAYS=15
BACKUPDIR="/var/backups/mysql"
DATE=$(date +%Y-%m-%d)

logger Iniciando backup de mysql

echo "USERS GRANTS - > users_grants.sql"
pt-show-grants | gzip -9 > "$BACKUPDIR/$DATE-users_grants.sql.gz"
DBS=($(mysql -N -e "show databases;"))
for DB in "${DBS[@]}"; do
   if [[ ! $DB =~ ^(mysql|information_schema|performance_schema)$ ]]; then
      echo "mysqldump $DB"
      mysqldump --opt --add-drop-database --skip-comments --databases --routines "$DB" | gzip -9 > "${BACKUPDIR}/${DATE}-${DB}.sql.gz"
   fi
done
find "$BACKUPDIR" -type f -mtime +${MAXDAYS} -exec rm {} \;
find "$BACKUPDIR" -type d -empty -delete;

logger Backup de mysql finalizado
