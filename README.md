# claude-dev-container: Claude Code im Dev Container, mit Netzsperre

## Für wen

Devs und IT-Verantwortliche, die Claude Code in VS Code nutzen und den Agenten nicht mehr direkt auf dem Laptop arbeiten lassen wollen, sondern in einem abgeschotteten Container, für ein Repo, dem sie trauen.

## Was es tut

Der Ordner `.devcontainer/` macht ein beliebiges Repo zum Dev Container: VS Code arbeitet im Container als Benutzer `node`, das Repo ist nach `/workspace` eingehängt, der Login von Claude Code liegt in einem Volume, und ausgehend ist nur eine Liste von Zielen erreichbar.

| Datei | Was darin steht |
|---|---|
| `.devcontainer/Dockerfile` | der Bauplan: Node 22, Git und die Werkzeuge der Netzsperre; gearbeitet wird als `node` ohne Administratorrechte |
| `.devcontainer/devcontainer.json` | der Anschluss: Claude Code als Dev-Container-Feature, Repo als eingehängter Ordner, zwei Volumes je Projekt, Netzsperre bei jedem Start |
| `.devcontainer/netzsperre.sh` | die Netzsperre: ausgehend alles gesperrt außer Namensauflösung, GitHub und den Zielen aus `erlaubt.txt`; prüft sich beim Start selbst und bricht den Start ab, wenn die Sperre nicht greift |
| `.devcontainer/erlaubt.txt` | die Liste der erlaubten Ziele, eine Domain je Zeile |
| `vorab-check.ps1` | prüft vor dem ersten Start Docker, VS Code mit „Dev Containers“ und Git |

## Die Regel dahinter

Repos, denen du nicht traust, auf eine VM, alles andere in Container. Zustand ins Volume, Code ins Repo, Werkzeuge ins Image. Ohne Freigaben arbeitet der Agent im Dev Container hinter der Netzsperre, an Repos, denen du traust.

## Voraussetzungen

- **Docker.** Docker Desktop mit WSL 2 (Installation braucht Administratorrechte und meist einen Neustart: `docs.docker.com/desktop/setup/install/windows-install/`). Docker Desktop ist kostenlos privat, in der Bildung, für nicht-kommerzielle Open Source und in Firmen unter 250 Beschäftigten **und** unter 10 Mio. $ Jahresumsatz, sonst braucht es ein Abo (`docs.docker.com/subscription/desktop-license/`). Ohne Abo: Docker Engine direkt in Ubuntu unter WSL, Rancher Desktop oder Podman Desktop; VS Code Dev Containers arbeitet mit allen dreien.
- **VS Code** mit der Erweiterung „Dev Containers“: `code --install-extension ms-vscode-remote.remote-containers`
- **Git**
- **Ein Claude-Konto** mit Abo für den Login im Container. Andere Anmeldewege, etwa ein langlebiges Token aus `claude setup-token`, beschreibt Anthropic unter `code.claude.com/docs/en/authentication`.
- Rund 2 GB Platz für das Image und Internet für den ersten Bau.

## Installation

1. **Vorlage holen und prüfen.** In PowerShell:
   ```powershell
   git clone https://github.com/neurawork-git/claude-dev-container
   cd claude-dev-container
   powershell -ExecutionPolicy Bypass -File .\vorab-check.ps1
   ```
   Am Ende steht `bereit`. Sonst nennt das Skript, was fehlt. Für dein eigenes Repo: statt im Klon zu arbeiten, den Ordner `.devcontainer/` in die Wurzel deines Repos kopieren, samt der Datei `.devcontainer/.gitattributes` darin. Sie hält die Skripte auf Unix-Zeilenenden; mit Windows-Zeilenenden bricht der Start mit `$'\r': command not found` ab.
