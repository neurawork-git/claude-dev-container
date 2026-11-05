# Bauplan des Arbeitsraums. Claude Code selbst kommt als Dev-Container-Feature
# (siehe devcontainer.json), hier steht nur, was die Netzsperre und der Alltag brauchen.
FROM node:22-bookworm

# Verknüpft das fertige Image in der GitHub Container Registry mit diesem Repo.
LABEL org.opencontainers.image.source=https://github.com/neurawork-git/claude-dev-container

# Werkzeuge: iptables + ipset für die Netzsperre, jq für die GitHub-Adressliste,
# sudo für genau ein Skript, dazu Git und ein paar Helfer fürs Terminal.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      iptables ipset jq curl ca-certificates sudo git less procps tzdata \
 && rm -rf /var/lib/apt/lists/*

# Die Netzsperre und ihre Liste gehören root. Der Benutzer `node` darf das Skript
# starten, aber weder das Skript noch die Liste ändern.
COPY netzsperre.sh /usr/local/bin/netzsperre.sh
COPY erlaubt.txt /usr/local/etc/netzsperre/erlaubt.txt
RUN chmod 0755 /usr/local/bin/netzsperre.sh \
 && chmod 0644 /usr/local/etc/netzsperre/erlaubt.txt \
 && echo 'node ALL=(root) NOPASSWD: /usr/local/bin/netzsperre.sh' > /etc/sudoers.d/netzsperre \
 && chmod 0440 /etc/sudoers.d/netzsperre \
 && visudo -cf /etc/sudoers.d/netzsperre

# Ziele der Volumes vorab anlegen und `node` übergeben: Ein neues Volume übernimmt
# beim ersten Einhängen den Besitzer dieses Ordners.
RUN mkdir -p /home/node/.claude /commandhistory /workspace \
 && chown -R node:node /home/node/.claude /commandhistory /workspace

USER node
WORKDIR /workspace
