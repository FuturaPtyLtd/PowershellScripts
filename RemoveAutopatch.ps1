function Unenroll-WindowsUpdateAssets {
    param(
        [string[]] $Ids,

        [Parameter(Mandatory)]
        [ValidateSet('feature', 'quality', 'driver')]
        [string] $UpdateCategory
    )

    if ($Ids.Count -eq 0) {
        Write-Output 'No IDs supplied — nothing to unenroll.'
        return
    }

    # Graph endpoint
    $uri = 'https://graph.microsoft.com/beta/admin/windows/updates/updatableAssets/unenrollAssetsById'

    # Request body
    $body = @{
        updateCategory   = $UpdateCategory
        memberEntityType = '#microsoft.graph.windowsUpdates.azureADDevice'
        ids              = $Ids
    } | ConvertTo-Json -Depth 5

    # POST call with full HTTP response
    $response = Invoke-MgGraphRequest `
        -Method POST `
        -Uri $uri `
        -Body $body `
        -ContentType 'application/json' `
        -OutputType HttpResponseMessage

    Write-Output '$UpdateCategory ID removal response (NoContent is good) - ' $response.StatusCode
}

Disconnect-MgGraph -ErrorAction SilentlyContinue
Write-Output "Disconnected from Graph"

Connect-MgGraph -Scopes 'Device.Read.All','WindowsUpdates.ReadWrite.All' -Environment Global -NoWelcome

$account = Get-MgContext
Write-Output 'Connected to Graph on Account: '$account.Account

$uri = 'https://graph.microsoft.com/beta/admin/windows/updates/updatableAssets/microsoft.graph.windowsUpdates.azureADDevice'

$allDevices = @()

do {
    $response = Invoke-MgGraphRequest -Method GET -Uri $uri

    # Add current page of devices
    if ($response.value) {
        $allDevices += $response.value
    }

    # Get next page URL if present
    $uri = $response.'@odata.nextLink'

} while ($uri)

$featureIds = @()
$qualityIds = @()
$driverIds = @()

foreach ($device in $allDevices) 
{
    if ($device.enrollment.feature.enrollmentState -ne 'notEnrolled') 
    {
        $featureIds += $device.id
    }
    if ($device.enrollment.quality.enrollmentState -ne 'notEnrolled') 
    {
        $qualityIds += $device.id
    }
    if ($device.enrollment.driver.enrollmentState -ne 'notEnrolled') 
    {
        $driverIds += $device.id
    }
}

Write-Output 'List of Feature IDs'
Write-Output $featureIds
Write-Output 'List of Quality IDs'
Write-Output $qualityIds
Write-Output 'List of Driver IDs'
Write-Output $driverIds

Unenroll-WindowsUpdateAssets -Ids $featureIds -UpdateCategory 'feature'
Unenroll-WindowsUpdateAssets -Ids $qualityIds -UpdateCategory 'quality'
Unenroll-WindowsUpdateAssets -Ids $driverIds -UpdateCategory 'driver'