2. **Container bauen und verbinden.** `code .`, dann Befehlspalette (`F1`) → **„Dev Containers: Reopen in Container“**. Der erste Bau lädt das Basis-Image und dauert einige Minuten. Danach steht unten links „Dev Container“, und das Terminal (`Terminal → New Terminal`) läuft im Container.
3. **Claude Code anmelden.** Im Terminal `claude` starten und das Claude-Konto wählen. Im Container gibt es keinen Browser: Claude Code zeigt eine Login-URL (`c` kopiert sie), die öffnest du im Browser des Laptops, meldest dich an und fügst den angezeigten Code bei `Paste code here` ein. Fertig, wenn `Login successful` erscheint.

Jedes Repo bekommt eigene Volumes, also einmal je Repo anmelden. Den Ordner `.devcontainer/` committen: Wer das Repo klont, bekommt dieselbe Umgebung.

## Prüfen, dass es steht

Im Terminal des Containers:

```bash
whoami                                            # node
claude --version                                  # Versionsnummer von Claude Code
curl -sS --max-time 5 https://example.com         # scheitert: Failed to connect
curl -sS --max-time 5 https://api.github.com/zen  # antwortet mit einem Satz
```

Dienste auf dem Laptop sind ebenfalls gesperrt: Läuft auf dem Laptop etwa `python -m http.server 8099 --bind 127.0.0.1`, scheitert im Container `curl -m 5 http://host.docker.internal:8099` mit `Failed to connect`.

Zustand im Volume: Befehlspalette → **„Dev Containers: Rebuild Container“**, danach startet `claude` ohne neue Anmeldung.

Ohne Einzelfreigaben arbeiten lassen: im Container `claude --dangerously-skip-permissions`. Als root verweigert Claude Code das; darum arbeitet die Vorlage als `node`.

## Anpassen

- **Liste erweitern.** Braucht dein Projekt PyPI oder eine Paketquelle der Firma, trägst du die Domain in `.devcontainer/erlaubt.txt` ein (Beispiele stehen auskommentiert darin), dann „Rebuild Container“. Die Liste wird ins Image gebaut und gehört dort root: Der Agent kann die laufende Sperre nicht selbst lockern.
- **Anderer Coding-Agent.** In `devcontainer.json` das Feature von Claude Code durch die Installation des anderen Agenten ersetzen, in `erlaubt.txt` die Domains seines Anbieters eintragen; die Anthropic-Domains können raus.
- **Zeitzone.** Der Container übernimmt die Umgebungsvariable `TZ` des Laptops, sonst `Europe/Berlin`.

## Sicherheit

- **Nur für Repos, denen du traust.** Mit `--dangerously-skip-permissions` kann ein bösartiges Projekt alles abfließen lassen, was im Container liegt, auch deinen Claude-Login, und zwar über jedes erlaubte Ziel, GitHub eingeschlossen.
- **Keine Schlüssel oder Geheimnisse vom Laptop einhängen**, etwa `~/.ssh` oder `.env`-Dateien mit echten Zugangsdaten.
- **Das Repo ist schreibbar eingehängt:** Jede Änderung im Container landet sofort auf deinem Laptop, auch eine an `.devcontainer/erlaubt.txt`. Änderungen an `.devcontainer/` vor einem Rebuild ansehen.
- **Was offen bleibt:** Namensauflösung über den Namensserver des Containers. Gesperrt sind Dienste auf dem Laptop, Geräte im Heimnetz und IPv6.
- `sudo` darf `node` nur für `netzsperre.sh`, sonst nichts.

## Beispiel

Eingabe (`beispiel/eingabe.txt`): ein frisches Repo `mein-projekt` mit nur einer README, `.devcontainer/` hineinkopiert, Container gebaut, dann die Prüfschritte. Den Bau übernimmt im Beispiel die Dev-Containers-Kommandozeile (`npx @devcontainers/cli up --workspace-folder .`), dasselbe, was VS Code bei „Reopen in Container“ tut.

Ausgabe (`beispiel/erwartet.txt`, echter Lauf), gekürzt:

