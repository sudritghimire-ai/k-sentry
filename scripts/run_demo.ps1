Write-Host "=== TimeFence Local Artifact Demo ===" -ForegroundColor Cyan

$Root = "C:\Users\sudri\OneDrive\Desktop\k-sentry"
$VerusDir = "$Root\verus-x86-win"
$ProofFile = "$Root\proofs\finaltest_timefence_core_verified.rs"
$RustDir = "$Root\timefence-core"
$ArtifactDir = "$Root\artifacts"

New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null

Write-Host "`n[1/4] Running Verus proof..." -ForegroundColor Yellow
cd $VerusDir
.\verus.exe $ProofFile

Write-Host "`n[2/4] Running Rust tests..." -ForegroundColor Yellow
cd $RustDir
cargo test

Write-Host "`n[3/4] Running release demo..." -ForegroundColor Yellow
cargo run --release

Write-Host "`n[4/4] Copying outputs..." -ForegroundColor Yellow
Copy-Item "$RustDir\timefence_report.json" "$ArtifactDir\timefence_report.json" -Force
Copy-Item "$RustDir\artifacts\bench.csv" "$ArtifactDir\bench.csv" -Force

Write-Host "`nDone. Outputs:" -ForegroundColor Green
Write-Host "$ArtifactDir\timefence_report.json"
Write-Host "$ArtifactDir\bench.csv"