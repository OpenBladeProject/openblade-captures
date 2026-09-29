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
function Get-FileSha256([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($Path))) -replace '-', '') } finally { $sha.Dispose() }
}
$raw = [IO.File]::ReadAllText((Join-Path $AnnotationDirectory '2026-09-29-rz09-0528-padless-hyperboost-low-power-lifecycle.json'))
Assert-True (-not $raw.Contains("`r")) 'Annotation bytes must remain LF.'
$a = $raw | ConvertFrom-Json
Assert-Keys $a 'schemaVersion,publicationStatus,evidenceKind,evidenceProvenance,device,operatorConfirmation,scenario,validation,productionRestore,companionEvidence,artifacts,interpretation,sanitization'
Assert-True ($a.schemaVersion -eq 1 -and $a.publicationStatus -ceq 'UserApprovedSanitizedEvidence' -and $a.evidenceKind -ceq 'InstalledLowPowerLifecycle') 'Evidence identity changed.'

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
Assert-True ($s.restorationBoundary -cin @('before low power', 'before display-off safety boundary')) 'Restoration boundary is not one the verifier accepts.'

$v = $a.validation
Assert-True ($v.arm.success -eq $true -and $v.arm.hyperBoostConfirmed -eq $true -and $v.arm.durableOwnershipConfirmed -eq $true -and $v.arm.markerCreated -eq $true -and $v.arm.cleanupAttempted -eq $false -and $v.arm.manualRecoveryRequired -eq $false) 'Arm facts changed.'
Assert-True ($v.boundary.sleepCount -eq 1 -and $v.boundary.sameServiceProcessAcrossBoundary -eq $true -and $v.boundary.serviceRestarted -eq $false -and $v.boundary.restorationBeforeSleep -eq $true) 'Low-power boundary facts changed.'
$r = $v.verification
Assert-True ($r.success -eq $true -and $r.exactInstalledGeneration -eq $true -and $r.expectedProcessBoundary -eq $true -and $r.exactRestoreIntentConfirmed -eq $true -and $r.journalRetired -eq $true -and $r.stableSecondObservation -eq $true -and $r.readOnly -eq $true) 'Verification facts changed.'
Assert-True ($r.recoveryAttemptsObserved -eq 1 -and $r.recoveryCompletionsObserved -eq 1) 'Exactly one recovery attempt and completion are required.'
$post = $v.postResumeState
Assert-True ($post.baselinePassed -eq $true -and $post.performance -ceq 'Performance' -and $post.fans -ceq 'Automatic' -and $post.hyperBoostActive -eq $false -and @($post.externalChanges).Count -eq 0 -and $post.writesBlocked -eq $false -and $post.unconfirmedWrites -eq 0 -and $post.keyboardDriverModeReacquired -eq $true) 'Post-resume state changed.'

$restore = $a.productionRestore
Assert-True ($restore.restored -eq $true -and $restore.journalAbsentBeforeRestore -eq $true -and $restore.finalBaselinePassed -eq $true -and @($restore.finalExternalChanges).Count -eq 0) 'Production restoration changed.'

# The companion unexpected-exit evidence must be the exact committed bytes of the same installed generation.
$c = $a.companionEvidence
Assert-Keys $c 'annotation,annotationSha256,sameInstalledGeneration,relationship'
$cited = Join-Path $AnnotationDirectory $c.annotation
Assert-True ($c.annotation -ceq '2026-09-29-rz09-0528-padless-hyperboost-crash-recovery-lifecycle.json' -and (Test-Path -LiteralPath $cited)) 'Companion annotation is missing.'
Assert-True ((Get-FileSha256 $cited) -ceq $c.annotationSha256) 'Companion annotation bytes changed.'
$crash = [IO.File]::ReadAllText($cited) | ConvertFrom-Json
Assert-True ($c.sameInstalledGeneration -eq $true -and $crash.evidenceProvenance.installedGenerationSha256 -ceq $p.installedGenerationSha256 -and $crash.evidenceProvenance.sourceRevision -ceq $p.sourceRevision) 'Companion evidence is from another installed generation.'
Assert-True ($crash.interpretation.crashRecoveryValidated -eq $true -and $crash.validation.verification.success -eq $true) 'Companion evidence does not validate crash recovery.'

$roles = @($a.artifacts | ForEach-Object role)
Assert-True (($roles -join ',') -ceq 'FreshBaseline,ValidationServiceSwapReport,LifecycleArm,PrivateLifecycleMarker,LifecycleVerification,PostResumeBaseline,ProductionRestoreReport,FinalBaseline') 'Artifact set changed.'
foreach ($artifact in $a.artifacts) {
    Assert-Keys $artifact 'role,sha256,byteLength,committed'
    Assert-Sha256 $artifact.sha256 "Artifact hash is malformed: $($artifact.role)"
    Assert-True ($artifact.byteLength -gt 0 -and $artifact.committed -eq $false) "Private artifact must stay uncommitted: $($artifact.role)"
}

$i = $a.interpretation
Assert-True ($i.lowPowerLifecycleValidated -eq $true -and $i.crashRecoveryValidated -eq $true -and $i.productionPadlessAdmitted -eq $false) 'Unsupported inference.'
Assert-True ($i.limits -clike '*suspend callback path was not exercised*Production admission requires a separate reviewed change*') 'Evidence limits changed.'
foreach ($property in $a.sanitization.PSObject.Properties) { Assert-True ($property.Value -eq $true) 'Private data exclusion changed.' }
Assert-True ($raw -notmatch '(?i)[A-Z]:\\|\\\\|USB\\|HID\\|S-1-5-|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|"(?:ProcessId|processId|startUtcTicks|transitionId|StartedAtUtc|InstanceId|SerialNumber)"') 'Private or unapproved identity data detected.'
Write-Output "Padless HyperBoost low-power evidence passed $script:checks assertions. No hardware operations performed."
