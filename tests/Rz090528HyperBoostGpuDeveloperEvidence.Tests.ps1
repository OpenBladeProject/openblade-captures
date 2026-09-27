$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$annotation = Get-Content -Raw (Join-Path $repository 'annotations/2026-09-27-rz09-0528-hyperboost-gpu-developer-validation.json') | ConvertFrom-Json
$decoded = Get-Content -Raw (Join-Path $repository 'decoded/rz09-0528-pid-02c6-bios-2.02-hyperboost-gpu-developer-validation.json') | ConvertFrom-Json
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$phases = @('Scenario1/Baseline', 'Scenario1/Candidate', 'Scenario1/Candidate/ApplyFive', 'Scenario1/Candidate/RestoreZero', 'Scenario1/Restored', 'Scenario2/Baseline', 'Scenario2/Baseline/ApplyFive', 'Scenario2/Candidate', 'Scenario2/Restored', 'Scenario2/Restored/RestoreZero')
$offsets = @(0, 0, 5, 0, 0, 0, 5, 5, 5, 0)
foreach ($evidence in @($annotation, $decoded)) {
    Assert-True ($evidence.device.sku -ceq 'RZ09-05289EN4' -and $evidence.device.productIdHex -ceq '02C6' -and $evidence.device.bios -ceq '2.02') 'Exact laptop scope changed.'
    Assert-True ($evidence.gpu.model -ceq 'NVIDIA GeForce RTX 5090 Laptop GPU' -and $evidence.gpu.driverVersion -ceq '617.14') 'Exact GPU/driver scope changed.'
    Assert-True ($evidence.provenance.sourceRevision -ceq 'f5d2c63e6bdd9e869332b21eb5585eda48ca6cb4') 'Reviewed validator revision changed.'
    Assert-True ($evidence.provenance.buildManifestSha256 -ceq '8745BE7D2B963F04422652A3F1A104131E00E8944789791496EC5EE4F97194B7') 'Immutable payload binding changed.'
    Assert-True ($evidence.scenarios.Count -eq 2 -and $evidence.gpuObservations.Count -eq 10 -and $evidence.thermalResults.Count -eq 2) 'Both complete bounded scenarios are required.'
    for ($index = 0; $index -lt $phases.Count; $index++) {
        $observation = $evidence.gpuObservations[$index]
        Assert-True ($observation.phase -ceq $phases[$index]) 'Scenario phase ordering changed.'
        foreach ($api in @($observation.nvml, $observation.nvapi)) {
            Assert-True ($api.coreMegahertz -eq $offsets[$index] -and $api.memoryMegahertz -eq $offsets[$index]) 'Independent readback must confirm only the exact 0/+5 steps.'
        }
    }
    foreach ($thermal in $evidence.thermalResults) {
        Assert-True ($thermal.Baseline.Thermal1Hex -ceq '01010200' -and $thermal.Baseline.Thermal2Hex -ceq '01020200') 'Performance baseline changed.'
        Assert-True ($thermal.Candidate.Thermal1Hex -ceq '01010700' -and $thermal.Candidate.Thermal2Hex -ceq '01020700') 'HyperBoost candidate changed.'
        Assert-True ($thermal.Restoration.Thermal1Hex -ceq '01010200' -and $thermal.Restoration.Thermal2Hex -ceq '01020200') 'Performance restoration changed.'
        Assert-True ($thermal.Success -and $thermal.ApplyAcknowledged -and $thermal.CandidateConfirmed -and $thermal.RestoreAcknowledged -and $thermal.Restored -and -not $thermal.ManualRecoveryRequired) 'Both thermal round trips must be confirmed.'
        Assert-True ($null -eq $thermal.CandidateFanRpm -and $thermal.CandidateFanRpmSamples.Count -eq 0) 'Fan RPM must not be inferred.'
    }
    foreach ($property in $evidence.admission.PSObject.Properties) { Assert-True ($property.Value -eq $false) "Developer checkpoint cannot advance $($property.Name)." }
    $json = $evidence | ConvertTo-Json -Depth 20
    Assert-True ($json -notmatch '[A-Za-z]:\\' -and $json -notmatch 'hid#|usb#|ProcessId') 'Private paths or raw process/device identifiers must be excluded.'
}
Assert-True ($annotation.wrapperOutcome.initialOriginalOverrideRestorationExitCode -eq 2 -and $annotation.wrapperOutcome.subsequentExplicitGuardedRecoveryExitCode -eq 0 -and $annotation.wrapperOutcome.originalOverrideRestoreExitCode -eq 0 -and -not $annotation.wrapperOutcome.restorationPending) 'Initial strict refusal and subsequent successful recovery must remain visible.'
Assert-True ($annotation.wrapperOutcome.independentPostThermal.performance -ceq 'Performance' -and $annotation.wrapperOutcome.independentPostThermal.fans -ceq 'Automatic') 'Independent final thermal query must confirm Performance/Automatic.'
foreach ($property in @('nvmlCoreMegahertz', 'nvmlMemoryMegahertz', 'nvapiCoreMegahertz', 'nvapiMemoryMegahertz')) { Assert-True ($annotation.wrapperOutcome.independentPostGpu.$property -eq 0) 'Independent final GPU query must confirm zero offsets.' }
Assert-True ($annotation.wrapperOutcome.allPreviouslyRunningServicesRestored -and $annotation.wrapperOutcome.profileContentsExcluded) 'Restoration must remain documented without profile contents.'
Write-Host 'RZ09-0528 combined HyperBoost/GPU developer evidence tests passed.'
