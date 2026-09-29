param([string]$AnnotationDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) 'annotations'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$script:checks = 0
function Assert-True([bool]$Condition, [string]$Message) {
    $script:checks++
    if (-not $Condition) { throw $Message }
}
function Assert-Keys($Object, [string]$Names) {
    $expected = @($Names.Split(',') | Sort-Object)
    $actual = @($Object.PSObject.Properties.Name | Sort-Object)
    Assert-True (($actual -join ',') -ceq ($expected -join ',')) 'Evidence contains missing or unapproved fields.'
}
function Get-FileSha256([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($Path))) -replace '-', '') } finally { $sha.Dispose() }
}
$raw = [IO.File]::ReadAllText((Join-Path $AnnotationDirectory '2026-09-29-rz09-0528-padless-post-restoration-absence.json'))
Assert-True (-not $raw.Contains("`r")) 'Annotation bytes must remain LF.'
$a = $raw | ConvertFrom-Json
Assert-Keys $a 'schemaVersion,publicationStatus,evidenceKind,device,check,runs,interpretation,sanitization'
Assert-True ($a.schemaVersion -eq 1 -and $a.publicationStatus -ceq 'UserApprovedSanitizedEvidence' -and $a.evidenceKind -ceq 'PostRestorationPadAbsence') 'Evidence identity changed.'
Assert-True ($a.device.modelNumber -ceq 'RZ09-0528' -and $a.device.bios -ceq '2.02') 'Exact model/BIOS scope changed.'
Assert-Keys $a.check 'method,failClosed,timingBasis'
Assert-True ($a.check.method -clike '*VID 1532, PID 0F43*after the validator confirmed the Performance restoration*before the two-sample full-AC proof and installed-service restart') 'Check method changed.'
Assert-True ($a.check.timingBasis -clike '*upper bound*') 'Timing caveat changed.'
$expected = [ordered]@{
    '2026-09-28-rz09-0528-padless-hyperboost-battery-boundary.json' = 2.4
    '2026-09-28-rz09-0528-padless-hyperboost-usb-c-boundary.json' = 12.3
    '2026-09-29-rz09-0528-padless-hyperboost-no-load-sixty-second.json' = 2.2
    '2026-09-29-rz09-0528-padless-hyperboost-stress-test-sixty-second.json' = 7.6
}
$runs = @($a.runs)
Assert-True ($runs.Count -eq $expected.Count) 'Exactly the four reviewed runs are in scope.'
$index = 0
foreach ($name in $expected.Keys) {
    $run = $runs[$index++]
    Assert-Keys $run 'annotation,annotationSha256,validatorRestorationConfirmed,restorationReadback,padUsbPresenceAbsentAfterRestoration,checkNoLaterThanSecondsAfterValidatorExit,checkBeforeServiceRestart,preRestartFullAcSamples'
    Assert-True ($run.annotation -ceq $name) 'Run order or reference changed.'
    $cited = Join-Path $AnnotationDirectory $name
    Assert-True (Test-Path -LiteralPath $cited) "Cited annotation missing: $name"
    Assert-True ((Get-FileSha256 $cited) -ceq $run.annotationSha256) "Cited annotation bytes changed: $name"
    Assert-True ($run.validatorRestorationConfirmed -eq $true -and $run.padUsbPresenceAbsentAfterRestoration -eq $true -and $run.checkBeforeServiceRestart -eq $true) 'Post-restoration absence facts changed.'
    Assert-True ($run.restorationReadback.Thermal1Hex -ceq '01010200' -and $run.restorationReadback.Thermal2Hex -ceq '01020200') 'Restoration readback changed.'
    Assert-True ([Math]::Abs([double]$run.checkNoLaterThanSecondsAfterValidatorExit - $expected[$name]) -lt 0.0001) 'Timing fact changed.'
    Assert-True ($run.preRestartFullAcSamples -eq 2) 'Pre-restart proof count changed.'
    # The cited run must itself record a successful restoration to Performance.
    $c = [IO.File]::ReadAllText($cited) | ConvertFrom-Json
    Assert-True ($c.validation.thermalPair.Restored -eq $true -and $c.validation.thermalPair.Restoration.Thermal1Hex -ceq '01010200') "Cited run does not record restoration: $name"
}
Assert-Keys $a.interpretation 'supports,productionPadlessAdmitted,lifecycleValidated,limits'
Assert-True ($a.interpretation.productionPadlessAdmitted -eq $false -and $a.interpretation.lifecycleValidated -eq $false) 'Unsupported inference.'
Assert-True ($a.interpretation.limits -clike '*no new hardware operation*Windows PnP*') 'Evidence limits changed.'
foreach ($property in $a.sanitization.PSObject.Properties) { Assert-True ($property.Value -eq $true) 'Private data exclusion changed.' }
Assert-True ($raw -notmatch '(?i)[A-Z]:\\|\\\\|USB\\|HID\\|S-1-5-|"(?:ProcessId|StartedAtUtc|InstanceId|SerialNumber)"') 'Private or unapproved identity data detected.'
Write-Output "Post-restoration pad-absence evidence passed $script:checks assertions. No hardware operations performed."
