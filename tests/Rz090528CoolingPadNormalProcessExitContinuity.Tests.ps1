[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$path = Join-Path $repository 'annotations\2026-09-29-rz09-0528-cooling-pad-normal-process-exit-continuity.json'
$source = Get-Content -LiteralPath $path -Raw
$annotation = $source | ConvertFrom-Json
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
Assert-True ($annotation.schemaVersion -eq 1 -and
    $annotation.evidenceProvenance.sourceCommit -ceq '836ae17265bcc6131ca9f8da0e282b18c87ad63f' -and
    $annotation.evidenceProvenance.hardwareTested -eq $true -and
    $annotation.evidenceProvenance.usbPcapUsed -eq $false -and
    $annotation.evidenceProvenance.independentNativeReportTraceRetained -eq $false -and
    $annotation.queryArtifact.sha256 -ceq 'FFD073093B6E9ED91496E3A9E969EEB3BDC836031D60B5BB4F024E35EBC34AC2' -and
    $annotation.queryArtifact.byteLength -eq 2476 -and
    $annotation.queryArtifact.rawArtifactCommitted -eq $false) 'Hardware typed evidence must not become native packet evidence.'
Assert-True ($annotation.device.modelNumber -ceq 'RZ09-0528' -and
    $annotation.device.sku -ceq 'RZ09-05289EN4' -and $annotation.device.vendorIdHex -ceq '1532' -and
    $annotation.device.productIdHex -ceq '0F43' -and $annotation.device.revisionHex -ceq '0200' -and
    $annotation.device.interfaceNumber -ceq '00' -and $annotation.device.usagePageHex -ceq '000C' -and
    $annotation.device.usageHex -ceq '0001' -and $annotation.device.featureBufferBytes -eq 91 -and
    $annotation.device.featureReportPrefixHex -ceq '00' -and $annotation.device.biosIsProvenanceOnly -eq $true) `
    'The exact accessory boundary or BIOS provenance policy changed.'
Assert-True ($annotation.completedAtUtc -ceq '2026-09-30T01:13:16.3131264+00:00') 'Actual normal-exit completion time changed.'
$expected = @('00/84:0000', '00/04:0300', '00/84:0000', '0D/10:01012C', '00/84:0000', '0D/10:000600', '00/04:0000', '00/84:0000')
Assert-True (($annotation.performedLogicalSequenceAccordingToResultAndReviewedSource -join ',') -ceq ($expected -join ',')) `
    'Completed stages must retain the fixed eight reviewed logical exchanges.'
$boundary = $annotation.continuityBoundary
Assert-True ($boundary.kind -ceq 'normal-process-exit-and-new-process' -and
    $boundary.firstSessionFullyDisposed -eq $true -and $boundary.firstNormalExitObserved -eq $true -and
    $boundary.firstExitCode -eq 0 -and $boundary.freshProcessOpenAfterFirstExit -eq $true -and
    $boundary.matchingCompletionReceiptsRequiredByReviewedSource -eq $true -and
    $boundary.originalBaselineRetainedBySupervisor -ceq '0000' -and $boundary.freshProcessIntermediate -ceq '0300' -and
    $boundary.intermediateUsedAsRestorationBaseline -eq $false -and $boundary.secondSessionFullyDisposed -eq $true -and
    $boundary.secondNormalExitObserved -eq $true -and $boundary.secondExitCode -eq 0 -and
    $boundary.childStillRunning -eq $false -and $boundary.hardwareTested -eq $true -and
    $boundary.newProcessTested -eq $true -and $boundary.processCrashTested -eq $false) `
    'Actual normal process exit must precede new-process opening without acquiring crash safety.'
$expectedReceipts = @('PHYSICAL:baseline:YES', 'DONE:1:open:opened', 'DONE:1:baseline:0000',
    'DONE:1:acquire:0300', 'DONE:1:candidate:0300', 'DONE:1:fixed:01012C',
    'DONE:1:fixedPhysical:YES', 'DONE:1:close:FullyDisposed', 'EXIT:1:0',
    'DONE:2:open:opened', 'DONE:2:intermediate:0300', 'DONE:2:auto:000600',
    'DONE:2:autoPhysical:YES', 'DONE:2:restore:0000', 'DONE:2:restored:0000',
    'DONE:2:finalPhysical:YES', 'DONE:2:close:FullyDisposed', 'EXIT:2:0')
Assert-True (($annotation.sanitizedCompletedStageReceipts -join ',') -ceq ($expectedReceipts -join ',')) `
    'Private result stage receipts must preserve exact close/exit/open ordering and payload outcomes.'
Assert-True ($annotation.result.success -eq $true -and $null -eq $annotation.result.failure -and
    $annotation.result.rawBaseline -ceq '0000' -and $annotation.result.rawCandidate -ceq '0300' -and
    $annotation.result.rawIntermediate -ceq '0300' -and $annotation.result.rawRestored -ceq '0000' -and
    $annotation.result.exitCode -eq 0 -and $annotation.result.manualRecoveryRequired -eq $false) `
    'Original raw baseline and successful restoration must remain distinct from the intermediate state.'
foreach ($flag in @('modeAcquireAcknowledged', 'candidateConfirmed', 'fixedAcknowledged',
    'fixedPhysicalConfirmed', 'autoAcknowledged', 'autoPhysicalConfirmed', 'modeRestoreAcknowledged',
    'rawRestorationConfirmed', 'finalPhysicalConfirmed')) {
    Assert-True ($annotation.result.$flag -eq $true) "Completed hardware outcome changed: $flag"
}
Assert-True ($annotation.preflight.operatorPresent -eq $true -and
    $annotation.preflight.supervisorBaselinePhysicalConfirmationAccepted -eq $true -and
    $annotation.preflight.synapseUseForbidden -eq $true -and
    $annotation.preflight.recoveryAcknowledgement -ceq 'ManualPowerCycleOnly' -and
    $annotation.preflight.prefilledPhysicalAnswers -eq $false -and
    $annotation.operatorOutcomes.Count -eq 3) 'All physical confirmations must remain attended without Synapse recovery.'
foreach ($outcome in $annotation.operatorOutcomes) {
    Assert-True ($outcome.userReply -ceq 'yes' -and $outcome.submittedToSupervisor -eq $true -and
        $outcome.fullBrightnessStaticGreenConfirmed -eq $true -and $outcome.noRedOrSleepConfirmed -eq $true) `
        'Each operator reply must retain its actual submission and physical lighting/sleep observation.'
}
Assert-True ($annotation.operatorOutcomes[0].normalMediumConfirmed -eq $true -and
    $annotation.operatorOutcomes[1].quietAutoConfirmed -eq $true -and
    $annotation.operatorOutcomes[2].quietAutoConfirmed -eq $true) 'Medium and original quiet Auto observations changed.'
foreach ($flag in @('lightingCommandsSubmitted', 'recoveryPerformedByCommand', 'automaticRecovery',
    'synapseActionsPerformed', 'serviceActionsPerformed', 'powerCyclePerformed', 'retryPerformed')) {
    Assert-True ($annotation.result.$flag -eq $false) "Unperformed action was acquired: $flag"
}
foreach ($property in $annotation.productionAdmission.PSObject.Properties) {
    if ($property.Name -ne 'reason') {
        Assert-True ($property.Value -eq $false) 'One normal-exit success must keep every production and semantic gate closed.'
    }
}
Assert-True (-not ($source -match '(?i)[A-Z]:\\|"(?:pid|parentPid|processId|childProcessIds|pipeName|nonce|serialNumber|deviceInstanceId|rawReport|rawReports)"')) `
    'Private paths, operating-system identifiers, authentication secrets and raw native reports must not enter evidence.'
Write-Host 'RZ09-0528 cooling-pad normal-process-exit continuity evidence tests passed.'
