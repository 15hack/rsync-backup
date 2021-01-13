#!/bin/bash
mkdir -p mysql
DBS=($(ssh rhetzner "pct exec 101 -- bash -c 'mysql -N -e \"show databases;\"' 2>/dev/null"))
echo "USERS GRANTS - > users_grants.sql"
ssh rhetzner "pct exec 101 -- bash -c 'pt-show-grants' 2>/dev/null" | gzip -9 > "mysql/users_grants.sql.gz"
for DB in "${DBS[@]}"; do
   if [[ ! $DB =~ ^(mysql|information_schema|performance_schema)$ ]]; then
      echo "mysqldump $DB"
      ssh rhetzner "pct exec 101 -- bash -c 'mysqldump --opt --add-drop-database --skip-comments --databases $DB' 2>/dev/null" | gzip -9 > "mysql/$DB.sql.gz"
   fi
done
