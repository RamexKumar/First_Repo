#!/bin/sh

ifconfig wlp2s0 down

# Check support for P2P
iw list | grep -A 8 "Supported interface modes"

echo '
ctrl_interface=/var/run/wpa_supplicant
ctrl_interface_group=0
update_config=1
device_name=LAPTOP
device_type=1-0050F204-1
p2p_disabled=0
p2p_go_intent=15
p2p_go_ht40=1
p2p_listen_reg_class=81
p2p_listen_channel=1
p2p_oper_channel=1
p2p_oper_reg_class=81
driver_param=use_multi_chan_concurrent=1 use_p2p_group_interface=1
country=US
network={
    ssid="LAPTOP-AP"
    psk="87654321"
    proto=RSN
    key_mgmt=WPA-PSK
    pairwise=CCMP
    mode=3
    disabled=2
}

' > /tmp/wpa_supplicant.conf


# wpa_supplicant -D nl80211 -i wlp2s0 -c /tmp/wpa_supplicant.conf -d
wpa_supplicant -D nl80211 -i wlp2s0 -c /tmp/wpa_supplicant.conf -f /tmp/wpa_supplicant.log -d -B


wpa_cli -i p2p-dev-wlp2s0 p2p_group_add persistent=0



ifconfig p2p-wlp2s0-0 10.42.43.1


dnsmasq --interface=p2p-wlp2s0-0                                        \
        --conf-file=/dev/null                                           \
        --port=0                                                        \
		--no-hosts                                                      \
		--bind-interfaces                                               \
		--except-interface=lo                                           \
		--except-interface=wlp2s0                                       \
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
		--log-facility=/tmp/dnsmasq.log                                 \
		--dhcp-leasefile=/tmp/dhcp-lease.log




echo 'ssid="LAPTOP-AP"'
echo 'psk="87654321"'


