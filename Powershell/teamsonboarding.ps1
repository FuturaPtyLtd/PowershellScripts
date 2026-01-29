function CreateAndVerifyDomain {
	try {
		Get-AZTenant -ErrorAction STOP
	} catch {
		if(-not (Get-Module AzureAD -ListAvailable)){
			Write-Host "Installing AzureAD Module onto your PC" -ForegroundColor red
			Install-Module AzureAD -Force
			Write-Host "Succesfully Installed" -ForegroundColor green
		}
		else
		{
			Write-Host "AzureAD Module found, no need to install." -ForegroundColor green
		}
	}

    $existingdomains = Get-AzureADDomain
	$founddomain = ""
	foreach($edomain in $existingdomains)
	{
		if($edomain.Name -Match ".aue-1.audiocodes-ap-lc.com")
		{
			$founddomain = $edomain.Name
		}
	}
	
	if($founddomain -eq "")
	{
		$selecteddomain = Read-Host "Enter the start of the domain you would like to add EG demo01"
		$founddomain = $selecteddomain + ".aue-1.audiocodes-ap-lc.com" 
		New-AzureADDomain -Name $founddomain
	}
	else
	{
		Write-Host "Audiocodes domain was already found within the tenant value: $founddomain" -ForegroundColor green
	}

	$dnsrecords = Get-AzureADDomainVerificationDnsRecord -Name $founddomain

	foreach($dnsrecord in $dnsrecords)
	{
		if($dnsrecord.RecordType -eq "Txt" -And $dnsrecord.Text -Match "MS=")
		{
			Write-Host "TXT recorded which needs to be added is: " $dnsrecord.Text
		}
	}
	
	try {
		Confirm-AzureADDomain -Name $founddomain
		Write-Host "Domain now verified"
	}
	catch {
		$errorMessage = $_.Exception.Message
		if ($errorMessage -match "Message: Domain verification failed with the following error:(.+?)\n") {
			Write-Host $matches[1] -ForegroundColor red
		}
		elseif  ($errorMessage -match "Message: Domain is already verified."){
			Write-Host $matches[0] -ForegroundColor green
		}
		else {
			Write-Host $errorMessage -ForegroundColor red
		}
	}
}

