#!/bin/bash
mkdir -p conf
mkdir -p data

VMIDS=($(ssh rhetzner "pct list 2>/dev/null" | grep running | cut -d' ' -f1))

echo "rsync rhetzner:/var/lib/vz/vzdump/dump/ conf/vzdump/"

echo "" > conf/exclude.txt
ssh rhetzner 'find /var/lib/vz/vzdump/dump -name *.tar.gz' | sed -E 's|^/var/lib/vz/vzdump/dump/\|\.tar\.gz$||g' | sort -r | perl -lne 'if ((defined $l) && index($_, $l)==0) {print "/" . $_ . "*"} $l=substr($_, 0, 15);' | sort >> conf/exclude.txt
rsync -azh --delete --delete-excluded --exclude-from="conf/exclude.txt" rhetzner:/var/lib/vz/vzdump/dump/ conf/vzdump/

find -L conf/ -maxdepth 2 -type l -name "vzdump-*.tar.gz" -execdir realpath . \; | xargs rm -R 2>/dev/null
for gz in conf/vzdump/*.tar.gz; do
   CTID=$(echo "$gz"|cut -d- -f3)
   NMGZ=$(basename "$gz")
   if [[ " ${VMIDS[@]} " =~ " ${CTID} " ]]; then
    HN=$(tar -axf "$gz" ./etc/hostname -O 2>/dev/null | head -n 1)
    TRG="conf/$CTID"
    if [ ! -z "$HN" ]; then
      TRG="${TRG}-${HN}"
    fi
    if [ ! -e "$TRG/$NMGZ" ]; then
      mkdir -p "$TRG"
      echo "tar $NMGZ $TRG"
      #--exclude="*/.git" --exclude="*/.svn" --exclude="./home/*/.*" --exclude="./root/.*"
      tar --wildcards --exclude-backups --exclude-vcs --exclude-caches-all --exclude-from="conf/exclude.tar.txt" --same-owner -p -xf "$gz" -C "$TRG" ./home/ ./etc/vzdump/ ./etc/apache2/ ./root/ ./etc/nginx/ ./etc/mysql/ ./etc/varnish/ ./etc/hostname ./etc/cron*
      pushd "$TRG" > /dev/null
      ln -s "../vzdump/$NMGZ"
      popd > /dev/null
    fi
   fi
done

echo "rsync rhetzner:/ conf/hetzner"
rsync -azh --delete --delete-excluded --filter="merge conf/hetzner.txt" rhetzner:/ conf/hetzner

find conf -type d -empty -delete

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

echo "rsync rhetzner:/var/lib/vz/vzdump/backups/ data/"
rsync -azh --delete --delete-excluded --exclude-from=exclude.data.txt rhetzner:/var/lib/vz/vzdump/backups/ data/
mv exclude.data.txt data/exclude.txt

rm -R www 2> /dev/null
mkdir www
cd www
find .. -maxdepth 4 -regex ".*/[0-9][0-9][0-9]/www/.*\.net" -exec ln -s {} \;
cd ..
