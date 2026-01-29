function Invoke-FusionPbxApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DomainName,              # e.g. test.fusionpbx.com

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ApiVersion,              # e.g. 7

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ApiMethod,               # e.g. "domains" or "users?domain_uuid=all"

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Key,                     # API key value (used as ?key=...)

        [ValidateSet("GET","POST","PUT","PATCH","DELETE")]
        [string]$Method = "GET",

        # Pass a PS object (recommended) OR a JSON string
        [Parameter()]
        [object]$Body
    )

    $uri = "https://$DomainName/app/api/$ApiVersion/$ApiMethod"
    $sep = ($uri -match "\?") ? "&" : "?"
    $uri = "$uri$sep" + "key=$Key"

    $headers = @{
        "Content-Type" = "application/json"
        "Accept"       = "application/json"
    }

    try {
        $irmParams = @{
            Method      = $Method
            Uri         = $uri
            Headers     = $headers
            ErrorAction = "Stop"
        }

        if ($PSBoundParameters.ContainsKey("Body") -and $null -ne $Body) {
            # If they gave a JSON string, use it. Otherwise convert object -> JSON.
            if ($Body -is [string]) {
                $json = $Body
            } else {
                $json = $Body | ConvertTo-Json -Depth 20
            }

            $irmParams["Body"] = $json
        }

        return Invoke-RestMethod @irmParams
    }
    catch {
        throw "API call failed ($Method $uri): $($_.Exception.Message)"
    }
}


$APIKey = "BSagg6CJVjWJHFahSTCxCvVVf4CjQzib"
$BaseDomainName = "sip01.futurasip.com"
$CustomerDomainName = "test.futurasip.com"
$CustomerName = "test"
$ApiVersion = "7"
$SBCIP = "10.0.5.4"
$SBCPort = "5062"

#Create Domain
$data = @{
    domains = @(
        @{
            domain_name    = $CustomerDomainName
            domain_enabled = "true"
        }
    )
}

$json = $data | ConvertTo-Json
Write-Host "Creating Domain"
$result = Invoke-FusionPbxApi -DomainName $BaseDomainName -ApiVersion $ApiVersion -ApiMethod "domains" -Key $APIKey -Method POST -Body $json
$newDomainUUID = $result.uuid

#Create Gateway
$data = @{
    gateways = @(
        @{
            domain_uuid = $newDomainUUID
            gateway = "CTS-$SBCPort-$CustomerName"
            proxy = "$($SBCIP):$($SBCPort)"
            expire_seconds = "800"
            register = "false"
            profile = "external"
            context = "public"
        }
    )
}
$json = $data | ConvertTo-Json
Write-Host "Creating Gateway"
$result = Invoke-FusionPbxApi -DomainName $BaseDomainName -ApiVersion $ApiVersion -ApiMethod "gateways" -Key $APIKey -Method POST -Body $json
$newGatewayUUID = $result.uuid

#Start Gateway.
Write-Host "Starting Gateway"
Invoke-FusionPbxApi -DomainName $BaseDomainName -ApiVersion $ApiVersion -ApiMethod "gateway?name=$newGatewayUUID&action=start&profile=external" -Key $APIKey -Method GET

#Create FNN Dialplan
$dialplanXml = @"
<extension name="CTS-$SBCPort-$CustomerName.FNN" continue="false" uuid="">
	<condition field="`${user_exists}`" expression="false"/>
	<condition field="destination_number" expression="^(0|61|\+61)?([2?|3-9]{1}[0-9]{8})$">
		<action application="export" data="call_direction=outbound" inline="true"/>
		<action application="unset" data="call_timeout"/>
		<action application="set" data="hangup_after_bridge=true"/>
		<action application="set" data="effective_caller_id_name=`${outbound_caller_id_name}`"/>
		<action application="set" data="effective_caller_id_number=`${outbound_caller_id_number}`"/>
		<action application="set" data="inherit_codec=true"/>
		<action application="set" data="ignore_display_updates=true"/>
		<action application="set" data="callee_id_number=0$2"/>
		<action application="set" data="continue_on_fail=1,2,3,6,18,21,27,28,31,34,38,41,42,44,58,88,111,403,501,602,607,809"/>
		<action application="bridge" data="sofia/gateway/$newGatewayUUID/0$2"/>
	</condition>
</extension>
"@

#Create FNN Dialpad - 8c914ec3-9fc0-8ab5-4cda-6c9288bdc9a3 is the id for outbound routes
$data = @{
    dialplans = @(
        @{
            domain_uuid = $newDomainUUID
            app_uuid = "8c914ec3-9fc0-8ab5-4cda-6c9288bdc9a3"
            hostname = ""
            dialplan_context = $CustomerDomainName
            dialplan_name = "CTS-$SBCPort-$CustomerName.FNN"
            dialplan_destination = "false"
            dialplan_continue = "false"
            dialplan_order = "100"
            dialplan_enabled = "true"
            dialplan_description = "$CustomerName - Full National Number Dialplan"
            dialplan_xml = $dialplanXml
        }
    )
}

$json = $data | ConvertTo-Json

Write-Host "Creating Dialplan"
$result = Invoke-FusionPbxApi -DomainName $BaseDomainName -ApiVersion $ApiVersion -ApiMethod "dialplans" -Key $APIKey -Method POST -Body $json
