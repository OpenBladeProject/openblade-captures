[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$path = Join-Path $repository 'annotations\2026-09-29-rz09-0528-cooling-pad-passive-usb-reconnect.json'
$annotation = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
Assert-True ($annotation.schemaVersion -eq 1 -and
    $annotation.evidenceProvenance.usbPcapUsed -eq $false -and
    $annotation.evidenceProvenance.independentNativeReportTraceRetained -eq $false -and
    $annotation.device.productIdHex -ceq '0F43' -and $annotation.device.revisionHex -ceq '0200' -and
    $annotation.device.featureReportPrefixHex -ceq '00' -and $annotation.device.biosIsProvenanceOnly -eq $true) `
    'Exact typed-evidence accessory boundary changed.'
foreach ($query in @($annotation.baselineQuery, $annotation.postReconnectQuery)) {
    Assert-True ($query.queryArtifact.sha256 -ceq '47627BAA16CF3C0346839AAA9330AD3340943BF2AA70900841E066D61B1CD704' -and
        $query.queryArtifact.byteLength -eq 757 -and $query.requestCommand -ceq '00/84' -and
        $query.requestPayloadHex -ceq '0000' -and $query.responsePayloadHex -ceq '0000' -and
        $query.readOnlySemanticIntent -eq $true -and $query.transportSuccess -eq $true -and $query.exitCode -eq 0) `
        'Both private query results must retain raw0000 and their original provenance.'
}
Assert-True ($annotation.freshEnumeration.performedBeforePostQuery -eq $true -and
    $annotation.freshEnumeration.baselineAndPostControlGeometryEqual -eq $true -and
    $annotation.freshEnumeration.interfaceNumber -ceq '00' -and
    $annotation.freshEnumeration.usagePageHex -ceq '000C' -and
    $annotation.freshEnumeration.usageHex -ceq '0001' -and
    $annotation.freshEnumeration.featureReportBytes -eq 91) 'Fresh enumeration must retain the selected control geometry.'
Assert-True ($annotation.operatorReconnect.userReply -ceq 'reconnected, no changes' -and
    $annotation.operatorReconnect.usbOnlyActionInstructed -eq $true -and
    $annotation.operatorReconnect.approximateDisconnectSecondsInstructed -eq 5 -and
    $annotation.operatorReconnect.independentlyTimed -eq $false -and
    $annotation.operatorReconnect.power12VRetainedInstructed -eq $true) `
    'Reconnect instructions must not become independently timed or measured facts.'
Assert-True ($annotation.preflight.quietAutoConfirmed -eq $true -and
    $annotation.preflight.padDependentHyperBoostInactiveConfirmed -eq $true -and
    $annotation.operatorFinal.userReply -ceq 'Still normal and unchanged' -and
    $annotation.operatorFinal.quietAutoConfirmed -eq $true -and
    $annotation.operatorFinal.fullBrightnessStaticGreenConfirmed -eq $true -and
    $annotation.operatorFinal.noRedOrSleepConfirmed -eq $true -and
    $annotation.operatorFinal.replyAfterPostReconnectQuery -eq $true -and
    $annotation.operatorFinal.physicalObservationPending -eq $false) 'Final confirmation must retain the actual bounded operator reply.'
Assert-True ($annotation.executionBoundaries.logicalQueryCount -eq 2 -and
    $annotation.executionBoundaries.setterCount -eq 0 -and
    $annotation.executionBoundaries.shellParserFailureBeforeCommands -eq $true -and
    $annotation.executionBoundaries.deviceFailureEstablishedByParserFailure -eq $false -and
    $annotation.executionBoundaries.deviceIoRetryPerformed -eq $false) 'Shell syntax correction must not become device I/O or a retry.'
foreach ($flag in @('synapseActionsPerformed', 'serviceActionsPerformed', 'usbPcapUsed', 'powerCyclePerformed')) {
    Assert-True ($annotation.executionBoundaries.$flag -eq $false) "Unperformed action was acquired: $flag"
}
foreach ($property in $annotation.productionAdmission.PSObject.Properties) {
    if ($property.Name -ne 'reason') {
        Assert-True ($property.Value -eq $false) 'Passive reconnect must keep every production gate closed.'
    }
}
Assert-True (-not ((Get-Content -LiteralPath $path -Raw) -match '(?i)[A-Z]:\\|"(?:processId|deviceInstanceId|serialNumber)"')) `
    'Private paths and identifiers must not enter the annotation.'
Write-Host 'RZ09-0528 cooling-pad passive USB reconnect evidence tests passed.'
