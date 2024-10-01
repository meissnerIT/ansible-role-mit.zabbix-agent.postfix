#!/usr/bin/env bash
#
# Distributed via ansible - mit.zabbix-agent.postfix
#
#11182: Postfix-Überwachung per Zabbix, <markus.meissner@meissner.IT>
#
# v2015-03-24-1
#
# * Added sasl users
# * Made sasl_method flexible (ivar=LOGIN, pilatus=PLAIN)

DAT1=/var/lib/zabbix-postfix/zabbix-postfix-offset.dat
DAT2=$(mktemp)
ZABBIX_CONF=/etc/zabbix/zabbix_agentd.conf
DEBUG=0

function zsend {
    key="postfix[`echo "$1" | tr ' -' '_' | tr '[A-Z]' '[a-z]' | tr -cd [a-z_]`]"
    value=`grep -m 1 "$1" $DAT2 | awk '{print $1}'`
    if [[ "$value" == *k ]]; then
        value=${value%k}
        value=$((value * 1024))
    fi
    [ ${DEBUG} -ne 0 ] && echo "Send key "${key}" with value "${value}"" >&2
    #/usr/bin/zabbix_sender -c $ZABBIX_CONF -k "${key}" -o "${value}" 2>&1 >/dev/null
    /usr/bin/zabbix_sender -c $ZABBIX_CONF -k "${key}" -o "${value}" >/dev/null
}

/usr/sbin/logtail -f/var/log/mail.log -o$DAT1 | /usr/sbin/pflogsumm -h 0 -u 0 --bounce_detail=0 --deferral_detail=0 --reject_detail=0 --no_no_msg_size --smtpd_warning_detail=0 > $DAT2

zsend received
zsend delivered
zsend forwarded
zsend deferred
zsend bounced
zsend rejected
zsend held
zsend discarded
zsend "reject warnings"
zsend "bytes received"
zsend "bytes delivered"
zsend senders
zsend recipients

rm $DAT2

key="postfix[sasl-users]"
value=$(/usr/sbin/logtail -f/var/log/mail.log -o/var/lib/zabbix-postfix/zabbix-postfix-offset-sasl-users.dat|grep "sasl_method=.*, sasl_username="|wc -l)
[ ${DEBUG} -ne 0 ] && echo "Send key "${key}" with value "${value}"" >&2
/usr/bin/zabbix_sender -c $ZABBIX_CONF -k "${key}" -o "${value}" >/dev/null

if [ ${value} -gt 59 ]; then
    echo "Found ${value} sasl users since last run, here is a list of todays sasl user:"
    awk ' BEGIN { FS="="; } /(LOGIN|PLAIN), sasl_username=/ { print $4; }' < /var/log/mail.log | sort | uniq -c
fi

