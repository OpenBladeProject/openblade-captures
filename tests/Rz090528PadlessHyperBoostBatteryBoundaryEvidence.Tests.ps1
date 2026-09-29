param([string]$AnnotationPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'annotations/2026-09-28-rz09-0528-padless-hyperboost-battery-boundary.json'))
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
Assert-True ($a.evidenceProvenance.sourceRevision -ceq '888dca81dfe6ca756524e7e880e155b5e7fc2567') 'Source revision changed.'
Assert-True ($a.evidenceProvenance.planSha256 -ceq 'FAEAE270DA1DB0E520A256BD67AE8C1112107D5886D585B22A0B5B4CABECC0E7') 'Plan hash changed.'
Assert-Keys $a.device 'modelNumber,bios'
Assert-True ($a.device.modelNumber -ceq 'RZ09-0528' -and $a.device.bios -ceq '2.02') 'Exact approved model/BIOS scope changed.'
Assert-Keys $a.operatorConfirmation 'padUsbAndPowerDisconnected,usbCPowerDisconnected,originalAdapterConnected,noWorkload,attendedSpokenPromptsConfirmed'
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
Assert-Keys $b 'completed,batteryObserved,automaticReversionObserved,batteryWritesPerformed,operatorPrompts,samples'
Assert-True ($b.completed -eq $true -and $b.batteryObserved -eq $true) 'Boundary completion changed.'
Assert-True ($b.automaticReversionObserved -eq $false) 'Do not claim a firmware reversion that was not observed.'
Assert-True ($b.batteryWritesPerformed -eq $false) 'No battery write may be claimed or introduced.'
Assert-Keys $b.operatorPrompts 'unplugPromptLatencyMilliseconds,reconnectPromptLatencyMilliseconds,unplugPromptToFirstCoherentBatterySampleMilliseconds'
Assert-Number $b.operatorPrompts.unplugPromptLatencyMilliseconds 60.2
Assert-Number $b.operatorPrompts.reconnectPromptLatencyMilliseconds 30.1
Assert-Number $b.operatorPrompts.unplugPromptToFirstCoherentBatterySampleMilliseconds 7718.4
$fields = @('Phase','ElapsedMilliseconds','FirmwarePowerBefore','FirmwarePowerAfter','Thermal1Mode','Thermal2Mode','WindowsAcBefore','WindowsAcAfter','CpuCelsius','GpuCelsius','GpuUtilizationPercent','Classification')
$expected = @(
    @('EntryBeforeApply',768.5551,'1111','1111',2,2,$true,$true,51,41,0,'Coherent'),
    @('EntryBeforeApply',3384.84,'1111','1111',2,2,$true,$true,51.6,41,0,'Coherent'),
    @('Boundary',654.0526,'1111','1111',7,7,$true,$true,47.5,41,0,'Coherent'),
    @('Boundary',2261.795,'1111','1111',7,7,$true,$true,47,41,0,'Coherent'),
    @('Boundary',3876.0079,'1111','1111',7,7,$true,$true,46.8,41,0,'Coherent'),
    @('Boundary',5898.9447,'0011','0011',7,7,$null,$false,46.4,41,0,'TransitionalDiscarded'),
    @('Boundary',7718.4348,'0011','0011',7,7,$false,$false,45.4,41,0,'Coherent'),
    @('Boundary',9550.4701,'0011','0011',7,7,$false,$false,46.6,41,0,'Coherent'),
    @('Boundary',11369.0195,'0011','0011',7,7,$false,$false,45.6,41,0,'Coherent'),
    @('Boundary',13082.7022,'1111','1111',7,7,$true,$true,45.6,41,0,'Coherent'),
    @('Boundary',14761.3219,'1111','1111',7,7,$true,$true,45.2,41,0,'Coherent')
)
Assert-True (@($b.samples).Count -eq $expected.Count) 'Exactly the recorded samples are in scope.'
for ($i = 0; $i -lt $expected.Count; $i++) {
    Assert-Keys $b.samples[$i] ($fields -join ',')
    for ($j = 0; $j -lt $fields.Count; $j++) {
        $actual = $b.samples[$i].($fields[$j]); $want = $expected[$i][$j]
        if ($null -eq $want) { Assert-True ($null -eq $actual) 'A transitional Windows reading must stay unknown.' }
        elseif ($want -is [string] -or $want -is [bool]) { Assert-True ($actual -ceq $want -or ($want -is [bool] -and $actual -eq $want)) "Observed fact changed: sample $i $($fields[$j])" }
        else { Assert-Number $actual $want }
    }
    $s = $b.samples[$i]
    Assert-True ($s.CpuCelsius -lt 75 -and $s.GpuCelsius -lt 75 -and $s.GpuUtilizationPercent -le 10) 'Samples must stay inside the no-load experimental envelope.'
    if ($s.Phase -eq 'EntryBeforeApply') { Assert-True ($s.CpuCelsius -le 70 -and $s.GpuCelsius -le 72) 'Entry envelope changed.' }
    if ($s.FirmwarePowerAfter -eq '0011') { Assert-True ($s.Thermal1Mode -eq $s.Thermal2Mode) 'Battery samples must remain paired.' }
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
Assert-Keys $a.interpretation 'cpuSource,gpuSource,powerSource,elapsedBasis,firmwareBehavior,productionPadlessAdmitted,batterySetterAdmitted,thermalSafetyEstablished,usbCTransitionValidated,limits'
foreach ($name in @('productionPadlessAdmitted','batterySetterAdmitted','thermalSafetyEstablished','usbCTransitionValidated')) {
    Assert-True ($a.interpretation.$name -eq $false) "Unsupported inference: $name"
}
Assert-True ($a.interpretation.cpuSource -ceq 'HWiNFO named CPU Tctl/Tdie with newly consumed row peaks') 'CPU provenance must not become an EC-zone claim.'
Assert-True ($a.interpretation.gpuSource -ceq 'NVML temperature and utilization') 'GPU provenance changed.'
Assert-True ($a.interpretation.elapsedBasis -clike '*do not establish exact physical mode residency*') 'Timing caveat changed.'
Assert-True ($a.interpretation.limits -clike 'Single attended no-load*no workload, sustained, USB-C, low-power, sleep or crash-recovery claim.') 'Evidence limits changed.'
Assert-Keys $a.sanitization 'rawOutputsExcluded,localPathsExcluded,deviceInstancePathsExcluded,serialNumbersExcluded,processIdentityExcluded,profileContentsExcluded'
foreach ($property in $a.sanitization.PSObject.Properties) { Assert-True ($property.Value -eq $true) 'Private data exclusion changed.' }
Assert-True ($raw -notmatch '(?i)[A-Z]:\\|\\\\|USB\\|HID\\|S-1-5-|"(?:ProcessId|StartedAtUtc|ExecutableName|Profile|Profiles|Sku|GpuName|SerialNumber|Hwinfo)"') 'Private or unapproved identity data detected.'
Write-Output "Battery boundary sanitized evidence passed $script:checks assertions. No hardware operations performed."