function CreateActivationUser {
	try {
		Get-AZTenant -ErrorAction STOP
	} catch {
		if(-not (Get-Module AzureAD -ListAvailable)){
			Write-Host "Installing AzureAD Module onto your PC" -ForegroundColor red
			Install-Module AzureAD -Force
			Write-Host "Succesfully Installed" -ForegroundColor green
		}
		else
		{
			Write-Host "AzureAD Module found, no need to install." -ForegroundColor green
		}
		
	}

	$existingdomains = Get-AzureADDomain
	$founddomain = ""
	foreach($edomain in $existingdomains)
	{
		if($edomain.Name -Match ".aue-1.audiocodes-ap-lc.com")
		{
			$founddomain = $edomain.Name
		}
	}

	$activationupn = "FTGActivation@" + $founddomain
	
	try {
		$activationuser = Get-AzureADUser -ObjectId $activationupn
		Write-Host "Existing Activation User already exists" -ForegroundColor green
	}
	catch {
		Write-Host "Creating Activation User now"

		$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
		$PasswordProfile.Password = "L95lW77BcuoP-omTXtEJEtAceWaekYBr"
		New-AzureADUser -DisplayName "FTGActivation" -PasswordProfile $PasswordProfile -UserPrincipalName $activationupn -AccountEnabled $true -MailNickName "FTGActivation" -UsageLocation "AU"
	}

	$licenses = Get-MgSubscribedSKU -All -Property @("SkuId", "ConsumedUnits", "PrepaidUnits", "SkuPartNumber") | Select-Object *, @{Name = "ActiveUnits"; Expression = { ($_ | Select-Object -ExpandProperty PrepaidUnits).Enabled } } | Select-Object SkuId, ActiveUnits, ConsumedUnits, SkuPartNumber
	$licensetouse

	foreach($license in $licenses)
	{
		if($license.SkuPartNumber -Match "PHONESYSTEM_VIRTUALUSER")
		{
			if($license.ConsumedUnits -lt $license.ActiveUnits)
			{
				$licensetouse = $license
			}
		}
	}
4
	if($licensetouse -eq "" -or $licensetouse -eq $null)
	{
		Write-Host "Unable to find teams calling license with enough spare licenses" -ForegroundColor red
	} else {
		Set-MgUserLicense -UserId $activationupn -AddLicenses @{SkuId = $licensetouse.SkuId} -RemoveLicenses @()
	}
}
function CreateTeamsCallingRoutes {
	if(-not (Get-Module MicrosoftTeams -ListAvailable)){
		Write-Host "Installing MicrosoftTeams Module onto your PC" -ForegroundColor red
		Install-Module MicrosoftTeams -Force
		Write-Host "Succesfully Installed" -ForegroundColor green
	}
	else
	{
		Write-Host "MicrosoftTeams Module found, no need to install." -ForegroundColor green
	}

	$pstnusage = Get-CsOnlinePstnUsage
	$checkpstnusage = $pstnusage.Usage | where {$_ -eq "ftg-pu-unrestricted"}

	if($checkpstnusage -eq $null)
	{
		Write-Host "Global PSTN usage hasn't been added, adding now" -ForegroundColor green
		Set-CsOnlinePstnUsage -Identity Global -Usage @{Add="ftg-pu-unrestricted"}
	} else {
		Write-Host "Global PSTN already exists will not add" -ForegroundColor green
	}

	$existingdomains = Get-AzureADDomain
	$founddomain = ""
	foreach($edomain in $existingdomains)
	{
		if($edomain.Name -Match ".aue-1.audiocodes-ap-lc.com")
		{
			$founddomain = $edomain.Name
		}
	}

	#Validate Voice Route
	$voiceroutes = Get-CsOnlineVoiceRoute -Identity ftg-vr-unrestricted -ErrorAction SilentlyContinue
	if ($null -eq $voiceroutes){
		Write-Host "Online voice route wasn't found adding now" -ForegroundColor green
		New-CsOnlineVoiceRoute -Identity "ftg-vr-unrestricted" -NumberPattern "^(.*)$" -OnlinePstnGatewayList $founddomain -Priority 1 -OnlinePstnUsages "ftg-pu-unrestricted"
	} else {
		Write-Host "Voice Route already exists will not add" -ForegroundColor green
	}

	$VoiceRoutePolicies = Get-CsOnlineVoiceRoutingPolicy 
	$VoiceRoutePolicy = $VoiceRoutePolicies.Identity | where {$_ -eq "Tag:ftg-vrp-unrestricted"}

	if($VoiceRoutePolicy -eq $null)
	{
		Write-Host "Voice Routing Policy doesn't existing creating now" -ForegroundColor green
		New-CsOnlineVoiceRoutingPolicy "ftg-vrp-unrestricted" -OnlinePstnUsages "ftg-pu-unrestricted"
	} else {
		Write-Host "Voice Routing Policy already exists will not add" -ForegroundColor green
	}

}
function Get-UsersWithLicense {
    param (
        [Parameter(Mandatory=$true)]
        [string]$LicenseSku
    )

    # Get all users
    $users = Get-AzureADUser -All $true
    
    # Filter users based on the license SKU
    $licensedUsers = @()
    foreach ($user in $users) {
        $assignedLicenses = Get-AzureADUserLicenseDetail -ObjectId $user.ObjectId
        foreach ($license in $assignedLicenses) {
            if ($license.SkuPartNumber -eq $LicenseSku) {
                $licensedUsers += $user
            }
        }
    }
	$final = @()
	foreach($user in $licensedUsers)
	{
		$phonedata = Get-CsPhoneNumberAssignment -AssignedPstnTargetId $user.UserPrincipalName
		$final += [PSCustomObject]@{
			UPN     = $user.UserPrincipalName
			PhoneNumber = $phonedata.TelephoneNumber
		}
	}

    return $final
}
function ExportUsersWithCalling {
	if(-not (Get-Module MicrosoftTeams -ListAvailable)){
		Write-Host "Installing MicrosoftTeams Module onto your PC" -ForegroundColor red
		Install-Module MicrosoftTeams -Force
		Write-Host "Succesfully Installed" -ForegroundColor green
	}
	else
	{
		Write-Host "MicrosoftTeams Module found, no need to install." -ForegroundColor green
	}

	$users = @()
	$users += Get-UsersWithLicense "MCOEV"
	$users += Get-UsersWithLicense "MCOCAP"
	$users += Get-UsersWithLicense "M365EDU_A5_FACULTY"
	$users += Get-UsersWithLicense "PHONESYSTEM_VIRTUALUSER"
	$users | Export-Csv -Path ".\exported_users.csv" -NoTypeInformation
	Write-Host "Users list has been exported to a csv called exported_users.csv from here you need to add another column called PhoneNumbers and add the numbers in the format 61xxxxxxxxx eg 61290098800. Also make sure to delete any additional users that are not required"-ForegroundColor green
}
function GetTenantID {
	try {
		Get-AZTenant -ErrorAction STOP
	} catch {
		if(-not (Get-Module AzureAD -ListAvailable)){
			Write-Host "Installing AzureAD Module onto your PC" -ForegroundColor red
			Install-Module AzureAD -Force
			Write-Host "Succesfully Installed" -ForegroundColor green
		}
		else
		{
			Write-Host "AzureAD Module found, no need to install." -ForegroundColor green
		}
		
	}
	$tenant = Get-AZTenant
	Write-Host "Tenant ID: " $tenant.ID
}
function ImportUsers {
	if(-not (Get-Module MicrosoftTeams -ListAvailable)){
		Write-Host "Installing MicrosoftTeams Module onto your PC" -ForegroundColor red
		Install-Module MicrosoftTeams -Force
		Write-Host "Succesfully Installed" -ForegroundColor green
	}
	else
	{
		Write-Host "MicrosoftTeams Module found, no need to install." -ForegroundColor green
	}

	$filename = Read-Host "Enter the name of the file to import"
	$fullPath = Join-Path -Path (Get-Location) -ChildPath $filename
	$CSVData = Import-Csv -Path $fullPath

	foreach ($user in $CSVData)
	{
		$number = "+"+$user.PhoneNumber
		$upn = $user.UPN

		Write-Host "Activating User " + $upn + " with phone number " $number 
		Set-CsPhoneNumberAssignment -identity $upn -PhoneNumber $number -PhoneNumberType DirectRouting
		Grant-CsOnlineVoiceRoutingPolicy -Identity $upn -PolicyName ftg-vrp-unrestricted
	}
}
function UpdateSpecificUser {
	$upn = Read-Host "Enter the UPN of the user you wish to update"
	$number = Read-Host "Enter the number for the user enter the number is the format +61 eg +61290098800"
	$phonenumber = $number

	Set-CsPhoneNumberAssignment -identity $upn -PhoneNumber $phonenumber -PhoneNumberType DirectRouting
	Grant-CsOnlineVoiceRoutingPolicy -Identity $upn -PolicyName ftg-vrp-unrestricted
}
function UpdateCallPolicyOnExistingUsers{
	if(-not (Get-Module MicrosoftTeams -ListAvailable)){
		Write-Host "Installing MicrosoftTeams Module onto your PC" -ForegroundColor red
		Install-Module MicrosoftTeams -Force
		Write-Host "Succesfully Installed" -ForegroundColor green
	}
	else
	{
		Write-Host "MicrosoftTeams Module found, no need to install." -ForegroundColor green
	}
	$users = @()
	$users += Get-UsersWithLicense "MCOEV"
	$users += Get-UsersWithLicense "MCOCAP"
	$users += Get-UsersWithLicense "M365EDU_A5_FACULTY"
	$users += Get-UsersWithLicense "PHONESYSTEM_VIRTUALUSER"

	$users | Select-Object UPN

	foreach ($user in $users)
	{
		$upn = $user.UPN
		Write-Host "Updating User " + $upn
		Grant-CsOnlineVoiceRoutingPolicy -Identity $upn -PolicyName ftg-vrp-unrestricted
	}
}
function SetupUsers{

		Write-Host "1. Export list of users with teams calling license" -ForegroundColor green
		Write-Host "2. Import New Users with phone numbers" -ForegroundColor green
		Write-Host "3. Update Call Routing Policy on existing Users" -ForegroundColor green
		Write-Host "4. Update a specific user / resource account" -ForegroundColor green
		Write-Host "5. Return to main menu" -ForegroundColor green
		$option = Read-Host "Enter the number of your choice"

		# Process the user's selection
		switch ($option) {
			1 { ExportUsersWithCalling }
			2 { ImportUsers }
			3 { UpdateCallPolicyOnExistingUsers }
			4 {UpdateSpecificUser}
			5 { Exit }
			default { Write-Host "Invalid selection. Please enter 1, 2, 3, 4, 5, 6, 7" }
		}
}
function Instructions{
	Write-Host "Welcome to the FTG onboarding script for Microsoft Teams!" -ForegroundColor green
	Write-Host "Press the option below for what instructions you would like to know" -ForegroundColor green
	Write-Host "0. Requirements before you start" -ForegroundColor green
	Write-Host "1. Instructions about how to setup in audiocodes sbc" -ForegroundColor green
	Write-Host "2. Instructions about this powershell script" -ForegroundColor green
	Write-Host "3. Back to the start" -ForegroundColor green

	$option = Read-Host "Enter your choice:"

	# Process the user's selection
	switch ($option) {
		0 { Requirements }
		1 { AudioCodesInstructions }
		2 { AboutThisScript }
		3 { MainMenu }
		default { Write-Host "Invalid selection. Please enter 1, 2, 3, 4, 5, 6, 7" }
	}
}
function Requirements{
	Write-Host "Before going ahead with this script you will need the below" -ForegroundColor green
	Write-Host "1. The senior team to have onboarded the customer onto FTG's SBC" -ForegroundColor green
	Write-Host "2. The senior team to provide phone numbers per user" -ForegroundColor green
	Write-Host "3. The senior team to provide a port number to connect up the audiocodes sbc" -ForegroundColor green
	Write-Host "4. The customer has teams licenses for users and a spare Teams Phone Resource Account (free) for the user we need to create within their tenant" -ForegroundColor green
	Write-Host "5. For step 5 of this script (Export list of users with teams calling license) this only detects users with the license Microsoft Teams Phone Standard, if the customer is using alternative licenses you will need to create your own CSV for the import" -ForegroundColor red
}
function AboutThisScript{
	Write-Host "This lovely script was designed with the intention to automate the onboarding of teams calling for customers easy" -ForegroundColor green
	Write-Host "Step by Step the following needs to be done" -ForegroundColor green
	Write-Host "1. Complete Pre-Requirements" -ForegroundColor green
	Write-Host "2. Complete Audiocodes Onboarding" -ForegroundColor green
	Write-Host "3. Add the audiocodes domain into the customers tenant (option 2)" -ForegroundColor green
	Write-Host "4. Inform Audiocodes of the TXT record so they can add on their end " -ForegroundColor green
	Write-Host "5. Verify the domain name (option 2)" -ForegroundColor green
	Write-Host "6. Create a user with the audiocodes domain name this validates the use of the domain and also activates teams pbx as it assigns a license to the user (option 3)" -ForegroundColor green
	Write-Host "7. Sets up Global calling routes so that when teams users make calls it routes out to the Audiocodes SBC (option 4)" -ForegroundColor green
	Write-Host "8. Exports a list of users with the license Microsoft Teams Phone Standard (option 5)" -ForegroundColor green
	Write-Host "8. Imports a list which has a users UPN and a phone number then links them together within microsoft teams (option 6)" -ForegroundColor green
}
function AudioCodesInstructions {
	
	Write-Host "The below will provide you with instructions on how to setup a new customer with Audiocodes Live" -ForegroundColor green
	Write-Host "1. Goto the following website https://apac-ltc.audiocodesaas.com/ and sign in with your FTG email address" -ForegroundColor green
	Write-Host "2. On the top panel select network, then press customer actions, direct routing, add customer" -ForegroundColor green
	Write-Host "3. Fill in customer details as below: " -ForegroundColor green
	Write-Host "	3a. Full Name: Enter the name of the customer " -ForegroundColor green
	Write-Host "	3b. Short Name: Enter a short version of the customers name. Must be between 3-15 characters and must start with FTG_ " -ForegroundColor green
	Write-Host "	3c. License Type: For majority of installs this is Hosted Essentials however this can change verify with senior team if unsure." -ForegroundColor green
	Write-Host "	3d. TenantID: Enter customers TenantID you can get this from this powershell script option 1" -ForegroundColor green
	Write-Host "4. Enter in the SBC Details as below:" -ForegroundColor green
	Write-Host "	4a. Online PSTN Gateway: Think up a domain name for this customer then add .aue-1.audiocodes-ap-lc.com so for example for demo01 it was ftgdemo01.aue-1.audiocodes-ap-lc.com REMEMBER WHAT YOU ENTERED FOR LATER THIS IS IMPORTANT" -ForegroundColor green
	Write-Host "	4b. SBC Configuration: BYOC" -ForegroundColor green
	Write-Host "	4c. Region: AC_LC_APAC_AUE1_SBC" -ForegroundColor green
	Write-Host "	4d. Carrier: BYOC" -ForegroundColor green
	Write-Host "5. Number prefix, just press next on this screen we will do later." -ForegroundColor green
	Write-Host "6. SBC Setup" -ForegroundColor green
	Write-Host "	6a. SBC Onboarding Script: 4001_FTG_SBC_Hosted_DirectRouting_Onboarding" -ForegroundColor green
	Write-Host "	6b. SBC Cleanup Script: 4001_FTG_SBC_Hosted_DirectRouting_Cleanup" -ForegroundColor green
	Write-Host "	6c. Variable port number: This will be provided by the senior team when FTG's SBC is setup" -ForegroundColor green
	Write-Host "7. Wait for it to deploy then customer actions, direct routing, edit customer" -ForegroundColor green
	Write-Host "8. Click Manage SBC prefixes" -ForegroundColor green
	Write-Host "9. Fill in details for phone numbers" -ForegroundColor green
	Write-Host "	9a. Select Dial Plan: CustDialPlan" -ForegroundColor green
	Write-Host "	9b. Telephone Number Prefix: Add a number you wish to add eg +612xxxxxxxx repeat for each number" -ForegroundColor green
	Write-Host "	9c. Scroll down and press save" -ForegroundColor green
}
function MainMenu {
	While($true)
	{
			
		Write-Host "Please select an option:"
		Write-Host "0. Instructions"
		Write-Host "1. Get Tenant ID"
		Write-Host "2. Add/Verify Audiocodes Domain"
		Write-Host "3. Create Activation User"
		Write-Host "4. Setup Global Teams Calling Routes"
		Write-Host "5. Setup Users"

		Write-Host "6. Exit"

		# Capture user input
		$option = Read-Host "Enter the number of your choice"

		# Process the user's selection
		switch ($option) {
			0 { Instructions }
			1 { GetTenantID }
			2 { CreateAndVerifyDomain }
			3 { CreateActivationUser }
			4 { CreateTeamsCallingRoutes }
			5 {SetupUsers}
			6 { Exit }
			default { Write-Host "Invalid selection. Please enter 1, 2, 3, 4, 5, 6, 7" }
		}
	}
}
function DisplayLogo {
	Write-Host "----------------------------------------------------------------------------"
	Write-Host "                                                     _,__        .:         " -ForegroundColor green
	Write-Host "                                                    <*  /        | \        " -ForegroundColor green
	Write-Host " 8888888888 88888888888 .d8888b.                .-./     |.     :  :,       " -ForegroundColor green
	Write-Host " 888            888    d88P  Y88b              /           '-._/     \_     " -ForegroundColor green
	Write-Host " 888            888    888    888             /                '       \    " -ForegroundColor green
	Write-Host " 8888888        888    888                  .'                         *:   " -ForegroundColor green
	Write-Host " 888            888    888  88888        .-'                             ;  " -ForegroundColor green
	Write-Host " 888            888    888    888        |                               |  " -ForegroundColor green
	Write-Host " 888            888    Y88b  d88P        \                              /   " -ForegroundColor green
	Write-Host " 888            888     Y8888P88          |                           */    " -ForegroundColor green
	Write-Host "                                           \*        __.--._          /     " -ForegroundColor green
	Write-Host "                                            \     _.'       \:.       |     " -ForegroundColor green
	Write-Host "                                            >__,-'             \_/*_.-'     " -ForegroundColor green 
	Write-Host "                                                                            "
	Write-Host "                    Microsoft Teams Onboarding Script                       "
	Write-Host "                    By Chris Condy-Pollett                                  "
	Write-Host "----------------------------------------------------------------------------"
	Write-Host ""	
}

DisplayLogo

Connect-AzureAD
Connect-MicrosoftTeams
Connect-MgGraph -Scopes User.ReadWrite.All, Organization.Read.All

MainMenu
