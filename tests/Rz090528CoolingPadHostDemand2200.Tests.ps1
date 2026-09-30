[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$source = Get-Content (Join-Path $repository 'annotations/2026-09-29-rz09-0528-cooling-pad-host-demand-2200.json') -Raw
$annotation = $source | ConvertFrom-Json
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
Assert-True ($annotation.schemaVersion -eq 1 -and
    $annotation.evidenceProvenance.sourceCommit -ceq '7a6472d07cad4d3312d0e560c0a1dc2458b5c666' -and
    $annotation.evidenceProvenance.captureApphostSha256 -ceq '0CB5F426C5FE2FE83C74A4E521BD2F151F65297E034B293B01E6FF98B1F6A682' -and
    $annotation.evidenceProvenance.captureDllSha256 -ceq 'C697F009A5A20878E347CEED8E38E4A088E5D13EF506ACBDC1523099C5879C76' -and
    $annotation.queryArtifact.sha256 -ceq '9CCA1AEA250D64A1FE0148C6E0F1EF54F1B7BE6B04A35CB0A47C93D1E1C25C7A' -and
    $annotation.queryArtifact.byteLength -eq 2799 -and $annotation.queryArtifact.rawArtifactCommitted -eq $false -and
    $annotation.evidenceProvenance.hardwareTested -eq $true -and
    $annotation.evidenceProvenance.usbPcapUsed -eq $false -and
    $annotation.evidenceProvenance.independentNativeReportTraceRetained -eq $false) 'Actual trial provenance changed.'
Assert-True ($annotation.device.sku -ceq 'RZ09-05289EN4' -and
    $annotation.device.vendorIdHex -ceq '1532' -and $annotation.device.productIdHex -ceq '0F43' -and
    $annotation.device.revisionHex -ceq '0200' -and $annotation.device.featureBufferBytes -eq 91 -and
    $annotation.device.featureReportPrefixHex -ceq '00' -and $annotation.device.biosIsProvenanceOnly -eq $true) 'Exact device scope changed.'
$expected = @('00/84:0000','00/04:0300','00/84:0000','0D/10:000600','0D/01:01052C','0D/10:01012C','0D/10:000600','00/04:0000','00/84:0000')
Assert-True (($annotation.performedLogicalSequenceAccordingToResultAndReviewedSource -join ',') -ceq ($expected -join ',') -and
    $annotation.sequenceEvidenceLimit -match 'planned sequence only' -and
    $annotation.sequenceEvidenceLimit -match 'result flags' -and
    $annotation.sequenceEvidenceLimit -match 'not an independent native packet count') 'Logical sequence must not acquire packet-trace provenance.'
$result = $annotation.result
Assert-True ($result.rawBaseline -ceq '0000' -and $result.rawCandidate -ceq '0300' -and
    $result.rawRestored -ceq '0000' -and $null -eq $result.failure -and $null -eq $result.failurePhase -and
    $result.manualRecoveryRequired -eq $false -and $result.submissionStateUnknown -eq $false) 'Successful raw outcome changed.'
foreach ($flag in @('modeAcquireAttempted','modeAcquireAcknowledged','candidateConfirmed','demandEntryAttempted',
    'demandEntryAcknowledged','hostDemandAttempted','hostDemandAcknowledged','hostDemandPhysicalConfirmed',
    'fixedAttempted','fixedAcknowledged','fixedPhysicalConfirmed','autoAttempted','autoAcknowledged',
    'autoPhysicalConfirmed','modeRestoreAttempted','modeRestoreAcknowledged','rawRestorationConfirmed','finalPhysicalConfirmed')) {
    Assert-True ($result.$flag -eq $true) "Completed outcome changed: $flag"
}
Assert-True ($annotation.physicalTarget.configuredHostDemandRpm -eq 2200 -and
    $annotation.physicalTarget.measuredRpmConfirmed -eq $false -and
    $annotation.physicalTarget.rawControlStateIsFanReadback -eq $false -and
    $annotation.physicalTarget.requestedPreferredQuietAutoFinalConfirmed -eq $true -and
    $annotation.trialOutcome.compoundRestorationPreviouslyValidated -eq $false -and
    $annotation.trialOutcome.compoundRestorationObservedThisTrial -eq $true -and
    $annotation.trialOutcome.trialSequenceCompleted -eq $true -and $annotation.trialOutcome.exitCode -eq 0) 'One configured-demand observation must not become prior validation or measured RPM.'
$times = @('2026-09-30T05:34:39.0496017+00:00','2026-09-30T05:35:20.4847992+00:00','2026-09-30T05:36:00.0511200+00:00','2026-09-30T05:36:37.9009220+00:00')
Assert-True (($annotation.operatorOutcomes.recordedAtUtc -join ',') -ceq ($times -join ',') -and
    $annotation.preflight.operatorInitialStateRecordedAtUtc -ceq '2026-09-30T05:31:45.5601942+00:00' -and
    $annotation.preflight.quietNormalGreenNoRedSleepHyperBoostInactiveConfirmed -eq $true -and
    $annotation.completedAtUtc -ceq '2026-09-30T05:36:36.2867945+00:00' -and
    ($annotation.limitations -join ' ') -match 'journal-save times, not YES submission timestamps') 'Five attended confirmations require exact journal provenance.'
foreach ($outcome in $annotation.operatorOutcomes) {
    Assert-True ($outcome.userReply -ceq 'yes' -and $outcome.greenLightingUnchanged -eq $true -and
        $outcome.noRedOrSleep -eq $true -and $outcome.submittedToRunner -eq $true) 'Physical confirmation changed.'
}
foreach ($flag in @('synapseActionsPerformed','serviceActionsPerformed','powerCyclePerformedDuringThisSequence',
    'retryPerformed','lightingCommandsSubmitted','lifecycleBoundaryTested')) {
    Assert-True ($annotation.trialOutcome.$flag -eq $false) "Unperformed action acquired: $flag"
}
foreach ($property in $annotation.productionAdmission.PSObject.Properties) {
    Assert-True ($property.Value -eq $false) 'Single demand success must keep semantic and production gates closed.'
}
foreach ($flag in @('productionAdmitted','fanStateConfirmed','ownershipConfirmed','handbackConfirmed')) {
    Assert-True ($result.$flag -eq $false) "Typed result gate changed: $flag"
}
Assert-True (-not ($source -match '(?i)[A-Z]:\\|"(?:pid|parentPid|processId|childProcessIds|pipeName|nonce|mvid|moduleId|serialNumber|deviceInstanceId|rawReport|rawReports)"')) 'Private identifiers or reports must not enter evidence.'
Write-Host 'RZ09-0528 host-demand 2200 typed evidence tests passed.'
