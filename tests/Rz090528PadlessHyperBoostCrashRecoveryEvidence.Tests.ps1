param([string]$AnnotationDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) 'annotations'))
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
function Assert-Sha256([string]$Value, [string]$Message) {
    Assert-True ($Value -cmatch '^[0-9A-F]{64}$') $Message
}
$raw = [IO.File]::ReadAllText((Join-Path $AnnotationDirectory '2026-09-29-rz09-0528-padless-hyperboost-crash-recovery-lifecycle.json'))
Assert-True (-not $raw.Contains("`r")) 'Annotation bytes must remain LF.'
$a = $raw | ConvertFrom-Json
Assert-Keys $a 'schemaVersion,publicationStatus,evidenceKind,evidenceProvenance,device,operatorConfirmation,scenario,validation,productionRestore,artifacts,priorAttempts,interpretation,sanitization'
Assert-True ($a.schemaVersion -eq 1 -and $a.publicationStatus -ceq 'UserApprovedSanitizedEvidence' -and $a.evidenceKind -ceq 'InstalledUnexpectedExitLifecycle') 'Evidence identity changed.'

$p = $a.evidenceProvenance
Assert-True ($p.role -ceq 'OpenBladeTypedValidation' -and $p.sourceRevision -cmatch '^8ed9088a[0-9a-f]{32}$') 'Provenance changed.'
Assert-True ($p.controller -clike '*lifecycle-validation Service 0.23.0-nightly.4+8ed9088a*FirmwareSmoke 0.23.0-nightly.4+8ed9088a') 'Exact tool generation changed.'
Assert-True ($p.readinessDescriptorSha256 -ceq 'A18E7BA301C87A0BA41BA0F39FECDFC4FC3A43660AE5DE28077C2863E7165237') 'Readiness descriptor binding changed.'
foreach ($name in 'installerSha256', 'serviceExecutableSha256', 'productionServiceAssemblySha256', 'validationServiceAssemblySha256', 'validationBuildManifestSha256', 'firmwareSmokeExecutableSha256', 'firmwareSmokeAssemblySha256', 'installedGenerationSha256') {
    Assert-Sha256 $p.$name "Provenance hash is malformed: $name"
}
Assert-True ($p.validationServiceAssemblySha256 -cne $p.productionServiceAssemblySha256) 'Validation and production assemblies must differ.'

Assert-True ($a.device.modelNumber -ceq 'RZ09-0528' -and $a.device.sku -ceq 'RZ09-05289EN4' -and $a.device.vendorIdHex -ceq '1532' -and $a.device.productIdHex -ceq '02C6' -and $a.device.bios -ceq '2.02') 'Exact model scope changed.'
foreach ($property in $a.operatorConfirmation.PSObject.Properties) { Assert-True ($property.Value -eq $true) 'Operator confirmation changed.' }

$s = $a.scenario
Assert-True ($s.baseMode -ceq 'Performance' -and $s.requiresCoolingPad -eq $false -and $s.padlessEligibilityObservedByService -ceq 'CoolingPadAbsent' -and $s.activePowerSource -ceq 'PluggedIn') 'Scenario scope changed.'
Assert-True ($s.restoreIntent.performance -ceq 'Performance' -and $s.restoreIntent.fans -ceq 'Automatic' -and $null -eq $s.restoreIntent.customPerformance -and $null -eq $s.restoreIntent.gpuClockTuning) 'Only the captured Performance/Automatic intent is in scope.'

