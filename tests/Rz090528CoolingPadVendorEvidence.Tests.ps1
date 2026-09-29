[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$annotationPath = Join-Path $repository 'annotations\2026-09-29-rz09-0528-cooling-pad-vendor-auto-round-trip.json'
& (Join-Path $repository 'tools\Test-CaptureEvidence.ps1') -AnnotationPath $annotationPath -SchemaOnly | Out-Null
$annotation = Get-Content -LiteralPath $annotationPath -Raw | ConvertFrom-Json

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Evidence {
    param([string]$Kind)
    $items = @($annotation.sanitizedEvidence | Where-Object kind -ceq $Kind)
    Assert-True ($items.Count -eq 1) "Expected one $Kind evidence item."
    return $items[0]
}

Assert-True ($annotation.evidenceProvenance.role -ceq 'OracleCapture' -and
    $annotation.evidenceProvenance.openBladeTypedApplyPerformed -eq $false -and
    $annotation.evidenceProvenance.openBladeReadbackConfirmed -eq $false) `
    'Vendor observation must not become OpenBlade typed validation.'
Assert-True ($annotation.device.modelNumber -ceq 'RZ09-0528' -and
    $annotation.device.productIdHex -ceq '0F43' -and $annotation.device.bios -ceq '2.02' -and
    $annotation.capture.sha256 -ceq '05237B8380FA1D1D81FBD2305CFB1A8BFE15E5237BD03851624DCE6A7158BDF6' -and
    $annotation.capture.byteLength -eq 5783 -and $annotation.capture.stopMode -ceq 'Graceful') `
    'Exact-model capture identity or provenance changed.'
$identity = Get-Evidence 'ExactHostAndPadInventory'
Assert-True ($identity.revisionHex -ceq '0200' -and $identity.featureReportBytes -eq 91 -and
    $identity.rawUsbReportBodyBytes -eq 90 -and $identity.rawUsbFeatureReportSelectorHex -ceq '0300' -and
    $identity.rawUsbReportId -eq 0 -and $identity.userModeFeatureReportIdValidated -eq $false) `
    'USB-wire framing must remain distinct from unvalidated user-mode framing.'
$auto = Get-Evidence 'VendorAutoPair'
$restore = Get-Evidence 'VendorFixedMediumRestorationPair'
foreach ($pair in @($auto, $restore)) {
    Assert-True ($pair.commandClassHex -ceq '0D' -and $pair.commandIdHex -ceq '10' -and
        $pair.requestCount -eq 1 -and $pair.acknowledgementCount -eq 1 -and
        $pair.responseStatusHex -ceq '02' -and $pair.transactionMatched -eq $true -and
        $pair.semanticEchoMatched -eq $true -and $pair.checksumsValid -eq $true) `
        'A vendor fan pair lost its bounded correlation evidence.'
}
Assert-True ($auto.semanticPayloadHex -ceq '000600' -and $auto.transactionHex -ceq '1B' -and
    $restore.semanticPayloadHex -ceq '01012C' -and $restore.transactionHex -ceq '1C') `
    'Medium restoration must not be replaced by the historical High command.'
$interval = Get-Evidence 'BoundedAutoInterval'
Assert-True ($interval.intervalSeconds -eq 44.86975 -and $interval.hostDemandWriteCount -eq 0 -and
    $interval.fanQueryCount -eq 0 -and $interval.autonomousPadOwnershipConfirmed -eq $false -and
    $interval.vendorControllerRelinquishmentObserved -eq $false) `
    'Absence of demand updates must not establish autonomous operation or ownership.'
$lighting = Get-Evidence 'StaticGreenLightingContext'
Assert-True ($lighting.frameRequestCount -eq 25 -and $lighting.uniformRgbHex -ceq '00FF00' -and
    $lighting.firmwareNativeEffectConfirmed -eq $false -and $lighting.brightnessQueryCount -eq 0) `
    'Static presentation must not be promoted to native effect or brightness readback.'
Assert-True ($annotation.productionAdmission.coolingPadFanWriteAdmitted -eq $false -and
    $annotation.productionAdmission.coolingPadLightingWriteAdmitted -eq $false -and
    $annotation.productionAdmission.openBladeHandbackValidated -eq $false -and
    $annotation.productionAdmission.activeModeReadbackConfirmed -eq $false -and
    $annotation.productionAdmission.tachometerReadbackConfirmed -eq $false) `
    'Vendor evidence must keep OpenBlade mutation gates closed.'
