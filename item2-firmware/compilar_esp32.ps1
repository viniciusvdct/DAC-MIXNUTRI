<#
Compila ou grava o ESP32 mesmo quando o caminho do projeto contem acentos.
O linker do toolchain Windows pode falhar com "Area de Trabalho"; subst cria
uma letra temporaria sem mover os arquivos.
#>
[CmdletBinding()]
param(
    [switch]$Upload,
    [switch]$Monitor,
    [string]$Port
)

$ErrorActionPreference = 'Stop'
$projectDir = $PSScriptRoot
$config = Join-Path $projectDir 'firmware\config_local.h'
if ($Upload -and -not (Test-Path -LiteralPath $config)) {
    throw 'Configure a rede primeiro: execute item3-integracao/ferramentas/preparar_esp32.ps1 para criar config_local.h.'
}
if ($Monitor -and -not $Port) { throw 'Informe -Port COMx para abrir o monitor serial' }

$drive = @('P:', 'Q:', 'R:', 'S:', 'T:', 'U:', 'V:', 'W:', 'X:', 'Y:', 'Z:') |
    Where-Object { -not (Test-Path "$_\") } | Select-Object -First 1
if (-not $drive) { throw 'Nao ha uma letra de unidade temporaria livre (P: a Z:)' }

subst $drive $projectDir
if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar a unidade temporaria' }
try {
    $env:PLATFORMIO_CORE_DIR = "$drive\.platformio"
    $localPio = "$drive\.venv\Scripts\pio.exe"
    if (Test-Path -LiteralPath $localPio) {
        $pio = $localPio
    } else {
        $found = Get-Command pio -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $found) { throw 'Instale PlatformIO ou use o ambiente .venv do projeto' }
        $pio = $found.Source
    }

    if (-not $Monitor -or $Upload) {
        $arguments = @('run', '-d', "$drive\firmware", '-e', 'esp32dev')
        if ($Upload) { $arguments += @('-t', 'upload') }
        if ($Port) { $arguments += @('--upload-port', $Port) }
        & $pio @arguments
        if ($LASTEXITCODE -ne 0) { throw "PlatformIO falhou (codigo $LASTEXITCODE)" }
    }
    if ($Monitor) {
        & $pio device monitor -p $Port -b 115200
        if ($LASTEXITCODE -ne 0) { throw "Monitor serial falhou (codigo $LASTEXITCODE)" }
    }
} finally {
    subst $drive /D | Out-Null
}
