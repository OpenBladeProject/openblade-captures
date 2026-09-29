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
function Get-SampleDigest($Samples) {
    # Culture-invariant row text so the digest pins every recorded fact independently of JSON formatting.
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $rows = foreach ($s in $Samples) {
        $cells = foreach ($name in 'ElapsedMilliseconds','CpuCelsius','GpuCelsius','GpuUtilizationPercent','CpuSourceAgeMilliseconds','Fan1Rpm','Fan2Rpm') {
            $value = $s.$name
            if ($null -eq $value) { 'null' } else { ([double]$value).ToString('R', $culture) }
        }
        $cells -join '|'
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($rows -join "`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '') } finally { $sha.Dispose() }
}
$cases = @(
    @{ File = '2026-09-29-rz09-0528-padless-hyperboost-no-load-sixty-second.json'; Loaded = $false; Profile = 'NoLoad60'
       Plan = '7C5F8DA522F2DEBA865D4128E9D485D152E41F6E7AB0B9DE5847E6A1D88F424E'; Digest = '09A53C37CA90E5D685B5EBE72F0B10B7A42901EE793B751824110FCEDC076205'
       Observation = 60005.6607; Apply = 781.1881; Restore = 60778.9138 },
    @{ File = '2026-09-29-rz09-0528-padless-hyperboost-stress-test-sixty-second.json'; Loaded = $true; Profile = 'Loaded60'
       Plan = 'AA1C670D89373C3823236BDFB6458747F2002DB8175EBE325D6845C9529ABDF7'; Digest = '33EAAC6BB7D5B8E724C60D0284A1A96DC603C3EBB40D1C9C62329D4A0972CBE2'
       Observation = 60005.1217; Apply = 1194.1112; Restore = 61269.2773 }
)
foreach ($case in $cases) {
    $raw = [IO.File]::ReadAllText((Join-Path $AnnotationDirectory $case.File))
    Assert-True (-not $raw.Contains("`r")) 'Annotation bytes must remain LF.'
    $a = $raw | ConvertFrom-Json
    Assert-Keys $a 'schemaVersion,publicationStatus,evidenceProvenance,device,operatorConfirmation,validation,preRestartFullAcProof,restoration,interpretation,sanitization'
    Assert-True ($a.schemaVersion -eq 1 -and $a.publicationStatus -ceq 'UserApprovedSanitizedEvidence') 'Publication status changed.'
    Assert-Keys $a.evidenceProvenance 'controller,role,sourceRevision,profile,planSha256'
    Assert-True ($a.evidenceProvenance.role -ceq 'ReversibleValidation' -and $a.evidenceProvenance.sourceRevision -clike '6960f65a*' -and $a.evidenceProvenance.sourceRevision.Length -eq 40) 'Source provenance changed.'
    Assert-True ($a.evidenceProvenance.profile -ceq $case.Profile -and $a.evidenceProvenance.planSha256 -ceq $case.Plan) 'Profile or plan changed.'
    Assert-True ($a.device.modelNumber -ceq 'RZ09-0528' -and $a.device.bios -ceq '2.02') 'Exact approved model/BIOS scope changed.'
    foreach ($property in $a.operatorConfirmation.PSObject.Properties) { Assert-True ($property.Value -eq $true) "Attended prerequisite changed: $($property.Name)" }
    $v = $a.validation
    Assert-Keys $v 'success,thermalPair,workloadBound,qualificationSamples,observationMilliseconds,candidateApplyMilliseconds,confirmedCandidateToRestorationReadbackMilliseconds,samples,finalGpuOffsetsZero,hardwareDisposed,externalTelemetryQuiesced,snapshotQuiesced'
    foreach ($name in 'success','finalGpuOffsetsZero','hardwareDisposed','externalTelemetryQuiesced','snapshotQuiesced') { Assert-True ($v.$name -eq $true) "Completed state changed: $name" }
    $t = $v.thermalPair
    foreach ($stage in 'Baseline','Candidate','Restoration') {
        $mode = if ($stage -eq 'Candidate') { '07' } else { '02' }
        Assert-True ($t.$stage.Thermal1Hex -ceq "0101${mode}00" -and $t.$stage.Thermal2Hex -ceq "0102${mode}00") "Paired readback changed: $stage"
    }
    foreach ($name in 'ApplyAttempted','ApplyAcknowledged','CandidateConfirmed','RestoreAttempted','RestoreAcknowledged','Restored','Success') { Assert-True ($t.$name -eq $true) "Typed roundtrip changed: $name" }
    Assert-True ($t.IndeterminatePartialWrite -eq $false -and $t.ManualRecoveryRequired -eq $false -and $t.Failure -ceq 'None') 'A failed run cannot become successful evidence.'
    Assert-True ($v.workloadBound -eq $case.Loaded) 'Workload binding changed.'
    Assert-True ($v.qualificationSamples -eq $(if ($case.Loaded) { 3 } else { 0 })) 'Qualification changed.'
    Assert-True ([Math]::Abs($v.observationMilliseconds - $case.Observation) -lt 0.001 -and [Math]::Abs($v.candidateApplyMilliseconds - $case.Apply) -lt 0.001 -and [Math]::Abs($v.confirmedCandidateToRestorationReadbackMilliseconds - $case.Restore) -lt 0.001) 'Timing facts changed.'
    Assert-True ($v.confirmedCandidateToRestorationReadbackMilliseconds -gt $v.observationMilliseconds) 'Observation time must not be presented as residency.'
    $samples = @($v.samples)
    Assert-True ($samples.Count -eq 30) 'Exactly thirty samples are in scope.'
    Assert-True ((Get-SampleDigest $samples) -ceq $case.Digest) 'A recorded sample changed.'
    for ($i = 0; $i -lt 30; $i++) {
        $s = $samples[$i]
        Assert-Keys $s 'ElapsedMilliseconds,CpuCelsius,GpuCelsius,GpuUtilizationPercent,CpuSourceAgeMilliseconds,Fan1Rpm,Fan2Rpm'
        Assert-True ($s.CpuCelsius -lt 85 -and $s.GpuCelsius -lt 80) 'Samples must stay under the approved tripwire.'
        Assert-True ($s.CpuSourceAgeMilliseconds -ge 0 -and $s.CpuSourceAgeMilliseconds -le 4000) 'CPU source must stay fresh.'
        if ($i -eq 29) { Assert-True ($null -eq $s.Fan1Rpm -and $null -eq $s.Fan2Rpm) 'External-only sample must not claim fans.' }
        elseif ($case.Loaded) { Assert-True ($s.Fan1Rpm -gt 0 -and $s.Fan2Rpm -gt 0) 'Loaded fans must spin at every paired snapshot.' }
        else { Assert-True ($s.Fan1Rpm -ge 0 -and $s.Fan2Rpm -ge 0) 'No-load fan readbacks must be valid.' }
        if ($case.Loaded) { Assert-True ($s.GpuUtilizationPercent -ge 80) 'Qualifying GPU load must persist.' }
        else { Assert-True ($s.GpuUtilizationPercent -le 10) 'No-load GPU must stay idle.' }
    }
    Assert-True (@($a.preRestartFullAcProof).Count -eq 2) 'Two pre-restart proofs are required.'
    foreach ($p in @($a.preRestartFullAcProof)) { Assert-True ($p.WindowsAcBefore -eq $true -and $p.WindowsAcAfter -eq $true -and $p.FirmwarePower -ceq '1111' -and $p.Thermal1Hex -ceq '01010200' -and $p.Thermal2Hex -ceq '01020200') 'Pre-restart proof changed.' }
    $r = $a.restoration
    Assert-True ($r.ValidationExitCode -eq 0 -and $r.OriginalRestoreExitCode -eq 0 -and $r.RestorationPending -eq $false -and $null -eq $r.Failure -and @($r.Errors).Count -eq 0) 'Restoration changed.'
    foreach ($name in 'BenchmarkExitConfirmed','IndependentPerformanceStateConfirmed','OriginalIntentRestored','servicesReturnedToPriorState','gpuOffsetsIndependentlyZero') { Assert-True ($r.$name -eq $true) "Restoration confirmation changed: $name" }
    $i = $a.interpretation
    Assert-Keys $i 'cpuSource,gpuSource,fanSource,experimentalTripwire,timing,fanBehavior,productionPadlessAdmitted,thermalSafetyEstablished,sustainedBeyondWindowEstablished,limits'
    foreach ($name in 'productionPadlessAdmitted','thermalSafetyEstablished','sustainedBeyondWindowEstablished') { Assert-True ($i.$name -eq $false) "Unsupported inference: $name" }
    Assert-True ($i.cpuSource -ceq 'HWiNFO named CPU Tctl/Tdie with newly consumed row peaks') 'CPU provenance changed.'
    Assert-True ($i.experimentalTripwire -clike 'CPU 85 C / GPU 80 C*not hardware ratings') 'Tripwire meaning changed.'
    Assert-True ($i.limits -clike 'Single attended 60-second*') 'Evidence limits changed.'
    foreach ($property in $a.sanitization.PSObject.Properties) { Assert-True ($property.Value -eq $true) 'Private data exclusion changed.' }
    Assert-True ($raw -notmatch '(?i)[A-Z]:\\|\\\\|USB\\|HID\\|S-1-5-|"(?:ProcessId|StartedAtUtc|ExecutableName|Profiles|Sku|SerialNumber|Hwinfo|Workload)"') 'Private or unapproved identity data detected.'
}
Write-Output "Sixty-second padless evidence passed $script:checks assertions. No hardware operations performed."
