# Instala o cliente MineServer no Windows.
# Funciona com o Minecraft oficial e com o SKLauncher: os dois leem o mesmo perfil.
# O mesmo fluxo existe em instalar.sh. Instalar.bat abre este script.
param(
  [string]$MinecraftDir = "",
  [string]$ServerDir = "",
  [string]$GameDir = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Test-MinecraftClientOpen {
  try {
    $rows = Get-CimInstance Win32_Process -ErrorAction Stop
  } catch {
    return $false
  }
  foreach ($row in $rows) {
    if ($row.Name -match '^(java|javaw)\.exe$' -and $row.CommandLine -match 'KnotClient|net\.minecraft\.client\.main\.Main') {
      return $true
    }
  }
  return $false
}

function Test-SameInstallerTree([string]$Src, [string]$Dest) {
  & robocopy.exe $Src $Dest /L /E /NFL /NDL /NJH /NJS /NC /NS /NP /XF .mineserver-rev /XD .git | Out-Null
  $code = $LASTEXITCODE
  $global:LASTEXITCODE = 0
  return ($code -eq 0)
}

function Update-InstallerFromGitHub {
  if ($env:MINESERVER_SKIP_UPDATE -eq "1") { return }
  if (Test-Path -LiteralPath (Join-Path $Root ".git")) { return }
  if (Test-MinecraftClientOpen) {
    Write-Host "O Minecraft está aberto. Fecha ele por completo e roda o instalador de novo. Com o jogo aberto a atualização não entra."
    exit 1
  }
  $api = "https://api.github.com/repos/JacobsenNando/MineServer/commits/master"
  $zipUrl = "https://github.com/JacobsenNando/MineServer/archive/refs/heads/master.zip"
  try {
    $response = Invoke-WebRequest -Uri $api -UseBasicParsing -Headers @{
      "User-Agent" = "MineServer-installer"
      "Accept" = "application/vnd.github+json"
    }
    $sha = [string](($response.Content | ConvertFrom-Json).sha)
  } catch {
    Write-Host "Não consegui consultar o GitHub. Sigo com a cópia que já está aqui."
    return
  }
  if ($sha -notmatch '^[0-9a-f]{40}$') {
    Write-Host "Não consegui consultar o GitHub. Sigo com a cópia que já está aqui."
    return
  }
  $stampPath = Join-Path $Root ".mineserver-rev"
  $localRev = ""
  if (Test-Path -LiteralPath $stampPath) {
    $localRev = ([System.IO.File]::ReadAllText($stampPath)).Trim()
  }
  if ($localRev -eq $sha) { return }
  Write-Host "Consultando a versão no GitHub."
  $tmp = Join-Path $env:TEMP ("mineserver-update-" + [guid]::NewGuid().ToString("n"))
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  $zip = Join-Path $tmp "master.zip"
  $extracted = Join-Path $tmp "src"
  try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing -Headers @{
      "User-Agent" = "MineServer-installer"
    }
    New-Item -ItemType Directory -Force -Path $extracted | Out-Null
    if (Get-Command tar.exe -ErrorAction SilentlyContinue) {
      & tar.exe -xf $zip -C $extracted
    } else {
      Expand-Archive -LiteralPath $zip -DestinationPath $extracted -Force
    }
  } catch {
    Write-Host "Não consegui baixar a versão nova. Sigo com a cópia que já está aqui."
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    return
  }
  $src = Join-Path $extracted "MineServer-master"
  if (-not (Test-Path -LiteralPath (Join-Path $src "instalar.ps1"))) {
    Write-Host "O zip novo não trouxe o instalador. Sigo com a cópia que já está aqui."
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    return
  }
  if (Test-SameInstallerTree $src $Root) {
    [System.IO.File]::WriteAllText($stampPath, $sha)
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Esta pasta já está na versão nova."
    return
  }
  & robocopy.exe $src $Root /E /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) {
    $global:LASTEXITCODE = 0
    Write-Host "Não consegui copiar a versão nova. Sigo com a cópia que já está aqui."
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    return
  }
  $global:LASTEXITCODE = 0
  [System.IO.File]::WriteAllText($stampPath, $sha)
  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  Write-Host "Pasta atualizada. Continuo a instalação com a versão nova."
  $bound = @()
  foreach ($key in $PSBoundParameters.Keys) {
    $bound += "-$key"
    $bound += [string]$PSBoundParameters[$key]
  }
  $env:MINESERVER_SKIP_UPDATE = "1"
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "instalar.ps1") @bound
  exit $LASTEXITCODE
}

Update-InstallerFromGitHub

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

function Get-ProfileGameDir {
  $profilesPath = Join-Path $MinecraftDir "launcher_profiles.json"
  if (-not (Test-Path -LiteralPath $profilesPath)) { return "" }
  $parsed = Get-Content -Raw -LiteralPath $profilesPath | ConvertFrom-Json
  foreach ($entry in $parsed.profiles.PSObject.Properties) {
    if ($entry.Value.name -eq $ProfileName -and $entry.Value.gameDir) {
      return [string]$entry.Value.gameDir
    }
  }
  return ""
}

