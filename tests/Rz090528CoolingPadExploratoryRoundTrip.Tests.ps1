[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$path = Join-Path $repository 'annotations\2026-09-29-rz09-0528-cooling-pad-fan-exploratory-round-trip.json'
$annotation = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
Assert-True ($annotation.schemaVersion -eq 1 -and $annotation.attempt -eq 3 -and
    $annotation.evidenceProvenance.usbPcapUsed -eq $false -and
    $annotation.evidenceProvenance.independentNativeReportTraceRetained -eq $false -and
    $annotation.queryArtifact.sha256 -ceq '0B3C59A523B5312CB77166901BB2507255D5F6DA1F40F8ABE5AEB2B0BD17A377' -and
    $annotation.queryArtifact.byteLength -eq 1651) 'Typed provenance must not become native packet evidence.'
Assert-True ($annotation.device.productIdHex -ceq '0F43' -and
    $annotation.device.revisionHex -ceq '0200' -and
    $annotation.device.featureReportPrefixHex -ceq '00' -and
    $annotation.device.biosIsProvenanceOnly -eq $true) 'Exact accessory boundary changed.'
$expected = @('00/84:0000', '00/04:0300', '00/84:0000', '0D/10:01012C', '0D/10:000600', '00/04:0000', '00/84:0000')
Assert-True (($annotation.performedLogicalSequenceAccordingToResultAndReviewedSource -join ',') -ceq ($expected -join ',')) `
    'Completed logical stages must retain the reviewed bounded sequence.'
Assert-True ($annotation.result.rawBaseline -ceq '0000' -and
    $annotation.result.rawCandidate -ceq '0300' -and
    $annotation.result.rawRestored -ceq '0000' -and
    $annotation.result.exitCode -eq 0 -and $null -eq $annotation.result.failure -and
    $annotation.result.manualRecoveryRequired -eq $false) 'Successful raw round trip changed.'
foreach ($flag in @('modeAcquireAttempted', 'modeAcquireAcknowledged', 'candidateConfirmed',
    'fixedAttempted', 'fixedAcknowledged', 'fixedPhysicalConfirmed', 'autoAttempted',
    'autoAcknowledged', 'autoPhysicalConfirmed', 'modeRestoreAttempted',
    'modeRestoreAcknowledged', 'rawRestorationConfirmed', 'finalPhysicalConfirmed')) {
    Assert-True ($annotation.result.$flag -eq $true) "Completed trial flag changed: $flag"
}
Assert-True ($annotation.operatorOutcomes.Count -eq 3 -and
    $annotation.operatorOutcomes[0].physicalReply -ceq 'Medium; normal and green unchanged' -and
    $annotation.operatorOutcomes[1].physicalReply -ceq 'Quiet Auto; normal and green unchanged' -and
    $annotation.operatorOutcomes[2].physicalReply -ceq 'Normal and unchanged') 'Bounded operator observations changed.'
foreach ($outcome in $annotation.operatorOutcomes) {
    Assert-True ($outcome.submittedToCommand -eq $true) 'All three confirmations were submitted to this trial.'
}
Assert-True ($annotation.preflight.synapseUseForbidden -eq $true -and
    $annotation.preflight.recoveryArgumentIsPriorAcknowledgementOnly -eq $true -and
    $annotation.preflight.freshVendorRecoveryPermissionEstablished -eq $false -and
    $annotation.preflight.prefilledPhysicalAnswers -eq $false) 'Recovery metadata must not authorize vendor recovery.'
foreach ($flag in @('lightingCommandsSubmitted', 'recoveryPerformedByCommand', 'synapseActionsPerformed',
    'serviceActionsPerformed', 'powerCyclePerformed')) {
    Assert-True ($annotation.result.$flag -eq $false) "Unperformed action was acquired: $flag"
}
$postExit = $annotation.postExitObservation
Assert-True ($postExit.queryArtifact.sha256 -ceq '47627BAA16CF3C0346839AAA9330AD3340943BF2AA70900841E066D61B1CD704' -and
    $postExit.queryArtifact.byteLength -eq 757 -and $postExit.readOnlySemanticIntent -eq $true -and
    $postExit.setterCount -eq 0 -and $postExit.responsePayloadHex -ceq '0000' -and
    $postExit.transportSuccess -eq $true) 'Post-exit observation must remain one raw read without setters.'
$elapsed = ([DateTimeOffset]::Parse($postExit.startedAtUtc) - [DateTimeOffset]::Parse($annotation.completedAtUtc)).TotalSeconds
Assert-True ([Math]::Abs($elapsed - $postExit.secondsSinceTrialExitFromUtcTimestamps) -lt 0.0000001 -and
    $postExit.sourceDerivedElapsedSeconds -lt 0) 'Correct UTC elapsed must retain the original derived-field discrepancy.'
Assert-True ($postExit.physicalObservationPending -eq $false -and
    $postExit.physicalReply -ceq 'Still normal and unchanged' -and $postExit.physicalConfirmed -eq $true -and
    $postExit.quietAutoConfirmedByOperator -eq $true -and
    $postExit.greenLightingUnchangedConfirmedByOperator -eq $true -and
    $postExit.noRedOrSleepConfirmedByOperator -eq $true -and $postExit.replyAfterReadOnlyQuery -eq $true) `
    'Post-exit physical observation must retain the actual operator reply and its bounded meaning.'
foreach ($property in $annotation.productionAdmission.PSObject.Properties) {
    if ($property.Name -ne 'reason') {
        Assert-True ($property.Value -eq $false) 'One exploratory success must keep every production gate closed.'
    }
}
Assert-True (-not ((Get-Content -LiteralPath $path -Raw) -match '(?i)[A-Z]:\\|"(?:processId|deviceInstanceId|serialNumber)"')) `
    'Private paths and identifiers must not enter the annotation.'
Write-Host 'RZ09-0528 cooling-pad exploratory round-trip evidence tests passed.'
