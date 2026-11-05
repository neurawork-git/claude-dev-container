# Vorab-Check für claude-dev-container: läuft Docker, ist VS Code mit "Dev Containers" da, gibt es Git?
# Aufruf in PowerShell: powershell -ExecutionPolicy Bypass -File .\vorab-check.ps1
# Ändert nichts am Rechner. Exit 0 = bereit, Exit 1 = etwas fehlt.

$fehlt = @()

function Zeile($ok, $was, $detail) {
    $marke = if ($ok) { "[ok]    " } else { "[fehlt] " }
    Write-Output ("{0}{1}: {2}" -f $marke, $was, $detail)
}

# 1. Docker: Kommandozeile und laufender Server
if (Get-Command docker -ErrorAction SilentlyContinue) {
    $server = docker version --format '{{.Server.Version}}' 2>$null
    if ($LASTEXITCODE -eq 0 -and $server) {
        $os = docker info --format '{{.OSType}}' 2>$null
        if ($os -eq "linux") {
            Zeile $true "Docker" "Server $server, Linux-Container"
        } else {
            Zeile $false "Docker" "Server läuft mit '$os'-Containern; auf Linux-Container umschalten"
            $fehlt += "Docker"
        }
    } else {
        Zeile $false "Docker" "Kommandozeile da, aber kein Server: Docker Desktop (oder die Alternative) starten"
        $fehlt += "Docker"
    }
} else {
    Zeile $false "Docker" "nicht installiert: Docker Desktop, Rancher Desktop, Podman oder Docker Engine in WSL"
    $fehlt += "Docker"
}

# 2. VS Code und die Erweiterung Dev Containers
if (Get-Command code -ErrorAction SilentlyContinue) {
    $erweiterungen = code --list-extensions 2>$null
    if ($erweiterungen -contains "ms-vscode-remote.remote-containers") {
        Zeile $true "VS Code" "Erweiterung Dev Containers installiert"
    } else {
        Zeile $false "VS Code" "Erweiterung fehlt: code --install-extension ms-vscode-remote.remote-containers"
        $fehlt += "Dev Containers"
    }
} else {
    Zeile $false "VS Code" "Befehl 'code' nicht gefunden: VS Code installieren"
    $fehlt += "VS Code"
}

# 3. Git
if (Get-Command git -ErrorAction SilentlyContinue) {
    Zeile $true "Git" ((git --version) -replace '^git version ', '')
} else {
    Zeile $false "Git" "nicht installiert: git-scm.com"
    $fehlt += "Git"
}

if ($fehlt.Count -eq 0) {
    Write-Output "bereit"
    exit 0
}
Write-Output ("nicht bereit, es fehlt: " + ($fehlt -join ", "))
exit 1
