param([string]$AnnotationPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'annotations/2026-09-28-rz09-0528-padless-hyperboost-usb-c-boundary.json'))
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
function Assert-Number($Actual, [double]$Expected) {
    Assert-True ($null -ne $Actual -and [Math]::Abs([double]$Actual - $Expected) -lt 0.0000001) 'Observed numeric fact changed.'
}
$raw = [IO.File]::ReadAllText($AnnotationPath)
Assert-True (-not $raw.Contains("`r")) 'Annotation bytes must remain LF.'
$a = $raw | ConvertFrom-Json
Assert-Keys $a 'schemaVersion,publicationStatus,evidenceProvenance,device,operatorConfirmation,validation,preRestartFullAcProof,restoration,interpretation,sanitization'
Assert-True ($a.schemaVersion -eq 1) 'Schema must remain 1.'
Assert-True ($a.publicationStatus -ceq 'UserApprovedSanitizedEvidence') 'User-approved publication status must be retained.'
Assert-Keys $a.evidenceProvenance 'controller,role,sourceRevision,planSha256'
Assert-True ($a.evidenceProvenance.controller -ceq 'OpenBlade exact-device developer validation runner') 'Controller provenance changed.'
Assert-True ($a.evidenceProvenance.role -ceq 'ReversibleValidation') 'Evidence role changed.'
Assert-True ($a.evidenceProvenance.sourceRevision -ceq '7bd52a7ea5d2c31bbdb2359d3b92a29d507f0830') 'Source revision changed.'
Assert-True ($a.evidenceProvenance.planSha256 -ceq 'D6E14BCFF2FF64DB6B4548066E2580E0CF217B3D6B7F9B2A7E2EC857FC648B79') 'Plan hash changed.'
Assert-Keys $a.device 'modelNumber,bios'
Assert-True ($a.device.modelNumber -ceq 'RZ09-0528' -and $a.device.bios -ceq '2.02') 'Exact approved model/BIOS scope changed.'
Assert-Keys $a.operatorConfirmation 'padUsbAndPowerDisconnected,usbC100WAndOriginalAdapterConnectedBeforeApply,onlyBarrelRemovedAndReconnected,usbCRemovedBeforeServiceRestart,noWorkload,attendedSpokenPromptsConfirmed'
foreach ($property in $a.operatorConfirmation.PSObject.Properties) { Assert-True ($property.Value -eq $true) "Attended prerequisite changed: $($property.Name)" }

$v = $a.validation
Assert-Keys $v 'success,thermalPair,boundary,finalGpuOffsetsZero,hardwareDisposed,externalTelemetryQuiesced,snapshotQuiesced'
foreach ($name in @('success','finalGpuOffsetsZero','hardwareDisposed','externalTelemetryQuiesced','snapshotQuiesced')) {
    Assert-True ($v.$name -eq $true) "Required completed state changed: $name"
}
$t = $v.thermalPair
Assert-Keys $t 'Target,Baseline,Candidate,Restoration,ApplyAttempted,ApplyAcknowledged,CandidateConfirmed,RestoreAttempted,RestoreAcknowledged,Restored,IndeterminatePartialWrite,ManualRecoveryRequired,Failure,Success'
Assert-True ($t.Target -ceq 'HyperBoostFromPerformance') 'Restoration base must remain Performance.'
foreach ($stage in @('Baseline','Candidate','Restoration')) {
    Assert-Keys $t.$stage 'Thermal1Hex,Thermal2Hex'
    $mode = if ($stage -eq 'Candidate') { '07' } else { '02' }
    Assert-True ($t.$stage.Thermal1Hex -ceq "0101${mode}00" -and $t.$stage.Thermal2Hex -ceq "0102${mode}00") "Paired readback changed: $stage"
}
foreach ($name in @('ApplyAttempted','ApplyAcknowledged','CandidateConfirmed','RestoreAttempted','RestoreAcknowledged','Restored','Success')) {
    Assert-True ($t.$name -eq $true) "Typed roundtrip confirmation changed: $name"
}
Assert-True ($t.IndeterminatePartialWrite -eq $false -and $t.ManualRecoveryRequired -eq $false -and $t.Failure -ceq 'None') 'A failed/ambiguous run cannot become successful evidence.'

