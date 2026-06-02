# Firewall.wiki Community

Origin protection for Linux servers running behind Cloudflare or a protected gateway.

Firewall.wiki Community helps protect selected origin ports from abusive client traffic while keeping deployment simple.

```bash
curl -fsSL https://raw.githubusercontent.com/wlan1/firewall-wiki-community/main/install.sh | sudo bash
```

## Recommended deployment

Firewall.wiki Community should be deployed behind Cloudflare, a reverse proxy, or another protected edge.

```text
Visitor -> Cloudflare -> Origin with Firewall.wiki Community
```

Also supported:

```text
Visitor -> Protected Gateway -> Origin with Firewall.wiki Community
```

Do not expose the origin directly to the public Internet unless your upstream network already provides volumetric DDoS protection.

## Features

* One-command installation
* Linux kernel 5.x and 6.x support
* Protect one or many origin ports
* TCP and UDP service protection
* Per-client-IP traffic control
* Shared client control across protected ports
* Lightweight origin deployment
* Simple file-based configuration
* Suitable for web, API, TCP service, and game origin protection
* Recommended behind Cloudflare or another protected gateway

## Requirements

```text
Linux kernel: 5.x / 6.x
Architecture: x86_64
Privileges: root
Init system: systemd
```

Required tools:

```text
bash
iproute2
bpftool
systemd
```

Recommended distributions:

```text
CentOS Stream 9
Rocky Linux 9
AlmaLinux 9
Ubuntu 22.04+
Debian 12+
```

## Install

Default install:

```bash
curl -fsSL https://raw.githubusercontent.com/wlan1/firewall-wiki-community/main/install.sh | sudo bash
```

Install with custom interface:

```bash
curl -fsSL https://raw.githubusercontent.com/wlan1/firewall-wiki-community/main/install.sh | sudo IFACE=eth0 bash
```

Install with custom config URL:

```bash
curl -fsSL https://raw.githubusercontent.com/wlan1/firewall-wiki-community/main/install.sh | sudo CONFIG_URL=https://example.com/config.cfg bash
```

## Configuration

Default config path:

```text
/opt/firewall-wiki-community/config.cfg
```

Example:

```cfg
iface=eth0

# Gateway / protected edge address.
# Use 127.0.0.1 for local Community mode.
gw_ip=127.0.0.1

# Protect one or many ports.
# Examples:
# origin_port=80
# origin_port=80,443
# origin_port=80,8080,25565
origin_port=80,8080

# Enable origin protection.
rate_limit=true
```

## TCP / UDP port protection

Firewall.wiki Community protects ports from the config file.

Use:

```cfg
origin_port=80,8080
```

This means the configured service ports are protected for supported TCP/UDP traffic handled by the runtime profile.

For web services:

```cfg
origin_port=80,443
```

For web plus application service:

```cfg
origin_port=80,443,8080
```

For game or UDP service:

```cfg
origin_port=27015,7777
```

## Traffic model

Community uses a client-based model.

```text
protected port match -> client IP control
```

Port is used to decide whether protection applies.

Client IP is used for traffic control.

This means:

```text
One IP hitting many protected ports -> one shared client control
Many IPs hitting one protected port -> separate client handling
```

Example:

```text
origin_port=80,8080
```

Then:

```text
1.2.3.4 -> 80
1.2.3.4 -> 8080
```

Both flows are treated as the same client.

This helps prevent simple port-spreading abuse where one source tries to multiply its allowance by hitting multiple protected ports.

But:

```text
1.1.1.1 -> 80
2.2.2.2 -> 80
3.3.3.3 -> 80
```

Each client is handled separately.

## Service control

Check status:

```bash
systemctl status firewall-wiki-community
```

Restart:

```bash
systemctl restart firewall-wiki-community
```

View logs:

```bash
journalctl -u firewall-wiki-community -f
```

Reload after config change:

```bash
systemctl restart firewall-wiki-community
```

## Uninstall

```bash
sudo /opt/firewall-wiki-community/uninstall.sh
```

## Files

```text
/opt/firewall-wiki-community/
├── config.cfg
├── firewall.wiki
├── libfirewall_core.so
├── origin.o
└── uninstall.sh
```

## Community vs Premium

Community is designed for simple origin protection behind Cloudflare or a protected gateway.

Premium adds managed gateway profiles, advanced service grouping, deployment support, and commercial assistance.

```text
https://firewall.wiki
```
