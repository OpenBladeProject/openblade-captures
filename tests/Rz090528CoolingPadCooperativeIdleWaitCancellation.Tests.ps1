[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$path = Join-Path $repository 'annotations\2026-09-29-rz09-0528-cooling-pad-cooperative-idle-wait-cancellation.json'
$source = Get-Content -LiteralPath $path -Raw
$annotation = $source | ConvertFrom-Json
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
Assert-True ($annotation.schemaVersion -eq 1 -and
    $annotation.evidenceProvenance.sourceCommit -ceq '587a6f1ab97f6aa539941f351984c4374d5a5745' -and
    $annotation.evidenceProvenance.hardwareTested -eq $true -and
    $annotation.evidenceProvenance.usbPcapUsed -eq $false -and
    $annotation.evidenceProvenance.independentNativeReportTraceRetained -eq $false -and
    $annotation.queryArtifact.sha256 -ceq 'C3A4FDECA0407AE93D32A37890602EF575BA326D16DADA4BEB67C5E180A60412' -and
    $annotation.queryArtifact.byteLength -eq 2819 -and
    $annotation.queryArtifact.rawArtifactCommitted -eq $false) 'This hardware typed result must not become native packet evidence.'
Assert-True ($annotation.device.modelNumber -ceq 'RZ09-0528' -and
    $annotation.device.sku -ceq 'RZ09-05289EN4' -and $annotation.device.vendorIdHex -ceq '1532' -and
    $annotation.device.productIdHex -ceq '0F43' -and $annotation.device.revisionHex -ceq '0200' -and
    $annotation.device.interfaceNumber -ceq '00' -and $annotation.device.usagePageHex -ceq '000C' -and
    $annotation.device.usageHex -ceq '0001' -and $annotation.device.featureBufferBytes -eq 91 -and
    $annotation.device.featureReportPrefixHex -ceq '00' -and $annotation.device.biosIsProvenanceOnly -eq $true) `
    'Exact accessory identity and BIOS provenance policy changed.'
Assert-True ($annotation.completedAtUtc -ceq '2026-09-30T01:40:19.0389896+00:00') 'Actual supervisor completion time changed.'
$expected = @('00/84:0000', '00/04:0300', '00/84:0000', '0D/10:01012C', '00/84:0000', '0D/10:000600', '00/04:0000', '00/84:0000')
Assert-True (($annotation.performedLogicalSequenceAccordingToResultAndReviewedSource -join ',') -ceq ($expected -join ',')) `
    'The eight bounded HID exchanges must remain unchanged by the idle-wait cancellation boundary.'
$cancel = $annotation.cancellationBoundary
Assert-True ($cancel.workKind -ceq 'developer-armed-idle-wait' -and $cancel.armedAfterLogicalExchange -eq 4 -and
    $cancel.occurredBetweenHidOperations -eq $true -and $cancel.matchingWorkTokenObservedCancellation -eq $true -and
    $cancel.cancellationReceipt -ceq 'ObservedCancellation' -and $cancel.firstFullyDisposedBeforeCancellationExit -eq $true -and
    $cancel.firstActualExitCode -eq 4 -and $cancel.postExitMediumPhysicalConfirmationAccepted -eq $true -and
    $cancel.postCancellationPhysicalBeforeSecondOpen -eq $true -and $cancel.secondProcessOpenedOnce -eq $true -and
    $cancel.productionWorkLoopCancellationTested -eq $false -and $cancel.inFlightIoCancellationTested -eq $false -and
    $cancel.processCrashTested -eq $false -and $cancel.forcedTerminationTested -eq $false) `
    'Matching-token developer idle-wait cancellation must not acquire production, native-I/O or crash coverage.'
$boundary = $annotation.continuityBoundary
Assert-True ($boundary.kind -ceq 'cooperative-cancellation-between-HID-operations-and-new-process' -and
    $boundary.firstSessionFullyDisposed -eq $true -and $boundary.firstCancellationExitObserved -eq $true -and
    $boundary.firstExitCode -eq 4 -and $boundary.freshProcessOpenAfterFirstExit -eq $true -and
    $boundary.matchingCompletionReceiptsRequiredByReviewedSource -eq $true -and
    $boundary.originalBaselineRetainedBySupervisor -ceq '0000' -and $boundary.freshProcessIntermediate -ceq '0300' -and
    $boundary.intermediateUsedAsRestorationBaseline -eq $false -and $boundary.secondSessionFullyDisposed -eq $true -and
    $boundary.secondNormalExitObserved -eq $true -and $boundary.secondExitCode -eq 0 -and
    $boundary.childStillRunning -eq $false -and $boundary.hardwareTested -eq $true -and
    $boundary.newProcessTested -eq $true -and $boundary.processCrashTested -eq $false) `
    'Full disposal and actual cancellation exit must precede post-exit physical confirmation and new-process opening.'
$expectedReceipts = @('PHYSICAL:baseline:YES', 'DONE:1:open:opened', 'DONE:1:baseline:0000',
    'DONE:1:acquire:0300', 'DONE:1:candidate:0300', 'DONE:1:fixed:01012C', 'DONE:1:fixedPhysical:YES',
    'DONE:1:cancelWork:ObservedCancellation', 'DONE:1:close:FullyDisposed', 'EXIT:1:4',
    'PHYSICAL:postCancellation:YES', 'DONE:2:open:opened', 'DONE:2:intermediate:0300',
    'DONE:2:auto:000600', 'DONE:2:autoPhysical:YES', 'DONE:2:restore:0000', 'DONE:2:restored:0000',
    'DONE:2:finalPhysical:YES', 'DONE:2:close:FullyDisposed', 'EXIT:2:0')
Assert-True (($annotation.sanitizedCompletedStageReceipts -join ',') -ceq ($expectedReceipts -join ',')) `
    'Sanitized receipts must preserve actual matching-token cancellation, exit4 and continuation ordering.'
Assert-True ($annotation.result.success -eq $true -and $null -eq $annotation.result.failure -and
    $annotation.result.rawBaseline -ceq '0000' -and $annotation.result.rawCandidate -ceq '0300' -and
    $annotation.result.rawIntermediate -ceq '0300' -and $annotation.result.rawRestored -ceq '0000' -and
    $annotation.result.cooperativeCancellationObserved -eq $true -and
    $annotation.result.postCancellationPhysicalConfirmed -eq $true -and
    $annotation.result.exitCode -eq 0 -and $annotation.result.manualRecoveryRequired -eq $false) `
    'The original raw0000 target must remain separate from the fresh intermediate raw0300.'
Assert-True ($annotation.preflight.operatorPresent -eq $true -and
    $annotation.preflight.operatorBaselineReply -ceq 'yes' -and
    $annotation.preflight.supervisorBaselinePhysicalConfirmationAccepted -eq $true -and
    $annotation.preflight.synapseUseForbidden -eq $true -and
    $annotation.preflight.recoveryAcknowledgement -ceq 'ManualPowerCycleOnly' -and
    $annotation.preflight.prefilledPhysicalAnswers -eq $false -and $annotation.operatorOutcomes.Count -eq 4) `
    'Five confirmations including the fresh post-exit observation must remain attended.'
foreach ($outcome in $annotation.operatorOutcomes) {
    Assert-True ($outcome.userReply -ceq 'yes' -and $outcome.submittedToSupervisor -eq $true -and
        $outcome.fullBrightnessStaticGreenConfirmed -eq $true -and $outcome.noRedOrSleepConfirmed -eq $true) `
        'Each physical reply must preserve actual acceptance and normal lighting/sleep observations.'
}
Assert-True ($annotation.operatorOutcomes[0].normalMediumConfirmed -eq $true -and
    $annotation.operatorOutcomes[1].phase -ceq 'post-cancellation' -and
    $annotation.operatorOutcomes[1].normalMediumConfirmed -eq $true -and
    $annotation.operatorOutcomes[2].quietAutoConfirmed -eq $true -and
    $annotation.operatorOutcomes[3].quietAutoConfirmed -eq $true) 'Post-exit Medium and subsequent quiet Auto observations changed.'
