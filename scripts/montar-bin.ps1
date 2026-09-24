<#
  montar-bin.ps1 (T61) - monta a pasta bin\ de entrega do ERP Vendas e confere a
  arquitetura (32/64 bits) de cada binario. Rode DEPOIS de compilar a
  configuracao Release, Win32, na IDE (Project > Build).

  Uso (na raiz do repositorio):
    powershell -ExecutionPolicy Bypass -File scripts\montar-bin.ps1
    powershell -File scripts\montar-bin.ps1 -OpenSslDir C:\caminho\com\libeay32-e-ssleay32

  Copia: ERPVendas.exe (Win32\Release), fbclient.dll (Firebird 32 bits),
  erpvendas.ini.example e, se -OpenSslDir for informado, libeay32.dll e
  ssleay32.dll (OpenSSL 1.0.2 Win32; so necessarias para SMTP com TLS).
  Nao copia erpvendas.ini real, logs nem PDFs. Sai com codigo 1 se algo faltar
  ou a arquitetura for incoerente.
#>
param(
  [string]$Exe = 'Win32\Release\ERPVendas.exe',
  [string]$FirebirdDir = 'C:\Program Files (x86)\Firebird\Firebird_3_0',
  [string]$OpenSslDir = '',
  [string]$Destino = 'bin',
  [string[]]$BplDirs = @(
    'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin',
    'C:\Program Files (x86)\DevExpress\VCL\Library\RS37'
  )
)

$ErrorActionPreference = 'Stop'

function Get-Arquitetura([string]$Caminho) {
  $fs = [System.IO.File]::OpenRead($Caminho)
  try {
    $br = New-Object System.IO.BinaryReader($fs)
    $fs.Position = 0x3C
    $pe = $br.ReadInt32()
    $fs.Position = $pe + 4
    $m = $br.ReadUInt16()
    switch ($m) { 0x014c { 'x86' } 0x8664 { 'x64' } default { ('0x{0:x}' -f $m) } }
  } finally { $fs.Dispose() }
}

$falhas = @()
if (-not (Test-Path $Exe)) {
  Write-Host "ERRO: $Exe nao existe. Compile a configuracao Release (Win32) na IDE." -ForegroundColor Red
  exit 1
}
$fb = Join-Path $FirebirdDir 'fbclient.dll'
if (-not (Test-Path $fb)) {
  Write-Host "ERRO: fbclient.dll nao encontrada em $FirebirdDir (use -FirebirdDir)." -ForegroundColor Red
  exit 1
}

New-Item -ItemType Directory -Force $Destino | Out-Null
Copy-Item $Exe $Destino -Force
Copy-Item $fb $Destino -Force
Copy-Item 'config\erpvendas.ini.example' $Destino -Force

# A configuracao Release usa runtime packages: o DevExpress trial nao traz .dcu,
# so .bpl/.dcp (ver BLOCKERS 008). Descobre os .bpl importados pelo exe e,
# transitivamente, por cada .bpl copiado, e copia todos para bin\.
function Get-BplsImportados([string]$Caminho) {
  $txt = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($Caminho))
  [regex]::Matches($txt, '[A-Za-z0-9_]+\.bpl') | ForEach-Object { $_.Value } | Sort-Object -Unique
}
$fila = New-Object System.Collections.Queue
$vistos = @{}
Get-BplsImportados $Exe | ForEach-Object { $fila.Enqueue($_) }
while ($fila.Count -gt 0) {
  $n = $fila.Dequeue()
  if ($vistos.ContainsKey($n.ToLower())) { continue }
  $vistos[$n.ToLower()] = $true
  $achou = $null
  # O nome vem de bytes do binario: o byte de tamanho antes da string pode colar 1
  # caractere no inicio (ex.: 'Vvclie370.bpl'); tenta tambem sem o 1o caractere.
  foreach ($cand in @($n, $n.Substring(1))) {
    foreach ($d in $BplDirs) {
      $c = Join-Path $d $cand
      if (Test-Path $c) { $achou = $c; $n = $cand; break }
    }
    if ($achou) { break }
  }
  if ($achou) {
    $vistos[$n.ToLower()] = $true
    Copy-Item $achou $Destino -Force
    Get-BplsImportados $achou | ForEach-Object { $fila.Enqueue($_) }
  } else {
    $falhas += "$n (importado) nao encontrado em -BplDirs"
  }
}
Write-Host ("Runtime packages copiados: {0}" -f $vistos.Count)

if ($OpenSslDir -ne '') {
  foreach ($n in 'libeay32.dll', 'ssleay32.dll') {
    $p = Join-Path $OpenSslDir $n
    if (Test-Path $p) { Copy-Item $p $Destino -Force }
    else { $falhas += "$n nao encontrada em $OpenSslDir" }
  }
} else {
  Write-Host 'AVISO: OpenSSL nao incluido (-OpenSslDir). SMTP com TLS falhara; sem TLS (ex.: porta 2525) funciona.' -ForegroundColor Yellow
}

Write-Host "`nArquitetura dos binarios em ${Destino}:"
$arqs = @{}
foreach ($f in Get-ChildItem $Destino -Include *.exe, *.dll, *.bpl -Recurse) {
  $a = Get-Arquitetura $f.FullName
  $arqs[$f.Name] = $a
  '{0,-22} {1}' -f $f.Name, $a
}
if (($arqs.Values | Sort-Object -Unique).Count -gt 1) {
  $falhas += 'Arquiteturas misturadas (exe, fbclient.dll e OpenSSL devem ser todas x86).'
}
if ($arqs['ERPVendas.exe'] -ne 'x86') {
  $falhas += 'ERPVendas.exe nao e Win32 (x86): a plataforma-alvo e 32 bits.'
}

if (Test-Path (Join-Path $Destino 'erpvendas.ini')) {
  $falhas += 'erpvendas.ini real presente em bin\ (nao pode ir no pacote).'
}

Write-Host "`nConteudo de ${Destino}:"
Get-ChildItem $Destino | ForEach-Object { '{0,-24} {1,10:N0} bytes' -f $_.Name, $_.Length }

if ($falhas.Count -gt 0) {
  Write-Host "`nFALHAS:" -ForegroundColor Red
  $falhas | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
  exit 1
}
Write-Host "`nOK: pacote montado e arquiteturas coerentes." -ForegroundColor Green
