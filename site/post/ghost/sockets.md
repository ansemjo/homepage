---
title: Access Ghost via UNIX Socket
date: 2016-02-16
draft: false
toc: false
categories:
  - blog
  - technology
tags:
  - ghost
  - systemd
  - linux
---

Okay, so I set [this][ghosthome] thing up recently as my new landing page.

Using some [scripts] and [templates] from etherpad-lite, which I modified slightly, I now run this as a systemd service under a new user. _(You can find the modified files at the end of this post.)_ However, somehow I can't get ghost to listen properly on sockets yet.. or at least nginx gives me `502` errors when trying to connect .. I'll resort to using `localhost:port` for now.

<!--more-->

But yeah. This whole thing looks __pretty__ great .. I was using PicoCMS before, which I loved for its simple flat-file structure and markdown support. But writing your markdown online with a live preview does add some value. And Ghost has a pretty kick-ass default theme.

__edit:__ Well, nevermind. It was a simple permission error on the socket. Of course I forgot that nginx runs with a different user than the one I set up for ghost and the socket has `0660` permissions by default. I simply added nginx' user to the group under which ghost is running, et voila!

[ghosthome]: https://ghost.org/ "Ghost - Just a blogging platform"
[scripts]: https://github.com/ether/etherpad-lite/blob/develop/bin/safeRun.sh "autorestarting script from etherpad-lite"
[templates]: https://github.com/ether/etherpad-lite/wiki/How-to-deploy-Etherpad-Lite-as-a-service "deploying etherpad-lite as a service .."

---

~ghost/run.sh
```bash
#!/bin/sh

# Original from the etherpad-lite scripts
# This script ensures that ghost is automatically restarted after an error happens

ERROR_HANDLING=1 # 0 silent / 1 email
EMAIL_ADDRESS="mail@domain.tld" # receiver
TIME_BETWEEN_EMAILS=3600 # 60 minutes minimum between emails

LAST_EMAIL_SEND=0
LOG="$1"

#Move to the folder where ghost is installed
cd `dirname $0`

#Stop the script if it's started as root
if [ "$(id -u)" -eq 0 ]; then
  echo "You shouldn't start Ghost as root!"
  exit 2
fi

#check if a logfile parameter is set
if [ -z "${LOG}" ]; then
  echo "Set a logfile as the first parameter"
  exit 1
fi

shift
while [ 1 ]; do

  #try to touch the file if it doesn't exist
  if [ ! -f ${LOG} ]; then
    touch ${LOG} || { echo "Logfile '${LOG}' is not writeable"; exit 1; }
  fi
  #check if the file is writeable
  if [ ! -w ${LOG} ]; then
    echo "Logfile '${LOG}' is not writeable"; exit 1;
  fi

  # We have liftoff ..
  npm start --production | tee -a ${LOG}

  #Send email on error
  if [ $ERROR_HANDLING = 1 ]; then
    TIME_NOW=$(date +%s)
    TIME_SINCE_LAST_SEND=$(($TIME_NOW - $LAST_EMAIL_SEND))

    if [ $TIME_SINCE_LAST_SEND -gt $TIME_BETWEEN_EMAILS ]; then
      printf "Server was restarted at: $(date)\nThe last 50 lines of the log before the error happens:\n $(tail -n 50 ${LOG})" | mail -s "Ghost was restarted" $EMAIL_ADDRESS
      LAST_EMAIL_SEND=$TIME_NOW
    fi
  fi

  echo "RESTART!" | tee -a ${LOG}
  #Sleep 10 seconds before restart
  sleep 10
done
```

/etc/systemd/system/ghost.service
```bash
[Unit]
Description=Ghost instance
After=syslog.target network.target

[Service]
Type=simple
User=ghostuser
Group=ghostgroup
ExecStart=/var/www/ghost/run-safe.sh /var/log/ghostcms.log

[Install]
WantedBy=multi-user.target
```
