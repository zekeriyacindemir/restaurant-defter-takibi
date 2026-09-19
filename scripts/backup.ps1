param(
 [Parameter(Mandatory=$true)][string]$Recipient,
 [string]$OutputDirectory = (Join-Path $PSScriptRoot '../backups')
)
# Requires Supabase CLI, running Docker Desktop, and age in PATH.
# Supply SUPABASE_DB_URL securely in this process environment. Never put it in VITE_*.
$ErrorActionPreference = 'Stop'
if (-not $env:SUPABASE_DB_URL) { throw 'SUPABASE_DB_URL ortam değişkeni tanımlanmamış.' }
if (-not $Recipient.StartsWith('age1')) { throw 'age alıcı açık anahtarını kullanın.' }
Get-Command supabase,age -ErrorAction Stop | Out-Null
$backupRoot = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
$backupStamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,6)
$backupStage = Join-Path $backupRoot ('stage-' + $backupStamp)
New-Item -ItemType Directory -Path $backupStage | Out-Null
$backupFiles = @('roles.sql','schema.sql','data.sql') | ForEach-Object { Join-Path $backupStage $_ }
$backupZip = Join-Path $backupStage 'backup.zip'
$backupFinal = Join-Path $backupRoot ($backupStamp + '.zip.age')
try {
 & supabase db dump --db-url $env:SUPABASE_DB_URL -f $backupFiles[0] --role-only
 if ($LASTEXITCODE -ne 0) { throw 'Rol yedeği alınamadı.' }
 & supabase db dump --db-url $env:SUPABASE_DB_URL -f $backupFiles[1]
 if ($LASTEXITCODE -ne 0) { throw 'Şema yedeği alınamadı.' }
 & supabase db dump --db-url $env:SUPABASE_DB_URL -f $backupFiles[2] --use-copy --data-only -x 'storage.buckets_vectors' -x 'storage.vector_indexes'
 if ($LASTEXITCODE -ne 0) { throw 'Veri yedeği alınamadı.' }
 foreach ($backupFile in $backupFiles) { if ((Get-Item -LiteralPath $backupFile).Length -eq 0) { throw 'Boş yedek dosyası oluştu.' } }
 Compress-Archive -LiteralPath $backupFiles -DestinationPath $backupZip
 & age --recipient $Recipient --output $backupFinal $backupZip
 if ($LASTEXITCODE -ne 0) { throw 'Yedek şifrelenemedi.' }
 Get-FileHash -LiteralPath $backupFinal -Algorithm SHA256 | Select-Object Hash | ConvertTo-Json | Set-Content -LiteralPath ($backupFinal + '.sha256.json')
 Write-Output "Şifreli yedek hazır: $backupFinal"
 Write-Output 'Ayrı bir konuma kopyalayın ve test projesinde geri yüklemeyi doğrulayın.'
}
finally {
 # Only remove the exact plaintext files created by this run. Never recurse.
 foreach ($backupTemp in ($backupFiles + @($backupZip))) {
  $backupResolved = [IO.Path]::GetFullPath($backupTemp)
  if (-not $backupResolved.StartsWith($backupStage + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Geçici dosya yolu geçersiz.' }
  if (Test-Path -LiteralPath $backupResolved) { Remove-Item -LiteralPath $backupResolved }
 }
 if (Test-Path -LiteralPath $backupStage) { Remove-Item -LiteralPath $backupStage }
}
