#!/bin/bash
mkdir -p conf
mkdir -p data

VMIDS=($(ssh rhetzner "pct list 2>/dev/null" | grep running | cut -d' ' -f1))

cat > conf/exclude.txt <<EOL
EOL
ssh rhetzner 'find /var/lib/vz/vzdump/dump -name *.tar.gz' | sed -E 's|^/var/lib/vz/vzdump/dump/\|\.tar\.gz$||g' | sort -r | perl -lne 'if ((defined $l) && index($_, $l)==0) {print "/" . $_ . "*"} $l=substr($_, 0, 15);' | sort >> conf/exclude.txt
rsync -avzh --delete --delete-excluded --exclude-from=conf/exclude.txt rhetzner:/var/lib/vz/vzdump/dump/ conf/vzdump/

find conf/ -mindepth 1 -maxdepth 1 -regex ".*/[0-9][0-9][0-9].*" -exec rm -R {} \;
for gz in conf/vzdump/*.tar.gz; do
   CTID=$(echo "$gz"|cut -d- -f3)
   if [[ " ${VMIDS[@]} " =~ " ${CTID} " ]]; then
      TRG="conf/$CTID"
      mkdir -p "$TRG"
      #--exclude="*/.git" --exclude="*/.svn" --exclude="./home/*/.*" --exclude="./root/.*"
      tar --exclude="*/.cache" --exclude="*/.local" --exclude="./home/cyttorak" --exclude="./home/titulos/tmp" --same-owner -p -xvf "$gz" -C "$TRG" ./home/ ./etc/vzdump/ ./etc/apache2/ ./root/ ./etc/nginx/ ./etc/mysql/ ./etc/varnish/ ./etc/hostname
      if [ -f "$TRG/etc/hostname" ]; then
         HN=$(cat "$TRG/etc/hostname" | head -n 1)
         if [ ! -z "$HN" ]; then
            mv "$TRG" "$TRG - $HN"
         fi
      fi
   fi
done
find conf -type d -empty -delete
for dr in $(find conf/ -mindepth 1 -maxdepth 1 -regex ".*/[0-9][0-9][0-9]"); do
   pushd "$dr" > /dev/null
   TRG="../vzdump/*-$(basename $(pwd))-*.tar.gz"
   ln -s $TRG
   popd > /dev/null
done

cat > exclude.data.txt <<EOL
/102
/106/apachelog
/107/apachelog
/104/mailman/old
/104/mailman/logs/*
/104/mailman/otros/
/104/mailman/data/aliases*.old
/106/www/nginx_status
/109
/130
/*/www/html
/*/www/index.html
*.log
*.log.*.gz
*/lost+found
*/wp-content/envato-backups
*/wp-content/backup-db
*/wp-snapshots
*/wp-content/ai1wm-backups
*/wp-content/updraft
*/wp-content/uploads/snapshots
*/wp-content/backups
*/wp-content/wfcache
*/wp-content/wflogs
*/wp-content/cache
*/wp-content/**/cache
*/wp-content/plugins/wordfence/tmp
*/wp-admin/error_log
*/_wpeprivate
*/wp-content/plugins/wpengine-snapshot/snapshots
*/ics-importer-cache
*/wp-config-sample.php
*/wp-content/managewp
*/wp-content/upgrade
EOL
ssh rhetzner 'find /var/lib/vz/vzdump/backups/104/mailman/archives/ -name index.html' | sed -E 's|^/var/lib/vz/vzdump/backups/\|/index.html$||g' | sort | perl -lne 'if ((not defined $l) || index($_, $l)==-1) {$l=$_ . "/"; print "/" . $_}' >> exclude.data.txt

rsync -avzh --delete --delete-excluded --exclude-from=exclude.data.txt rhetzner:/var/lib/vz/vzdump/backups/ data/
mv exclude.data.txt data/exclude.txt

rm -R www 2> /dev/null
mkdir www
cd www
find .. -maxdepth 4 -regex ".*/[0-9][0-9][0-9]/www/.*\.net" -exec ln -s {} \;
cd ..

