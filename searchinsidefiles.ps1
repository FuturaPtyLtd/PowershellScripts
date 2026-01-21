param (
    [Parameter(Mandatory = $true)]
    [String]$Folder,
    [Parameter(Mandatory = $true)]
    [String]$Keyword
)
function Search-Keyword {
    param (
        [Parameter(Mandatory = $true)]
        [String]$Folder,
        [Parameter(Mandatory = $true)]
        [String]$Keyword
    )
    # Get all files in the current folder
    $files = Get-ChildItem -Path $folder -File
    # Iterate through each file
    foreach ($file in $files) {
        $fileContent = Get-Content $file.FullName -Raw
        # Check if keyword exists within file contents
        if ($fileContent.Contains($Keyword)) {
            Write-Output "Keyword '$Keyword' found in file: $($file.FullName)"
        }
    }
    # Get all subfolders in the current folder
    $subfolders = Get-ChildItem -Path $folder -Directory
    # Recursively search in each subfolder
    foreach ($subfolder in $subfolders) {
        Search-Keyword -Folder $subfolder.FullName -Keyword $Keyword
    }
}

# Call the function to initiate the search
Search-Keyword -Folder $Folder -Keyword $Keyword
