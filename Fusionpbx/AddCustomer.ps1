
param (
    [Parameter(Mandatory)]
    [string]$APIUrl,
    [int]$APIVersion = 7,
    [Parameter(Mandatory)]
    [string]$APIKey,
    [Parameter(Mandatory)]
    [string]$CustomerDomain,
    [Parameter(Mandatory)]
    [string]$CustomerName,
    [Parameter(Mandatory)]
    [string]$SBCIP,
    [Parameter(Mandatory)]
    [string]$SBCPort
)

function Invoke-FusionPbxJsonTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DomainName,
        [Parameter(Mandatory)][string]$ApiVersion,
        [Parameter(Mandatory)][ValidateScript({ Test-Path $_ })][string]$TemplatePath,

        [Parameter(Mandatory)]
        [hashtable]$Tokens, 

        [string]$ApiKeyInUrl,
        [string]$BasicKeyHeader,
        [ValidateSet("POST","PUT","PATCH")][string]$Method = "POST",
        [switch]$Insecure
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    if ($Insecure) {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    }

    $uri = "https://$DomainName/app/api/$ApiVersion/domains"
    $headers = @{ "Content-Type"="application/json"; "Accept"="application/json" }

    if ($BasicKeyHeader) { $headers["Authorization"] = "Basic $BasicKeyHeader" }
    elseif ($ApiKeyInUrl) { $uri += (($uri -match "\?") ? "&" : "?") + "key=$ApiKeyInUrl" }
    else { throw "Provide -ApiKeyInUrl OR -BasicKeyHeader" }

    $json = Get-Content -Path $TemplatePath -Raw -Encoding UTF8
    foreach ($k in $Tokens.Keys) {
        $json = $json.Replace($k, [string]$Tokens[$k])
    }

    Write-Host "Sending Data to $uri"
    Write-Host $json
    
    try {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $json -ErrorAction Stop
    }
    catch {
        throw "FusionPBX API call failed ($Method $uri): $($_.Exception.Message)"
    }
}

$tokens = @{
  "__CUSTOMER_DOMAIN__"  = $CustomerDomain
  "__SBC_IP__"           = $SBCIP
  "__SBC_PORT__"         = $SBCPort
  "__CUSTOMER_NAME__"    = $CustomerName
  "__DOMAIN_UUID__"    = [guid]::NewGuid()
  "__GATEWAY_UUID__"     = [guid]::NewGuid()
  "__DIALPLAN_FNN_UUID__"     = [guid]::NewGuid()
  "__DIALPLAN_NSW_UUID__"     = [guid]::NewGuid()
  "__DIALPLAN_13xx_UUID__"     = [guid]::NewGuid()
  "__DIALPLAN_1300_UUID__"     = [guid]::NewGuid()
}

$result = Invoke-FusionPbxJsonTemplate `
  -DomainName $APIUrl `
  -ApiVersion "$APIVersion" `
  -TemplatePath ".\NewCustomerSeed.json" `
  -Tokens $tokens `
  -ApiKeyInUrl $APIKey `
  -Method POST `
  -Insecure