if ($ServerDir -and -not (Test-Path -LiteralPath $ServerDir -PathType Container)) {
  throw "Não achei a pasta do servidor: $ServerDir"
}

$GameDirArg = $GameDir
if ($GameDirArg) {
  $GameDir = $GameDirArg
} else {
  $existingGameDir = Get-ProfileGameDir
  if ($existingGameDir) { $GameDir = $existingGameDir }
  else { $GameDir = Join-Path $MinecraftDir $GameDirName }
}

New-Item -ItemType Directory -Force -Path (Join-Path $GameDir "mods") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $GameDir "shaderpacks") | Out-Null
if ($ServerDir) {
  New-Item -ItemType Directory -Force -Path (Join-Path $ServerDir "mods") | Out-Null
}
$VersionDir = Join-Path $MinecraftDir "versions\$VersionId"
New-Item -ItemType Directory -Force -Path $VersionDir | Out-Null

function Remove-RetiredViewer([string]$Dest) {
  foreach ($name in @("RoughlyEnoughItems-26.2.820.jar", "architectury-fabric-21.1.12.jar")) {
    $path = Join-Path (Join-Path $Dest "mods") $name
    if (Test-Path -LiteralPath $path) {
      Remove-Item -LiteralPath $path -Force
      Write-Host "Removi $name."
    }
  }
}
Remove-RetiredViewer $GameDir
if ($ServerDir) { Remove-RetiredViewer $ServerDir }

function Get-Sha1([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA1).Hash.ToLowerInvariant()
}

function Test-Hash([string]$Path, [string]$Sum) {
  if (-not $Sum -or $Sum -eq "-") { return $false }
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  return (Get-Sha1 $Path) -eq $Sum
}

function Save-Url([string]$Url, [string]$Dest, [string]$Sum, [string]$AltSum) {
  if (-not $Url.StartsWith("https://")) {
    throw "A ficha tem um endereço que não é https: $Dest"
  }
  if ((Test-Hash $Dest $Sum) -or (Test-Hash $Dest $AltSum)) {
    Write-Host "já está certo: $(Split-Path -Leaf $Dest)"
    return
  }
  Write-Host "baixando $(Split-Path -Leaf $Dest)"
  $partial = "$Dest.partial"
  Invoke-WebRequest -Uri $Url -OutFile $partial -UseBasicParsing
  if ((Get-Sha1 $partial) -ne $Sum) {
    Remove-Item -LiteralPath $partial -Force
    throw "O arquivo $(Split-Path -Leaf $Dest) não confere com a ficha. O que já estava no lugar ficou."
  }
  Move-Item -LiteralPath $partial -Destination $Dest -Force
}

function Update-ReiClass([System.IO.Compression.ZipArchive]$Zip, [string]$EntryName, [string]$ClassPath) {
  if (-not (Test-Path -LiteralPath $ClassPath)) {
    throw "Falta $ClassPath para corrigir o mod."
  }
  $payload = [System.IO.File]::ReadAllBytes($ClassPath)
  $entry = $Zip.GetEntry($EntryName)
  if (-not $entry) {
    $created = $Zip.CreateEntry($EntryName)
    $created.LastWriteTime = [DateTimeOffset]::Parse("1980-01-01T00:00:00Z")
    $write = $created.Open()
    $write.Write($payload, 0, $payload.Length)
    $write.Close()
    return
  }
  $read = $entry.Open()
  $buffer = New-Object System.IO.MemoryStream
  $read.CopyTo($buffer)
  $read.Close()
  $current = $buffer.ToArray()
  $buffer.Dispose()
  $same = $current.Length -eq $payload.Length
  if ($same) {
    for ($i = 0; $i -lt $current.Length; $i++) {
      if ($current[$i] -ne $payload[$i]) { $same = $false; break }
    }
  }
  if ($same) { return }
  $entry.Delete()
  $created = $Zip.CreateEntry($EntryName)
  $created.LastWriteTime = [DateTimeOffset]::Parse("1980-01-01T00:00:00Z")
  $write = $created.Open()
  $write.Write($payload, 0, $payload.Length)
  $write.Close()
}

function Update-SkillHud([string]$Jar) {
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::Open($Jar, [System.IO.Compression.ZipArchiveMode]::Update)
  try {
    Update-ReiClass $zip "daripher/skilltree/client/hud/SkillProgressHudOverlay.class" (Join-Path $Root "patches\skilltree\SkillProgressHudOverlay.class")
    Update-ReiClass $zip "daripher/skilltree/client/SkillTreeModClient.class" (Join-Path $Root "patches\skilltree\SkillTreeModClient.class")
  } finally {
    $zip.Dispose()
  }
}

