$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$names = @('installed-hyperboost-validation', 'installed-hyperboost-pad-disconnect', 'padless-hyperboost-immediate')
$count = 0
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message }; $script:count++ }
foreach ($name in $names) {
 $raw = Get-Content -Raw (Join-Path $repository ('annotations/2026-09-27-rz09-0528-' + $name + '.json'))
 $e = $raw | ConvertFrom-Json
 Assert-True ($e.publicationStatus -ceq 'UserApprovedSanitizedEvidence') 'Approved publication boundary changed.'
 Assert-True ($e.device.sku -ceq 'RZ09-05289EN4' -and $e.device.productIdHex -ceq '02C6' -and $e.device.bios -ceq '2.02' -and $e.device.ec -ceq '1.09' -and $e.device.mcu -ceq '1.9.0.0') 'Exact device/firmware scope changed.'
 Assert-True ($e.gpu.model -ceq 'NVIDIA GeForce RTX 5090 Laptop GPU' -and $e.gpu.driverVersion -ceq '617.14' -and $e.gpu.coreMegahertz -eq 0 -and $e.gpu.memoryMegahertz -eq 0) 'GPU baseline scope changed.'
 foreach ($property in $e.admission.PSObject.Properties) { Assert-True ($property.Value -eq $false) 'Evidence must not expand admission.' }
 Assert-True ($e.sanitization.deviceInstancePathsExcluded -and $e.sanitization.serialNumbersExcluded) 'Private instance paths and serial numbers must be excluded.'
 Assert-True ($raw -notmatch '[A-Za-z]:\\|hid#|usb#|ProcessId|SystemSerial|UserName|TemperatureCelsius|ManualCurve') 'Private paths, device IDs, or profile contents leaked.'
 if ($name -eq 'padless-hyperboost-immediate') {
  Assert-True (-not $e.provenance.installedProductValidation -and $e.provenance.sourceRevision -ceq 'ffd0a01e19c3c89d92b00eb5c28d13b52174be88') 'Padless is a separate developer experiment.'
  Assert-True ($e.provenance.planSha256 -ceq '53436C5DE5B19301FFDDA9EB3670DA62F6440B9CA5168A81878FE58386DB8CD1') 'Reviewed immediate plan changed.'
  Assert-True ($e.prerequisites.firstRobustAbsenceConfirmed -and $e.prerequisites.secondRobustAbsenceConfirmed -and $e.prerequisites.minimumAbsenceIntervalMilliseconds -eq 500 -and $e.prerequisites.actualAbsenceIntervalMilliseconds -ge 500) 'Robust absence evidence missing.'
  $r=$e.typedResult
  Assert-True ($r.Baseline.Thermal1Hex -ceq '01010200' -and $r.Baseline.Thermal2Hex -ceq '01020200' -and $r.Candidate.Thermal1Hex -ceq '01010700' -and $r.Candidate.Thermal2Hex -ceq '01020700' -and $r.Restoration.Thermal1Hex -ceq '01010200' -and $r.Restoration.Thermal2Hex -ceq '01020200') 'Exact immediate paired transition changed.'
  Assert-True ($r.Success -and $r.ApplyAcknowledged -and $r.RestoreAcknowledged -and $r.Restored -and -not $r.IndeterminatePartialWrite -and -not $r.ManualRecoveryRequired) 'Hardware round trip must be unambiguous.'
  foreach($sample in @($e.telemetry.before,$e.telemetry.second,$e.telemetry.after)){Assert-True ($sample.CpuCelsius -eq 45 -and $null -eq $sample.GpuCelsius -and $sample.GpuInactive) 'Do not infer temperatures for inactive GPU.'}
  Assert-True ($e.noDwellOrLoadPerformed -and -not $e.gpuWritesPerformed -and -not $e.coolingPadFeatureWritesPerformed -and -not $e.telemetry.thermalSafetyEstablished) 'Immediate scope widened.'
  Assert-True ($e.restoration.originalProfilesAndOverridesRestored -and $e.restoration.allPriorServiceStatesRestored -and -not $e.restoration.restorationPending) 'Final original state must be confirmed.'
 } else {
  Assert-True ($e.provenance.installedProductValidation -and $e.provenance.sourceRevision -ceq '6e10043f9a53192b9c6952c2b56f2e6f1ba68871' -and $e.provenance.serviceExecutableSha256 -ceq 'D42A6A49C1B22C4BBB5A48713D3ED60B7650EDE6F1F38989D8A2203BA0EA23AA') 'Installed provenance changed.'
  $r=$e.typedResults
  Assert-True ($r.hyperBoostActiveConfirmed -and $r.journalState -ceq 'OwnedConfirmed' -and $r.journalTransitionMatchesEnableRequest -and $r.journalRequiresCoolingPad) 'Owned enable evidence missing.'
  Assert-True ($r.final -ceq 'Balanced/Automatic' -and -not $r.finalHyperBoostActive -and $r.finalJournalAbsent -and $r.finalUnconfirmedWriteCount -eq 0 -and -not $r.restorationPending -and $r.originalProfilesAndOverridesRestored -and $r.allPriorServiceStatesRestored) 'Installed original baseline not restored.'
  if($name -eq 'installed-hyperboost-pad-disconnect'){Assert-True ($r.serviceOwnedExit -and $r.helperDisableCalls -eq 0 -and $r.finalPadState -ceq 'Absent') 'Pad-loss evidence must reflect autonomous exit, not helper disable.'}
  else{Assert-True ($r.explicitDisableAcknowledged -and $r.finalPadState -ceq 'PresentExact') 'Connected-pad explicit disable boundary changed.'}
 }
}
$raw=Get-Content -Raw (Join-Path $repository 'annotations/2026-09-27-rz09-0528-padless-hyperboost-no-load.json')
$e=$raw|ConvertFrom-Json
Assert-True ($e.publicationStatus -ceq 'UserApprovedSanitizedEvidence' -and -not $e.provenance.installedProductValidation) 'No-load report is developer evidence only.'
Assert-True ($e.device.sku -ceq 'RZ09-05289EN4' -and $e.device.bios -ceq '2.02' -and $e.gpu.driverVersion -ceq '617.14') 'Exact no-load device changed.'
Assert-True ($e.provenance.sourceRevision -ceq '9715098e94688e6d57b26a959ab3ca85738794b6' -and $e.provenance.buildManifestSha256 -ceq 'AF988774897A978EA6E6011424434F7831F9A29E606D6C7AFB29C1D3520496CB' -and $e.provenance.planSha256 -ceq '3B7BD9F935A1E095FE41222E0581A59AC85C17F9BC33C9B2D5D2281056C79578') 'No-load immutable provenance changed.'
$o=$e.noLoadObservation
Assert-True ($o.Completed -and $null -eq $o.Failure -and $o.Baseline.Count -eq 3 -and $o.Samples.Count -eq 30 -and $o.ElapsedMilliseconds -eq 60012.0734) 'Observed duration/sample count changed.'
Assert-True ($o.CpuAbortCelsius -eq 55 -and $null -eq $o.GpuAbortCelsius -and $e.experimentalCpuTripwireIsNotThermalLimit -and -not $e.thermalSafetyEstablished) 'Experimental tripwire must not become thermal limit.'
foreach($sample in @($o.Baseline)+@($o.Samples)){
 Assert-True ($sample.CpuCelsius -eq 45 -and $null -eq $sample.GpuCelsius -and $sample.GpuInactive -and $sample.ObservedAtUtc -match '\+00:00$') 'Retain measured CPU and explicitly inactive GPU with UTC timestamps.'
}
Assert-True ($o.Baseline[0].Fans.Selector1Rpm -eq 500 -and $o.Samples[0].Fans.Selector1Rpm -eq 0 -and $o.Samples[0].Fans.Selector2Rpm -eq 0 -and $o.Samples[29].Fans.Selector1Rpm -eq 2900 -and $o.Samples[29].Fans.Selector2Rpm -eq 2700) 'Do not discard valid zero RPM or imply fans stayed stopped.'
$r=$e.typedResult
Assert-True ($r.Success -and $r.Restored -and -not $r.ManualRecoveryRequired -and $r.Candidate.Thermal1Hex -ceq '01010700' -and $r.Candidate.Thermal2Hex -ceq '01020700' -and $r.Restoration.Thermal1Hex -ceq '01010200' -and $r.Restoration.Thermal2Hex -ceq '01020200') 'Paired restoration must remain confirmed.'
Assert-True ($e.restoration.originalProfilesAndOverridesRestored -and $e.restoration.allPriorServiceStatesRestored -and $e.restoration.independentNvmlAndNvapiGpuZero -and -not $e.restoration.restorationPending -and $e.postInstalledBaseline.passed -eq 38 -and $e.postInstalledBaseline.warnings -eq 1 -and $e.postInstalledBaseline.failed -eq 0) 'Restoration and post-installed baseline changed.'
foreach($property in $e.admission.PSObject.Properties){Assert-True ($property.Value -eq $false) 'No-load evidence cannot change admission.'}
Assert-True ($e.noLoadPerformed -and -not $e.gpuWritesPerformed -and -not $e.coolingPadFeatureWritesPerformed -and $raw -notmatch '[A-Za-z]:\\|hid#|usb#|ProcessId|SystemSerial|UserName|TemperatureCelsius|ManualCurve') 'No-load scope or sanitization changed.'
Write-Host "RZ09-0528 installed and padless lifecycle evidence passed: $count assertions."