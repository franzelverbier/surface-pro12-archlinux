# Formate le SanDisk Portable SSD 2 To (disque 1) en exFAT pour servir de sauvegarde des videos.
# SECURITES : verifie nom/taille/bus avant tout effacement, et refuse si le disque ressemble a la SHARGE.
$ErrorActionPreference = 'Stop'
Start-Transcript -Path "$PSScriptRoot\format-backup.log" -Force | Out-Null
try {
  $TARGET = 1
  $disk = Get-Disk -Number $TARGET
  Write-Host "Disque $TARGET = $($disk.FriendlyName) ; $([math]::Round($disk.Size/1GB,1)) GB ; bus $($disk.BusType)"
  $gb = [math]::Round($disk.Size/1GB)
  if ($disk.FriendlyName -notlike '*SanDisk*Portable*') { throw "ABORT: nom inattendu ($($disk.FriendlyName)) - ce n'est pas le SanDisk Portable SSD." }
  if ($disk.FriendlyName -like '*SHARGE*')             { throw "ABORT: c'est la SHARGE (videos) !" }
  if ($disk.BusType -ne 'USB')                          { throw "ABORT: pas un disque USB." }
  if ($gb -lt 1800 -or $gb -gt 1950)                    { throw "ABORT: taille inattendue ($gb GB)." }
  # Securite supplementaire : la SHARGE doit exister ailleurs et NE PAS etre le disque cible
  $sharge = Get-Disk | Where-Object { $_.FriendlyName -like '*SHARGE*' }
  if (-not $sharge)                 { throw "ABORT: SHARGE introuvable - debranchee ? On arrete par securite." }
  if ($sharge.Number -eq $TARGET)   { throw "ABORT: la SHARGE est le disque $TARGET !" }
  Write-Host "OK securites. SHARGE = disque $($sharge.Number) (intacte). Effacement du disque $TARGET..."

  Clear-Disk -Number $TARGET -RemoveData -RemoveOEM -Confirm:$false
  Initialize-Disk -Number $TARGET -PartitionStyle GPT
  $part = New-Partition -DiskNumber $TARGET -UseMaximumSize -AssignDriveLetter
  Start-Sleep -Seconds 2
  Format-Volume -Partition $part -FileSystem exFAT -NewFileSystemLabel BACKUP -Confirm:$false | Out-Null
  $part = Get-Partition -DiskNumber $TARGET | Where-Object DriveLetter
  Write-Host "TERMINE: SanDisk 2 To formate exFAT, lettre = $($part.DriveLetter):"
} catch {
  Write-Host "ERREUR: $($_.Exception.Message)"
} finally {
  Stop-Transcript | Out-Null
}