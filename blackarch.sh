#!/bin/sh

# -------------------------- Begin Set Variables ----------------------------- #

ACCESS_POINT_WIFI_INTERFACE=wlp0s20f0u2
ACCESS_POINT_WIFI_INTERFACE=wlp2s0

INTERNET_INTERFACE=wlp2s0
INTERNET_INTERFACE=wlp0s20f0u2

WIFI_SSID=TuxAP

WIFI_CHANNEL=11

WIFI_PASSWORD=secretpassword

# ========================== End of Set Variables ============================ #




# ----------------  No more variable setting beyond this point  -------------- #

WORK_DIR=/tmp/hostapd_${$}

mkdir ${WORK_DIR}

# ----------------------- Confirmation for Settings -------------------------- #

echo -e "
Access Point is going to be created with following Settings.

   Access Point WiFi Interface: ${ACCESS_POINT_WIFI_INTERFACE}
   Internet Interface: ${INTERNET_INTERFACE}
   WiFi SSID Name: ${WIFI_SSID}
   WiFi Channel: ${WIFI_CHANNEL}
   WiFi Password: ${WIFI_PASSWORD}

   Log files are captured at ${WORK_DIR} folder

Press Enter to continue or Ctrl-C to abort ...
"

read CONFIRM_TO_PROCEED

# ----------------------- Hostapd Configuraiton File ------------------------- #

echo -e "

interface=${ACCESS_POINT_WIFI_INTERFACE}

ssid=${WIFI_SSID}
channel=${WIFI_CHANNEL}
wpa=3
wpa_passphrase=${WIFI_PASSWORD}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP

hw_mode=g
driver=nl80211

macaddr_acl=0
# auth_algs=1
ignore_broadcast_ssid=0

logger_syslog=-1
logger_syslog_level=2
logger_stdout=-1
logger_stdout_level=0

ctrl_interface=/var/run/hostapd
country_code=US


" > ${WORK_DIR}/hostapd.conf


# ------------------------- Start Hostapd Process ---------------------------- #

hostapd -B -K -t -d ${WORK_DIR}/hostapd.conf 2>&1 | tee -a ${WORK_DIR}/hostapd.log


# ------------------------- Set Access Point IP ------------------------------ #

ifconfig ${ACCESS_POINT_WIFI_INTERFACE} 10.42.43.1


# ------------------------- Start DHCP Server -------------------------------- #

dnsmasq --interface=${ACCESS_POINT_WIFI_INTERFACE}                      \
        --conf-file=/dev/null                                           \
        --port=0                                                        \
		--no-hosts                                                      \
		--bind-interfaces                                               \
		--except-interface=lo                                           \
		--except-interface=${INTERNET_INTERFACE}                        \
		--clear-on-reload                                               \
		--strict-order                                                  \
		--server=8.8.8.8                                                \
		--server=8.8.4.4                                                \
		--dhcp-range=10.42.43.10,10.42.43.100,255.255.255.0,168h        \
		--dhcp-option=option:router,10.42.43.1                          \
		--dhcp-option=option:dns-server,8.8.8.8,8.8.4.4                 \
		--dhcp-lease-max=50                                             \
		--log-dhcp                                                      \
		--log-queries                                                   \
		--log-facility=${WORK_DIR}/dnsmasq.log                          \
		--dhcp-leasefile=${WORK_DIR}/dhcp-lease.log

#		--keep-in-foreground                                            \

# --------------------- Setup Routing / NAT / Firewall ----------------------- #

# ================================ INTRODUCTION ============================== #

#  IPTABLES  PROXY  script
#  The script will make this system as Proxy with IP Masquerade &
#  IP Forwarding using IPTABLES
#
#  This script is a derivitive of the script presented in
#  IP Masquerade HOWTO page at:
#  http://www.tldp.org/HOWTO/IP-Masquerade-HOWTO/firewall-examples.html
#
#  This script is presented as an example for testing purpose ONLY and
#  should not be used as a production proxy server
#  Once Proxy has been tested, with this simple ruleset, it is highly
#  recommended to use a stronger IPTABLES ruleset

# ============================================================================ #


# ================================ USER INPUTS =============================== #

#  PLEASE SET USER VARIABLES IN SECTIONS A AND B

# ============================================================================ #


echo -e "\n\nSetting up IPTABLES Proxy ... \n"


# ================================= SECTION A ================================ #

