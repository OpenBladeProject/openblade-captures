[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$recoveryText = Get-Content (Join-Path $repository 'annotations/2026-09-30-rz09-0528-cooling-pad-host-demand1500-recovery.json') -Raw
$changingText = Get-Content (Join-Path $repository 'annotations/2026-09-30-rz09-0528-cooling-pad-temperature-demand-changing.json') -Raw
$recovery = $recoveryText | ConvertFrom-Json
$changing = $changingText | ConvertFrom-Json
$failed = $recovery.failedDemandTrial
$raw = $recovery.rawStateRecovery
$quiet = $recovery.preferredQuietRecovery
$artifacts = @($failed.queryArtifact, $raw.queryArtifact, $quiet.queryArtifact, $changing.queryArtifact)
$hashes = @('5FA811B9267723C96F5F6C15A5ECF5D8F702DE1CE1980FCFA02CD86F8AE1BEE2', '5BE69D4AB50B865DF99CF89C5CC82B1EBB6C4069E2763C2F2A9ECAC8B474D470', '0A2F9C288541ED2D4D3A2D9C6B12EC1B510515573DF90F22592ACB1E6C1E2774', '7E6A4617DF4D14363AD5A0802B90B39845E52E5439C47D58A050C1C65D5DF3A8')
$lengths = @(4979, 989, 2522, 9449)
for ($i = 0; $i -lt 4; $i++) {
    Assert-True ($artifacts[$i].sha256 -ceq $hashes[$i] -and $artifacts[$i].byteLength -eq $lengths[$i] -and $artifacts[$i].rawArtifactCommitted -eq $false) 'Actual private result identity changed.'
}
Assert-True ($failed.evidenceProvenance.sourceCommit -ceq '389a1db0ece446357520b3091dc5d1d90c34b9c2' -and $raw.sourceCommit -ceq $failed.evidenceProvenance.sourceCommit -and
    $quiet.evidenceProvenance.sourceCommit -ceq '68d6cdb9d260f2dcc0de1aa7c48eb68129fbb37f' -and $changing.evidenceProvenance.sourceCommit -ceq $quiet.evidenceProvenance.sourceCommit) 'Source provenance changed.'
Assert-True ($failed.exitCode -eq 2 -and $failed.trialSequenceCompleted -eq $false -and $failed.result.failure -ceq 'OperatorTimeout' -and
    $failed.result.failurePhase -ceq 'firstDemandPhysicalConfirmation' -and $failed.result.firstDemandPhysicalConfirmed -eq $false -and
    $failed.result.rawCandidate -ceq '0300' -and $null -eq $failed.result.rawRestored -and $failed.result.modeRestoreAttempted -eq $false -and
    $failed.result.fixedAttempted -eq $false -and $failed.result.autoAttempted -eq $false -and $failed.result.manualRecoveryRequired -eq $true -and
    $failed.result.samples.Count -eq 2 -and $failed.result.samples[1].plannedConfiguredDemandRpm -eq 1500 -and $failed.result.samples[1].acknowledged -eq $true) 'Failed first physical gate must retain acknowledged1500 and no restoration.'
Assert-True ($raw.exitCode -eq 2 -and $raw.result.rawBaseline -ceq '0300' -and $raw.result.rawRestored -ceq '0000' -and
    $raw.result.restoreAcknowledged -eq $true -and $raw.result.rawRestorationConfirmed -eq $true -and $raw.result.physicalConfirmed -eq $false -and
    $raw.result.failure -ceq 'OperatorTimeout' -and $raw.result.manualRecoveryRequired -eq $true -and $raw.fanCommandsSubmitted -eq $false -and
    $raw.latePhysicalObservation.acceptedByRunner -eq $false -and $raw.latePhysicalObservation.changesTypedResult -eq $false) 'Raw recovery timeout must not become physical quiet or a successful trial.'
Assert-True ($quiet.exitCode -eq 0 -and $quiet.requestedRecoverySequenceCompleted -eq $true -and $quiet.operatorWaitSeconds -eq 600 -and
    $quiet.previousConfiguredDemandRpm -eq 1500 -and $quiet.previousConfiguredDemandIsFirmwareReadback -eq $false -and
    $quiet.result.rawBaseline -ceq '0000' -and $quiet.result.rawRestored -ceq '0000' -and $null -eq $quiet.result.failure -and
    $quiet.result.fixedPhysicalConfirmed -eq $true -and $quiet.result.autoPhysicalConfirmed -eq $true -and $quiet.result.finalPhysicalConfirmed -eq $true -and
    $quiet.result.manualRecoveryRequired -eq $false) 'Successful separate quiet recovery changed.'
Assert-True (($failed.performedLogicalSequenceAccordingToResultAndReviewedSource -join ',') -ceq '00/84:0000,00/04:0300,00/84:0000,0D/10:000600,0D/01:01051E' -and
    ($raw.performedLogicalSequenceAccordingToResultAndReviewedSource -join ',') -ceq '00/84:0000,00/04:0000,00/84:0000' -and
    ($quiet.performedLogicalSequenceAccordingToResultAndReviewedSource -join ',') -ceq '00/84:0000,00/04:0300,00/84:0000,0D/10:01012C,0D/10:000600,00/04:0000,00/84:0000' -and
    ($changing.performedLogicalSequenceAccordingToResultAndReviewedSource -join ',') -ceq '00/84:0000,00/04:0300,00/84:0000,0D/10:000600,0D/01:010520,0D/01:01051B,0D/10:01012C,0D/10:000600,00/04:0000,00/84:0000') 'Inferred command counts and configured-demand encodings changed.'
Assert-True ($changing.trialOutcome.exitCode -eq 0 -and $changing.trialOutcome.trialSequenceCompleted -eq $true -and
    $changing.trialOutcome.rawControlStateRestored -eq $true -and $changing.trialOutcome.rawControlStateIsFanReadback -eq $false -and
    $changing.result.rawRestored -ceq '0000' -and $null -eq $changing.result.failure -and $changing.result.manualRecoveryRequired -eq $false) 'Changing-demand outcome changed.'
foreach ($flag in @('firstDemandPhysicalConfirmed','curvePhysicalConfirmed','fixedPhysicalConfirmed','autoPhysicalConfirmed','finalPhysicalConfirmed')) {
    Assert-True ($changing.result.$flag -eq $true) "Physical gate changed: $flag"
}
$samples = @($changing.result.samples)
Assert-True ($samples.Count -eq 12 -and $changing.telemetryOutcome.demandAcknowledgementCount -eq 2 -and $changing.telemetryOutcome.unchangedDemandSuppressionCount -eq 9) 'Sample or demand counts changed.'
for ($i = 0; $i -lt 12; $i++) {
    $sample = $samples[$i]
    $gpu = if ($i -lt 2) { 54 } else { 44 }
    $demand = if ($i -lt 2) { 1600 } else { 1350 }
    Assert-True ($sample.index -eq $i -and $sample.cpuCelsius -eq 45 -and $sample.gpuCelsius -eq $gpu -and $sample.gpuInactive -eq $false -and
        $sample.plannedConfiguredDemandRpm -eq $demand -and $sample.reason -ceq 'DemandPlanned' -and
        $sample.submissionAttempted -eq ($i -in @(1,2)) -and $sample.acknowledged -eq ($i -in @(1,2)) -and
        $sample.suppressedUnchanged -eq ($i -ge 3)) 'One downward demand change and nine suppressions must match actual telemetry.'
}
Assert-True ($changing.benchmarkContext.userAuthorizedUiRestartBeforeTrial -eq $true -and $changing.benchmarkContext.independentPerformanceTraceRetained -eq $false -and
    $changing.benchmarkContext.renderingDuringDemandChangesEstablished -eq $false -and $changing.planningPolicy.physicalConfirmationPausesHoldLastTarget -eq $true -and
    $changing.planningPolicy.gpuInactiveMeaning -match '150ms' -and $changing.planningPolicy.gpuInactiveMeaning -match 'not a GPU power-off guarantee' -and
    $changing.planningPolicy.cpuSourceMeaning -match 'not per-core CPU temperature') 'Workload or sensor interpretation overclaimed.'
$inventories = $changing.postExitReadOnlyInventories
Assert-True ($inventories.Count -eq 2 -and $inventories[0].captureProcessCount -eq 1 -and $inventories[1].captureProcessCount -eq 0 -and
    $inventories[0].recordedAtUtc -ceq '2026-09-30T08:34:16.5773773+00:00' -and $inventories[1].recordedAtUtc -ceq '2026-09-30T08:34:46.2710892+00:00') 'Both successive inventory snapshots must remain.'
foreach ($inventory in $inventories) { Assert-True ($inventory.processOwnershipInferred -eq $false -and $inventory.processesModified -eq $false) 'Inventory cannot infer ownership or process intervention.' }
Assert-True ($failed.startedAtUtc -ceq '2026-09-30T07:18:02.4069893+00:00' -and $failed.completedAtUtc -ceq '2026-09-30T07:21:18.4569625+00:00' -and
    $raw.completedAtUtc -ceq '2026-09-30T07:40:52.0637053+00:00' -and $quiet.completedAtUtc -ceq '2026-09-30T08:08:52.3822757+00:00' -and
    $changing.startedAtUtc -ceq '2026-09-30T08:11:56.3693627+00:00' -and $changing.completedAtUtc -ceq '2026-09-30T08:33:00.9962058+00:00') 'Original UTC timestamp strings or precision changed.'
foreach ($annotation in @($recovery,$changing)) {
    Assert-True ($annotation.schemaVersion -eq 1 -and $annotation.device.sku -ceq 'RZ09-05289EN4' -and $annotation.device.productIdHex -ceq '0F43' -and
        $annotation.device.revisionHex -ceq '0200' -and $annotation.device.featureBufferBytes -eq 91 -and $annotation.device.biosIsProvenanceOnly -eq $true) 'Exact annotation/device scope changed.'
    foreach ($property in $annotation.productionAdmission.PSObject.Properties) { Assert-True ($property.Value -eq $false) 'Semantic/production claims must remain closed.' }
    foreach ($property in $annotation.actions.PSObject.Properties) { Assert-True ($property.Value -eq $false) 'Unperformed action acquired.' }
    Assert-True (($annotation.limitations -join ' ') -match 'not an independent native packet count|not independent native packet counts') 'Logical exchange inference must remain distinct from packet evidence.'
}
foreach ($text in @($recoveryText,$changingText)) {
    Assert-True (-not ($text -match '(?i)[A-Z]:\\|"(?:pid|parentPid|processId|captureProcessId|parentProcessId|pipeName|nonce|serialNumber|deviceInstanceId|rawReport|rawReports)"')) 'Private identifiers or reports must not enter annotations.'
    Assert-True (-not ($text -match '"[^"]*AtUtc"\s*:\s*"[^"]*(?:-07:00|Z)"')) 'UTC fields must preserve original +00:00 strings.'
}
Write-Host 'RZ09-0528 changing-demand and recovery evidence tests passed.'