# A camada do meio do peito da armadura divina não desenha mais o brilho forçado.
# Em primeira pessoa, a armadura do próprio jogador não desenha por cima da câmera.
function Update-ImmersiveArmors([string]$Jar) {
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::Open($Jar, [System.IO.Compression.ZipArchiveMode]::Update)
  try {
    Update-ReiClass $zip "immersive_armors/ItemsClient.class" (Join-Path $Root "patches\immersive_armors\ItemsClient.class")
    Update-ReiClass $zip "immersive_armors/mixin/MixinHumanoidArmorLayer.class" (Join-Path $Root "patches\immersive_armors\mixin\MixinHumanoidArmorLayer.class")
  } finally {
    $zip.Dispose()
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
  $origin = $col[8]
  $alt = "-"
  if ($col.Length -gt 9) { $alt = $col[9] }
  if ($side -eq "shader" -and -not $WantShaders) { continue }
  if ($side -ne "required" -and $side -ne "shader") { throw "Lado desconhecido na ficha: $side" }
  $targets = @(Join-Path (Join-Path $GameDir $dest) $filename)
  if ($ServerDir -and $origin -eq "server") {
    $targets += Join-Path (Join-Path $ServerDir $dest) $filename
  }
  foreach ($target in $targets) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Save-Url $url $target $sum $alt
    if ($patch -ne "-" -and -not (Test-Hash $target $alt)) { Update-LoaderPin $target $patch }
    if ($filename -eq "PassiveSkillTree-Fabric-26.2-0.7.6+c.jar") { Update-SkillHud $target }
    if ($filename -eq "immersive_armors-1.8.2+26.2-fabric.jar") { Update-ImmersiveArmors $target }
  }
}

function Install-ClientConfig([string]$Dest) {
  $src = Join-Path $Root "bundled\config\trinkets.json"
  if (-not (Test-Path -LiteralPath $src)) { throw "Falta $src." }
  $config = Join-Path $Dest "config"
  New-Item -ItemType Directory -Force -Path $config | Out-Null
  Copy-Item -LiteralPath $src -Destination (Join-Path $config "trinkets.json") -Force
  Write-Host "Coluna de berloques gravada em $(Join-Path $config 'trinkets.json')"
}

function Install-ServerBundle([string]$Dest) {
  $jar = Join-Path $Root "bundled\server\mineserver-classes-1.0.0.jar"
  $trinkets = Join-Path $Root "bundled\config\trinkets.json"
  $horses = Join-Path $Root "bundled\config\icys-better-horses.json"
  if (-not (Test-Path -LiteralPath $jar)) { throw "Falta $jar." }
  if (-not (Test-Path -LiteralPath $trinkets)) { throw "Falta $trinkets." }
  if (-not (Test-Path -LiteralPath $horses)) { throw "Falta $horses." }
  New-Item -ItemType Directory -Force -Path (Join-Path $Dest "mods") | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $Dest "config") | Out-Null
  Copy-Item -LiteralPath $trinkets -Destination (Join-Path $Dest "config\trinkets.json") -Force
  Copy-Item -LiteralPath $horses -Destination (Join-Path $Dest "config\icys-better-horses.json") -Force
  Copy-Item -LiteralPath $jar -Destination (Join-Path $Dest "mods\mineserver-classes-1.0.0.jar") -Force
  Write-Host "MineServer Classes copiado para $(Join-Path $Dest 'mods')."
}

function Install-ClassMod([string]$Dest) {
  $jar = Join-Path $Root "bundled\server\mineserver-classes-1.0.0.jar"
  if (-not (Test-Path -LiteralPath $jar)) { throw "Falta $jar." }
  New-Item -ItemType Directory -Force -Path (Join-Path $Dest "mods") | Out-Null
  Copy-Item -LiteralPath $jar -Destination (Join-Path $Dest "mods\mineserver-classes-1.0.0.jar") -Force
  Write-Host "MineServer Classes copiado para $(Join-Path $Dest 'mods')."
}

function Install-JeiAddon([string]$Dest) {
  $jar = Join-Path $Root "bundled\client\mineserver-jei-1.0.0.jar"
  if (-not (Test-Path -LiteralPath $jar)) { throw "Falta $jar." }
  New-Item -ItemType Directory -Force -Path (Join-Path $Dest "mods") | Out-Null
  Copy-Item -LiteralPath $jar -Destination (Join-Path $Dest "mods\mineserver-jei-1.0.0.jar") -Force
  Write-Host "MineServer JEI copiado para $(Join-Path $Dest 'mods')."
}

Install-ClientConfig $GameDir
Install-JeiAddon $GameDir
Install-ClassMod $GameDir
if ($ServerDir) { Install-ServerBundle $ServerDir }

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
    Write-Host "O perfil $ProfileName já existe. Atualizei os mods em $GameDir."
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
if ($ServerDir) {
  Write-Host "Mods do servidor atualizados em $(Join-Path $ServerDir 'mods')."
  Write-Host "A trava de classe está em $(Join-Path $ServerDir 'mods\mineserver-classes-1.0.0.jar')."
}
Write-Host "O menu de caminhos usa $(Join-Path $GameDir 'mods\mineserver-classes-1.0.0.jar'). Feche o Minecraft por completo para carregar."
Write-Host "Anel, livro e mochila ficam na coluna ao lado do personagem. Feche o jogo e abra de novo se ele estiver aberto."
Write-Host "O endereço do servidor o grupo manda no chat."
