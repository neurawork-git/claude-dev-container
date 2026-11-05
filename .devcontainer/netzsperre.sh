#!/usr/bin/env bash
# Netzsperre für den Dev Container.
# Ausgehend ist alles gesperrt, außer: Loopback, Namensauflösung über die
# Namensserver des Containers, schon bestehende Verbindungen, GitHub und die
# Domains aus /usr/local/etc/netzsperre/erlaubt.txt.
# Läuft bei jedem Start des Containers (postStartCommand) als root über sudo und
# prüft am Ende sich selbst. Schlägt der Selbsttest fehl, endet es mit Exit 1.
set -euo pipefail

LISTE=/usr/local/etc/netzsperre/erlaubt.txt
SATZ=netzsperre-erlaubt     # Adressmenge, auf die die Regel zeigt
NEU=netzsperre-neu          # wird erst gefüllt, dann gegen SATZ getauscht

meldung() { echo "netzsperre: $*"; }
abbruch() { echo "netzsperre: FEHLER: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || abbruch "muss als root laufen: sudo $0"
[ -r "$LISTE" ] || abbruch "Liste $LISTE fehlt."

# ---------------------------------------------------------------------------
# 1. Sammeln, solange das Netz noch offen ist (oder GitHub schon erlaubt ist).
# ---------------------------------------------------------------------------

# Namensserver aus resolv.conf. Nur an sie darf Port 53 gehen.
namensserver=$(awk '$1 == "nameserver" && $2 ~ /^[0-9.]+$/ {print $2}' /etc/resolv.conf)
[ -n "$namensserver" ] || abbruch "kein IPv4-Namensserver in /etc/resolv.conf."

ipset create "$NEU" hash:net family inet -exist
ipset flush "$NEU"

# GitHub veröffentlicht seine Adressbereiche selbst. Übernommen werden die für
# Webseite, API und Git (nur IPv4).
github_json=$(curl -fsS --max-time 15 https://api.github.com/meta) \
  || abbruch "GitHub-Adressliste von api.github.com/meta nicht abrufbar."
github_netze=$(jq -r '(.web + .api + .git)[]' <<<"$github_json" | grep -v ':' | sort -u)
[ -n "$github_netze" ] || abbruch "GitHub-Adressliste ist leer."
for netz in $github_netze; do
  ipset add "$NEU" "$netz" -exist
done
meldung "erlaubt: GitHub ($(wc -w <<<"$github_netze") Bereiche)"

# Domains aus der Liste auflösen. Jede Adresse kommt einzeln in die Menge;
# -exist, weil sich Domains Adressen teilen können.
while IFS= read -r zeile || [ -n "$zeile" ]; do
  zeile=${zeile%$'\r'}            # Windows-Zeilenende abschneiden
  domain=${zeile%%#*}             # Kommentar abschneiden
  domain=$(xargs <<<"$domain")    # Leerzeichen abschneiden
  [ -z "$domain" ] && continue
  adressen=$(getent ahostsv4 "$domain" | awk '{print $1}' | sort -u)
  [ -n "$adressen" ] || abbruch "$domain lässt sich nicht auflösen."
  for adresse in $adressen; do
    ipset add "$NEU" "$adresse" -exist
  done
  meldung "erlaubt: $domain ($(wc -w <<<"$adressen") Adressen)"
done < "$LISTE"

# Neue Menge in einem Zug gegen die alte tauschen.
ipset create "$SATZ" hash:net family inet -exist
ipset swap "$NEU" "$SATZ"
ipset destroy "$NEU"

# ---------------------------------------------------------------------------
# 2. Sperren. Erst alles auf Verwerfen, dann die Ausnahmen neu eintragen.
#    Die nat-Tabelle bleibt unberührt: Dort leitet Docker seine Namensauflösung um.
# ---------------------------------------------------------------------------
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
iptables -F INPUT
iptables -F FORWARD
iptables -F OUTPUT

# Eingehend: nur Loopback und Antworten auf eigene Verbindungen.
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Ausgehend: Loopback, bestehende Verbindungen, Namensauflösung, Liste.
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
for server in $namensserver; do
  iptables -A OUTPUT -d "$server" -p udp --dport 53 -j ACCEPT
  iptables -A OUTPUT -d "$server" -p tcp --dport 53 -j ACCEPT
done
iptables -A OUTPUT -m set --match-set "$SATZ" dst -j ACCEPT
# Alles andere sofort ablehnen statt still verwerfen: Programme scheitern schnell
# mit einer klaren Meldung, statt in eine Zeitüberschreitung zu laufen.
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

# IPv6: komplett gesperrt bis auf Loopback.
if ip6tables -L -n >/dev/null 2>&1; then
  ip6tables -P INPUT DROP
  ip6tables -P FORWARD DROP
  ip6tables -P OUTPUT DROP
  ip6tables -F INPUT
  ip6tables -F FORWARD
  ip6tables -F OUTPUT
  ip6tables -A INPUT -i lo -j ACCEPT
  ip6tables -A OUTPUT -o lo -j ACCEPT
  ip6tables -A OUTPUT -j REJECT
  meldung "IPv6 gesperrt"
elif awk '$4 == "00" {gefunden = 1} END {exit !gefunden}' /proc/net/if_inet6 2>/dev/null; then
  abbruch "Container hat eine öffentliche IPv6-Adresse, ip6tables steht aber nicht zur Verfügung."
else
  meldung "IPv6 nicht vorhanden"
fi

# ---------------------------------------------------------------------------
# 3. Selbsttest: Gesperrtes muss scheitern, Erlaubtes muss gehen.
# ---------------------------------------------------------------------------
if curl -sS --max-time 5 -o /dev/null https://example.com 2>/dev/null; then
  abbruch "Selbsttest: example.com ist erreichbar, die Sperre greift nicht."
fi
meldung "Selbsttest: example.com gesperrt"

curl -sS --max-time 10 -o /dev/null https://api.github.com/zen \
  || abbruch "Selbsttest: api.github.com nicht erreichbar, die Liste greift nicht."
meldung "Selbsttest: api.github.com erreichbar"

meldung "aktiv"
