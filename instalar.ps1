# Instala o cliente MineServer no Windows.
# Funciona com o Minecraft oficial e com o SKLauncher: os dois leem o mesmo perfil.
param(
  [string]$MinecraftDir = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Req = Join-Path $Root "requirements\client.txt"
if (-not (Test-Path $Req)) {
  Write-Host "Não achei requirements\client.txt. Rode este instalador na pasta baixada do MineServer."
  exit 1
}

if (-not $MinecraftDir) {
  if ($env:MINECRAFT_DIR) { $MinecraftDir = $env:MINECRAFT_DIR }
  else { $MinecraftDir = Join-Path $env:APPDATA ".minecraft" }
}

function Read-Meta([string]$Key) {
  foreach ($line in Get-Content -LiteralPath $Req -Encoding UTF8) {
    if ($line.StartsWith("# $Key ")) {
      return $line.Substring(("# $Key ").Length).Trim()
    }
  }
  throw "A ficha não tem o campo $Key."
}

$MinecraftVersion = Read-Meta "minecraft"
$LoaderVersion = Read-Meta "loader_version"
$ProfileName = Read-Meta "profile"
$ProfileId = Read-Meta "profile_id"
$GameDirName = Read-Meta "game_dir"
$Memory = Read-Meta "memory"
$VersionId = "fabric-loader-$LoaderVersion-$MinecraftVersion"

$answer = $env:MINESERVER_SHADERS
if (-not $answer) {
  $answer = Read-Host "Quer instalar os shaders? O jogo fica mais bonito e mais pesado. Digite s para sim, ou Enter para não"
}
$WantShaders = $answer -match '^(s|sim)$'

$GameDir = Join-Path $MinecraftDir $GameDirName
New-Item -ItemType Directory -Force -Path (Join-Path $GameDir "mods") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $GameDir "shaderpacks") | Out-Null
$VersionDir = Join-Path $MinecraftDir "versions\$VersionId"
New-Item -ItemType Directory -Force -Path $VersionDir | Out-Null

function Get-Sha1([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA1).Hash.ToLowerInvariant()
}

function Save-Url([string]$Url, [string]$Dest, [string]$Sum) {
  if (-not $Url.StartsWith("https://")) {
    throw "A ficha tem um endereço que não é https: $Dest"
  }
  if ((Test-Path -LiteralPath $Dest) -and (Get-Sha1 $Dest) -eq $Sum) {
    Write-Host "já está certo: $(Split-Path -Leaf $Dest)"
    return
  }
  Write-Host "baixando $(Split-Path -Leaf $Dest)"
  $partial = "$Dest.partial"
  Invoke-WebRequest -Uri $Url -OutFile $partial -UseBasicParsing
  Move-Item -LiteralPath $partial -Destination $Dest -Force
  if ((Get-Sha1 $Dest) -ne $Sum) {
    Remove-Item -LiteralPath $Dest -Force
    throw "O arquivo $(Split-Path -Leaf $Dest) não confere com a ficha."
  }
}

function Update-LoaderPin([string]$Jar, [string]$Needed) {
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::Open($Jar, [System.IO.Compression.ZipArchiveMode]::Update)
  try {
    $entry = $zip.GetEntry("fabric.mod.json")
    if (-not $entry) { throw "Não achei fabric.mod.json em $(Split-Path -Leaf $Jar)." }
    $reader = New-Object System.IO.StreamReader($entry.Open())
    $json = $reader.ReadToEnd()
    $reader.Close()
    $needle = '"fabricloader": "0.19.3"'
    if (-not $json.Contains($needle)) {
      throw "Não achei a trava do Fabric Loader dentro de $(Split-Path -Leaf $Jar)."
    }
    $entry.Delete()
    $updated = $json.Replace($needle, '"fabricloader": "' + $Needed + '"')
    $created = $zip.CreateEntry("fabric.mod.json")
    $writer = New-Object System.IO.StreamWriter($created.Open())
    $writer.Write($updated)
    $writer.Close()
  } finally {
    $zip.Dispose()
  }
}

foreach ($line in Get-Content -LiteralPath $Req -Encoding UTF8) {
  if (-not $line -or $line.StartsWith("#")) { continue }
  $col = $line.Split("`t")
  if ($col.Length -lt 9) { throw "Linha incompleta na ficha." }
  $side = $col[0]
  $filename = $col[3]
  $sum = $col[4]
  $url = $col[5]
  $dest = $col[6]
  $patch = $col[7]
  if ($side -eq "shader" -and -not $WantShaders) { continue }
  if ($side -ne "required" -and $side -ne "shader") { throw "Lado desconhecido na ficha: $side" }
  $target = Join-Path (Join-Path $GameDir $dest) $filename
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
  Save-Url $url $target $sum
  if ($patch -ne "-") { Update-LoaderPin $target $patch }
}

$fabricJson = Join-Path $VersionDir "$VersionId.json"
Write-Host "baixando o perfil Fabric $VersionId"
Invoke-WebRequest -UseBasicParsing -OutFile $fabricJson `
  "https://meta.fabricmc.net/v2/versions/loader/$MinecraftVersion/$LoaderVersion/profile/json"

$profiles = Join-Path $MinecraftDir "launcher_profiles.json"
$stamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z")
$gameJson = $GameDir.Replace("\", "\\")
if (-not (Test-Path -LiteralPath $profiles)) {
  $fresh = @"
{
  "profiles": {
    "$ProfileId": {
      "created": "$stamp",
      "gameDir": "$gameJson",
      "icon": "Enchanting_Table",
      "javaArgs": "$Memory",
      "lastUsed": "$stamp",
      "lastVersionId": "$VersionId",
      "name": "$ProfileName",
      "type": "custom"
    }
  },
  "selectedProfile": "$ProfileId",
  "version": 4
}
"@
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($profiles, $fresh, $utf8)
} else {
  $text = [System.IO.File]::ReadAllText($profiles)
  if ($text -match ('"name"\s*:\s*"' + [regex]::Escape($ProfileName) + '"')) {
    Write-Host "O perfil $ProfileName já existe. Atualizei os mods dessa instalação."
  } else {
    $block = @"
    "$ProfileId": {
      "created": "$stamp",
      "gameDir": "$gameJson",
      "icon": "Enchanting_Table",
      "javaArgs": "$Memory",
      "lastUsed": "$stamp",
      "lastVersionId": "$VersionId",
      "name": "$ProfileName",
      "type": "custom"
    },
"@
    $updated = [regex]::Replace($text, '"profiles"\s*:\s*\{', '"profiles": {' + [Environment]::NewLine + $block, 1)
    if ($updated -eq $text) { throw "Não consegui acrescentar o perfil no launcher. Os mods estão em $GameDir" }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($profiles, $updated, $utf8)
  }
}

Write-Host ""
Write-Host "Pronto."
Write-Host "Abra o Minecraft oficial ou o SKLauncher e escolha o perfil $ProfileName."
Write-Host "O nome que você usa no launcher é o nome dentro do jogo. Use o seu."
if ($WantShaders) { Write-Host "Shaders instalados. No jogo, o pacote é o Complementary." }
else { Write-Host "Shaders não instalados." }
Write-Host "O endereço do servidor o grupo manda no chat."
