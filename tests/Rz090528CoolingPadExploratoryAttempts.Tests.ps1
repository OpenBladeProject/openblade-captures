[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$path = Join-Path $repository 'annotations\2026-09-29-rz09-0528-cooling-pad-fan-exploratory-attempts.json'
$annotation = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-True ($annotation.schemaVersion -eq 1 -and $annotation.attempts.Count -eq 2 -and
    $annotation.evidenceProvenance.usbPcapUsed -eq $false -and
    $annotation.evidenceProvenance.independentNativeReportTraceRetained -eq $false) `
    'Typed results must not become independently captured packet evidence.'
Assert-True ($annotation.device.productIdHex -ceq '0F43' -and
    $annotation.device.revisionHex -ceq '0200' -and
    $annotation.device.featureReportPrefixHex -ceq '00' -and
    $annotation.device.biosIsProvenanceOnly -eq $true) 'Exact accessory and BIOS provenance boundary changed.'
$first, $second = $annotation.attempts
Assert-True ($first.queryArtifact.sha256 -ceq 'C6174DFB6842B128D65D310AB125A27C25FE4E72B8E6FA294620B88404C71F0B' -and
    $first.queryArtifact.byteLength -eq 1692 -and
    $second.queryArtifact.sha256 -ceq 'C689239572D3E34BBA497389607BB7D4E979D692934BAAB3C83462546A20A192' -and
    $second.queryArtifact.byteLength -eq 1683) 'Private typed-result provenance changed.'
Assert-True ($annotation.plannedSequence.Count -eq 7 -and
    $first.performedLogicalSequenceAccordingToResult.Count -eq 4 -and
    $second.performedLogicalSequenceAccordingToResult.Count -eq 1 -and
    $second.performedLogicalSequenceAccordingToResult[0] -ceq '00/84:0000') `
    'The planned sequence must not be treated as a completed round trip.'
Assert-True ($first.result.rawBaseline -ceq '0000' -and $first.result.rawCandidate -ceq '0300' -and
    $first.result.fixedAcknowledged -eq $true -and
    $first.result.failurePhase -ceq 'fixedPhysicalConfirmation' -and
    $first.result.failure -ceq 'OperatorTimeout' -and
    $first.result.fixedPhysicalConfirmedByCommand -eq $false -and
    $first.operatorOutcome.physicalReplyReceivedAfterCommandTimeout -eq $true -and
    $first.operatorOutcome.physicalReplySubmittedToCommand -eq $false -and
    $first.result.hardwareRegressionEstablished -eq $false) `
    'A late operator reply must not rewrite the confirmation timeout or establish hardware failure.'
foreach ($attempt in $annotation.attempts) {
    Assert-True ($attempt.result.autoAttempted -eq $false -and
        $attempt.result.modeRestoreAttempted -eq $false -and
        $attempt.result.rawRestorationConfirmed -eq $false -and
        $attempt.result.recoveryPerformedByCommand -eq $false) `
        'Neither attempt performed Auto or mode restoration.'
}
Assert-True ($second.preflight.newAttemptExplicitlyRequested -eq $true -and
    $second.preflight.recoveryAcknowledgementIsCommandMetadataOnly -eq $true -and
    $second.preflight.freshVendorRecoveryPermissionEstablished -eq $false -and
    $second.result.rawBaseline -ceq '0300' -and $second.result.failure -ceq 'BaselineNot0000' -and
    $second.result.modeAcquireAttempted -eq $false -and $second.result.fixedAttempted -eq $false -and
    $second.result.semanticSetterCount -eq 0 -and $second.result.manualRecoveryRequired -eq $false) `
    'The second attempt must remain a baseline rejection without setters.'
Assert-True ($first.subsequentVendorRecovery.recoveryViaSynapseReported -eq $true -and
    $first.subsequentVendorRecovery.powerCycleReported -eq $false -and
    $first.subsequentVendorRecovery.openBladeModeRestorationPerformed -eq $false) `
    'Vendor recovery must not become OpenBlade restoration or a reported power cycle.'
foreach ($property in $annotation.productionAdmission.PSObject.Properties) {
    if ($property.Name -ne 'reason') {
        Assert-True ($property.Value -eq $false) 'Exploratory attempts must keep every production gate closed.'
    }
}
Assert-True (-not ((Get-Content -LiteralPath $path -Raw) -match '(?i)[A-Z]:\\|"(?:processId|deviceInstanceId|serialNumber)"')) `
    'Private paths and identifiers must not enter the annotation.'
Write-Host 'RZ09-0528 cooling-pad exploratory attempt evidence tests passed.'
