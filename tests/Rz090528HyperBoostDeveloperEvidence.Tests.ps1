$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$annotation = Get-Content -Raw (Join-Path $repository 'annotations/2026-09-27-rz09-0528-hyperboost-developer-validation.json') | ConvertFrom-Json
$decoded = Get-Content -Raw (Join-Path $repository 'decoded/rz09-0528-pid-02c6-bios-2.02-hyperboost-developer-validation.json') | ConvertFrom-Json
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
Assert-True ($annotation.device.sku -ceq 'RZ09-05289EN4' -and $annotation.device.productIdHex -ceq '02C6') 'Exact laptop scope changed.'
foreach ($evidence in @($annotation, $decoded)) {
    $v = $evidence.validation
    Assert-True ($v.Success -and $v.ApplyAcknowledged -and $v.CandidateConfirmed -and $v.RestoreAcknowledged -and $v.Restored) 'Developer round trip must remain confirmed.'
    Assert-True ($v.Baseline.Thermal1Hex -ceq '01010200' -and $v.Baseline.Thermal2Hex -ceq '01020200') 'Only Performance baseline is validated.'
    Assert-True ($v.Candidate.Thermal1Hex -ceq '01010700' -and $v.Candidate.Thermal2Hex -ceq '01020700') 'HyperBoost candidate changed.'
    Assert-True ($v.Restoration.Thermal1Hex -ceq '01010200' -and $v.Restoration.Thermal2Hex -ceq '01020200') 'Performance restoration changed.'
    Assert-True ($null -eq $v.CandidateFanRpm -and $v.CandidateFanRpmSamples.Count -eq 0) 'Fan RPM must not be inferred.'
    foreach ($property in $evidence.admission.PSObject.Properties) { Assert-True ($property.Value -eq $false) "Developer evidence must not advance $($property.Name)." }
    Assert-True (-not $evidence.commandScope.padFeatureWritesPerformed) 'No pad write was validated.'
}
Assert-True ($annotation.priorAttempts.Count -eq 2 -and -not $annotation.priorAttempts[1].applyAttempted) 'Rejected prior attempts must remain recorded.'
Assert-True ($annotation.wrapperOutcome.initialOriginalOverrideRestorationExitCode -eq 2 -and $annotation.wrapperOutcome.subsequentExplicitRecoveryExitCode -eq 0) 'Preserve initial restoration failure and subsequent recovery.'
Assert-True ($annotation.metadataDiscovery.before.discovery -ceq 'ObservationFailed' -and $annotation.metadataDiscovery.after.discovery -ceq 'PresentExact') 'Metadata correction evidence changed.'
Assert-True ($annotation.metadataDiscovery.readOnly -and -not $annotation.metadataDiscovery.featureReportsSent) 'Metadata inspection must remain read-only.'
$protocolCollections = @($annotation.metadataDiscovery.descriptors | Where-Object { $_.Interface -ceq 'mi_00' -and $_.VersionNumber -eq 512 -and $_.FeatureReportByteLength -eq 91 })
Assert-True ($protocolCollections.Count -eq 1) 'Exactly one pad protocol collection is evidenced.'
foreach ($value in @($annotation.provenance.validatorAssemblySha256, $annotation.provenance.protocolAssemblySha256, $annotation.provenance.buildManifestSha256)) { Assert-True ($value -cmatch '^[0-9A-F]{64}$') 'Build provenance hash malformed.' }
Write-Host 'RZ09-0528 developer HyperBoost evidence tests passed.'