$annotationPath = Join-Path $repository 'annotations\2026-09-29-rz09-0528-cooling-pad-vendor-exit-reopen.json'
& (Join-Path $repository 'tools\Test-CaptureEvidence.ps1') -AnnotationPath $annotationPath -SchemaOnly | Out-Null
$annotation = Get-Content -LiteralPath $annotationPath -Raw | ConvertFrom-Json
Assert-True ($annotation.capture.sha256 -ceq 'F6E97C42AF1398EFE91514F5629A7DAB82EC68D0A61C3BAC6D0118C0062967E7' -and
    $annotation.capture.byteLength -eq 32567 -and $annotation.capture.stopMode -ceq 'Graceful' -and
    $annotation.evidenceProvenance.openBladeTypedApplyPerformed -eq $false) `
    'Exit/reopen evidence must retain exact provenance and vendor-only scope.'
$exit = Get-Evidence 'VendorExitCandidatePair'
$reopen = Get-Evidence 'VendorReopenCandidatePair'
Assert-True ($exit.semanticPayloadHex -ceq '0000' -and $exit.transactionHex -ceq '0C' -and
    $exit.requestFrame -eq 29 -and $exit.responseFrame -eq 32 -and
    $exit.independentOwnershipReadbackConfirmed -eq $false -and
    $reopen.semanticPayloadHex -ceq '0300' -and $reopen.rawModeQueryPairCount -eq 2 -and
    $reopen.rawModeQueryResponsePayloadHex -ceq '0300') `
    'Mode-family candidates must preserve packet correlation without assigning ownership.'
$closed = Get-Evidence 'ClosedApplicationInterval'
Assert-True ($closed.zeroAppEngineSnapshotCount -eq 3 -and
    $closed.remainingRunningVendorServiceNames.Count -eq 3 -and
    $closed.completeReportSilenceSeconds -eq 133.521335 -and
    $closed.allVendorControllersAbsent -eq $false -and $closed.autonomousPadOperationConfirmed -eq $false) `
    'Sampled application exit must not establish absent controllers or autonomous firmware.'
$transport = Get-Evidence 'TransportAndCaptureCleanup'
Assert-True ($transport.completeRazerBodyCount -eq 173 -and
    $transport.allCompleteBodyChecksumsValid -eq $true -and
    $transport.userModeFeatureReportIdValidated -eq $false -and
    $transport.openBladeServiceRestarted -eq $true -and $transport.captureErrorCount -eq 0) `
    'Transport evidence must preserve framing and cleanup boundaries.'
Assert-True ($annotation.productionAdmission.coolingPadFanWriteAdmitted -eq $false -and
    $annotation.productionAdmission.coolingPadLightingWriteAdmitted -eq $false -and
    $annotation.productionAdmission.openBladeHandbackValidated -eq $false -and
    $annotation.productionAdmission.independentPadOwnershipConfirmed -eq $false) `
    'Exit/reopen evidence must keep mutation and ownership gates closed.'
$annotationPath = Join-Path $repository 'annotations\2026-09-29-rz09-0528-cooling-pad-vendor-fixed-exit-reopen.json'
& (Join-Path $repository 'tools\Test-CaptureEvidence.ps1') -AnnotationPath $annotationPath -SchemaOnly | Out-Null
$annotation = Get-Content -LiteralPath $annotationPath -Raw | ConvertFrom-Json
$fixed = Get-Evidence 'VendorFixedPairsAndAutoRestoration'
Assert-True ($annotation.capture.byteLength -eq 40565 -and
    $annotation.capture.sha256 -ceq '0A025B0B247D4397770C278C79A19AED26E0ECC838FD7F9F4327106B523B9932' -and
    $fixed.mediumPairCount -eq 8 -and $fixed.postReopenMediumPairCount -eq 7 -and
    $fixed.mediumPayloadHex -ceq '01012C' -and $fixed.autoPayloadHex -ceq '000600' -and
    $fixed.independentFanStateReadbackConfirmed -eq $false) `
    'Fixed lifecycle evidence must retain vendor repetitions and unavailable independent readback.'
