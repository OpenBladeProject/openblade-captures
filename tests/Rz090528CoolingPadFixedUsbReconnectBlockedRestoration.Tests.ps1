[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$path = Join-Path $repository 'annotations\2026-09-29-rz09-0528-cooling-pad-fixed-usb-reconnect-blocked-restoration.json'
$source = Get-Content -LiteralPath $path -Raw
$annotation = $source | ConvertFrom-Json
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
Assert-True ($annotation.schemaVersion -eq 1 -and
    $annotation.evidenceProvenance.sourceCommit -ceq '0a204045757ffa8f628fb9033b8d575b85f4e8df' -and
    $annotation.evidenceProvenance.hardwareTested -eq $true -and
    $annotation.evidenceProvenance.usbPcapUsed -eq $false -and
    $annotation.evidenceProvenance.independentNativeReportTraceRetained -eq $false -and
    $annotation.queryArtifact.sha256 -ceq '6DA25C5ED64A7AAE23D3D6957D203F962702B203F20712F505C2582DA42EDD23' -and
    $annotation.queryArtifact.byteLength -eq 3179 -and $annotation.queryArtifact.rawArtifactCommitted -eq $false) `
    'Failed hardware typed evidence must not become successful restoration or native packet evidence.'
Assert-True ($annotation.device.modelNumber -ceq 'RZ09-0528' -and
    $annotation.device.sku -ceq 'RZ09-05289EN4' -and $annotation.device.vendorIdHex -ceq '1532' -and
    $annotation.device.productIdHex -ceq '0F43' -and $annotation.device.revisionHex -ceq '0200' -and
    $annotation.device.interfaceNumber -ceq '00' -and $annotation.device.usagePageHex -ceq '000C' -and
    $annotation.device.usageHex -ceq '0001' -and $annotation.device.featureBufferBytes -eq 91 -and
    $annotation.device.featureReportPrefixHex -ceq '00' -and $annotation.device.biosIsProvenanceOnly -eq $true) `
    'Exact accessory geometry and BIOS provenance boundary changed.'
Assert-True ($annotation.completedAtUtc -ceq '2026-09-30T02:14:17.2979970+00:00') 'Actual failure completion time changed.'
$expected = @('00/84:0000', '00/04:0300', '00/84:0000', '0D/10:01012C', '00/84:0000')
Assert-True (($annotation.performedLogicalSequenceAccordingToResultAndReviewedSource -join ',') -ceq ($expected -join ',')) `
    'Only the five actually performed logical exchanges may be published.'
Assert-True (($annotation.conditionalRemainingCommandsNotSubmitted -join ',') -ceq
    '0D/10:000600,00/04:0000,00/84:0000') 'No Auto or restoration command may be acquired after rejection.'
$boundary = $annotation.continuityBoundary
Assert-True ($boundary.firstSessionFullyDisposed -eq $true -and $boundary.firstNormalExitObserved -eq $true -and
    $boundary.firstExitCode -eq 0 -and $boundary.manualUsbBoundaryObservedBeforeFreshOpen -eq $true -and
    $boundary.freshProcessOpened -eq $true -and $boundary.originalBaselineRetainedBySupervisor -ceq '0000' -and
    $boundary.freshQueryObservedRaw -ceq '0000' -and $boundary.freshQueryAcceptedAsCandidate -eq $false -and
    $boundary.expectedContinuationCandidate -ceq '0300' -and $boundary.intermediateUsedAsRestorationBaseline -eq $false -and
    $boundary.sameRawValueEstablishesPhysicalRestoration -eq $false -and
    $boundary.immediatePostFixedPreUsbQueryPerformed -eq $false -and $boundary.usbCausedRawStateResetConfirmed -eq $false -and
    $boundary.secondFullDisposalReceiptRecorded -eq $false -and $boundary.childStillRunning -eq $false -and
    $boundary.conditionalRestorationCompleted -eq $false -and $boundary.newProcessTrialCompletedSuccessfully -eq $false -and
    $boundary.processCrashTested -eq $false) 'The failed continuation must not acquire restoration, crash or causal-reset claims.'
$usb = $annotation.usbObservation
Assert-True ($usb.initiallyPresent -eq $true -and $usb.disconnectAcknowledged -eq $true -and
    $usb.observedAbsenceMilliseconds -eq 5113.7454 -and $usb.nominalPollingIntervalMilliseconds -eq 250 -and
    $usb.reconnectAcknowledged -eq $true -and $usb.reconnected -eq $true -and $usb.physicalMediumConfirmed -eq $true -and
    $usb.powerAndSamePadSamePortAreOperatorProvenanceOnly -eq $true -and
    $usb.passiveObservationEstablishesExactIdentity -eq $false -and $usb.canExcludeReconnectBetweenSamples -eq $false -and
    $usb.boundaryObservationCompleted -eq $true -and $usb.overallTrialSuccess -eq $false) `
    'Nominal polling and operator provenance must remain distinct from successful restoration and electrical evidence.'
$expectedReceipts = @('PHYSICAL:baseline:YES', 'DONE:1:open:opened', 'DONE:1:baseline:0000',
    'DONE:1:acquire:0300', 'DONE:1:candidate:0300', 'DONE:1:fixed:01012C', 'DONE:1:fixedPhysical:YES',
    'DONE:1:close:FullyDisposed', 'EXIT:1:0', 'USB:observed-absence-at-least-five-seconds',
    'PHYSICAL:postReconnect:YES', 'DONE:2:open:opened', 'READ:2:intermediate:0000')
Assert-True (($annotation.sanitizedStageReceipts -join ',') -ceq ($expectedReceipts -join ',')) `
    'The final diagnostic READ must remain rejected, not an accepted DONE or restoration receipt.'
$result = $annotation.result
Assert-True ($result.success -eq $false -and
    $result.failure -ceq 'InvalidDataException: Process trial phase or evidence rejected.' -and
    $result.failureStageAccordingToResultAndReviewedSource -ceq 'freshIntermediateQuery' -and
    $result.rawBaseline -ceq '0000' -and $result.rawCandidateBeforeFixed -ceq '0300' -and
    $result.rawIntermediate -ceq '0000' -and $null -eq $result.rawRestored -and
    $result.postReconnectPhysicalMediumConfirmed -eq $true -and $result.manualRecoveryRequired -eq $true -and
    $result.exitCode -eq 2) 'Raw0000 matching the original value must not become physical quiet Auto restoration.'
foreach ($flag in @('autoAttempted', 'modeRestoreAttempted', 'rawRestorationConfirmed', 'finalPhysicalRestorationConfirmed',
    'lightingCommandsSubmitted', 'reacquireAttempted', 'recoveryPerformedByCommand', 'automaticRecovery',
    'synapseActionsPerformed', 'serviceActionsPerformed', 'powerCyclePerformedDuringTrial', 'retryPerformed')) {
    Assert-True ($result.$flag -eq $false) "Unperformed action or restoration was acquired: $flag"
}
$expectedJournalTimes = @('2026-09-30T02:13:21.1298833+00:00', '2026-09-30T02:13:49.0638188+00:00',
    '2026-09-30T02:14:10.5123903+00:00', '2026-09-30T02:14:52.5074860+00:00')
Assert-True (($annotation.operatorOutcomes.recordedAtUtc -join ',') -ceq ($expectedJournalTimes -join ',') -and
    $annotation.operatorOutcomes[0].userReply -ceq 'yes' -and $annotation.operatorOutcomes[0].normalMediumConfirmed -eq $true -and
    $annotation.operatorOutcomes[1].userReply -ceq 'unplugged' -and $annotation.operatorOutcomes[1].twelveVoltRetainedOperatorConfirmed -eq $true -and
    $annotation.operatorOutcomes[2].userReply -ceq 'reconnected' -and $annotation.operatorOutcomes[2].samePadAndPortOperatorConfirmed -eq $true -and
    $annotation.operatorOutcomes[2].twelveVoltRetainedOperatorConfirmed -eq $true -and
    $annotation.operatorOutcomes[3].userReply -ceq 'yes' -and $annotation.operatorOutcomes[3].normalMediumConfirmed -eq $true) `
    'Exact journal-save times and post-reconnect Medium observations changed.'
Assert-True (($annotation.limitations -join ' ') -match 'not YES submission timestamps' -and
    ($annotation.limitations -join ' ') -match 'do not establish that USB removal caused') `
    'Bookkeeping timestamps and absent immediate pre-USB readback must retain their limits.'
Assert-True ($annotation.postTrialInventory.activeRelevantProcessCount -eq 0 -and
    $annotation.postTrialInventory.activeRazerServiceCount -eq 0 -and
    $annotation.manualRecovery.separateFromTrial -eq $true -and $annotation.manualRecovery.instructionIssued -eq $true -and
    $annotation.manualRecovery.operatorOutcomePending -eq $false -and $annotation.manualRecovery.performedByCommand -eq $false -and
    $annotation.manualRecovery.outcomeConfirmed -eq $false -and
    $annotation.manualRecovery.manualCyclePerformedOperatorReported -eq $true -and
    $annotation.manualRecovery.recordedAtUtc -ceq '2026-09-30T02:21:09.9916468+00:00' -and
    $annotation.manualRecovery.operatorReply -ceq 'went back to Medium with the same lighting' -and
    $annotation.manualRecovery.normalMediumOperatorReported -eq $true -and
    $annotation.manualRecovery.lightingUnchangedOperatorReported -eq $true -and
    $annotation.manualRecovery.preferredQuietBaselineRecovered -eq $false -and
    $annotation.manualRecovery.synapseUsed -eq $false -and $annotation.manualRecovery.servicesRestarted -eq $false -and
    $annotation.manualRecovery.postCycleRawModeQueried -eq $false -and $null -eq $annotation.manualRecovery.postCycleRawMode) `
    'Separate operator-reported return to Medium must not acquire quiet recovery, a raw-state read or vendor recovery.'
foreach ($property in $annotation.productionAdmission.PSObject.Properties) {
    if ($property.Name -ne 'reason') {
        Assert-True ($property.Value -eq $false) 'A rejected continuation must keep every production and semantic gate closed.'
    }
}
Assert-True (-not ($source -match '(?i)[A-Z]:\\|"(?:pid|parentPid|processId|childProcessIds|pipeName|nonce|mvid|moduleId|serialNumber|deviceInstanceId|rawReport|rawReports)"')) `
    'Private paths, operating-system identifiers, authentication secrets, module identifiers and raw reports must not enter evidence.'
Write-Host 'RZ09-0528 cooling-pad Fixed USB reconnect blocked-restoration evidence tests passed.'
