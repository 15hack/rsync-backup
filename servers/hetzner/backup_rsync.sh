#!/bin/bash
SNAPSIZE=10G
VZROOT=/var/lib/vz
MOUNTROOT=$VZROOT/mounts
BACKUPSROOT=$VZROOT/vzdump/backups
for s in $(lvs|grep vm-|grep -v disk-1|awk '{ print $1 }');do
	SNAPNAME=snap_${s}
	CTID=$(echo $s|cut -d- -f2)
	LVNAME=$(echo $s|cut -d- -f3)
	SNAPDIR=$MOUNTROOT/$CTID/$LVNAME
	BACKUPDIR=$BACKUPSROOT/$CTID/$LVNAME
	lvcreate -L $SNAPSIZE -n $SNAPNAME -pr -s pve/$s
	echo "mount $SNAPNAME en $SNAPDIR"
	umount -l $SNAPDIR
	mkdir -p $SNAPDIR
	mount /dev/pve/$SNAPNAME $SNAPDIR
	mkdir -p $BACKUPDIR
	rsync -avz --exclude 'tmp/' --delete $SNAPDIR/  $BACKUPDIR/
	umount -l $SNAPDIR
	lvremove -f /dev/pve/$SNAPNAME
done
