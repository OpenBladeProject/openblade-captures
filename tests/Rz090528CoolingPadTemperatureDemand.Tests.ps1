[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$source = Get-Content (Join-Path $repository 'annotations/2026-09-29-rz09-0528-cooling-pad-temperature-demand.json') -Raw
$annotation = $source | ConvertFrom-Json
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
Assert-True ($annotation.schemaVersion -eq 1 -and
    $annotation.evidenceProvenance.sourceCommit -ceq '389a1db0ece446357520b3091dc5d1d90c34b9c2' -and
    $annotation.evidenceProvenance.captureApphostSha256 -ceq 'ACF400E23431CD330F86DC88FECB1D7159768BA97D8E758BD743B1D848A07B94' -and
    $annotation.evidenceProvenance.captureDllSha256 -ceq '3F79FB3502F8C38CB9FAFEC7C7736B22D1153633023326186E7FBDDF8810FCAB' -and
    $annotation.queryArtifact.sha256 -ceq 'B150C9812B35496CAB0419920B729B1223F941E77DD9E87040CCC01C6A3CDDBF' -and
    $annotation.queryArtifact.byteLength -eq 9535 -and $annotation.queryArtifact.rawArtifactCommitted -eq $false) 'Actual result/build provenance changed.'
Assert-True ($annotation.device.sku -ceq 'RZ09-05289EN4' -and $annotation.device.vendorIdHex -ceq '1532' -and
    $annotation.device.productIdHex -ceq '0F43' -and $annotation.device.revisionHex -ceq '0200' -and
    $annotation.device.interfaceNumber -ceq '00' -and $annotation.device.usagePageHex -ceq '000C' -and
    $annotation.device.usageHex -ceq '0001' -and $annotation.device.featureBufferBytes -eq 91 -and
    $annotation.device.featureReportPrefixHex -ceq '00' -and $annotation.device.biosIsProvenanceOnly -eq $true) 'Exact device scope changed.'
$expected = @('00/84:0000','00/04:0300','00/84:0000','0D/10:000600','0D/01:010517','0D/10:01012C','0D/10:000600','00/04:0000','00/84:0000')
Assert-True (($annotation.performedLogicalSequenceAccordingToResultAndReviewedSource -join ',') -ceq ($expected -join ',') -and
    $annotation.sequenceEvidenceLimit -match 'planned sequence only' -and
    $annotation.sequenceEvidenceLimit -match 'not an independent native packet count' -and
    $annotation.evidenceProvenance.usbPcapUsed -eq $false -and
    $annotation.evidenceProvenance.independentNativeReportTraceRetained -eq $false) 'Logical sequence must not acquire packet-trace provenance.'
$result = $annotation.result
Assert-True ($result.rawBaseline -ceq '0000' -and $result.rawCandidate -ceq '0300' -and $result.rawRestored -ceq '0000' -and
    $result.rawRestorationConfirmed -eq $true -and $result.failurePhase -ceq 'finalPhysicalConfirmation' -and
    $result.failure -ceq 'OperatorTimeout' -and $result.finalPhysicalConfirmed -eq $false -and
    $result.manualRecoveryRequired -eq $true -and $result.submissionStateUnknown -eq $false -and
    $annotation.trialOutcome.exitCode -eq 2 -and $annotation.trialOutcome.trialSequenceCompleted -eq $false -and
    $annotation.trialOutcome.manualRecoveryRequired -eq $true -and
    $annotation.trialOutcome.preferredAutoFinalPhysicalConfirmed -eq $false) 'Timeout must remain a typed incomplete outcome after raw restoration.'
foreach ($flag in @('modeAcquireAttempted','modeAcquireAcknowledged','demandEntryAttempted','demandEntryAcknowledged',
    'firstDemandPhysicalConfirmed','curvePhysicalConfirmed','fixedAttempted','fixedAcknowledged','fixedPhysicalConfirmed',
    'autoAttempted','autoAcknowledged','autoPhysicalConfirmed','modeRestoreAttempted','modeRestoreAcknowledged',
    'temperatureSourceConstructionStarted','temperatureSourceDisposalConfirmed')) {
    Assert-True ($result.$flag -eq $true) "Completed flag changed: $flag"
}
$samples = @($result.samples)
Assert-True ($samples.Count -eq 12 -and $samples[0].stage -ceq 'preflightTelemetry' -and
    $samples[1].stage -ceq 'initialDemandTelemetry') 'Preflight, initial and ten further readings must remain separate.'
for ($i = 0; $i -lt $samples.Count; $i++) {
    $sample = $samples[$i]
    Assert-True ($sample.index -eq $i -and $sample.cpuCelsius -eq 45 -and $null -eq $sample.gpuCelsius -and
        $sample.gpuInactive -eq $true -and $sample.plannedConfiguredDemandRpm -eq 1150 -and
        $sample.reason -ceq 'DemandPlanned' -and $sample.hostAcquisitionAgeMilliseconds -ge 0 -and
        $sample.hostAcquisitionAgeMilliseconds -lt 5000) 'Observed stable CPU/inactive GPU sample changed.'
    Assert-True ($sample.submissionAttempted -eq ($i -eq 1) -and $sample.acknowledged -eq ($i -eq 1) -and
        $sample.suppressedUnchanged -eq ($i -ge 2)) 'Exactly one demand is acknowledged; ten equal targets are suppressed.'
    if ($i -ge 2) { Assert-True ($sample.stage -ceq 'curveTelemetry') 'Further-reading phase changed.' }
}
Assert-True ($annotation.telemetryOutcome.readingCount -eq 12 -and $annotation.telemetryOutcome.furtherReadingCount -eq 10 -and
    $annotation.telemetryOutcome.demandSubmissionAttemptCount -eq 1 -and $annotation.telemetryOutcome.demandAcknowledgementCount -eq 1 -and
    $annotation.telemetryOutcome.unchangedDemandSuppressionCount -eq 10 -and
    $annotation.telemetryOutcome.changedDemandUpdatesObserved -eq $false) 'Summary must agree with stable telemetry and suppression evidence.'
Assert-True ($annotation.planningPolicy.illustrativeOpenBladePolicy -eq $true -and $annotation.planningPolicy.synapsePreset -eq $false -and
    $annotation.planningPolicy.sourceOriginTimestampAvailable -eq $false -and
    $annotation.planningPolicy.ageBeforeSubmissionFieldMeaning -match 'prequeue' -and
    $annotation.planningPolicy.physicalConfirmationPausesHoldLastTarget -eq $true -and
    $annotation.planningPolicy.configuredDelayBetweenFurtherReadingsMilliseconds -eq 2000) 'Planning policy must not become sensor timestamp or continuous control evidence.'
Assert-True ($annotation.startedAtUtc -ceq '2026-09-30T06:51:37.1863386+00:00' -and
    $annotation.completedAtUtc -ceq '2026-09-30T07:02:26.1397198+00:00' -and
    $annotation.postExitPhysicalObservation.recordedAtUtc -ceq '2026-09-30T07:04:11.6577441+00:00' -and
    $annotation.postExitPhysicalObservation.userReply -ceq 'yes' -and
    $annotation.postExitPhysicalObservation.typedFinalGateAccepted -eq $false -and
    $annotation.postExitPhysicalObservation.changesTypedResult -eq $false -and
    $annotation.postExitPhysicalObservation.changesTrialExitCode -eq $false) 'Post-exit confirmation must not repair the typed timeout.'
Assert-True (@($annotation.operatorOutcomes | Where-Object { $_.acceptedByRunner -eq $true }).Count -eq 4 -and
    $annotation.operatorOutcomes[-1].acceptedByRunner -eq $false -and
    ($annotation.limitations -join ' ') -match 'not evidence that the pad physically failed') 'Physical gates or conservative timeout meaning changed.'
$inventory = $annotation.postTrialReadOnlyInventory
Assert-True ($inventory.captureProcessCount -eq 1 -and $inventory.zeroCaptureProcessesObserved -eq $false -and
    $inventory.activeRazerServiceCount -eq 0 -and $inventory.nativeControlReportsSent -eq $false -and
    $inventory.laterCaptureProcessIsOwnedTrial -eq $false -and $inventory.laterCaptureProcessActionsPerformed -eq $false -and
    $inventory.laterProcessInspection.evidenceKind -ceq 'transcribed-host-CIM-read-only-inspection' -and
    $inventory.laterProcessInspection.reportedCaptureCreatedAtUtc -ceq '2026-09-30T07:04:05.254042Z' -and
    $inventory.laterProcessInspection.creationAfterTrialExit -eq $true -and
    $inventory.laterProcessInspection.processModified -eq $false) 'Later process inventory must not imply zero, an owned survivor, or process intervention.'
foreach ($flag in @('manualRecoveryPerformed','synapseActionsPerformed','serviceActionsPerformed','powerCyclePerformedDuringThisSequence',
    'retryPerformed','lightingCommandsSubmitted','lifecycleBoundaryTested')) {
    Assert-True ($annotation.trialOutcome.$flag -eq $false) "Unperformed action acquired: $flag"
}
foreach ($property in $annotation.productionAdmission.PSObject.Properties) {
    Assert-True ($property.Value -eq $false) 'Stable demand observation must keep semantic and production gates closed.'
}
foreach ($flag in @('productionAdmitted','measuredRpmConfirmed','ownershipConfirmed','handbackConfirmed')) {
    Assert-True ($result.$flag -eq $false) "Typed semantic gate changed: $flag"
}
Assert-True (-not ($source -match '(?i)[A-Z]:\\|"(?:pid|parentPid|processId|captureProcessId|parentProcessId|childProcessIds|pipeName|nonce|mvid|moduleId|serialNumber|deviceInstanceId|rawReport|rawReports)"')) 'Private identifiers or reports must not enter evidence.'
Write-Host 'RZ09-0528 temperature-demand typed evidence tests passed.'
