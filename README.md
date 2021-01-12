Este proyecto sirve para descargar una copia de seguridad
del servidor de `hetzner`.

También intentará explicar como esta estructurado el `backup`.

# Requisitos

*1-* Tener usuario `root` o `sudo` en tu máquina local para
ejecutar con él `rsync` y/o los `scripts` que proporciona este proyecto
a fin de que la copia de ficheros pueda preservar los permisos,
usuarios y grupos de origen.

*2-* Tener acceso `root` a la máquina principal de `hetzner`
vía `ssh` con clave privada y estando
configurado en tu `/root/.ssh/config` en una entrada llamada `rhetzner`

# Consideraciones iniciales

Parece ser que solo hay una persona que sabe como se están
haciendo los `backups` y como usarlos para recuperar los servicios
en caso de desastre o migración.

Esa persona no soy yo y la única información que ha dado sobre el tema
es la siguiente:

```
Explicar todo el sistema es un poco complicado, pero básicamente estoy revisando que los backups se almacenen en /var/lib/vz. La idea es que cualquiera que tenga permiso de lectura en esa ruta pueda hacer rsync en varias vaces (son muchos GB) para ir teniendo cada una su copia local. Voy a hacer limpieza y os voy contando.
```

No existe documentación ni más información.

En las máquinas se pueden
encontrar numerosos `scripts` con nombres que contienen la palabra
`backup` o similar, siendo obvio que no todos deben funcionar
y debe haber copias antiguas obsoletas. Por lo tanto es
muy difícil saber cual es código correcto o cómo funciona cualquier cosa.

Por todo ello ha de entenderse que lo explicado a partir de aquí
es lo que yo he podido averiguar dando palos de ciego, haciendo de forense
y que no puedo garantizar si es correcto o no.

Dicho esto, y partiendo de lo único que sabemos (que el backup esta en `/var/lib/vz`)
sospechamos que:

* en `/var/lib/vz/vzdump/dump` están las configuraciones de las máquinas virtuales comprimidas
en un fichero `tar.gz` por máquina.
* en `/var/lib/vz/vzdump/backups` esta una copia de los datos que tienen las máquinas
virtuales en sus volúmenes lógicos asociados.

El primer punto parece confirmado porque en `/etc/cron.d/vzdump` hay
una orden semanal para ejecutar `vzdump --mailto vzdump --mailnotification failure --all 1 --quiet 1 --storage backups --mode snapshot --compress gzip`

El segundo punto **casi** parece confirmado porque en `/etc/cron.d/backup_rsync`
hay una orden diaria para ejecutar `/root/scripts/backup_rsync.sh`, un script
que hace copias en `/var/lib/vz/vzdump/backups` de los volúmenes lógicos.
¿Pero por qué he dicho **casi**? Porque la citada orden `cron` esta comentada
así que no se ejecuta nunca.

Aún así, después de buscar y buscar documentación y respuestas sin éxito,
me quedo con que las dos patas del `backup` son [`vzdump`](https://pve.proxmox.com/pve-docs/vzdump.1.html)
y `backup_rsync.sh` porque si no es imposible avanzar.

Por lo tanto descomento la orden `cron` que ejecuta `backup_rsync.sh`

En `/var/lib/vz` hay mucho más carpetas y contenido a parte de
`/var/lib/vz/vzdump/dump` y `/var/lib/vz/vzdump/backups` pero como
no hay documentación ni respuestas no he podido llegar a ninguna conclusión
sobre él.

# Descargar backup

Tenemos las siguientes opciones:

## Descarga completa de `/var/lib/vz`

Espacio necesario: **488 GB**.

Si quieres llevártelo todo, incluso lo que no sabemos ni que es, haz:

```console
# rsync -avzh --delete rhetzner:/var/lib/vz/ full-backup/
```

## Descarga completa de `/var/lib/vz/vzdump/dump` y `/var/lib/vz/vzdump/backups`

Espacio necesario: **273 GB**.

Si quieres llevártelo solo lo que creemos saber que es haz:

```console
# rsync -avzh --delete rhetzner:/var/lib/vz/vzdump/dump/ full-backup-conf/
# rsync -avzh --delete rhetzner:/var/lib/vz/vzdump/backups/ full-backup-data/
```

## Descarga filtrada de `/var/lib/vz/vzdump/dump` y `/var/lib/vz/vzdump/backups`

Espacio necesario: **94 GB**.

Si no te sobra el espacio y confiás en que se lo que hago puedes usar el
`script` [`rsync.sh`](/rsync.sh) de este proyecto que se encarga de solo descargar
aquello que creo que realmente hace falta.

Este `script` lo que hace es:

* Descarga en `./conf/vzdump` la última copia de seguridad hecha con `vzdump`
e ignora el resto (ya que en `/var/lib/vz/vzdump/dump` hay varias copias)
* Descarga en `./data/` todo `/var/lib/vz/vzdump/backups` menos logs, caches
de wordpress, carpetas `old` o `backup`, archivos html de `mailman`
(pues se pueden regenerar con [`arch`](https://wiki.list.org/DOC/4.09%20Summary%20of%20the%20mailman%20bin%20commands)) y los volúmenes
de la máquina `102 - caribu3` porque solo tiene logs,
`109 - jitsi` y `130 - stats` porque no he conseguido que alguien me
conteste si se usa.

Adicionalmente, para que sea más sencillo ver que te estas descargando,
se extraen de los ficheros `./conf/vzdump/*.tar.gz`
(en una carpeta por maquina bajo bajo `./conf/`)
los archivos y directorios más relevantes
(`/home/`, `/etc/vzdump/`, `/etc/apache2/` `/root/`, `/etc/nginx/`, `/etc/mysql/`, `/etc/varnish/` y `/etc/hostname`) para hacerse una idea rápida de que tiene cada
máquina sin tener que estar mirando uno por uno los `tar.gz`.

El script también buscara en las configuraciones de las máquinas
las carpetas que por cuyo nombre y ubicación parecen ser
páginas webs y creará un enlace simbólico a cada una de ellas
en `./wwww` para que fácilmente puedas ver que webs has recuperado
como mínimo.

## Descargar bases de datos con mysqldump

Espacio necesario: **4.5 GB**.

Aunque en todas las opciones anteriores se descargara `/mysql/`
(que es donde están los `frm`, `ibd`, etc) es recomendable
tener una copia de las bases de datos en sql
hecha con [`mysqldump`](https://mariadb.com/kb/en/mysqldump/)

Para ello ejecuta el `script` [`mysqldump.sh`](/mysqldump.sh) que
guarda en:

* `./mysql/users_grants.sql.gz` los usuarios y sus permisos
* `./mysql/XXXXX.sql.gz` la base de datos XXXXX para cualquier
XXXXX que no sea `mysql`,  `information_schema` y `performance_schema`.
