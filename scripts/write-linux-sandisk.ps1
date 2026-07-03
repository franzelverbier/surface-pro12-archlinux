# Ecrit l'image Linux (sp12.img) en RAW sur le SanDisk Portable SSD 2 To.
# SECURITES : cible le SanDisk par nom/bus/taille, refuse la SHARGE et le disque interne.
$ErrorActionPreference = 'Stop'
$base = $PSScriptRoot
Start-Transcript -Path (Join-Path $base 'write-linux.log') -Force | Out-Null
try {
  $IMG = 'C:\sp12-linux\sp12.img'
  if (-not (Test-Path $IMG)) { throw "Image absente: $IMG" }
  $imgLen = (Get-Item $IMG).Length
  Write-Host "Image = $IMG ($([math]::Round($imgLen/1GB,2)) GB)"

  # --- Identifier le SanDisk Portable SSD ---
  $cand = Get-Disk | Where-Object { $_.FriendlyName -like '*SanDisk*Portable*' -and $_.BusType -eq 'USB' }
  if (-not $cand)            { throw "ABORT: SanDisk Portable SSD introuvable." }
  if ($cand.Count -gt 1)     { throw "ABORT: plusieurs SanDisk Portable detectes." }
  $disk = $cand
  $gb = [math]::Round($disk.Size/1GB)
  Write-Host "Cible = disque $($disk.Number) : $($disk.FriendlyName) ($gb GB, $($disk.BusType))"
  if ($disk.FriendlyName -like '*SHARGE*') { throw "ABORT: c'est la SHARGE !" }
  if ($gb -lt 1800 -or $gb -gt 1950)        { throw "ABORT: taille inattendue ($gb GB)." }
  # SHARGE doit exister ailleurs (preuve qu'elle est branchee et != cible)
  $sharge = Get-Disk | Where-Object { $_.FriendlyName -like '*SHARGE*' }
  if (-not $sharge)               { throw "ABORT: SHARGE introuvable (debranchee ?) - on arrete." }
  if ($sharge.Number -eq $disk.Number) { throw "ABORT: la SHARGE est la cible !" }
  Write-Host "OK securites. SHARGE = disque $($sharge.Number) (intacte)."

  $N = $disk.Number
  # --- Nettoyer (libere les volumes/locks) ---
  Write-Host "Nettoyage du disque $N (diskpart clean)..."
  $dp = @("select disk $N","clean","exit") -join "`r`n"
  $dpFile = Join-Path $base 'dp-clean.txt'
  Set-Content -Path $dpFile -Value $dp -Encoding Ascii
  diskpart /s $dpFile | Out-Null
  Start-Sleep -Seconds 2

  # --- Ecriture RAW ---
  $phys = "\\.\PhysicalDrive$N"
  Write-Host "Ecriture RAW de l'image vers $phys ..."
  $src = New-Object IO.FileStream($IMG,[IO.FileMode]::Open,[IO.FileAccess]::Read)
  $dst = New-Object IO.FileStream($phys,[IO.FileMode]::Open,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
  try {
    $bs = 4MB
    $buf = New-Object byte[] $bs
    $total = 0L; $sw = [Diagnostics.Stopwatch]::StartNew(); $lastReport = 0L
    while (($read = $src.Read($buf,0,$bs)) -gt 0) {
      $dst.Write($buf,0,$read)
      $total += $read
      if (($total - $lastReport) -ge 1GB) {
        $mbps = [math]::Round($total/1MB/$sw.Elapsed.TotalSeconds,0)
        Write-Host ("  {0} GB ecrits ({1} MB/s)" -f [math]::Round($total/1GB,1), $mbps)
        $lastReport = $total
      }
    }
    $dst.Flush()
    Write-Host "Ecrit $([math]::Round($total/1GB,2)) GB en $([math]::Round($sw.Elapsed.TotalSeconds,0))s."
  } finally { $dst.Close(); $src.Close() }

  # --- Verif : relire le secteur 0 (signature MBR protective 55 AA) ---
  $chk = New-Object IO.FileStream($phys,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
  try {
    $b = New-Object byte[] 512
    $null = $chk.Read($b,0,512)
    $sig = '{0:X2}{1:X2}' -f $b[510],$b[511]
    Write-Host "Signature secteur 0 (attendu 55AA) : $sig"
    if ($sig -ne '55AA') { Write-Host "ATTENTION: signature inattendue." }
  } finally { $chk.Close() }

  Write-Host "TERMINE: image Linux ecrite sur le SanDisk (disque $N)."
} catch {
  Write-Host "ERREUR: $($_.Exception.Message)"
} finally {
  Stop-Transcript | Out-Null
}