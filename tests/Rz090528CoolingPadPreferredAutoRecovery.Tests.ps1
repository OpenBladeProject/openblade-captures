[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$path = Join-Path $repository 'annotations\2026-09-29-rz09-0528-cooling-pad-preferred-auto-recovery.json'
$source = Get-Content -LiteralPath $path -Raw
$annotation = $source | ConvertFrom-Json
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
Assert-True ($annotation.schemaVersion -eq 1 -and $annotation.purpose -ceq 'reassert-requested-preferred-Auto' -and
    $annotation.evidenceProvenance.sourceCommit -ceq '248ec506ed606f6b14bd9667bd80ee2ca2a55995' -and
    $annotation.evidenceProvenance.existingSevenCommandRunnerUnchanged -eq $true -and
    $annotation.evidenceProvenance.hardwareTested -eq $true -and
    $annotation.evidenceProvenance.usbPcapUsed -eq $false -and
    $annotation.evidenceProvenance.independentNativeReportTraceRetained -eq $false -and
    $annotation.queryArtifact.sha256 -ceq 'BF86D90201FE261E21EC87D858950070DF38EC61D04D1E52013604D64F765372' -and
    $annotation.queryArtifact.byteLength -eq 2283 -and $annotation.queryArtifact.rawArtifactCommitted -eq $false) `
    'Requested preferred-Auto typed evidence must retain the unchanged core and distinct provenance.'
Assert-True ($annotation.device.modelNumber -ceq 'RZ09-0528' -and
    $annotation.device.sku -ceq 'RZ09-05289EN4' -and $annotation.device.vendorIdHex -ceq '1532' -and
    $annotation.device.productIdHex -ceq '0F43' -and $annotation.device.revisionHex -ceq '0200' -and
    $annotation.device.interfaceNumber -ceq '00' -and $annotation.device.usagePageHex -ceq '000C' -and
    $annotation.device.usageHex -ceq '0001' -and $annotation.device.featureBufferBytes -eq 91 -and
    $annotation.device.featureReportPrefixHex -ceq '00' -and $annotation.device.biosIsProvenanceOnly -eq $true) `
    'Exact accessory identity, geometry and BIOS provenance boundary changed.'
Assert-True ($annotation.completedAtUtc -ceq '2026-09-30T02:34:16.6198235+00:00' -and
    $annotation.preflight.operatorInitialStateReply -ceq 'yes, confirmed' -and
    $annotation.preflight.initialNormalMediumConfirmed -eq $true -and
    $annotation.preflight.requestedPhysicalTarget -ceq 'preferred quiet Auto' -and
    $annotation.preflight.synapseUseForbidden -eq $true -and $annotation.preflight.prefilledPhysicalAnswers -eq $false) `
    'Initial Medium and requested quiet Auto must remain distinct attended observations.'
$expected = @('00/84:0000', '00/04:0300', '00/84:0000', '0D/10:01012C', '0D/10:000600', '00/04:0000', '00/84:0000')
Assert-True (($annotation.performedLogicalSequenceAccordingToResultAndReviewedSource -join ',') -ceq ($expected -join ',') -and
    $annotation.sequenceEvidenceLimit -match 'planned sequence only' -and
    $annotation.sequenceEvidenceLimit -match 'result flags' -and
    $annotation.sequenceEvidenceLimit -match 'not an independently sniffed') `
    'Seven completed logical exchanges require result flags and source, not the planned list or native packet inference.'
Assert-True ($annotation.physicalTarget.purposeIsRestoreInitialPhysicalMedium -eq $false -and
    $annotation.physicalTarget.requestedPreferredQuietAutoAchieved -eq $true -and
    $annotation.physicalTarget.requestedPreferredQuietAutoFinalConfirmed -eq $true -and
    $annotation.physicalTarget.rawControlStateIsFanReadback -eq $false) `
    'Requested preference achievement must not become physical Medium restoration or a fan getter.'
$result = $annotation.result
Assert-True ($result.requestedRecoverySequenceCompleted -eq $true -and $result.nativeRunnerInvoked -eq $true -and
    $result.runnerResultUnavailable -eq $false -and $result.submissionStateUnknown -eq $false -and
    $result.rawBaseline -ceq '0000' -and $result.rawCandidate -ceq '0300' -and $result.rawRestored -ceq '0000' -and
    $null -eq $result.failurePhase -and $null -eq $result.failure -and $result.manualRecoveryRequired -eq $false -and
    $result.exitCode -eq 0) 'The actual successful raw-mode sequence and attended preference result changed.'
foreach ($flag in @('modeAcquireAttempted', 'modeAcquireAcknowledged', 'candidateConfirmed', 'fixedAttempted',
    'fixedAcknowledged', 'fixedPhysicalConfirmed', 'autoAttempted', 'autoAcknowledged', 'autoPhysicalConfirmed',
    'modeRestoreAttempted', 'modeRestoreAcknowledged', 'rawRestorationConfirmed', 'finalPhysicalConfirmed',
    'preferredAutoPhysicalConfirmed', 'preferredAutoFinalPhysicalConfirmed')) {
    Assert-True ($result.$flag -eq $true) "Completed logical outcome changed: $flag"
}
$expectedTimes = @('2026-09-30T02:33:49.9363499+00:00', '2026-09-30T02:34:11.5480153+00:00', '2026-09-30T02:34:55.3382121+00:00')
Assert-True (($annotation.operatorOutcomes.recordedAtUtc -join ',') -ceq ($expectedTimes -join ',') -and
    $annotation.operatorOutcomes[0].userReply -ceq 'yes' -and $annotation.operatorOutcomes[0].normalMediumConfirmed -eq $true -and
    $annotation.operatorOutcomes[1].userReply -ceq 'confirmed' -and $annotation.operatorOutcomes[1].preferredQuietAutoAchieved -eq $true -and
    $annotation.operatorOutcomes[2].userReply -ceq 'yes' -and $annotation.operatorOutcomes[2].preferredQuietAutoRemainsNormal -eq $true) `
    'Exact journal-save timestamps and actual physical replies changed.'
foreach ($outcome in $annotation.operatorOutcomes) {
    Assert-True ($outcome.submittedToRunner -eq $true -and $outcome.fullBrightnessStaticGreenConfirmed -eq $true -and
        $outcome.noRedOrSleepConfirmed -eq $true) 'Physical observations must retain their bounded lighting and sleep meaning.'
}
Assert-True (($annotation.limitations -join ' ') -match 'not YES submission timestamps' -and
    $annotation.relationshipToEarlierFailedTrial.separateSequence -eq $true -and
    $annotation.relationshipToEarlierFailedTrial.earlierFailedTrialOutcomeChanged -eq $false -and
    $annotation.relationshipToEarlierFailedTrial.earlierManualPowerCyclePartOfThisSequence -eq $false) `
    'Journal bookkeeping and the separate earlier failure must not be rewritten as this sequence.'
foreach ($flag in @('lightingCommandsSubmitted', 'automaticRecovery', 'synapseActionsPerformed',
    'serviceActionsPerformed', 'powerCyclePerformedDuringThisSequence', 'retryPerformed')) {
    Assert-True ($result.$flag -eq $false) "Unperformed action acquired: $flag"
}
foreach ($property in $annotation.productionAdmission.PSObject.Properties) {
    if ($property.Name -ne 'reason') {
        Assert-True ($property.Value -eq $false) 'Preferred quiet Auto success must keep every production and semantic gate closed.'
    }
}
Assert-True (-not ($source -match '(?i)[A-Z]:\\|"(?:pid|parentPid|processId|childProcessIds|pipeName|nonce|mvid|moduleId|serialNumber|deviceInstanceId|rawReport|rawReports)"')) `
    'Private paths, operating-system identifiers, authentication secrets, module identifiers and raw reports must not enter evidence.'
Write-Host 'RZ09-0528 cooling-pad requested preferred-Auto recovery evidence tests passed.'
