#!/bin/sh
# load path environment in dbus databse
eval `dbus export kms`
source /koolshare/scripts/base.sh
CONFIG_FILE=/jffs/configs/dnsmasq.d/kms.conf

start_kms(){
	/koolshare/bin/vlmcsd
	echo "srv-host=_vlmcs._tcp.lan,`uname -n`.lan,1688,0,100" > $CONFIG_FILE
	nvram set lan_domain=lan
   	nvram commit
	service restart_dnsmasq
	# creating iptables rules to firewall-start
	mkdir -p /jffs/scripts
	if [ ! -f /jffs/scripts/firewall-start ]; then 
		cat > /jffs/scripts/firewall-start <<-EOF
		#!/bin/sh
	EOF
	fi

	# creat start_up file
	if [ ! -L "/koolshare/init.d/S97Kms.sh" ]; then 
		ln -sf /koolshare/scripts/kms.sh /koolshare/init.d/S97Kms.sh
	fi
}
stop_kms(){
	# clear start up command line in firewall-start
	killall vlmcsd
	rm $CONFIG_FILE
	service restart_dnsmasq
}

open_port(){
	ifopen=`iptables -S -t filter | grep INPUT | grep dport |grep 1688`
	if [ -z "$ifopen" ];then
		iptables -t filter -I INPUT -p tcp --dport 1688 -j ACCEPT
	fi

	if [ ! -f /jffs/scripts/firewall-start ]; then
		cat > /jffs/scripts/firewall-start <<-EOF
		#!/bin/sh
		EOF
	fi
	
	fire_rule=$(cat /jffs/scripts/firewall-start | grep 1688)
	if [ -z "$fire_rule" ];then
		cat >> /jffs/scripts/firewall-start <<-EOF
		iptables -t filter -I INPUT -p tcp --dport 1688 -j ACCEPT
		EOF
	fi
}

close_port(){
	ifopen=`iptables -S -t filter | grep INPUT | grep dport |grep 1688`
	if [ ! -z "$ifopen" ];then
		iptables -t filter -D INPUT -p tcp --dport 1688 -j ACCEPT
	fi

	fire_rule=$(cat /jffs/scripts/firewall-start | grep 1688)
	if [ ! -z "$fire_rule" ];then
		sed -i '/1688/d' /jffs/scripts/firewall-start >/dev/null 2>&1
	fi
}

case $ACTION in
start)
	if [ "$kms_enable" == "1" ]; then
		logger "[软件中心]: 启动KMS！"
		start_kms
		open_port
	else
		logger "[软件中心]: KMS未设置开机启动，跳过！"
	fi
	;;
stop)
	close_port
	stop_kms
	;;
*)
	if [ "$kms_enable" == "1" ]; then
		close_port
		stop_kms
   		start_kms
   		open_port
   	else
   		close_port
		stop_kms
	fi
	;;
esac
