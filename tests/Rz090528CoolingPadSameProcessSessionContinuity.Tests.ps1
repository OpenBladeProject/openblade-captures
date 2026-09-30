[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$path = Join-Path $repository 'annotations\2026-09-29-rz09-0528-cooling-pad-same-process-session-continuity.json'
$annotation = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
Assert-True ($annotation.schemaVersion -eq 1 -and
    $annotation.evidenceProvenance.sourceCommit -ceq '1baf4d6a5644652202d609a20511524afe13ed88' -and
    $annotation.evidenceProvenance.usbPcapUsed -eq $false -and
    $annotation.evidenceProvenance.independentNativeReportTraceRetained -eq $false -and
    $annotation.queryArtifact.sha256 -ceq '04D809ACFBD3C717B45A69492F46F20EA18718624335CE1EE120A88449C3C007' -and
    $annotation.queryArtifact.byteLength -eq 2012) 'Typed continuity provenance must not become native packet evidence.'
Assert-True ($annotation.device.productIdHex -ceq '0F43' -and
    $annotation.device.revisionHex -ceq '0200' -and $annotation.device.interfaceNumber -ceq '00' -and
    $annotation.device.featureReportPrefixHex -ceq '00' -and $annotation.device.biosIsProvenanceOnly -eq $true) `
    'Exact accessory boundary changed.'
$expected = @('00/84:0000', '00/04:0300', '00/84:0000', '0D/10:01012C', '00/84:0000', '0D/10:000600', '00/04:0000', '00/84:0000')
Assert-True (($annotation.performedLogicalSequenceAccordingToResultAndReviewedSource -join ',') -ceq ($expected -join ',')) `
    'Completed continuity stages must retain all eight reviewed logical exchanges.'
$boundary = $annotation.continuityBoundary
Assert-True ($boundary.kind -ceq 'normal-close-and-fresh-session-in-same-process' -and
    $boundary.afterLogicalExchange -eq 4 -and $boundary.beforeLogicalExchange -eq 5 -and
    $boundary.firstSessionClosed -eq $true -and $boundary.freshSessionOpened -eq $true -and
    $boundary.rawIntermediate -ceq '0300' -and $boundary.freshCandidateConfirmed -eq $true -and
    $boundary.newProcessTested -eq $false -and $boundary.processCrashTested -eq $false) `
    'Same-process session continuity must not become new-process or crash evidence.'
Assert-True ($annotation.result.rawBaseline -ceq '0000' -and
    $annotation.result.rawCandidate -ceq '0300' -and $annotation.result.rawRestored -ceq '0000' -and
    $annotation.result.exitCode -eq 0 -and $null -eq $annotation.result.failure -and
    $annotation.result.manualRecoveryRequired -eq $false) 'Successful raw restoration outcome changed.'
foreach ($flag in @('modeAcquireAttempted', 'modeAcquireAcknowledged', 'candidateConfirmed',
    'fixedAttempted', 'fixedAcknowledged', 'fixedPhysicalConfirmed', 'autoAttempted',
    'autoAcknowledged', 'autoPhysicalConfirmed', 'modeRestoreAttempted',
    'modeRestoreAcknowledged', 'rawRestorationConfirmed', 'finalPhysicalConfirmed')) {
    Assert-True ($annotation.result.$flag -eq $true) "Completed continuity flag changed: $flag"
}
Assert-True ($annotation.operatorOutcomes.Count -eq 3 -and
    $annotation.operatorOutcomes[0].userReply -ceq 'Medium; normal and green unchanged' -and
    $annotation.operatorOutcomes[1].userReply -ceq 'Quiet Auto; normal and green unchanged' -and
    $annotation.operatorOutcomes[2].userReply -ceq 'Normal and unchanged') 'Actual operator replies changed.'
foreach ($outcome in $annotation.operatorOutcomes) {
    Assert-True ($outcome.submittedToCommand -eq $true) 'All three physical confirmations were submitted to this trial.'
}
Assert-True ($annotation.preflight.synapseUseForbidden -eq $true -and
    $annotation.preflight.recoveryAcknowledgement -ceq 'ManualPowerCycleOnly' -and
    $annotation.preflight.prefilledPhysicalAnswers -eq $false) 'No-Synapse and attended confirmation boundary changed.'
foreach ($flag in @('lightingCommandsSubmitted', 'recoveryPerformedByCommand', 'automaticRecovery',
    'synapseActionsPerformed', 'serviceActionsPerformed', 'powerCyclePerformed', 'retryPerformed')) {
    Assert-True ($annotation.result.$flag -eq $false) "Unperformed action was acquired: $flag"
}
foreach ($property in $annotation.productionAdmission.PSObject.Properties) {
    if ($property.Name -ne 'reason') {
        Assert-True ($property.Value -eq $false) 'One continuity success must keep every production gate closed.'
    }
}
Assert-True (-not ((Get-Content -LiteralPath $path -Raw) -match '(?i)[A-Z]:\\|"(?:processId|deviceInstanceId|serialNumber)"')) `
    'Private paths and identifiers must not enter the annotation.'
Write-Host 'RZ09-0528 cooling-pad same-process session continuity evidence tests passed.'
