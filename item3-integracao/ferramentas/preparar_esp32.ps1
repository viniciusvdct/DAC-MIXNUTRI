<#
Prepara o ESP32 fisico e o Mosquitto para a rede local do computador.
Execute novamente se o IP do computador mudar e grave o firmware outra vez.
O nome e a senha do Wi-Fi sao pedidos interativamente; a senha nao vai para o historico.
#>
[CmdletBinding()]
param(
    [string]$WifiSsid,
    [Security.SecureString]$WifiPassword,
    [string]$BrokerIp,
    [switch]$Force,
    [switch]$NoCompose,
    [switch]$ConfigureFirewall,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$kitDir = Split-Path -Parent $PSScriptRoot
$repoDir = Split-Path -Parent $kitDir
$firmwareDir = Join-Path $repoDir 'item2-firmware\firmware'
$envPath = Join-Path $kitDir '.env'
$configPath = Join-Path $firmwareDir 'config_local.h'

function Get-LanAddresses {
    foreach ($adapter in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
        if ($adapter.OperationalStatus -ne 'Up' -or
            $adapter.Name -match 'VPN|Radmin|vEthernet|Virtual|WSL|Hyper-V|Tailscale|Loopback|Docker' -or
            $adapter.Description -match 'VPN|Radmin|Virtual|WSL|Hyper-V|Tailscale|Loopback|Docker') {
            continue
        }
        $properties = $adapter.GetIPProperties()
        $hasGateway = @($properties.GatewayAddresses | Where-Object {
            $_.Address.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork
        }).Count -gt 0
        if (-not $hasGateway) { continue }
        foreach ($address in $properties.UnicastAddresses) {
            if ($address.Address.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { continue }
            $ip = $address.Address.IPAddressToString
            if ($ip -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)') {
                [pscustomobject]@{ Ip = $ip; Adapter = $adapter.Name }
            }
        }
    }
}

function Quote-CString([string]$value) {
    if ($value.Contains([char]10) -or $value.Contains([char]13) -or $value.Contains([char]0)) {
        throw 'SSID ou senha contem um caractere de controle nao permitido'
    }
    return '"' + $value.Replace('\', '\\').Replace('"', '\"') + '"'
}

if (-not (Test-Path -LiteralPath $envPath)) {
    throw "Crie primeiro o arquivo .env em $kitDir"
}
if ((Test-Path -LiteralPath $configPath) -and -not $Force -and -not $DryRun) {
    throw "config_local.h ja existe. Use -Force para substitui-lo quando mudar a rede."
}

$lan = @(Get-LanAddresses)
if (-not $BrokerIp) {
    if ($lan.Count -ne 1) {
        $options = ($lan | ForEach-Object { "$($_.Ip) ($($_.Adapter))" }) -join ', '
        throw "Nao foi possivel escolher uma unica rede local: $options. Use -BrokerIp."
    }
    $BrokerIp = $lan[0].Ip
}
$parsedIp = $null
if (-not [Net.IPAddress]::TryParse($BrokerIp, [ref]$parsedIp) -or
    $parsedIp.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -or
    $BrokerIp -notin @($lan | ForEach-Object Ip)) {
    throw "BrokerIp deve ser um IPv4 ativo deste computador em uma rede local: $BrokerIp"
}

if (-not $WifiSsid) { $WifiSsid = Read-Host 'Nome da rede Wi-Fi 2,4 GHz do ESP32' }
if (-not $WifiPassword) { $WifiPassword = Read-Host 'Senha do Wi-Fi (nao aparece na tela)' -AsSecureString }
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($WifiPassword)
try {
    $wifiPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}
if ([Text.Encoding]::UTF8.GetByteCount($WifiSsid) -lt 1 -or
    [Text.Encoding]::UTF8.GetByteCount($WifiSsid) -gt 32) {
    throw 'O SSID deve ter entre 1 e 32 bytes em UTF-8'
}
if ($wifiPlain.Length -lt 8 -or $wifiPlain.Length -gt 63) {
    throw 'A senha WPA2 do Wi-Fi deve ter entre 8 e 63 caracteres'
}

$envText = [IO.File]::ReadAllText($envPath)
$values = @{}
foreach ($line in ($envText -split "\r?\n")) {
    if ($line -match '^([A-Z][A-Z0-9_]*)=(.*)$') { $values[$Matches[1]] = $Matches[2] }
}
foreach ($key in @('MQTT_ESP32_USUARIO', 'MQTT_ESP32_SENHA')) {
    if (-not $values.ContainsKey($key) -or -not $values[$key] -or
        $values[$key].StartsWith('TROCAR_')) {
        throw "Credencial $key ausente no .env"
    }
}
if ($ConfigureFirewall) {
    $principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Execute PowerShell como Administrador para usar -ConfigureFirewall'
    }
}

$header = @(
    '// Gerado por item3-integracao/ferramentas/preparar_esp32.ps1.',
    '// Arquivo local com senhas: nao publique nem compartilhe.',
    '#pragma once',
    '#define MIXNUTRI_SIMULACAO 0',
    "static const char *WIFI_SSID = $(Quote-CString $WifiSsid), *WIFI_SENHA = $(Quote-CString $wifiPlain);",
    'static const int WIFI_CANAL = 0;',
    "static const char *MQTT_HOST = $(Quote-CString $BrokerIp);",
    'static const uint16_t MQTT_PORTA = 1883;',
    "static const char *MQTT_USUARIO = $(Quote-CString $values['MQTT_ESP32_USUARIO']), *MQTT_SENHA = $(Quote-CString $values['MQTT_ESP32_SENHA']);",
    'static const char *TOPICO_BASE = "mixnutri/sala01";',
    'static const char *DEVICE_ID = "sala01-esp32", *SALA_ID = "sala01";'
) -join [Environment]::NewLine
$wifiPlain = $null

if ($DryRun) {
    Write-Output "Verificacao OK: broker $BrokerIp, SSID informado, credenciais MQTT presentes."
    return
}

$newEnvLine = "MQTT_BIND=$BrokerIp"
if ($envText -match '(?m)^MQTT_BIND=.*$') {
    $newEnv = [regex]::Replace($envText, '(?m)^MQTT_BIND=.*$', $newEnvLine)
} else {
    $newEnv = $envText.TrimEnd() + [Environment]::NewLine + $newEnvLine + [Environment]::NewLine
}
[IO.File]::WriteAllText($configPath, $header + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($envPath, $newEnv, [Text.UTF8Encoding]::new($false))

if ($ConfigureFirewall) {
    $rule = Get-NetFirewallRule -DisplayName 'MixNutri MQTT ESP32' -ErrorAction SilentlyContinue
    if ($rule) { $rule | Remove-NetFirewallRule }
    New-NetFirewallRule -DisplayName 'MixNutri MQTT ESP32' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1883 -LocalAddress $BrokerIp -RemoteAddress LocalSubnet -Profile Any | Out-Null
}

if (-not $NoCompose) {
    $docker = (Get-Command docker -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source)
    if (-not $docker) {
        $docker = Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin\docker.exe'
    }
    if (-not (Test-Path -LiteralPath $docker)) { throw 'Docker nao encontrado; inicie o Docker Desktop' }
    $env:Path = "$(Split-Path -Parent $docker);$env:Path"
    Push-Location $kitDir
    try {
        & $docker compose up -d mosquitto
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao publicar o Mosquitto na rede local' }
    } finally {
        Pop-Location
    }
}
Write-Output "Pronto: ESP32 -> $($BrokerIp):1883 -> Mosquitto -> PostgreSQL -> Grafana."
Write-Output "Compile e grave item2-firmware/firmware com PlatformIO. Verifique wifi=1 mqtt=1 no serial."