```text
netzsperre: Selbsttest: example.com gesperrt
netzsperre: Selbsttest: api.github.com erreichbar
netzsperre: aktiv
$ whoami
node
$ claude --version
2.1.318 (Claude Code)
$ curl -sS --max-time 5 https://example.com
curl: (7) Failed to connect to example.com port 443 after 16 ms: Couldn't connect to server
$ curl -sS --max-time 5 https://api.github.com/zen
Responsive is better than fast.
$ curl -sS -m 5 http://host.docker.internal:8099
curl: (7) Failed to connect to host.docker.internal port 8099 after 1 ms: Couldn't connect to server
-- Container gelöscht und neu gebaut --
$ cat ~/.claude/marker.txt
1793876934
```

## Grundlagen zum Nachmachen

Neben der Vorlage liegen zwei kleine Beispiele, mit denen du die Grundbegriffe selbst ausprobierst. Befehle in Git-Bash oder einem Linux-Terminal, Docker muss laufen.

**`beispiele/hallo/`: ein Image bauen und starten.** Ein Dockerfile auf Basis von `alpine:3.21` und ein Skript `app.sh`.

```bash
cd claude-dev-container/beispiele/hallo
docker build -t hallo .
docker history hallo
echo 'echo 3' >> app.sh && docker build -t hallo .   # nur COPY läuft neu
docker run --rm hallo
```

Zustand und Port:

```bash
docker run --rm -v daten:/daten alpine sh -c "echo wichtig > /daten/daten.txt"
docker run --rm -v daten:/daten alpine sh -c "cat /daten/daten.txt"
docker run -d --name web -p 127.0.0.1:8080:8080 hallo sh -c "busybox-extras httpd -f -p 8080 -h /app"
# Browser: http://127.0.0.1:8080/app.sh
docker rm -f web && docker volume rm daten
```

**`beispiele/compose/`: drei Dienste aus einer Datei.** Datenbank, lokales Sprachmodell (Ollama) und Open WebUI. Die Images sind zusammen mehrere GB groß.

```bash
cd claude-dev-container/beispiele/compose
cp env.example .env        # eigenes Passwort eintragen; .env bleibt lokal
docker compose up -d       # Oberfläche: http://127.0.0.1:3000
docker compose down
```

## Wann es nicht passt

- **Das Repo ist fremd oder nicht vertrauenswürdig.** Der Container teilt sich den Kernel mit allen anderen Containern auf deinem Rechner, und was darin liegt, kann über erlaubte Ziele hinaus. Dafür eine eigene VM.
- **Firmenlaptop ohne Administratorrechte, WSL gesperrt, Firmen-Proxy oder Prüfung verschlüsselter Verbindungen.** Dann können Bau, Netzsperre oder Login scheitern; vorher mit der IT klären.
- **Der Agent soll selbst Container bauen.** Docker im Container hebelt die Abschottung aus. Dafür gibt es Docker Sandboxes mit einer eigenen kleinen VM je Agent (`docs.docker.com/ai/sandboxes/`).
- **Kein Docker am Laptop.** Dieselbe `devcontainer.json` läuft in GitHub Codespaces; dort bleibt der Login bei Stop und Start erhalten, bei einem Rebuild nicht.
- **Langsamer Dateizugriff.** Ein Repo auf Laufwerk `C:` ist im Container spürbar langsamer als eines im WSL-Dateisystem. Schneller: „Dev Containers: Clone Repository in Container Volume“.

## Lizenzen

- Diese Vorlage: MIT, siehe `LICENSE`.
- Claude Code kommt über das Dev-Container-Feature `ghcr.io/anthropics/devcontainer-features/claude-code:1` (`github.com/anthropics/devcontainer-features`, MIT). Für Claude Code selbst gelten die Bedingungen von Anthropic.
- Basis-Image `node:22-bookworm` ist ein Docker Official Image (`hub.docker.com/_/node`); Node.js steht unter MIT, die Debian-Pakete darin unter ihren eigenen Lizenzen.
- Die VS-Code-Erweiterung „Dev Containers“ (`ms-vscode-remote.remote-containers`) und die Dev-Containers-Kommandozeile (`@devcontainers/cli`, MIT) sind Werkzeuge auf dem Laptop, nicht Teil der Vorlage.