$b = $v.boundary
Assert-Keys $b 'destination,destinationPower,completed,destinationObserved,automaticReversionObserved,writesOffFullAcPerformed,operatorPrompts,samples'
Assert-True ($b.destination -ceq 'UsbC100W' -and $b.destinationPower -ceq '0711') 'Destination scope changed.'
Assert-True ($b.completed -eq $true -and $b.destinationObserved -eq $true) 'Boundary completion changed.'
Assert-True ($b.automaticReversionObserved -eq $false) 'Do not claim a firmware reversion that was not observed.'
Assert-True ($b.writesOffFullAcPerformed -eq $false) 'No write off full AC may be claimed or introduced.'
Assert-Keys $b.operatorPrompts 'unplugPromptLatencyMilliseconds,reconnectPromptLatencyMilliseconds,unplugPromptToFirstCoherentUsbCSampleMilliseconds'
Assert-Number $b.operatorPrompts.unplugPromptLatencyMilliseconds 25.2
Assert-Number $b.operatorPrompts.reconnectPromptLatencyMilliseconds 77.7
Assert-Number $b.operatorPrompts.unplugPromptToFirstCoherentUsbCSampleMilliseconds 8636.6
$fields = @('Phase','ElapsedMilliseconds','FirmwarePowerBefore','FirmwarePowerAfter','Thermal1Mode','Thermal2Mode','WindowsAcBefore','WindowsAcAfter','CpuCelsius','GpuCelsius','GpuUtilizationPercent','Classification')
$expected = @(
    @('EntryBeforeApply',678.5519,'1111','1111',2,2,$true,$true,45.2,39,0,'Coherent'),
    @('EntryBeforeApply',3254.0464,'1111','1111',2,2,$true,$true,48.1,39,0,'Coherent'),
    @('Boundary',616.3035,'1111','1111',7,7,$true,$true,48.1,39,0,'Coherent'),
    @('Boundary',2211.9554,'1111','1111',7,7,$true,$true,45.5,39,0,'Coherent'),
    @('Boundary',3808.0894,'1111','1111',7,7,$true,$true,44.4,39,0,'Coherent'),
    @('Boundary',5421.2195,'1111','1111',7,7,$true,$true,43.4,39,0,'Coherent'),
    @('Boundary',7059.6207,'1111','0711',7,7,$true,$true,43,39,0,'TransitionalDiscarded'),
    @('Boundary',8636.6722,'0711','0711',7,7,$true,$true,43,39,0,'Coherent'),
    @('Boundary',10233.4146,'0711','0711',7,7,$true,$true,43.2,39,0,'Coherent'),
    @('Boundary',11813.8782,'0711','0711',7,7,$true,$true,44,39,0,'Coherent'),
    @('Boundary',13388.4015,'0711','0711',7,7,$true,$true,43.4,39,0,'Coherent'),
    @('Boundary',14965.8017,'0711','0711',7,7,$true,$true,43.1,39,0,'Coherent'),
    @('Boundary',16522.4842,'1111','1111',7,7,$true,$true,43.1,39,0,'Coherent'),
    @('Boundary',18096.5094,'1111','1111',7,7,$true,$true,42.9,39,0,'Coherent')
)
Assert-True (@($b.samples).Count -eq $expected.Count) 'Exactly the recorded samples are in scope.'
for ($i = 0; $i -lt $expected.Count; $i++) {
    Assert-Keys $b.samples[$i] ($fields -join ',')
    for ($j = 0; $j -lt $fields.Count; $j++) {
        $actual = $b.samples[$i].($fields[$j]); $want = $expected[$i][$j]
        if ($want -is [string] -or $want -is [bool]) { Assert-True ($actual -ceq $want -or ($want -is [bool] -and $actual -eq $want)) "Observed fact changed: sample $i $($fields[$j])" }
        else { Assert-Number $actual $want }
    }
    $s = $b.samples[$i]
    Assert-True ($s.CpuCelsius -lt 75 -and $s.GpuCelsius -lt 75 -and $s.GpuUtilizationPercent -le 10) 'Samples must stay inside the no-load experimental envelope.'
    if ($s.Phase -eq 'EntryBeforeApply') { Assert-True ($s.CpuCelsius -le 70 -and $s.GpuCelsius -le 72) 'Entry envelope changed.' }
    if ($s.FirmwarePowerAfter -eq '0711') { Assert-True ($s.Thermal1Mode -eq 7 -and $s.Thermal2Mode -eq 7 -and $s.WindowsAcBefore -eq $true) 'USB-C samples must remain paired mode 7 with Windows AC online.' }
    Assert-True ($s.FirmwarePowerBefore -cin @('1111','0711') -and $s.FirmwarePowerAfter -cin @('1111','0711')) 'No battery or unknown power value was observed.'
}
Assert-True (@($b.samples | Where-Object Classification -eq 'TransitionalDiscarded').Count -eq 1) 'Exactly one discarded transitional sample was observed.'
$final = @($b.samples)[-2..-1]
Assert-True (@($final | Where-Object { $_.FirmwarePowerAfter -ceq '1111' -and $_.Thermal1Mode -eq 7 -and $_.Classification -ceq 'Coherent' }).Count -eq 2) 'Guarded restoration requires two coherent full-AC mode 7 samples.'
Assert-True (($final[1].ElapsedMilliseconds - $final[0].ElapsedMilliseconds) -ge 1000) 'Stable full-AC samples must be at least one second apart.'