$closed = Get-Evidence 'ClosedApplicationAndLightingInterval'
$transport = Get-Evidence 'TransportAndCleanup'
Assert-True ($closed.zeroAppEngineSnapshotCount -eq 2 -and
    $closed.completeReportSilenceSeconds -eq 49.650182 -and
    $closed.autonomousPadOperationConfirmed -eq $false -and
    $transport.completeRazerBodyCount -eq 216 -and $transport.captureErrorCount -eq 0 -and
    $annotation.productionAdmission.coolingPadFanWriteAdmitted -eq $false -and
    $annotation.productionAdmission.coolingPadLightingWriteAdmitted -eq $false -and
    $annotation.productionAdmission.openBladeHandbackValidated -eq $false -and
    $annotation.productionAdmission.userModeFeatureReportIdValidated -eq $false) `
    'Fixed lifecycle success must not admit framing, independent ownership or pad writes.'
$annotationPath = Join-Path $repository 'annotations\2026-09-29-rz09-0528-cooling-pad-report-descriptor.json'
& (Join-Path $repository 'tools\Test-CaptureEvidence.ps1') -AnnotationPath $annotationPath -SchemaOnly | Out-Null
$annotation = Get-Content -LiteralPath $annotationPath -Raw | ConvertFrom-Json
$descriptor = Get-Evidence 'ActualHidReportDescriptor'
$bytes = [byte[]]@(for ($offset = 0; $offset -lt $descriptor.responseHex.Length; $offset += 2) {
    [Convert]::ToByte($descriptor.responseHex.Substring($offset, 2), 16)
})
$hash = [Security.Cryptography.SHA256]::Create()
try { $computed = [BitConverter]::ToString($hash.ComputeHash($bytes)).Replace('-', '') }
finally { $hash.Dispose() }
Assert-True ($computed -ceq $descriptor.descriptorSha256 -and $bytes.Length -eq 22 -and
    $descriptor.requestFrame -eq 247 -and $descriptor.responseFrame -eq 248 -and
    $descriptor.usbStatusSuccess -eq $true -and $descriptor.injectedDescriptor -eq $false) `
    'Actual report-descriptor provenance must not become an injected length advertisement.'
$size = 0; $count = 0; $featureBits = 0; $reportIds = 0
for ($offset = 0; $offset -lt $bytes.Length;) {
    $header = $bytes[$offset++]; $length = $header -band 3
    if ($length -eq 3) { $length = 4 }
    Assert-True ($header -ne 0xFE -and $offset + $length -le $bytes.Length) 'Descriptor item is incomplete.'
    $type = ($header -shr 2) -band 3; $tag = $header -shr 4; $value = 0
    for ($index = 0; $index -lt $length; $index++) { $value = $value -bor ($bytes[$offset + $index] -shl (8 * $index)) }
    if ($type -eq 1 -and $tag -eq 7) { $size = $value }
    if ($type -eq 1 -and $tag -eq 9) { $count = $value }
    if ($type -eq 1 -and $tag -eq 8) { $reportIds++ }
    Assert-True (-not ($type -eq 1 -and $tag -in 10, 11)) 'This fixture needs explicit Push/Pop handling.'
    if ($type -eq 0 -and $tag -eq 11) {
        Assert-True ($value -eq 1) 'The captured Feature item must remain constant.'
        $featureBits += $size * $count
    }
    $offset += $length
}
Assert-True ($featureBits -eq 720 -and $reportIds -eq 0 -and
    $annotation.productionAdmission.userModeFramingChoiceEstablished -eq $true -and
    $annotation.productionAdmission.actualWindowsFeatureIoValidated -eq $false -and
    $annotation.productionAdmission.coolingPadFanWriteAdmitted -eq $false) `
    'Descriptor-defined framing must remain separate from live I/O and mutation admission.'
$queryAnnotation = Get-Content (Join-Path $repository 'annotations\2026-09-29-rz09-0528-cooling-pad-control-state-query.json') -Raw | ConvertFrom-Json
Assert-True ($queryAnnotation.schemaVersion -eq 1 -and
    $queryAnnotation.evidenceProvenance.role -ceq 'ReadOnlyQueryCapture' -and
    $queryAnnotation.evidenceProvenance.openBladeTypedApplyPerformed -eq $false -and
    $queryAnnotation.queryArtifact.kind -ceq 'TypedQueryResultJson' -and
    $queryAnnotation.queryArtifact.byteLength -eq 757 -and
    $queryAnnotation.queryArtifact.sha256 -ceq '47627BAA16CF3C0346839AAA9330AD3340943BF2AA70900841E066D61B1CD704' -and
    $queryAnnotation.queryArtifact.usbPcapUsed -eq $false) `
    'Typed query provenance must remain distinct from an invented PCAP.'
$query = @($queryAnnotation.sanitizedEvidence | Where-Object kind -ceq 'SingleTypedRawControlStateQuery')[0]
$outcome = @($queryAnnotation.sanitizedEvidence | Where-Object kind -ceq 'UserAuthorizedControllerStopAndOutcome')[0]
Assert-True ($query.commandIdHex -ceq '84' -and $query.responsePayloadHex -ceq '0000' -and
    $query.requestCount -eq 1 -and $query.retryCount -eq 0 -and $query.modeSetterCount -eq 0 -and
    $query.actualWindowsFeatureIoValidated -eq $true -and
    $queryAnnotation.productionAdmission.coolingPadFanWriteAdmitted -eq $false -and
    $queryAnnotation.productionAdmission.openBladeHandbackValidated -eq $false -and
    $outcome.vendorRestartDeclinedByUser -eq $true -and $outcome.vendorServicesRestarted -eq $false) `
    'Query success must preserve mutation gates and the explicit no-restart preference.'
Write-Host 'RZ09-0528 cooling-pad vendor evidence tests passed.'
