<#
.SYNOPSIS
  Scrive la ISO di mbp-os sulla chiavetta USB con quel seriale, poi la rilegge e confronta lo sha256.
.DESCRIPTION
  Sicurezze: tocca solo un disco con BusType USB, seriale che inizia con -Seriale, non di sistema
  né di avvio, grande abbastanza. Se ne trova zero o più di uno si ferma.
  -WhatIf mostra solo quale disco sceglierebbe. Serve l'amministratore (si rilancia da solo con RunAs).
.EXAMPLE
  .\scrivi-chiavetta.ps1 -Iso C:\...\mbp-os.iso -Seriale 001CC0EC -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)][string]$Iso,
    [Parameter(Mandatory = $true)][string]$Seriale
)
$ErrorActionPreference = 'Stop'
trap { Write-Host "ERRORE: $($_.Exception.Message) (riga $($_.InvocationInfo.ScriptLineNumber))"; exit 1 }

$Iso = (Resolve-Path -LiteralPath $Iso).Path
$dimIso = (Get-Item -LiteralPath $Iso).Length
if ($dimIso -le 0) { throw "ISO vuota: $Iso" }

$candidati = @(Get-Disk | Where-Object {
    $_.BusType -eq 'USB' -and
    $_.SerialNumber -and $_.SerialNumber.Trim().StartsWith($Seriale, [StringComparison]::OrdinalIgnoreCase) -and
    -not $_.IsSystem -and -not $_.IsBoot
})
if ($candidati.Count -ne 1) {
    Get-Disk | Format-Table Number, FriendlyName, BusType, SerialNumber, @{n='GB';e={[math]::Round($_.Size/1GB,1)}}, IsSystem, IsBoot | Out-String | Write-Host
    throw "Trovati $($candidati.Count) dischi USB con seriale '$Seriale*' (ne serve esattamente 1). Non scrivo nulla."
}
$disco = $candidati[0]
if ($disco.Size -lt $dimIso) { throw "La chiavetta ($($disco.Size) byte) è più piccola della ISO ($dimIso byte)." }

$descr = "disco $($disco.Number) '$($disco.FriendlyName)' seriale $($disco.SerialNumber.Trim()) $([math]::Round($disco.Size/1GB,1)) GB"
Write-Host "Scelto: $descr"
Write-Host "ISO:    $Iso ($([math]::Round($dimIso/1MB)) MB)"

if (-not $PSCmdlet.ShouldProcess($descr, "Cancellare tutto e scrivere la ISO")) { return }

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    $log = Join-Path $env:TEMP 'scrivi-chiavetta.log'
    $argomenti = "-NoProfile -ExecutionPolicy Bypass -Command `"& '$PSCommandPath' -Iso '$Iso' -Seriale '$Seriale' -Confirm:`$false *>&1 | Tee-Object -FilePath '$log'; if (-not `$?) { exit 1 }; exit `$LASTEXITCODE`""
    Remove-Item $log -ErrorAction SilentlyContinue
    $p = Start-Process pwsh -Verb RunAs -ArgumentList $argomenti -Wait -PassThru
    $testo = if (Test-Path $log) { Get-Content $log -Raw } else { '' }
    Write-Host $testo
    # Il codice d'uscita attraverso RunAs+Tee non è affidabile: conta solo la riga finale di successo
    if ($testo -match 'OK: chiavetta scritta e verificata') { exit 0 } else { Write-Host 'ERRORE: scrittura non completata'; exit 1 }
}

$n = $disco.Number
$hashIso = (Get-FileHash -LiteralPath $Iso -Algorithm SHA256).Hash
Write-Host "sha256 ISO: $hashIso"

# Niente volumi montati sopra mentre si scrive
if ($disco.PartitionStyle -ne 'RAW') { Clear-Disk -Number $n -RemoveData -RemoveOEM -Confirm:$false }
# Offline se possibile (le chiavette rimovibili non lo permettono: partono RAW, quindi niente volumi montati)
try { Set-Disk -Number $n -IsOffline $true -ErrorAction Stop; $offline = $true } catch { $offline = $false }

$blocco = 4MB
$buf = New-Object byte[] $blocco
$in = [IO.File]::OpenRead($Iso)
$out = New-Object IO.FileStream("\\.\PhysicalDrive$n", [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::ReadWrite, $blocco, [IO.FileOptions]::WriteThrough)
try {
    $scritti = 0L
    while (($letti = $in.Read($buf, 0, $blocco)) -gt 0) {
        $len = $letti
        if ($len % 512) { [Array]::Clear($buf, $len, 512 - ($len % 512)); $len += 512 - ($len % 512) }
        $out.Write($buf, 0, $len)
        $scritti += $letti
        Write-Progress -Activity "Scrittura" -PercentComplete ([int](100 * $scritti / $dimIso))
    }
    $out.Flush()
} finally { $in.Close(); $out.Close() }
Write-Progress -Activity "Scrittura" -Completed

# Rilettura degli stessi byte e confronto
$sha = [Security.Cryptography.SHA256]::Create()
$rd = New-Object IO.FileStream("\\.\PhysicalDrive$n", [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite, $blocco)
try {
    $resto = $dimIso
    while ($resto -gt 0) {
        $chiedi = if ($resto -ge $blocco) { $blocco } else { [int]([Math]::Ceiling($resto / 512) * 512) }
        $letti = $rd.Read($buf, 0, $chiedi)
        if ($letti -le 0) { throw "Rilettura interrotta a $($dimIso - $resto) byte" }
        $usa = if ($letti -lt $resto) { $letti } else { [int]$resto }
        [void]$sha.TransformBlock($buf, 0, $usa, $null, 0)
        $resto -= $usa
    }
    [void]$sha.TransformFinalBlock($buf, 0, 0)
} finally { $rd.Close() }
$hashChiavetta = ([BitConverter]::ToString($sha.Hash)).Replace('-', '')
if ($offline) { Set-Disk -Number $n -IsOffline $false }

Write-Host "sha256 chiavetta: $hashChiavetta"
if ($hashChiavetta -ne $hashIso) { Write-Host "ERRORE: la chiavetta NON corrisponde alla ISO"; exit 1 }
Write-Host "OK: chiavetta scritta e verificata"
exit 0