Assert-True (@($a.preRestartFullAcProof).Count -eq 2) 'Two pre-restart proofs are required.'
foreach ($p in @($a.preRestartFullAcProof)) {
    Assert-Keys $p 'WindowsAcBefore,WindowsAcAfter,FirmwarePower,Thermal1Hex,Thermal2Hex'
    Assert-True ($p.WindowsAcBefore -eq $true -and $p.WindowsAcAfter -eq $true -and $p.FirmwarePower -ceq '1111' -and $p.Thermal1Hex -ceq '01010200' -and $p.Thermal2Hex -ceq '01020200') 'Pre-restart full-AC Performance proof changed.'
}
Assert-Keys $a.restoration 'ValidationExitCode,IndependentPerformanceStateConfirmed,OriginalIntentRestored,OriginalRestoreExitCode,RestorationPending,Failure,Errors,servicesReturnedToPriorState,gpuOffsetsIndependentlyZero'
Assert-True ($a.restoration.ValidationExitCode -eq 0 -and $a.restoration.OriginalRestoreExitCode -eq 0) 'Restoration exit codes changed.'
foreach ($name in @('IndependentPerformanceStateConfirmed','OriginalIntentRestored','servicesReturnedToPriorState','gpuOffsetsIndependentlyZero')) {
    Assert-True ($a.restoration.$name -eq $true) "Restoration confirmation changed: $name"
}
Assert-True ($a.restoration.RestorationPending -eq $false -and $null -eq $a.restoration.Failure -and @($a.restoration.Errors).Count -eq 0) 'Unresolved recovery is not successful restoration.'
Assert-Keys $a.interpretation 'cpuSource,gpuSource,powerSource,elapsedBasis,firmwareBehavior,productionPadlessAdmitted,usbCSetterAdmitted,usbCPowerLimitsEstablished,hyperBoostApplyOnUsbCTested,thermalSafetyEstablished,otherChargerClassesValidated,limits'
foreach ($name in @('productionPadlessAdmitted','usbCSetterAdmitted','usbCPowerLimitsEstablished','hyperBoostApplyOnUsbCTested','thermalSafetyEstablished','otherChargerClassesValidated')) {
    Assert-True ($a.interpretation.$name -eq $false) "Unsupported inference: $name"
}
Assert-True ($a.interpretation.cpuSource -ceq 'HWiNFO named CPU Tctl/Tdie with newly consumed row peaks') 'CPU provenance must not become an EC-zone claim.'
Assert-True ($a.interpretation.gpuSource -ceq 'NVML temperature and utilization') 'GPU provenance changed.'
Assert-True ($a.interpretation.elapsedBasis -clike '*do not establish exact physical mode residency*') 'Timing caveat changed.'
Assert-True ($a.interpretation.limits -clike 'Single attended no-load barrel to 100 W USB-C*no workload, sustained, power-limit, other charger, low-power, sleep or crash-recovery claim.') 'Evidence limits changed.'
Assert-True ($a.interpretation.powerSource -clike '*only 07/8C distinguishes them') 'The Windows AC limitation must stay explicit.'
Assert-Keys $a.sanitization 'rawOutputsExcluded,localPathsExcluded,deviceInstancePathsExcluded,serialNumbersExcluded,processIdentityExcluded,profileContentsExcluded'
foreach ($property in $a.sanitization.PSObject.Properties) { Assert-True ($property.Value -eq $true) 'Private data exclusion changed.' }
Assert-True ($raw -notmatch '(?i)[A-Z]:\\|\\\\|USB\\|HID\\|S-1-5-|"(?:ProcessId|StartedAtUtc|ExecutableName|Profile|Profiles|Sku|GpuName|SerialNumber|Hwinfo)"') 'Private or unapproved identity data detected.'
Write-Output "USB-C HyperBoost boundary sanitized evidence passed $script:checks assertions. No hardware operations performed."