$v = $a.validation
Assert-True ($v.arm.success -eq $true -and $v.arm.hyperBoostConfirmed -eq $true -and $v.arm.durableOwnershipConfirmed -eq $true -and $v.arm.markerCreated -eq $true -and $v.arm.cleanupAttempted -eq $false -and $v.arm.manualRecoveryRequired -eq $false) 'Arm facts changed.'
Assert-True ($v.boundary.onlyOpenBladeServiceTerminated -eq $true -and $v.boundary.terminationCount -eq 1 -and $v.boundary.oldInstanceExited -eq $true -and $v.boundary.replacementFromSameValidationBuild -eq $true -and $v.boundary.markerBoundInstanceVerified -eq $true -and $v.boundary.ownershipJournalOwnedConfirmedBeforeTermination -eq $true) 'Boundary facts changed.'
$r = $v.verification
Assert-True ($r.success -eq $true -and $r.exactInstalledGeneration -eq $true -and $r.expectedProcessBoundary -eq $true -and $r.exactRestoreIntentConfirmed -eq $true -and $r.journalRetired -eq $true -and $r.stableSecondObservation -eq $true -and $r.readOnly -eq $true) 'Verification facts changed.'
Assert-True ($r.recoveryAttemptsObserved -eq 1 -and $r.recoveryCompletionsObserved -eq 1) 'Exactly one recovery attempt and completion are required.'
$post = $v.postRecoveryState
Assert-True ($post.baselinePassed -eq $true -and $post.performance -ceq 'Performance' -and $post.fans -ceq 'Automatic' -and $post.hyperBoostActive -eq $false -and @($post.externalChanges).Count -eq 0 -and $post.writesBlocked -eq $false -and $post.unconfirmedWrites -eq 0) 'Post-recovery state changed.'

$restore = $a.productionRestore
Assert-True ($restore.restored -eq $true -and $restore.journalAbsentBeforeRestore -eq $true -and $restore.finalBaselinePassed -eq $true -and @($restore.finalExternalChanges).Count -eq 0) 'Production restoration changed.'

$roles = @($a.artifacts | ForEach-Object role)
Assert-True (($roles -join ',') -ceq 'FreshBaseline,ValidationServiceSwapReport,LifecycleArm,PrivateLifecycleMarker,UnexpectedExitBoundaryReport,LifecycleVerification,PostRecoveryBaseline,ProductionRestoreReport,FinalBaseline') 'Artifact set changed.'
foreach ($artifact in $a.artifacts) {
    Assert-Keys $artifact 'role,sha256,byteLength,committed'
    Assert-Sha256 $artifact.sha256 "Artifact hash is malformed: $($artifact.role)"
    Assert-True ($artifact.byteLength -gt 0 -and $artifact.committed -eq $false) "Private artifact must stay uncommitted: $($artifact.role)"
}

# Earlier installed runs failed verification; they must stay disclosed with their fixes.
$prior = @($a.priorAttempts)
Assert-True ($prior.Count -eq 2) 'Both earlier failed runs must remain disclosed.'
$fixes = @('OpenBladeProject/openblade-core#606', 'OpenBladeProject/openblade-core#607')
for ($i = 0; $i -lt 2; $i++) {
    $attempt = $prior[$i]
    Assert-Sha256 $attempt.verificationArtifactSha256 'Prior verification hash is malformed.'
    Assert-True ($attempt.fixedBy -ceq $fixes[$i] -and $attempt.hardwareRestored -eq $true -and $attempt.productionRestored -eq $true) 'Prior attempt disclosure changed.'
    Assert-True ((@($attempt.failedChecks) -join ',') -ceq 'exactInstalledGeneration,exactRestoreIntentConfirmed') 'Prior failed checks changed.'
}

$i = $a.interpretation
Assert-True ($i.crashRecoveryValidated -eq $true -and $i.lowPowerLifecycleValidated -eq $false -and $i.productionPadlessAdmitted -eq $false) 'Unsupported inference.'
Assert-True ($i.limits -clike '*Low-power (sleep and resume) lifecycle validation is still required*') 'Evidence limits changed.'
foreach ($property in $a.sanitization.PSObject.Properties) { Assert-True ($property.Value -eq $true) 'Private data exclusion changed.' }
Assert-True ($raw -notmatch '(?i)[A-Z]:\\|\\\\|USB\\|HID\\|S-1-5-|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|"(?:ProcessId|processId|startUtcTicks|transitionId|StartedAtUtc|InstanceId|SerialNumber)"') 'Private or unapproved identity data detected.'
Write-Output "Padless HyperBoost crash-recovery evidence passed $script:checks assertions. No hardware operations performed."
