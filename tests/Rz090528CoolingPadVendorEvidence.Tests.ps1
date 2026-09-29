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
Write-Host 'RZ09-0528 cooling-pad vendor evidence tests passed.'
