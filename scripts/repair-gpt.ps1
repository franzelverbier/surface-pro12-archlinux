# Repare la GPT du SanDisk : etend l'en-tete primaire au plein disque + ecrit l'en-tete de secours en fin de disque.
# Ne touche PAS les entrees de partition ni les donnees. Auto-test CRC avant toute ecriture.
$ErrorActionPreference = 'Stop'
$base = $PSScriptRoot
Start-Transcript -Path (Join-Path $base 'repair-gpt.log') -Force | Out-Null
try {
  $disk = Get-Disk | Where-Object { $_.FriendlyName -like '*SanDisk*Portable*' -and $_.BusType -eq 'USB' }
  if (-not $disk)        { throw "SanDisk introuvable" }
  if ($disk.Count -gt 1) { throw "plusieurs SanDisk" }
  $gb = [math]::Round($disk.Size/1GB)
  if ($gb -lt 1800 -or $gb -gt 1950) { throw "taille inattendue ($gb GB)" }
  $N = $disk.Number
  $lss = [int]$disk.LogicalSectorSize
  $totalSectors = [int64]($disk.Size / $lss)
  $lastLBA = $totalSectors - 1
  Write-Host "SanDisk disque $N : $($disk.Size) octets, secteur=$lss, totalSectors=$totalSectors, lastLBA=$lastLBA"

  # --- CRC32 (zlib standard) ; tout en int64 avec suffixe L pour eviter les littéraux signés ---
  $script:POLY = 0xEDB88320L
  $script:M32  = 0xFFFFFFFFL
  $script:crcTable = New-Object 'int64[]' 256
  for ($i=0; $i -lt 256; $i++) {
    $c = [int64]$i
    for ($k=0; $k -lt 8; $k++) {
      if (($c -band 1L) -ne 0) { $c = ($script:POLY -bxor ($c -shr 1)) -band $script:M32 }
      else                     { $c = ($c -shr 1) -band $script:M32 }
    }
    $script:crcTable[$i] = $c
  }
  function Get-CRC32([byte[]]$data) {
    $crc = $script:M32
    foreach ($b in $data) {
      $idx = [int](($crc -bxor ([int64]$b)) -band 0xFFL)
      $crc = ((($crc -shr 8) -band 0xFFFFFFL) -bxor $script:crcTable[$idx]) -band $script:M32
    }
    return [uint32](($crc -bxor $script:M32) -band $script:M32)
  }
  function Set64($buf,$off,$val){ $b=[BitConverter]::GetBytes([uint64]$val); [Array]::Copy($b,0,$buf,$off,8) }
  function Set32($buf,$off,$val){ $b=[BitConverter]::GetBytes([uint32]$val); [Array]::Copy($b,0,$buf,$off,4) }
  function U32($buf,$off){ [BitConverter]::ToUInt32($buf,$off) }

  $phys = "\\.\PhysicalDrive$N"
  $fs = New-Object IO.FileStream($phys,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::ReadWrite)
  function ReadAt([int64]$off,[int]$len){ $b=New-Object byte[] $len; $null=$fs.Seek($off,[IO.SeekOrigin]::Begin); $r=0; while($r -lt $len){ $n=$fs.Read($b,$r,$len-$r); if($n-le 0){break}; $r+=$n }; return $b }
  function WriteAt([int64]$off,[byte[]]$bytes){ $null=$fs.Seek($off,[IO.SeekOrigin]::Begin); $fs.Write($bytes,0,$bytes.Length) }
  try {
    # Lire l'en-tete primaire (LBA1)
    $hdr = ReadAt ([int64]$lss) 512
    $sig = [Text.Encoding]::ASCII.GetString($hdr,0,8)
    if ($sig -ne 'EFI PART') { throw "Pas d'en-tete GPT primaire (sig='$sig')" }
    $hdrSize = [int](U32 $hdr 12)
    if ($hdrSize -lt 92 -or $hdrSize -gt 512) { throw "HeaderSize aberrant ($hdrSize)" }

    # --- AUTO-TEST CRC sur l'en-tete existant (qui a un CRC valide) ---
    $stored = U32 $hdr 16
    $tmp = $hdr.Clone(); Set32 $tmp 16 0
    $calc = Get-CRC32 ($tmp[0..($hdrSize-1)])
    Write-Host ("Auto-test CRC : stored={0:X8} calc={1:X8}" -f $stored,$calc)
    if ($calc -ne $stored) { throw "AUTO-TEST CRC ECHOUE -> calcul CRC non fiable, on n'ecrit RIEN." }
    Write-Host "Auto-test CRC OK -> calcul fiable, on procede."

    # Lire le tableau d'entrees de partition (LBA2.., 32 secteurs)
    $arrLen = 32 * $lss
    $arr = ReadAt ([int64]2*$lss) $arrLen

    # --- Nouvel en-tete PRIMAIRE ---
    $np = $hdr.Clone()
    Set64 $np 32 $lastLBA            # AlternateLBA = dernier secteur
    Set64 $np 48 ($totalSectors-34)  # LastUsableLBA
    Set32 $np 16 0
    $crcP = Get-CRC32 ($np[0..($hdrSize-1)])
    Set32 $np 16 $crcP
    WriteAt ([int64]$lss) $np
    Write-Host ("En-tete primaire reecrit (AlternateLBA={0}, LastUsableLBA={1}, CRC={2:X8})" -f $lastLBA,($totalSectors-34),$crcP)

    # --- Tableau d'entrees de SECOURS a (lastLBA-32) ---
    $arrBkLBA = $totalSectors - 33
    WriteAt ([int64]$arrBkLBA*$lss) $arr
    Write-Host "Tableau d'entrees de secours ecrit a LBA $arrBkLBA"

    # --- En-tete de SECOURS au dernier secteur ---
    $nb = $np.Clone()
    Set64 $nb 24 $lastLBA       # MyLBA = dernier secteur
    Set64 $nb 32 1             # AlternateLBA = 1 (primaire)
    Set64 $nb 72 $arrBkLBA     # PartitionEntryLBA = lastLBA-32
    Set32 $nb 16 0
    $crcB = Get-CRC32 ($nb[0..($hdrSize-1)])
    Set32 $nb 16 $crcB
    WriteAt ([int64]$lastLBA*$lss) $nb
    Write-Host ("En-tete de secours ecrit a LBA $lastLBA (CRC={0:X8})" -f $crcB)

    $fs.Flush()

    # --- Verif relecture ---
    $chk = ReadAt ([int64]$lss) 512
    $altNow = [BitConverter]::ToUInt64($chk,32)
    $bk = ReadAt ([int64]$lastLBA*$lss) 512
    $bksig = [Text.Encoding]::ASCII.GetString($bk,0,8)
    Write-Host ("VERIF: AlternateLBA primaire={0} (attendu {1}) ; en-tete secours sig='{2}'" -f $altNow,$lastLBA,$bksig)
    if ($altNow -eq $lastLBA -and $bksig -eq 'EFI PART') { Write-Host "REPARATION REUSSIE." }
    else { Write-Host "ATTENTION: verif inattendue." }
  } finally { $fs.Close() }
} catch {
  Write-Host "ERREUR: $($_.Exception.Message)"
} finally { Stop-Transcript | Out-Null }