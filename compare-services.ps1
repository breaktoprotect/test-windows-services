# ================================
# Compare-Server-Services.ps1
# ================================

param(
    [Parameter(Mandatory=$true)]
    [string]$BaselineCsvPath,      # e.g., "C:\baseline\services2022_full.csv"

    [Parameter(Mandatory=$true)]
    [string]$ComparisonCsvPath,     # e.g., "C:\baseline\services2025_full.csv"

    [Parameter(Mandatory=$true)]
    [string]$OutputFolder           # e.g., "C:\baseline\diff_output"
)

# Create output folder if it doesn't exist
if (!(Test-Path $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory | Out-Null
}

# Load CSVs
$baselineServices = Import-Csv -Path $BaselineCsvPath
$comparisonServices = Import-Csv -Path $ComparisonCsvPath

# Build service name sets
$baselineNames = $baselineServices.Name
$comparisonNames = $comparisonServices.Name

# Find new services in comparison
$newServicesNames = $comparisonNames | Where-Object { $_ -notin $baselineNames }
# Find removed services
$removedServicesNames = $baselineNames | Where-Object { $_ -notin $comparisonNames }

# Map back to full service info
$newServices = $comparisonServices | Where-Object { $newServicesNames -contains $_.Name }
$removedServices = $baselineServices | Where-Object { $removedServicesNames -contains $_.Name }

# Export results
$newServices | Sort-Object Name | Export-Csv -Path (Join-Path $OutputFolder "new_services.csv") -NoTypeInformation
$removedServices | Sort-Object Name | Export-Csv -Path (Join-Path $OutputFolder "removed_services.csv") -NoTypeInformation

# Optional: Output to screen summary
Write-Output "✅ Diff complete:"
Write-Output "➔ $($newServices.Count) new services found in comparison."
Write-Output "➔ $($removedServices.Count) services missing compared to baseline."
Write-Output "🗂️  Results exported to: $OutputFolder"
