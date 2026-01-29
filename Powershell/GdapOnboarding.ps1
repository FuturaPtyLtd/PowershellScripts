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
	Write-Host "                    GDAP Onboarding Script                                  "
	Write-Host "                    By Chris Condy-Pollett                                  "
	Write-Host "----------------------------------------------------------------------------"
	Write-Host ""	
}
function Add-GdapAccessAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$RelationshipId,

        [Parameter(Mandatory)]
        [string]$GroupId,

        [Parameter(Mandatory)]
        [string]$RoleDefinitionId
    )

    $uri = "https://graph.microsoft.com/v1.0/tenantRelationships/delegatedAdminRelationships/$RelationshipId/accessAssignments"

    $body = @{
        accessContainer = @{
            accessContainerId   = $GroupId
            accessContainerType = "securityGroup"
        }
        accessDetails = @{
            unifiedRoles = @(
                @{ roleDefinitionId = $RoleDefinitionId }
            )
        }
    }

    Invoke-MgGraphRequest `
        -Method POST `
        -Uri $uri `
        -Body ($body | ConvertTo-Json -Depth 5)
}


DisplayLogo

Disconnect-MgGraph -ErrorAction SilentlyContinue
Write-Output "Disconnected from Graph"

Connect-MgGraph -Scopes 'DelegatedAdminRelationship.ReadWrite.All' -Environment Global -NoWelcome

$account = Get-MgContext
Write-Output 'Connected to Graph on Account: '$account.Account

Write-Output "You can find the admin relationship by going within the admin relationship its the last guid in the URL eg"
Write-Output "https://partner.microsoft.com/dashboard/v2/customers/d1e8d542-256b-4e4b-aede-0dc2b010b310/adminrelationships/16d20ed3-cad0-457d-9833-9012837d852c-66089676-abaf-4914-8512-6fd1ec20f03d"
Write-Output "The correct value is 16d20ed3-cad0-457d-9833-9012837d852c-66089676-abaf-4914-8512-6fd1ec20f03d"
$relationshipId = Read-Host "Admin relationship guid:"
$Assignments = @(
    @{ GroupId = "471eb442-48f0-4a84-b0e4-befabc6a442c"; RoleDefinitionId = "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3" } # Application Administrator
    @{ GroupId = "1fd3b5a5-f730-436b-819f-8f612e62d2d6"; RoleDefinitionId = "cf1c38e5-3621-4004-a7cb-879624dced7c" } # Application Developer
    @{ GroupId = "26f85b5a-61e7-4186-b1bf-71f8491eac19"; RoleDefinitionId = "c430b396-e693-46cc-96f3-db01bf8bb62a" } # Attack Simulation Administrator
    @{ GroupId = "714a1f55-17c0-4395-9806-83c8772786ea"; RoleDefinitionId = "c4e39bd9-1100-46d3-8c65-fb160da0071f" } # Authentication Administrator
    @{ GroupId = "f7d0dfcf-03e9-4eef-a7eb-4fdc73adbd39"; RoleDefinitionId = "0526716b-113d-4c15-b2c8-68e3c22b9f80" } # Authentication Policy Administrator
    @{ GroupId = "15ad56f4-5414-4bab-ad21-f158704ec954"; RoleDefinitionId = "158c047a-c907-4556-b7ef-446551a6b5f7" } # Cloud Application Administrator
    @{ GroupId = "7c35d91a-6d2a-415e-8800-09693e78f1db"; RoleDefinitionId = "7698a772-787b-4ac8-901f-60d6b08affd2" } # Cloud Device Administrator
    @{ GroupId = "d5644ebc-7610-432b-bb3a-fbacceecb148"; RoleDefinitionId = "17315797-102d-40b4-93e0-432062caca18" } # Compliance Administrator
    @{ GroupId = "5e05bd28-b387-4d9e-bbd2-fd3dafb418fb"; RoleDefinitionId = "e6d1a23a-da11-4be4-9570-befc86d067a7" } # Compliance Data Administrator
    @{ GroupId = "e330230d-07eb-4e6e-8abc-6ac3b28f14d8"; RoleDefinitionId = "b1be1c3e-b65d-4f19-8427-f6fa0d97feb9" } # Conditional Access Administrator
    @{ GroupId = "41aff11f-934a-4ce2-919b-1c8986d2640b"; RoleDefinitionId = "88d8e3e3-8f55-4a1e-953a-9b9898b8876b" } # Directory Readers
    @{ GroupId = "4d1b7f80-12f9-42ce-b145-7982a0b7d037"; RoleDefinitionId = "9360feb5-f418-4baa-8175-e2a00bac4301" } # Directory Writers
	@{ GroupId = "6f96f551-8756-426f-8900-4b28373cfa60"; RoleDefinitionId = "8329153b-31d0-4727-b945-745eb3bc5f31" } # Domain Name Administrator
    @{ GroupId = "35beea1b-5f54-4b03-b11f-c32119dc484b"; RoleDefinitionId = "44367163-eba1-44c3-98af-f5787879f96a" } # Dynamics 365 Administrator
    @{ GroupId = "559c826d-d64c-4368-9b3d-df8492bb3471"; RoleDefinitionId = "9f06204d-73c1-4d4c-880a-6edb90606fd8" } # Entra Joined Device Local Admin
    @{ GroupId = "5cf259a9-ed07-4dce-bd42-27dee260dd92"; RoleDefinitionId = "29232cdf-9323-42fd-ade2-1d097af3e4de" } # Exchange Administrator
    @{ GroupId = "bfc0cde5-31ef-4417-b2b9-248f48cdb318"; RoleDefinitionId = "31392ffb-586c-42d1-9346-e59415a2cc4e" } # Exchange Recipient Administrator
    @{ GroupId = "aaa67681-0354-4ecc-ad4b-1aefda11b302"; RoleDefinitionId = "be2f45a1-457d-42af-a067-6ec1fa63bc45" } # External Identity Provider Administrator
    @{ GroupId = "a292b49f-0866-4066-85fb-e5526a2da082"; RoleDefinitionId = "a9ea8996-122f-4c74-9520-8edcd192826c" } # Fabric Administrator
    @{ GroupId = "3eef3b65-b131-4b68-95f2-f414a5172029"; RoleDefinitionId = "f2ef992c-3afb-46b9-b7cf-a126ee74c451" } # Global Reader
    @{ GroupId = "95c18d98-ee83-4d3d-8b68-da0dd238d0dc"; RoleDefinitionId = "fdd7a751-b60b-444a-984c-02652fe8fa1c" } # Groups Administrator
    @{ GroupId = "f1c3fc08-6c6b-4b2d-a3ae-b4cc67f4b04f"; RoleDefinitionId = "729827e3-9c14-49f7-bb1b-9608f156bbb8" } # Helpdesk Administrator
    @{ GroupId = "1e885863-59ec-4cff-8040-f60e5de0336f"; RoleDefinitionId = "8ac3fc64-6eca-42ea-9e69-59f4c7b60eb2" } # Hybrid Identity Administrator
    @{ GroupId = "47aa7326-2c4b-4790-82df-b8d61e2629a1"; RoleDefinitionId = "45d8d3c5-c802-45c6-b32a-1d70b5e1e86e" } # Identity Governance Administrator
    @{ GroupId = "ad4abd4b-2e81-4852-b61f-144504a65c6f"; RoleDefinitionId = "3a2c62db-5318-420d-8d74-23affee5d9d5" } # Intune Administrator
    @{ GroupId = "01a95135-f1ca-4056-a15b-99beee97affd"; RoleDefinitionId = "4d6ac14f-3453-41d0-bef9-a3e0c569773a" } # License Administrator
    @{ GroupId = "9e91b22c-f5d4-4c66-a4ab-51ba50d55ea3"; RoleDefinitionId = "790c1fb9-7f7d-4f88-86a1-ef1f95c05c1b" } # Message Center Reader
    @{ GroupId = "6642d68f-3aa5-49ad-aaf8-d23e3bb6135d"; RoleDefinitionId = "d37c8bed-0711-4417-ba38-b4abe66ce4c2" } # Network Administrator
    @{ GroupId = "73cfb8ed-402c-492b-a89a-0965b874b6ce"; RoleDefinitionId = "2b745bdf-0803-4d80-aa65-822c4493daac" } # Office Apps Administrator
    @{ GroupId = "7bf3c2ec-d1c4-48c6-aee6-e9255b0609bd"; RoleDefinitionId = "11648597-926c-4cf3-9c36-bcebb0ba8dcc" } # Power Platform Administrator
    @{ GroupId = "b15770a7-f126-4fd1-97e3-2d3de01c0f0b"; RoleDefinitionId = "644ef478-e28f-4e28-b9dc-3fdde9aa0b1f" } # Printer Administrator
    @{ GroupId = "02c4c7ab-664f-47bf-aebe-b42a968e0af6"; RoleDefinitionId = "7be44c8a-adaf-4e2a-84d6-ab2649e08a13" } # Privileged Authentication Administrator
    @{ GroupId = "b7eec1d4-cccb-4e23-b7d8-89f53c105cfd"; RoleDefinitionId = "e8611ab8-c189-46e8-94e1-60213ab1f814" } # Privileged Role Administrator
    @{ GroupId = "015a955e-1438-457b-9f52-9173509d1711"; RoleDefinitionId = "4a5d8f65-41da-4de4-8968-e035b65339cf" } # Reports Reader
    @{ GroupId = "623199a5-04ba-4e63-bd48-71c0632b8590"; RoleDefinitionId = "194ae4cb-b126-40b2-bd5b-6091b380977d" } # Security Administrator
    @{ GroupId = "f99d9a6a-9272-490d-9046-eda308fea9e0"; RoleDefinitionId = "5f2222b1-57c3-48ba-8ad5-d4759f1fde6f" } # Security Operator
    @{ GroupId = "ba4f0e94-58f6-439f-aad7-ff8da11498dd"; RoleDefinitionId = "5d6b6bb7-de71-4623-b4af-96380a352509" } # Security Reader
    @{ GroupId = "68467bd1-0475-484d-989b-004c2269de94"; RoleDefinitionId = "f023fd81-a637-4b56-95fd-791ac0226033" } # Service Support Administrator
    @{ GroupId = "f5be0dc4-118c-4083-bf71-c03d7da92f35"; RoleDefinitionId = "f28a1f50-f6e7-4571-818b-6a12f2af6b6c" } # SharePoint Administrator
    @{ GroupId = "49789b4a-f2f4-4a0e-ba82-eb125e524708"; RoleDefinitionId = "69091246-20e8-4a56-aa4d-066075b2a7a8" } # Teams Administrator
    @{ GroupId = "79083d08-5d79-408f-8bf8-0a7a27b52db2"; RoleDefinitionId = "baf37b3a-610e-45da-9e62-d9d1e5e8914b" } # Teams Communications Administrator
    @{ GroupId = "d9b59607-1aea-4c13-9fd9-e142b1ae39a3"; RoleDefinitionId = "f70938a0-fc10-4177-9e90-2178f8765737" } # Teams Communications Support Engineer
    @{ GroupId = "eb52c099-5616-4ba8-bc2c-4b19afe03d96"; RoleDefinitionId = "75934031-6c7e-415a-99d7-48dbd49e875e" } # Usage Summary Reports Reader
    @{ GroupId = "525af1fc-d7d1-4e7f-8596-56c610a98c9f"; RoleDefinitionId = "fe930be7-5e62-47db-91af-98c3a49a38b1" } # User Administrator
    @{ GroupId = "5b73e493-6267-4ca2-896c-69026e046d31"; RoleDefinitionId = "32696413-001a-46ae-978c-ce0f6b3620d2" } # Windows Update Deployment Administrator
)


foreach ($a in $assignments) {
    Add-GdapAccessAssignment `
        -RelationshipId $relationshipId `
        -GroupId $a.GroupId `
        -RoleDefinitionId $a.RoleId
}