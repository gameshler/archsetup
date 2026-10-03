#!/bin/sh -e

# menu: nftables
# desc: nftables firewall and kernel network hardening

. "$COMMON_SCRIPT"

install_nftables() {
    if ! command_exists nft; then
        printf "%b\n" "Installing NFTables..."

        install_packages nftables
    else
        printf "%b\n" "nftables is already installed."
    fi
}

configure_nftables() {
    # Reads the port security/ssh.sh chose, and only asks if it was never set,
    # so the ruleset can never open a port sshd is not listening on.
    resolve_ssh_port

    WAN_IF=$(ip route | awk '/^default/ {print $5; exit}')
    if [ -z "$WAN_IF" ]; then
        printf "%b\n" "Could not detect default interface, aborting nftables configuration."
        exit 1
    fi

    sudo WAN_IF="$WAN_IF" SSH_PORT="$SSH_PORT" bash -c '
    cat > /etc/nftables.conf << EOF
#!/usr/bin/nft -f

flush ruleset

table inet filter {

  chain input {
    type filter hook input priority 0; policy drop;

    ct state invalid drop
    ct state { established, related } accept

    iif lo accept

    # loopback protection
    iif != lo ip daddr 127.0.0.0/8 drop
    iif != lo ip6 daddr ::1/128 drop

    # ICMP 
    ip protocol icmp limit rate 10/second accept
    ip6 nexthdr icmpv6 limit rate 10/second accept

    # SSH 
    tcp dport $SSH_PORT ct state new limit rate 10/minute accept

    # Web 
    tcp dport {80, 443} accept

    # Libvirt 
    iifname "virbr0" accept

    # anti-spoofing 
    iifname "$WAN_IF" ip saddr {
      10.0.0.0/8,
      172.16.0.0/12,
      192.168.0.0/16,
      127.0.0.0/8
    } drop

    log prefix "DROP_INPUT " limit rate 5/second counter drop
  }

  chain forward {
    type filter hook forward priority 0; policy drop;

    ct state invalid drop
    ct state { established, related } accept

    # Docker 
    iifname "docker0" accept
    iifname "br-*" accept

    # Libvirt VM
    iifname "virbr0" accept
    oifname "virbr0" accept
  }

  chain output {
    type filter hook output priority 0; policy accept;
  }
}

table ip nat {
  chain postrouting {
    type nat hook postrouting priority 100;

    # Docker NAT 
    ip saddr 172.16.0.0/12 oifname "$WAN_IF" masquerade

    # Libvirt NAT
    ip saddr 192.168.122.0/24 oifname "$WAN_IF" masquerade
  }
}

EOF

systemctl enable --now nftables

    cat > /etc/sysctl.d/90-network.conf << EOF
# Do not act as a router
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# SYN flood protection
net.ipv4.tcp_syncookies = 1

# Disable ICMP redirect
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Do not send ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

EOF
    sysctl --system
'
}
install_nftables
configure_nftables
