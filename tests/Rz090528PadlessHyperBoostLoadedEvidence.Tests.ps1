param([string]$AnnotationPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'annotations/2026-09-28-rz09-0528-padless-hyperboost-loaded-ten-second.json'))
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
$a = $raw | ConvertFrom-Json
Assert-Keys $a 'schemaVersion,publicationStatus,evidenceProvenance,device,operatorConfirmation,validation,restoration,interpretation,sanitization'
Assert-True ($a.schemaVersion -eq 1) 'Schema must remain 1.'
Assert-True ($a.publicationStatus -ceq 'UserApprovedSanitizedEvidence') 'User-approved publication status must be retained.'
Assert-Keys $a.evidenceProvenance 'controller,role,sourceRevision,planSha256'
Assert-True ($a.evidenceProvenance.controller -ceq 'OpenBlade exact-device developer validation runner') 'Controller provenance changed.'
Assert-True ($a.evidenceProvenance.role -ceq 'ReversibleValidation') 'Evidence role changed.'
Assert-True ($a.evidenceProvenance.sourceRevision -ceq '99b02ff83b373fc91dc1c53642e27d3e75379156') 'Source revision changed.'
Assert-True ($a.evidenceProvenance.planSha256 -ceq 'FF5258CEDB14E09DFD9BF9C0F33030044E7F646F2088DAA3635240FABA37A029') 'Plan hash changed.'
Assert-Keys $a.device 'modelNumber,bios'
Assert-True ($a.device.modelNumber -ceq 'RZ09-0528' -and $a.device.bios -ceq '2.02') 'Exact approved model/BIOS scope changed.'
Assert-Keys $a.operatorConfirmation 'padUsbAndPowerDisconnected,originalAdapterConnected'
Assert-True ($a.operatorConfirmation.padUsbAndPowerDisconnected -eq $true -and $a.operatorConfirmation.originalAdapterConnected -eq $true) 'Attended prerequisites changed.'
$v = $a.validation
Assert-Keys $v 'success,thermalPair,observationMilliseconds,candidateApplyMilliseconds,confirmedCandidateToRestorationReadbackMilliseconds,samples,hardwareDisposed,externalTelemetryQuiesced,snapshotQuiesced'
foreach ($name in @('success','hardwareDisposed','externalTelemetryQuiesced','snapshotQuiesced')) {
    Assert-True ($v.$name -eq $true) "Required completed state changed: $name"
}
$t = $v.thermalPair
Assert-Keys $t 'Target,Baseline,Candidate,CandidateFanRpm,CandidateFanRpmSamples,Restoration,ApplyAttempted,ApplyAcknowledged,CandidateConfirmed,RestoreAttempted,RestoreAcknowledged,Restored,IndeterminatePartialWrite,ManualRecoveryRequired,Failure,Success'
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
Assert-True ($null -eq $t.CandidateFanRpm -and @($t.CandidateFanRpmSamples).Count -eq 0) 'Do not invent fan readings outside the sampled evidence.'
Assert-Number $v.observationMilliseconds 10006.6822
Assert-Number $v.candidateApplyMilliseconds 1413.075
Assert-Number $v.confirmedCandidateToRestorationReadbackMilliseconds 11397.2283
Assert-True ($v.confirmedCandidateToRestorationReadbackMilliseconds -gt $v.observationMilliseconds) 'Observation time must not be presented as physical mode residency.'
$expected = @(
    @(788.7603,55.4,60,100,127.8504,2500,2300),
    @(2805.8743,56.5,62,100,127.3423,2600,2400),
    @(4796.8897,57.5,63,100,116.0464,2700,2500),
    @(6826.1792,58.1,64,100,116.9774,2800,2600),
    @(8051.4002,59.5,65,100,120.7795,$null,$null)
)
$fields = @('ElapsedMilliseconds','CpuCelsius','GpuCelsius','GpuUtilizationPercent','CpuSourceAgeMilliseconds','Fan1Rpm','Fan2Rpm')
Assert-True (@($v.samples).Count -eq 5) 'Exactly five recorded samples are in scope.'
for ($i = 0; $i -lt 5; $i++) {
    Assert-Keys $v.samples[$i] ($fields -join ',')
    for ($j = 0; $j -lt $fields.Count; $j++) {
        $actual = $v.samples[$i].($fields[$j])
        if ($null -eq $expected[$i][$j]) { Assert-True ($null -eq $actual) 'External-only sample must not claim fresh fans.' }
        else { Assert-Number $actual $expected[$i][$j] }
    }
}
Assert-Keys $a.restoration 'ValidationExitCode,BenchmarkExitConfirmed,IndependentPerformanceStateConfirmed,OriginalIntentRestored,OriginalRestoreExitCode,RestorationPending,Failure,Errors'
Assert-True ($a.restoration.ValidationExitCode -eq 0 -and $a.restoration.OriginalRestoreExitCode -eq 0) 'Restoration exit codes changed.'
foreach ($name in @('BenchmarkExitConfirmed','IndependentPerformanceStateConfirmed','OriginalIntentRestored')) {
    Assert-True ($a.restoration.$name -eq $true) "Restoration confirmation changed: $name"
}
Assert-True ($a.restoration.RestorationPending -eq $false -and $null -eq $a.restoration.Failure -and @($a.restoration.Errors).Count -eq 0) 'Unresolved recovery is not successful restoration.'
Assert-Keys $a.interpretation 'cpuSource,gpuSource,fanSource,timing,productionPadlessAdmitted,sustainedThermalCapacityEstablished,stableModePerformanceComparison,limits'
foreach ($name in @('productionPadlessAdmitted','sustainedThermalCapacityEstablished','stableModePerformanceComparison')) {
    Assert-True ($a.interpretation.$name -eq $false) "Unsupported inference: $name"
}
Assert-True ($a.interpretation.cpuSource -ceq 'HWiNFO named CPU Tctl/Tdie with newly consumed row peaks') 'CPU provenance must not become an EC-zone claim.'
Assert-True ($a.interpretation.gpuSource -ceq 'NVML temperature and utilization') 'GPU provenance changed.'
Assert-True ($a.interpretation.fanSource -ceq 'Typed firmware fan readbacks; final external-only sample has no fresh fan measurement') 'Fan provenance changed.'
Assert-True ($a.interpretation.timing -ceq 'Scheduled observation duration differs from candidate-apply latency and confirmed-candidate-to-restoration-readback interval. Readback intervals do not establish exact physical residency.') 'Timing caveat changed.'
Assert-True ($a.interpretation.limits -ceq 'Brief GPU-heavy workload only; no sustained thermal, CPU-heavy, adapter-transition, low-power or crash-recovery claim. No stable-mode benchmark comparison.') 'Evidence limits changed.'
Assert-Keys $a.sanitization 'rawOutputsExcluded,localPathsExcluded,deviceInstancePathsExcluded,serialNumbersExcluded,processIdentityExcluded,profileContentsExcluded'
foreach ($property in $a.sanitization.PSObject.Properties) { Assert-True ($property.Value -eq $true) 'Private data exclusion changed.' }
Assert-True ($raw -notmatch '(?i)[A-Z]:\\|\\\\|USB\\|HID\\|S-1-5-|"(?:ProcessId|StartedAtUtc|ExecutableName|Profile|Sku|GpuName|SerialNumber)"') 'Private or unapproved identity data detected.'
Write-Output "Loaded sanitized evidence passed $script:checks assertions. No hardware operations performed."
