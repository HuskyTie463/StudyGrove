$ErrorActionPreference = "Stop"
$openssl = "C:\Program Files\Git\usr\bin\openssl.exe"
$work = Join-Path $env:TEMP "studygrove_p12"
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Get-ModMd5FromCert([string]$cer) {
  $mod = & $openssl x509 -inform DER -in $cer -noout -modulus 2>$null
  if ($LASTEXITCODE -ne 0) {
    $mod = & $openssl x509 -in $cer -noout -modulus
  }
  ($mod | & $openssl md5).ToString().Trim()
}

function Get-ModMd5FromKey([string]$key) {
  $mod = & $openssl rsa -in $key -noout -modulus 2>$null
  if ($LASTEXITCODE -ne 0) {
    $pubDer = Join-Path $work ("pub_" + [IO.Path]::GetFileName($key) + ".der")
    & $openssl pkey -in $key -pubout -outform DER -out $pubDer | Out-Null
    return (& $openssl md5 $pubDer).ToString().Trim()
  }
  ($mod | & $openssl md5).ToString().Trim()
}

Write-Output "=== certs ==="
& $openssl x509 -inform DER -in "c:\Users\adara\Downloads\mac_app.cer" -noout -subject -issuer -dates
Write-Output "---"
& $openssl x509 -inform DER -in "c:\Users\adara\Downloads\mac_installer.cer" -noout -subject -issuer -dates

$appCerMd5 = Get-ModMd5FromCert "c:\Users\adara\Downloads\mac_app.cer"
$instCerMd5 = Get-ModMd5FromCert "c:\Users\adara\Downloads\mac_installer.cer"
$appKeyMd5 = Get-ModMd5FromKey "c:\Users\adara\Downloads\StudyGrove_MacAppDistribution.key"
$instKeyMd5 = Get-ModMd5FromKey "c:\Users\adara\Downloads\StudyGrove_MacInstallerDistribution.key"

Write-Output "=== fingerprints ==="
Write-Output "mac_app.cer $appCerMd5"
Write-Output "mac_installer.cer $instCerMd5"
Write-Output "MacApp key $appKeyMd5"
Write-Output "MacInstaller key $instKeyMd5"

Write-Output "=== other signing files ==="
Get-ChildItem "c:\Users\adara\Downloads" -File | Where-Object {
  $_.Extension -match '\.(key|cer|csr|certSigningRequest|p12|pem)$'
} | ForEach-Object { "$($_.Name) $($_.Length) bytes" }

# Pair each cert with the matching key by modulus hash
$pairs = @(
  @{ Name = "MacApp"; Cer = "c:\Users\adara\Downloads\mac_app.cer"; Out = "c:\Users\adara\Downloads\StudyGrove_MacAppDistribution.p12"; Friendly = "StudyGrove Mac App Distribution"; Prefer = "c:\Users\adara\Downloads\StudyGrove_MacAppDistribution.key" },
  @{ Name = "MacInstaller"; Cer = "c:\Users\adara\Downloads\mac_installer.cer"; Out = "c:\Users\adara\Downloads\StudyGrove_MacInstallerDistribution.p12"; Friendly = "StudyGrove Mac Installer Distribution"; Prefer = "c:\Users\adara\Downloads\StudyGrove_MacInstallerDistribution.key" }
)

$keys = @(
  @{ Path = "c:\Users\adara\Downloads\StudyGrove_MacAppDistribution.key"; Md5 = $appKeyMd5 },
  @{ Path = "c:\Users\adara\Downloads\StudyGrove_MacInstallerDistribution.key"; Md5 = $instKeyMd5 }
)

function Convert-CerToPem([string]$cerPath, [string]$pemPath) {
  $head = Get-Content -Path $cerPath -TotalCount 1 -ErrorAction SilentlyContinue
  if ($head -like "*BEGIN CERTIFICATE*") {
    Copy-Item $cerPath $pemPath -Force
  } else {
    & $openssl x509 -inform DER -in $cerPath -out $pemPath
    if ($LASTEXITCODE -ne 0) { throw "Failed converting $cerPath to PEM" }
  }
}

foreach ($pair in $pairs) {
  $cerMd5 = Get-ModMd5FromCert $pair.Cer
  $match = $keys | Where-Object { $_.Md5 -eq $cerMd5 } | Select-Object -First 1
  if (-not $match) {
    Write-Output "NO_MATCH $($pair.Name) cert fingerprint $cerMd5"
    continue
  }
  Write-Output "MATCH $($pair.Name) -> $(Split-Path $match.Path -Leaf)"
  $pem = Join-Path $work ($pair.Name + ".pem")
  Convert-CerToPem $pair.Cer $pem
  if (Test-Path $pair.Out) { Remove-Item $pair.Out -Force }
  & $openssl pkcs12 -export -inkey $match.Path -in $pem -out $pair.Out -passout pass:studygrove -name $pair.Friendly
  if ($LASTEXITCODE -ne 0) { throw "Failed creating $($pair.Out)" }
  $bytes = (Get-Item $pair.Out).Length
  Write-Output "CREATED $($pair.Out) ($bytes bytes)"
}

Write-Output "=== verify subjects ==="
if (Test-Path "c:\Users\adara\Downloads\StudyGrove_MacAppDistribution.p12") {
  & $openssl pkcs12 -in "c:\Users\adara\Downloads\StudyGrove_MacAppDistribution.p12" -passin pass:studygrove -nokeys -clcerts -nomacver 2>$null | & $openssl x509 -noout -subject -dates
  Write-Output "app p12 ok"
}
if (Test-Path "c:\Users\adara\Downloads\StudyGrove_MacInstallerDistribution.p12") {
  & $openssl pkcs12 -in "c:\Users\adara\Downloads\StudyGrove_MacInstallerDistribution.p12" -passin pass:studygrove -nokeys -clcerts -nomacver 2>$null | & $openssl x509 -noout -subject -dates
  Write-Output "installer p12 ok"
}

Remove-Item -Recurse -Force $work
Write-Output "temp pems removed"
