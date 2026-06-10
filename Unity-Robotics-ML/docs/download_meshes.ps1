$baseUrl = "https://raw.githubusercontent.com/Unity-Technologies/Unity-Robotics-Hub/main/tutorials/pick_and_place/PickAndPlaceProject/Assets/URDF/niryo_one/niryo_one_urdf"
$dest = "C:\Unity_ML-Agents\Unity-Robotics-ML\Assets\URDF\niryo_one\niryo_one_urdf"

$files = @(
    # Collada meshes (visual)
    "meshes/collada/base_link.dae",
    "meshes/collada/shoulder_link.dae",
    "meshes/collada/arm_link.dae",
    "meshes/collada/elbow_link.dae",
    "meshes/collada/forearm_link.dae",
    "meshes/collada/wrist_link.dae",
    "meshes/collada/hand_link.dae",
    # STL meshes (collision)
    "meshes/stl/base_link.stl",
    "meshes/stl/shoulder_link.stl",
    "meshes/stl/arm_link.stl",
    "meshes/stl/elbow_link.stl",
    "meshes/stl/forearm_link.stl",
    "meshes/stl/wrist_link.stl",
    "meshes/stl/hand_link.stl",
    # Gripper STL
    "Gripper1/G1_MainSupport.STL",
    "Gripper1/G1_ServoHead.STL",
    "Gripper1/G1_Rod.STL",
    "Gripper1/G1_ClampRight.STL",
    "Gripper1/G1_ClampLeft.STL"
)

$jobs = @()
foreach ($file in $files) {
    $url = "$baseUrl/$file"
    $outFile = Join-Path $dest $file
    $job = Start-Job -ScriptBlock {
        param($u, $o)
        $dir = Split-Path $o -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        try {
            Invoke-WebRequest -Uri $u -OutFile $o -ErrorAction Stop
            return "OK: $o"
        } catch {
            return "FAIL: $o - $_"
        }
    } -ArgumentList $url, $outFile
    $jobs += $job
}

# Wait for all jobs
$jobs | Wait-Job | Out-Null
# Get results
$results = $jobs | Receive-Job
$results | ForEach-Object { Write-Host $_ }

# Count successes
$success = ($results | Where-Object { $_ -match "^OK:" }).Count
$fail = ($results | Where-Object { $_ -match "^FAIL:" }).Count
Write-Host "=== Downloaded: $success OK, $fail Failed ==="
