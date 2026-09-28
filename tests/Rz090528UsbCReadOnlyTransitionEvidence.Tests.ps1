param([string]$AnnotationPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'annotations/2026-09-28-rz09-0528-usb-c-readonly-transition.json'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$script:checks = 0
function Assert-True([bool]$Condition, [string]$Message) {
    $script:checks++
    if (-not $Condition) { throw $Message }
}
function Assert-Keys($Object, [string]$Names) {
    $expected = @($Names.Split(',') | Sort-Object)
    $actual = @($Object.PSObject.Properties.Name | Sort-Object)
    Assert-True (($actual -join ',') -ceq ($expected -join ',')) 'Evidence contains missing or unapproved fields.'
}
$raw = [IO.File]::ReadAllText($AnnotationPath)
Assert-True (-not $raw.Contains("`r")) 'Annotation bytes must remain LF.'
$a = $raw | ConvertFrom-Json
Assert-Keys $a 'schemaVersion,publicationStatus,evidenceProvenance,device,operatorConfirmation,isolation,observation,restoration,interpretation,sanitization'
Assert-True ($a.schemaVersion -eq 1) 'Schema must remain 1.'
Assert-True ($a.publicationStatus -ceq 'UserApprovedSanitizedEvidence') 'User-approved publication status must be retained.'
Assert-Keys $a.evidenceProvenance 'controller,role,sourceRevision,query'
Assert-True ($a.evidenceProvenance.role -ceq 'ReadOnlyObservation') 'This evidence is read-only; it cannot become a validation of writes.'
Assert-True ($a.evidenceProvenance.sourceRevision -ceq '888dca81dfe6ca756524e7e880e155b5e7fc2567') 'Source revision changed.'
Assert-True ($a.evidenceProvenance.query -clike 'query-rz09-0528-02c6-power-source*') 'Exact-device query provenance changed.'
Assert-Keys $a.device 'modelNumber,bios'
Assert-True ($a.device.modelNumber -ceq 'RZ09-0528' -and $a.device.bios -ceq '2.02') 'Exact approved model/BIOS scope changed.'
Assert-Keys $a.operatorConfirmation 'padUsbAndPowerDisconnected,originalAdapterConnectedAtEntry,usbCChargerNominalWatts,attendedSpokenPromptsConfirmed'
Assert-True ($a.operatorConfirmation.padUsbAndPowerDisconnected -eq $true -and $a.operatorConfirmation.originalAdapterConnectedAtEntry -eq $true -and $a.operatorConfirmation.attendedSpokenPromptsConfirmed -eq $true) 'Attended prerequisites changed.'
Assert-True ($a.operatorConfirmation.usbCChargerNominalWatts -eq 100) 'Charger scope changed.'
Assert-Keys $a.isolation 'openBladeServiceStopped,razerServicesStopped,synapseInactive,usbPcapInactive'
foreach ($property in $a.isolation.PSObject.Properties) { Assert-True ($property.Value -eq $true) "Controller isolation changed: $($property.Name)" }

$o = $a.observation
Assert-Keys $o 'firmwareWritesPerformed,gpuWritesPerformed,totalSamples,failedSamples,maximumQueryMilliseconds,sequence,phases'
Assert-True ($o.firmwareWritesPerformed -eq $false -and $o.gpuWritesPerformed -eq $false) 'Read-only evidence cannot claim writes.'
Assert-True ($o.totalSamples -eq 160 -and $o.failedSamples -eq 0) 'Sample totals changed.'
Assert-True ([Math]::Abs([double]$o.maximumQueryMilliseconds - 554.9) -lt 0.0001) 'Query duration fact changed.'
# Phase, sample count, then per-state power, first-seen seconds and count. Every state is Balanced on both channels with Windows AC online.
$expected = @(
    @('Baseline', 17, (,@('1111', 1.0, 17))),
    @('ConnectUsbC', 32, (,@('1111', 9.0, 32))),
    @('UnplugBarrel', 42, @(@('1111', 25.0, 9), @('0711', 29.0, 33))),
    @('ReconnectBarrel', 33, @(@('0711', 45.0, 14), @('1111', 52.0, 19))),
    @('UnplugUsbC', 32, (,@('1111', 60.0, 32)))
)
Assert-True (@($o.phases).Count -eq $expected.Count) 'Phase list changed.'
$phaseSamples = 0
for ($i = 0; $i -lt $expected.Count; $i++) {
    $p = @($o.phases)[$i]
    Assert-Keys $p 'Phase,SampleCount,States'
    Assert-True ($p.Phase -ceq $expected[$i][0] -and $p.SampleCount -eq $expected[$i][1]) "Phase fact changed: $($expected[$i][0])"
    $phaseSamples += $p.SampleCount
    $states = @($p.States); $want = $expected[$i][2]
    Assert-True ($states.Count -eq $want.Count) "State list changed: $($p.Phase)"
    $stateSamples = 0
    for ($j = 0; $j -lt $want.Count; $j++) {
        $s = $states[$j]
        Assert-Keys $s 'FirmwarePower,Thermal1Hex,Thermal2Hex,WindowsAcOnline,FirstSeenSeconds,SampleCount'
        Assert-True ($s.FirmwarePower -ceq $want[$j][0] -and [Math]::Abs([double]$s.FirstSeenSeconds - $want[$j][1]) -lt 0.0001 -and $s.SampleCount -eq $want[$j][2]) "State fact changed: $($p.Phase) $j"
        Assert-True ($s.Thermal1Hex -ceq '01010000' -and $s.Thermal2Hex -ceq '01020000') 'The observed pair must remain Balanced on both channels.'
        Assert-True ($s.WindowsAcOnline -eq $true) 'Windows AC must remain online in every recorded state.'
        Assert-True ($s.FirmwarePower -cin @('1111','0711')) 'No battery or unknown power state was observed.'
        $stateSamples += $s.SampleCount
    }
    Assert-True ($stateSamples -eq $p.SampleCount) 'Per-state counts must add up to the phase count.'
}
Assert-True ($phaseSamples -eq 156) 'Four samples belong to the initial and final full-AC proofs.'

Assert-Keys $a.restoration 'finalFullAcProofPassed,finalThermalPairMatchedInitial,servicesReturnedToPriorState,temporaryFanOverrideClearedByServiceRestart,temporaryFanOverrideRestoredByFanOnlyIpc,originalIntentMatchedAfterRestore'
foreach ($property in $a.restoration.PSObject.Properties) { Assert-True ($property.Value -eq $true) "Restoration fact changed: $($property.Name)" }
$i = $a.interpretation
Assert-Keys $i 'usbCOnlyFirmwarePower,barrelWithUsbCFirmwarePower,batteryStateObservedDuringSwaps,windowsAcOnlineThroughout,thermalPairUnchangedWithoutControllers,hyperBoostOnUsbCTested,chargerClassGeneralized,productionPadlessAdmitted,timingBasis,limits'
Assert-True ($i.usbCOnlyFirmwarePower -ceq '0711' -and $i.barrelWithUsbCFirmwarePower -ceq '1111') 'Power-value interpretation changed.'
Assert-True ($i.batteryStateObservedDuringSwaps -eq $false -and $i.windowsAcOnlineThroughout -eq $true -and $i.thermalPairUnchangedWithoutControllers -eq $true) 'Observed transition facts changed.'
foreach ($name in @('hyperBoostOnUsbCTested','chargerClassGeneralized','productionPadlessAdmitted')) { Assert-True ($i.$name -eq $false) "Unsupported inference: $name" }
Assert-True ($i.timingBasis -clike '*does not pinpoint physical plug events*') 'Timing caveat changed.'
Assert-True ($i.limits -clike 'Single attended read-only gapless swap*no HyperBoost*') 'Evidence limits changed.'
Assert-Keys $a.sanitization 'rawOutputsExcluded,localPathsExcluded,deviceInstancePathsExcluded,serialNumbersExcluded,processIdentityExcluded,profileContentsExcluded,chargerIdentityExcluded'
foreach ($property in $a.sanitization.PSObject.Properties) { Assert-True ($property.Value -eq $true) 'Private data exclusion changed.' }
Assert-True ($raw -notmatch '(?i)[A-Z]:\\|\\\\|USB\\|HID\\|S-1-5-|"(?:ProcessId|StartedAtUtc|StartedUtc|ExecutableName|Profile|Profiles|Sku|GpuName|SerialNumber|Hwinfo|FanControlOverride)"') 'Private or unapproved identity data detected.'
Write-Output "USB-C read-only transition evidence passed $script:checks assertions. No hardware operations performed."
