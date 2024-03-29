#!/bin/bash
mkdir -p conf
mkdir -p data

VMIDS=($(ssh rhetzner "pct list 2>/dev/null" | grep running | cut -d' ' -f1))

echo "rsync rhetzner:/var/lib/vz/vzdump/dump/ conf/vzdump/"

echo "" > conf/exclude.txt
ssh rhetzner 'find /var/lib/vz/vzdump/dump -name *.tar.gz -printf "%P\n"'| sort -r | perl -lne 'if ((defined $l) && index($_, $l)==0) {print "/" . substr($_, 0, -7) . "*"} $l=substr($_, 0, 15);' | sort >> conf/exclude.txt
ssh rhetzner 'find /var/lib/vz/vzdump/dump -mtime +1460 -name *.tar.gz -printf "%P\n"' | sort | sed 's|.tar.gz|*|' >> conf/exclude.txt
rsync --info=progress2 -azh --delete --delete-excluded --exclude-from="conf/exclude.txt" rhetzner:/var/lib/vz/vzdump/dump/ conf/vzdump/

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
      tar --wildcards --exclude-backups --exclude-vcs --exclude-caches-all --exclude-from="conf/exclude.tar.txt" --same-owner -p -xf "$gz" -C "$TRG" ./home/ ./etc/vzdump/ ./etc/apache2/ ./root/ ./etc/nginx/ ./etc/mysql/ ./etc/varnish/ ./etc/hostname ./etc/cron* /var/spool/cron/crontabs/
      pushd "$TRG" > /dev/null
      ln -s "../vzdump/$NMGZ"
      popd > /dev/null
    fi
   fi
done

echo "rsync rhetzner:/ conf/hetzner"
rsync --info=progress2 -azh --delete --delete-excluded --filter="merge conf/hetzner.txt" rhetzner:/ conf/hetzner

find conf -type d -empty -delete

cat > exclude.txt <<EOL
/101
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
ssh rhetzner 'find /var/lib/vz/vzdump/backups/104/mailman/archives/ -name index.html' | sed -E 's|^/var/lib/vz/vzdump/backups/\|/index.html$||g' | sort | perl -lne 'if ((not defined $l) || index($_, $l)==-1) {$l=$_ . "/"; print "/" . $_}' >> exclude.txt

echo "rsync rhetzner:/var/lib/vz/vzdump/backups/ data/"
rsync --info=progress2 -azh --delete --delete-excluded --exclude-from=exclude.txt rhetzner:/var/lib/vz/vzdump/backups/ data/
mv exclude.txt data/exclude.txt

echo "rsync rhetzner:/var/lib/vz/vzdump/mysql/ mysql/"

echo "" > rsync.txt
ssh rhetzner 'find /var/lib/vz/vzdump/mysql -name *.sql.gz -printf "%P\n"' | sort -r | perl -lne 'if ((substr($_, 10) ~~ @l)) {print "- /" . $_} push(@l, substr($_, 10));' | sort >> rsync.txt
echo "+ /**.sql.gz" >> rsync.txt
echo "- /*" >> rsync.txt
rsync --info=progress2 -azh --delete --delete-excluded --filter="merge rsync.txt" rhetzner:/var/lib/vz/vzdump/mysql/ mysql/
mv rsync.txt mysql/rsync.txt

rm -R www 2> /dev/null
mkdir www
cd www
find .. -maxdepth 4 -regex ".*/[0-9][0-9][0-9]/www/.*\.net" -exec ln -s {} \;
cd ..

ssh ovh 'find /var/backups/ovh/ -name "*.gz" -printf "%P\n"' | sort -r | perl -lne 'if ((substr($_, 10) ~~ @l)) {print "/" . $_} push(@l, substr($_, 10));' | sort > exclude.txt
rsync -avzh --delete  --delete-excluded --exclude-from="exclude.txt" ovh:/var/backups/ovh/ ovh-backup/
mv exclude.txt ovh-backup/
chmod 755 ovh-backup/

du -hs .