# SET INTERFACE DESIGNATION FOR CONNECTION TO YOUR INTERNAL (LOCAL) NETWORK
#
#   The default value below is for "eth0" (Wired Ethernet Network).
#   This value could also be "eth1" if you have TWO NICs in your system.
#
#   It could also be "wlan0" if internal network is connected through WiFi or
#   Wireless
#
#   Use "ifconfig" command to list the interfaces on the system.
#   The internal interface will likely have an address that is in one of the
#   private IP address ranges.
#
#   Note that this is an interface NAME - not IP address of the interface.
#
#   Enter the internal interface's designation for INTIF variable:

INTIF=`echo ${ACCESS_POINT_WIFI_INTERFACE}`

# ============================================================================ #


# ================================= SECTION B ================================ #

# SET INTERFACE DESIGNATION FOR EXTERNAL (INTERNET) CONNECTION
#
#   The default value below is "ppp0" which is for a MODEM internet connection.
#
#   If you have two NICs in your system, it may be "eth0" or "eth1"
#   (whichever is opposite of the value set for INTIF above).
#   This would be the NIC connected to your Cable or DSL modem
#   (WITHOUT a Cable/DSL router).
#
#   Note that this is an interface NAME - not IP address of the interface.
#
#   Enter the external interface's designation for the EXTIF variable:

EXTIF=`echo ${INTERNET_INTERFACE}`

# ============================================================================ #


# ----------------  No more variable setting beyond this point  ----------------


# ==================== IDENTIFY IP ADDRESSES OF INTERFACES =================== #

EXTIP="`/sbin/ifconfig ${EXTIF} | grep 'inet' | grep 'netmask' | awk '{print $2}' | sed -e 's/.*://'`"

INTIP="`/sbin/ifconfig ${INTIF} | grep 'inet' | grep 'netmask' | awk '{print $2}' | sed -e 's/.*://'`"

# ============================================================================ #




echo -e "    Loading required stateful/NAT kernel modules... \n"

/sbin/depmod -a
/sbin/modprobe ip_tables
/sbin/modprobe ip_conntrack
/sbin/modprobe ip_conntrack_ftp
/sbin/modprobe ip_conntrack_irc
/sbin/modprobe iptable_nat
/sbin/modprobe ip_nat_ftp
/sbin/modprobe ip_nat_irc

echo -e "    Enabling IP forwarding... \n"
echo -e "1" > /proc/sys/net/ipv4/ip_forward
echo -e "1" > /proc/sys/net/ipv4/ip_dynaddr

echo -e "    External interface: ${EXTIF}"
echo -e "       External interface IP address is: $EXTIP \n"

echo -e "    Internal interface: ${INTIF}"
echo -e "       Internal interface IP address is: $INTIP \n"

echo -e "    Loading proxy server rules... \n"

# Clearing any existing rules and setting default policy
iptables -P INPUT ACCEPT
iptables -F INPUT
iptables -P OUTPUT ACCEPT
iptables -F OUTPUT
iptables -P FORWARD DROP
iptables -F FORWARD
iptables -t nat -F


# Log traffic in Internal Interface

iptables -A INPUT                         \
         -j LOG                           \
         -i ${INTIF}                        \
         --log-level 1                    \
         --log-prefix "IPTABLES-INPUT "

iptables -A OUTPUT                        \
         -j LOG                           \
         -o ${INTIF}                        \
         --log-level 3                    \
         --log-prefix "IPTABLES-OUTPUT "

iptables -A FORWARD                       \
         -j LOG                           \
         -i ${INTIF}                        \
         --log-prefix "IPTABLES-FORWARD-OUT "

iptables -A FORWARD                       \
         -j LOG                           \
         -o ${INTIF}                        \
         --log-prefix "IPTABLES-FORWARD-IN "


# Forward: Allow all connections OUT and only existing and related ones IN

iptables -A FORWARD                       \
         -i ${INTIF}                        \
         -o ${EXTIF}                        \
         -j ACCEPT

iptables -A FORWARD                       \
         -i ${EXTIF}                        \
         -o ${INTIF}                        \
         -m state                         \
         --state ESTABLISHED,RELATED      \
         -j ACCEPT

# Enabling SNAT (MASQUERADE) functionality on ${EXTIF}
iptables -t nat                           \
         -A POSTROUTING                   \
         -o ${EXTIF}                        \
         -j MASQUERADE

echo -e "\t Proxy server rule loading is completed\n"

echo -e "IPTABLES Proxy Setup is Completed... \n"

# ============================== End of IP Tables ============================ #
