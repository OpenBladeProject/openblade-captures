[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$path = Join-Path $repository 'annotations\2026-09-29-rz09-0528-cooling-pad-raw-control-recovery.json'
$annotation = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
Assert-True ($annotation.schemaVersion -eq 1 -and
    $annotation.evidenceProvenance.usbPcapUsed -eq $false -and
    $annotation.evidenceProvenance.independentNativeReportTraceRetained -eq $false -and
    $annotation.queryArtifact.sha256 -ceq 'A6AC33D1A6C6842D5C90208575E9EFD186D524F09101887CAB737813D533AC7B' -and
    $annotation.queryArtifact.byteLength -eq 958) 'Private typed result provenance changed or became PCAP evidence.'
Assert-True ($annotation.device.productIdHex -ceq '0F43' -and
    $annotation.device.revisionHex -ceq '0200' -and
    $annotation.device.featureReportPrefixHex -ceq '00' -and
    $annotation.device.biosIsProvenanceOnly -eq $true) 'Exact accessory boundary changed.'
$sequence = $annotation.performedLogicalSequenceAccordingToResultAndReviewedSource
Assert-True ($sequence.Count -eq 3 -and $sequence[0].command -ceq '00/84' -and
    $sequence[0].responsePayloadHex -ceq '0300' -and
    $sequence[1].command -ceq '00/04' -and $sequence[1].requestPayloadHex -ceq '0000' -and
    $sequence[1].responsePayloadHex -ceq '0000' -and
    $sequence[2].command -ceq '00/84' -and $sequence[2].responsePayloadHex -ceq '0000' -and
    $annotation.result.rawControlSetterCountAccordingToReviewedSource -eq 1) `
    'Recovery must remain one bounded raw-control setter with before/after reads.'
Assert-True ($annotation.result.rawBaseline -ceq '0300' -and
    $annotation.result.rawRestored -ceq '0000' -and
    $annotation.result.restoreAcknowledged -eq $true -and
    $annotation.result.rawRestorationConfirmed -eq $true -and
    $annotation.result.physicalConfirmed -eq $true -and
    $annotation.result.exitCode -eq 0 -and
    $annotation.result.manualRecoveryRequired -eq $false -and
    $null -eq $annotation.result.failure) 'Successful raw recovery outcome changed.'
Assert-True ($annotation.preflight.synapseUseForbidden -eq $true -and
    $annotation.preflight.prefilledPhysicalAnswers -eq $false -and
    $annotation.operatorOutcome.physicalReply -ceq 'Normal and unchanged' -and
    $annotation.operatorOutcome.submittedToCommand -eq $true -and
    $annotation.result.fanCommandsSubmitted -eq $false -and
    $annotation.result.lightingCommandsSubmitted -eq $false -and
    $annotation.result.vendorRecoveryPerformed -eq $false -and
    $annotation.result.serviceActionsPerformed -eq $false) 'Recovery must not acquire fan, lighting or vendor actions.'
foreach ($property in $annotation.productionAdmission.PSObject.Properties) {
    if ($property.Name -ne 'reason') {
        Assert-True ($property.Value -eq $false) 'Raw recovery must keep every production gate closed.'
    }
}
Assert-True (-not ((Get-Content -LiteralPath $path -Raw) -match '(?i)[A-Z]:\\|"(?:processId|deviceInstanceId|serialNumber)"')) `
    'Private paths and identifiers must not enter the annotation.'
Write-Host 'RZ09-0528 cooling-pad raw-control recovery evidence tests passed.'