Assert-True ([DateTimeOffset]::Parse($annotation.operatorOutcomes[3].recordedAtUtc) -gt
    [DateTimeOffset]::Parse($annotation.completedAtUtc) -and
    ($annotation.limitations -join ' ') -match 'journal-save bookkeeping' -and
    ($annotation.limitations -join ' ') -match 'not YES submission timestamps') `
    'The final journal-save time must not be represented as a post-exit YES submission.'
foreach ($flag in @('lightingCommandsSubmitted', 'recoveryPerformedByCommand', 'automaticRecovery',
    'synapseActionsPerformed', 'serviceActionsPerformed', 'powerCyclePerformed', 'retryPerformed')) {
    Assert-True ($annotation.result.$flag -eq $false) "Unperformed action was acquired: $flag"
}
foreach ($property in $annotation.productionAdmission.PSObject.Properties) {
    if ($property.Name -ne 'reason') {
        Assert-True ($property.Value -eq $false) 'One idle-wait cancellation success must keep every production and semantic gate closed.'
    }
}
Assert-True (-not ($source -match '(?i)[A-Z]:\\|"(?:pid|parentPid|processId|childProcessIds|pipeName|nonce|mvid|moduleId|serialNumber|deviceInstanceId|rawReport|rawReports)"')) `
    'Private paths, operating-system identifiers, authentication secrets, module identifiers and raw reports must not enter evidence.'
Write-Host 'RZ09-0528 cooling-pad cooperative idle-wait cancellation evidence tests passed.'
