$Global:LogFilePathSWF2 = "C:\OSDCloud\Logs\Save-Webfile2.log"
$Global:LogFileSizeSWF2   = "40"

function Start-CMTraceLog {
    # Checks for path to log file and creates if it does not exist
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $indexoflastslash = $Path.lastindexof('\')
    $directory = $Path.substring(0, $indexoflastslash)

    if (!(test-path -path $directory)){
        New-Item -ItemType Directory -Path $directory
    }
    else{
        # Directory Exists, do nothing    
    }
}


function Write-CMTraceLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$LogPath = $($script:LogFilePathSWF2),
            
        [Parameter()]
        [ValidateSet(1, 2, 3)]
        [int]$LogLevel = 1,

        [Parameter()]
        [string]$Component,

        [Parameter()]
        [ValidateSet('Info','Warning','Error')]
        [string]$Type
    )
    Switch ($Type) {
        Info {$LogLevel = 1}
        Warning {$LogLevel = 2}
        Error {$LogLevel = 3}
    }
    # Get Date message was triggered
    $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
    $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
    $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), $Component, $LogLevel
    $Line = $Line -f $LineFormat
    # Write new line in the log file
    Add-Content -Value $Line -Path $LogPath
    # Roll log file over at size threshold
    if ((Get-Item $Global:LogFilePathSWF2).Length / 1KB -gt $Global:LogFileSizeSWF2) {
        $log = $Global:LogFilePathSWF2
        Remove-Item ($log.Replace(".log", ".lo_"))
        Rename-Item $Global:LogFilePathSWF2 ($log.Replace(".log", ".lo_")) -Force
    }
} 


Start-CMTraceLog -Path $Global:LogFilePathSWF2
Write-CMTraceLog -Message "Starting Save-Webfile2 Script..." -Type "Info" -Component "Save-Webfile"
<#
.SYNOPSIS
    Resolves the final URL after following all HTTP redirects.

.DESCRIPTION
    This function takes a URL and follows any HTTP redirects (301, 302, etc.) to determine the final destination URL.
    It's useful for checking where shortened URLs or redirected links ultimately lead.

.PARAMETER Url
    The initial URL to check for redirects. This can be a standard URL or a shortened URL.

.EXAMPLE
    PS C:\> Get-FinalRedirectUrl -Url "https://bit.ly/example"
    Returns the final destination URL after following all redirects from the bit.ly shortened URL.

.EXAMPLE
    PS C:\> "https://tinyurl.com/sample", "http://goo.gl/example" | Get-FinalRedirectUrl
    Processes multiple URLs from the pipeline and returns their final destination URLs.

.INPUTS
    System.String
    You can pipe string values representing URLs to this function.

.OUTPUTS
    System.String
    Returns the final URL as a string after following all redirects.

.NOTES
    Author: Peter Rinnenbach
    Version: 1.1
    Date: 02/08/2025
    Requirements:
    - Internet access to follow the URLs
    - .NET Framework for WebRequest functionality

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.net.webrequest
.LINK
    about_Redirection
#>
function Get-FinalRedirectUrl {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Url
    )

    Begin {
        [String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Host "${CmdletName}"
    }

    Process {
        try {
            $req = [System.Net.WebRequest]::Create($Url)
            $req.Method = 'GET'
            $req.AllowAutoRedirect = $false
            
            $resp = $req.GetResponse()
            
            if ($resp.ResponseUri.OriginalString -eq $Url) {
                Write-CMTraceLog -Message "Final url: $Url" -Type "Info" -Component "${CmdletName}"
                return $Url
            } else {
                #Write-Host "Redirected url: $($resp.ResponseUri.OriginalString)"
                Write-CMTraceLog -Message "Redirected url: $($resp.ResponseUri.OriginalString)" -Type "Info" -Component "${CmdletName}"
                return $resp.ResponseUri.OriginalString
            }
        }
        catch {
            #Write-Host "Error processing URL '$Url': $_"
            Write-CMTraceLog -Message "Error processing URL: '$Url' : $_" -Type "Error" -Component "${CmdletName}"
            throw $_
        }
        finally {
            if ($resp) {
                $resp.Close()
                $resp.Dispose()
            }
        }
    }
}


<#
.SYNOPSIS
    Retrieves the size of a specified file in bytes.

.DESCRIPTION
    This function checks if a file exists at the given path and returns its size in bytes.
    If the file doesn't exist, it returns 0. The function is useful for file monitoring,
    logging, or conditional operations based on file size.

.PARAMETER FilePath
    The full path to the file whose size you want to check. This can be a relative or absolute path.

.EXAMPLE
    PS C:\> Get-CurrentFileSize -FilePath "C:\Temp\example.txt"
    Returns the size of example.txt in bytes.

.EXAMPLE
    PS C:\> "C:\Temp\file1.txt", "C:\Temp\file2.txt" | Get-CurrentFileSize
    Returns sizes for multiple files piped to the function.

.EXAMPLE
    PS C:\> if ((Get-CurrentFileSize -FilePath "report.pdf") -gt 1MB) { "File is large" }
    Demonstrates using the function in a conditional statement with size comparison.

.INPUTS
    System.String
    You can pipe file path strings to this function.

.OUTPUTS
    System.Int64
    Returns the file size in bytes as a 64-bit integer. Returns 0 if file doesn't exist.

.NOTES
    Author: Peter Rinnenbach
    Version: 1.1
    Date: 02/08/2025
    Requirements:
    - Requires PowerShell 3.0 or later
    - Requires read access to the target file

.LINK
    Get-Item
.LINK
    Test-Path
#>
function Get-CurrentFileSize {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [String]$FilePath
    )
    Begin{
        [String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
         Write-Host "${CmdletName}"
         Write-CMTraceLog -Message "${CmdletName}" -Type "Info" -Component "${CmdletName}"
    }
    Process{
        if (Test-Path -Path $FilePath) {
        Write-CMTraceLog -Message "Local file size: $((Get-Item -Path $FilePath).Length)" -Type "Info" -Component "${CmdletName}"
        return (Get-Item -Path $FilePath).Length
        } else {
            Write-CMTraceLog -Message "Local file size: 0" -Type "Warning" -Component "${CmdletName}"
            return 0
        }
    }
    
}


<#
.SYNOPSIS
    Validates the integrity of a downloaded file by checking its size and hash against expected values.

.DESCRIPTION
    This function performs a two-step verification of a downloaded file:
    1. Compares the actual file size against the expected size
    2. If size matches, verifies the file hash against the expected hash
    If either check fails, the downloaded file is automatically removed.

.PARAMETER fileSize
    The expected file size in bytes that the downloaded file should match.

.PARAMETER downloadedFilePath
    The path to the downloaded file that needs verification.
    Can be relative or absolute path.

.EXAMPLE
    PS C:\> Test-FileIntegrity -fileSize 1048576 -downloadedFilePath "C:\Downloads\package.zip"
    Verifies if package.zip is exactly 1MB in size and has the correct hash.

.EXAMPLE
    PS C:\> $expectedSize = 5242880 # 5MB
    PS C:\> $downloadedFile = "C:\Temp\setup.exe"
    PS C:\> Test-FileIntegrity $expectedSize $downloadedFile
    Shows positional parameter usage to verify setup.exe is 5MB with correct hash.

.INPUTS
    System.Int64
    You can pipe the expected file size to the fileSize parameter.

    System.String
    You can pipe the file path to the downloadedFilePath parameter.

.OUTPUTS
    System.Boolean
    Returns $true if both size and hash verification pass, otherwise throws an exception.

.NOTES
    Author: Peter Rinnenbach
    Version: 1.1
    Date: 02/08/2025
    Requirements:
    - Requires Test-FileHashIntegrity function for hash verification
    - Requires Remove-DownloadedFile function for cleanup
    - Requires Write-Log function for logging

.LINK
    Test-FileHashIntegrity
.LINK
    Get-FileHash
.LINK
    about_Hash_Tables
#>

function Test-FileSize {
     [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [ValidateScript({$_ -ge 0})]
        [int64]$fileSize,
        
        [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$downloadedFilePath
    )
    Begin {
        [String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Host ${CmdletName}
    }

    Process {
        try {
            #Write-Host "Starting file integrity check..."
            Write-CMTraceLog -Message "Starting file integrity check..." -Type "Info" -Component "${CmdletName}"
            # Convert and validate path
            $cpath = Convert-Path $downloadedFilePath
            if (-not (Test-Path -Path $cpath -PathType Leaf)) {
                Write-CMTraceLog -Message "File not found: $downloadedFilePath" -Type "Error" -Component "${CmdletName}"
                throw "File not found: $downloadedFilePath"
            }

            # Check file size
            $actualSize = (Get-Item -Path $cpath).Length
            Write-CMTraceLog -Message "Expected size: $fileSize bytes, Actual size: $actualSize bytes" -Type "Info" -Component "${CmdletName}"
            #Write-Host "Expected size: $fileSize bytes, Actual size: $actualSize bytes"
            
            if ($fileSize -ne $actualSize) {
                Remove-DownloadedFile -downloadedFilePath $downloadedFilePath
                Write-CMTraceLog -Message "File size mismatch. Expected: $fileSize bytes, Actual: $actualSize bytes" -Type "Error" -Component "${CmdletName}"
                throw "File size mismatch. Expected: $fileSize bytes, Actual: $actualSize bytes"
            }
            
            Write-CMTraceLog -Message "File size verification passed"  -Type "Info" -Component "${CmdletName}"
            #Write-Host "File size verification passed" 
            return $true
        }
        catch {
            Write-CMTraceLog -Message "File integrity check failed: $_"  -Type "Error" -Component "${CmdletName}"
            Write-Host "File integrity check failed: $_"
            throw $_
        }
    }
}

function Test-FileIntegrity {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
        [ValidateScript({$_ -ge 0})]
        [int64]$fileSize,
        
        [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$downloadedFilePath,
		[Parameter(Mandatory = $false)]
		[string]$ChecksumType,

		[Parameter(Mandatory = $false)]
		[string]$Checksum
    )

    Begin {
        [String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Host ${CmdletName}
    }

    Process {
        try {
            Write-CMTraceLog -Message "Starting file integrity check..."  -Type "Info" -Component "${CmdletName}"
            #Write-Host "Starting file integrity check..."
            
            # Convert and validate path
            $cpath = Convert-Path $downloadedFilePath
            if (-not (Test-Path -Path $cpath -PathType Leaf)) {
                Write-CMTraceLog -Message "File not found: $downloadedFilePath"  -Type "Error" -Component "${CmdletName}"
                throw "File not found: $downloadedFilePath"
            }

            # Check file size
            $actualSize = (Get-Item -Path $cpath).Length
            Write-CMTraceLog -Message "Expected size: $fileSize bytes, Actual size: $actualSize bytes"  -Type "Info" -Component "${CmdletName}"
            #Write-Host "Expected size: $fileSize bytes, Actual size: $actualSize bytes"
            
            if ($fileSize -ne $actualSize) {
                Remove-DownloadedFile -downloadedFilePath $downloadedFilePath
                Write-CMTraceLog -Message "File size mismatch. Expected: $fileSize bytes, Actual: $actualSize bytes" -Type "Error" -Component "${CmdletName}"
                throw "File size mismatch. Expected: $fileSize bytes, Actual: $actualSize bytes"
            }
            
            Write-CMTraceLog -Message "File size verification passed"  -Type "Info" -Component "${CmdletName}"
            #Write-Host "File size verification passed" 

            # Check file hash if size matches
            Write-CMTraceLog -Message "Starting hash verification..."  -Type "Info" -Component "${CmdletName}"
            #Write-Host "Starting hash verification..."
            $hashResult = Test-FileHashIntegrity -Checksum $Checksum -ChecksumType $ChecksumType -downloadedFilePath $downloadedFilePath
            
            if (-not $hashResult) {
                Remove-DownloadedFile -downloadedFilePath $downloadedFilePath
                Write-CMTraceLog -Message "File hash verification failed: $_"  -Type "Error" -Component "${CmdletName}"
                throw "File hash verification failed"
            }

            Write-Host "File integrity check completed successfully"
            Write-CMTraceLog -Message "File integrity check completed successfully"  -Type "Info" -Component "${CmdletName}"
            return $true
        }
        catch {
            #Write-Host "File integrity check failed: $_"
            Write-CMTraceLog -Message "File integrity check failed: $_"  -Type "Error" -Component "${CmdletName}"
            throw $_
        }
    }
}


<#
.SYNOPSIS
    Verifies the integrity of a file by comparing its cryptographic hash with an expected value.

.DESCRIPTION
    This function calculates the cryptographic hash of a specified file using the specified algorithm
    and compares it with a provided expected hash value. It's commonly used to verify file integrity
    and authenticity after downloads or transfers.

.PARAMETER origHash
    The expected hash value to compare against. This should be provided by a trusted source.

.PARAMETER Type
    The cryptographic hash algorithm to use for verification.
    Supported algorithms: SHA1, SHA256, SHA384, SHA512, MD5

.PARAMETER downloadedFilePath
    The path to the file whose integrity needs to be verified.
    Can be relative or absolute path.

.EXAMPLE
    PS C:\> Test-FileHashIntegrity -origHash "A94A8FE5CC..." -Type SHA256 -downloadedFilePath "C:\Downloads\package.zip"
    Verifies if package.zip has the expected SHA256 hash value.

.EXAMPLE
    PS C:\> $expectedHash = "B94A8FE5CC..."
    PS C:\> $filePath = "setup.exe"
    PS C:\> Test-FileHashIntegrity $expectedHash SHA1 $filePath
    Shows positional parameter usage to verify setup.exe against an expected SHA1 hash.

.EXAMPLE
    PS C:\> Get-ChildItem *.iso | ForEach-Object {
    >>     Test-FileHashIntegrity -origHash $_.Hash -Type SHA512 -downloadedFilePath $_.FullName
    >> }
    Demonstrates verifying multiple files with their stored hash values.

.INPUTS
    System.String
    You can pipe file paths to the downloadedFilePath parameter.

.OUTPUTS
    System.Boolean
    Returns $true if the calculated hash matches the expected hash, $false otherwise.

.NOTES
    Author: Peter Rinnenbach
    Version: 1.1
    Date: 02/08/2025
    Requirements:
    - PowerShell 4.0 or later (for Get-FileHash cmdlet)
    - Read access to the target file

    Security Considerations:
    - MD5 and SHA1 are considered weak and should be avoided when possible
    - Always obtain hash values from trusted sources
    - Prefer SHA256 or stronger algorithms for security-sensitive applications

.LINK
    Get-FileHash
.LINK
    about_Hashing
.LINK
    https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash
#>
function Test-FileHashIntegrity {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [String]$Checksum,

        [Parameter(Mandatory=$true, Position=1)]
        [ValidateSet("SHA1","SHA256", "SHA384", "SHA512", "MD5")]
        [String]$ChecksumType,

        [Parameter(Mandatory=$true, Position=2, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateScript({
            if (-not (Test-Path -Path $_ -PathType Leaf)) {
                throw "File not found: $_"
            }
            $true
        })]
        [Alias("FullName","Path")]
        [String]$downloadedFilePath
    )

    Begin {
        [String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Host ${CmdletName}
    }

    Process {
        try {
            $cpath = Convert-Path $downloadedFilePath
            #Write-Host "Calculating $ChecksumType hash for file: $cpath"
            Write-CMTraceLog -Message "Calculating $ChecksumType hash for file: $cpath"  -Type "Info" -Component "${CmdletName}"
            
            $localFileHash = (Get-FileHash -Algorithm $ChecksumType -Path $cpath -ErrorAction Stop).Hash
            Write-CMTraceLog -Message "Calculated hash: $localFileHash"  -Type "Info" -Component "${CmdletName}"
            Write-CMTraceLog -Message "Expected hash: $Checksum"  -Type "Info" -Component "${CmdletName}"

            #Write-Host "Calculated hash: $localFileHash"
            #Write-Host "Expected hash: $Checksum"

            $result = $Checksum.ToUpper() -eq $localFileHash.ToUpper()
            
            if ($result) {
                Write-Host "Hash verification successful"
                Write-CMTraceLog -Message "Hash verification successful" -Type "Info" -Component "${CmdletName}"
            } else {
                Write-Host "Hash verification failed"
                Write-CMTraceLog -Message "Hash verification failed" -Type "Error" -Component "${CmdletName}"
            }
            
            return $result
        }
        catch {
            #Write-Host "Error during hash verification: $_"
            Write-CMTraceLog -Message "Error during hash verification: $_" -Type "Error" -Component "${CmdletName}"
            throw $_
        }
    }
}


<#
.SYNOPSIS
    Verifies a file's partial hash against an expected value using a specified algorithm.

.DESCRIPTION
    This function checks whether a file's cryptographic hash matches an expected value.
    It's particularly useful for verifying partial downloads or checking file integrity
    during transfer operations. The function supports multiple hash algorithms.

.PARAMETER FilePath
    The full path to the file to be verified. Can be absolute or relative.

.PARAMETER ExpectedHash
    The expected hash value to compare against. Must be provided in hexadecimal format.

.PARAMETER HashType
    The cryptographic hash algorithm to use for verification.
    Supported algorithms: SHA1, SHA256, SHA384, SHA512, MD5

.EXAMPLE
    PS C:\> Test-PartialFileHash -FilePath "C:\Temp\partial.zip" -ExpectedHash "A94A8FE5CC..." -HashType SHA256
    Verifies if partial.zip matches the expected SHA256 hash.

.EXAMPLE
    PS C:\> $files = Get-ChildItem "C:\Downloads\*.part"
    PS C:\> $files | Test-PartialFileHash -ExpectedHash "B94A8FE5CC..." -HashType SHA1
    Verifies multiple partial download files against an expected SHA1 hash.

.EXAMPLE
    PS C:\> if (Test-PartialFileHash "setup.exe" "C45D..." "MD5") {
    >>     Write-Output "File verification successful"
    >> } else {
    >>     Write-Output "Verification failed"
    >> }
    Demonstrates conditional usage with positional parameters.

.INPUTS
    System.String
    You can pipe file paths to the FilePath parameter.

.OUTPUTS
    System.Boolean
    Returns $true if the hash matches, $false if it doesn't or if the file doesn't exist.

.NOTES
    Author: Peter Rinnenbach
    Version: 1.1
    Date: 02/08/2025
    Requirements:
    - PowerShell 4.0 or later (for Get-FileHash cmdlet)
    - Read access to the target file

    Security Considerations:
    - Case-insensitive comparison is used for hash values
    - MD5 and SHA1 are cryptographically weak - prefer SHA256 or stronger
    - Always obtain expected hashes from trusted sources

.LINK
    Get-FileHash
.LINK
    Test-FileHashIntegrity
.LINK
    about_File_Hashing
#>
function Test-PartialFileHash {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateScript({
            if (-not (Test-Path -Path $_ -PathType Leaf)) {
                throw "File not found: $_"
            }
            $true
        })]
        [Alias("FullName","Path")]
        [String]$FilePath,

        [Parameter(Mandatory=$true, Position=1)]
        [ValidatePattern('^[0-9A-Fa-f]+$')]
        [String]$Checksum,

        [Parameter(Mandatory=$true, Position=2)]
        [ValidateSet("SHA1","SHA256", "SHA384", "SHA512", "MD5")]
        [String]$ChecksumType
    )

    Begin {
        [String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Host ${CmdletName}
    }

    Process {
        try {
            Write-CMTraceLog -Message "Starting partial hash verification for: $FilePath" -Type "Info" -Component "${CmdletName}"
            #Write-Host "Starting partial hash verification for: $FilePath"
            
            $computedHash = (Get-FileHash -Algorithm $ChecksumType -Path $FilePath -ErrorAction Stop).Hash
            Write-CMTraceLog -Message "Computed $ChecksumType hash: $computedHash" -Type "Info" -Component "${CmdletName}"
            Write-CMTraceLog -Message "Expected hash: $Checksum" -Type "Info" -Component "${CmdletName}"
            #Write-Host "Computed $ChecksumType hash: $computedHash"
            #Write-Host "Expected hash: $Checksum"
	
			$result = $Checksum.ToUpper() -eq $computedHash.ToUpper()
            
            if ($result) {
                Write-CMTraceLog -Message "Hash verification successful" -Type "Info" -Component "${CmdletName}"
                #Write-Host "Hash verification successful"
            } else {
                Write-CMTraceLog -Message "Hash verification failed" -Type "Error" -Component "${CmdletName}"
                Write-CMTraceLog -Message "Expected: $Checksum`nActual: $computedHash" -Type "Error" -Component "${CmdletName}"
                #Write-Host "Hash verification failed"
                #Write-Host "Expected: $Checksum`nActual: $computedHash"
            }
            
            return $result
        }
        catch {
            Write-CMTraceLog -Message "Error during partial hash verification: $_" -Type "Error" -Component "${CmdletName}"
            #Write-Host "Error during partial hash verification: $_"
            return $false
        }
    }
}


<#
.SYNOPSIS
    Safely removes downloaded files with logging and error handling.

.DESCRIPTION
    This function provides a secure way to remove downloaded files with comprehensive logging.
    It checks for file existence before attempting deletion and handles various file system objects
    including files, directories, and read-only items.

.PARAMETER downloadedFilePath
    The path to the file or directory to be removed. Can be absolute or relative path.
    Accepts pipeline input and wildcards in paths.

.EXAMPLE
    PS C:\> Remove-DownloadedFile -downloadedFilePath "C:\Downloads\tempfile.zip"
    Removes the specified file and logs the operation.

.EXAMPLE
    PS C:\> Get-ChildItem "C:\Temp\*.tmp" | Remove-DownloadedFile
    Removes all .tmp files in C:\Temp directory through pipeline input.

.EXAMPLE
    PS C:\> Remove-DownloadedFile "C:\PartialDownloads\*" -ErrorAction Continue
    Attempts to remove all files in the PartialDownloads directory, continuing on errors.

.INPUTS
    System.String
    You can pipe file or directory paths to this function.

.OUTPUTS
    None
    This function does not return any output.

.NOTES
    Author: Peter Rinnenbach
    Version: 1.1
    Date: 02/08/2025
    Requirements:
    - PowerShell 3.0 or later
    - Write access to the target file/directory

    Security Considerations:
    - Uses -Force to remove read-only and hidden items
    - Uses -Recurse to remove directories and their contents
    - Consider implementing a recycle bin option for critical files

.LINK
    Remove-Item
.LINK
    Test-Path
.LINK
    about_FileSystem_Provider
#>
function Remove-DownloadedFile {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    Param (
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("FullName","Path")]
        [string]$downloadedFilePath
    )

    Begin {
        [String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Host ${CmdletName}
    }

    Process {
        try {
            if (Test-Path -Path $downloadedFilePath) {
                Write-CMTraceLog -Message "Attempting to remove: $downloadedFilePath" -Type "Warning" -Component "${CmdletName}"
                #Write-Host "Attempting to remove: $downloadedFilePath"
                
                if ($PSCmdlet.ShouldProcess($downloadedFilePath, "Remove file/directory")) {
                    Remove-Item -Path $downloadedFilePath -Force -Recurse -ErrorAction Stop
                    #Write-Host "Successfully removed: $downloadedFilePath"
                    Write-CMTraceLog -Message "Successfully removed: $downloadedFilePath" -Type "Info" -Component "${CmdletName}"
                }
            }
            else {
                Write-CMTraceLog -Message "Path not found, nothing to remove: $downloadedFilePath" -Type "Error" -Component "${CmdletName}"
                #Write-Host "Path not found, nothing to remove: $downloadedFilePath"
            }
        }
        catch {
            Write-CMTraceLog -Message "Failed to remove $downloadedFilePath : $_" -Type "Error" -Component "${CmdletName}"
            #Write-Host "Failed to remove $downloadedFilePath : $_"
            throw $_
        }
    }
}


<#
.SYNOPSIS
    Downloads a file from a specified URL to a local path with optional validation.

.DESCRIPTION
    The Invoke-FileDownload function downloads a file from a specified URL to a local path. 
    It supports BITS transfer for efficient downloads and includes optional file validation.
    The function can resume partial downloads if the file is valid and provides detailed logging.

.PARAMETER URL
    Specifies the URL of the file to download. This parameter is mandatory.

.PARAMETER OutFile
    Specifies the local path where the downloaded file will be saved. This parameter is mandatory.

.PARAMETER Validate
    When specified, the function will validate the downloaded file's integrity.
    If a partial file exists, it will be validated before resuming the download.

.EXAMPLE
    Invoke-FileDownload -URL "https://example.com/file.zip" -OutFile "C:\Downloads\file.zip"
    
    Downloads file.zip from the specified URL and saves it to C:\Downloads\file.zip.

.EXAMPLE
    Invoke-FileDownload -URL "https://example.com/file.zip" -OutFile "C:\Downloads\file.zip" -Validate
    
    Downloads file.zip with validation enabled. If a partial file exists, it will be validated before resuming.

.INPUTS
    None. You cannot pipe objects to Invoke-FileDownload.

.OUTPUTS
    System.Boolean. Returns $true if the download was successful, $false otherwise.

.NOTES
    Author: Peter Rinnenbach
    Version: 1.1
    Date: 02/08/2025
    Prerequisite : PowerShell 5.1 or later

.LINK
    
#>
function Invoke-FileDownload {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [String]$URL,
        [Parameter(Mandatory = $true)]
        [String]$OutFile,
        [Parameter(Mandatory = $false)]
        [switch]$Validate,
		[Parameter(Mandatory = $false)]
		[string]$ChecksumType,
		[Parameter(Mandatory = $false)]
		[string]$Checksum
    )
    Begin {
        [String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Host ${CmdletName}

        $isPartialFileValid = $false
        if ($Validate -and (Test-Path -Path $OutFile)) {
            Write-CMTraceLog -Message "Partially downloaded file found. Verifying hash..." -Type "Info" -Component "${CmdletName}"
            #Write-Host "Partially downloaded file found. Verifying hash..."
            $isPartialFileValid = Test-PartialFileHash -FilePath $OutFile -Checksum $Checksum -ChecksumType $ChecksumType
            if ($isPartialFileValid) {
                Write-CMTraceLog -Message "Partial file is valid. Skipping download..." -Type "Info" -Component "${CmdletName}"
                #Write-Host "Partial file is valid. Skipping download..."
                return $true
            } else {
                Write-CMTraceLog -Message "Partial file is corrupted. Deleting and restarting download..." -Type "Error" -Component "${CmdletName}"
                #Write-Host "Partial file is corrupted. Deleting and restarting download..."
                Remove-DownloadedFile -downloadedFilePath $OutFile
            }
        }
    }
    Process {
        if ($isPartialFileValid) {
            return $true
        }

        $start_time = Get-Date
        try {
              try{
                    $link = Get-FinalRedirectUrl $URL
                    if ($PSVersionTable.PSVersion.Major -lt 6) {
						$requestedFile = (Invoke-WebRequest $link -Method Head -UseBasicParsing).Headers
					} else {
						$requestedFile = (Invoke-WebRequest $link -Method Head).Headers
					}
                    #$downloadSize = $requestedFile.'Content-Length'
                    $downloadSize = [Int64]::Parse(($requestedFile.'Content-Length' | Select-Object -First 1))
                    Write-CMTraceLog -Message "Selected download method: curl" -Type "Info" -Component "${CmdletName}"
                    Write-CMTraceLog -Message "Start downloading from $link" -Type "Info" -Component "${CmdletName}"
                    Write-CMTraceLog -Message "File size: $([math]::Round(([Int64]"$downloadSize")/1MB,2))MB" -Type "Info" -Component "${CmdletName}"
                    #Write-Host "Selected download method: Invoke-Webrequest"
                    #Write-Host "Start downloading from $link"
                    #Write-Host "File size: $([math]::Round(([Int64]"$downloadSize")/1MB,2))MB"
                    #Invoke-WebRequest -Uri $link -OutFile $OutFile
                    Invoke-Expression "& curl.exe --insecure --location --output `"$DestinationFullName`" --url `"$SourceUrl`""
                }
                catch {
                    Write-CMTraceLog -Message "Failed to transfer with Invoke-WebRequest. Here is the error message:" -Type "Error" -Component "${CmdletName}"
                    Write-CMTraceLog -Message "$($error[0].exception.message)" -Type "Error" -Component "${CmdletName}"
                    #Write-Host "Failed to transfer with Invoke-WebRequest. Here is the error message:"
                    #Write-Host "$($error[0].exception.message)"
                    throw
                }
            #}

            If (Test-Path -Path $OutFile) {
                
                Write-CMTraceLog -Message "Time taken: $((Get-Date).Subtract($start_time).Minutes) minute(s) $((Get-Date).Subtract($start_time).Seconds) second(s)" -Type "Info" -Component "${CmdletName}"
                Write-CMTraceLog -Message "Downloaded size: $([math]::Round((Get-ItemProperty -Path $OutFile).Length / 1MB, 2)) MB" -Type "Info" -Component "${CmdletName}"
                Write-CMTraceLog -Message "Downloaded file location: $OutFile" -Type "Info" -Component "${CmdletName}"
                #Write-Host "Time taken: $((Get-Date).Subtract($start_time).Minutes) minute(s) $((Get-Date).Subtract($start_time).Seconds) second(s)"
                #Write-Host "Downloaded size: $([math]::Round((Get-ItemProperty -Path $OutFile).Length / 1MB, 2)) MB"
                #Write-Host "Downloaded file location: $OutFile"

                if ($Validate) {
                    Write-CMTraceLog -Message "File integrity check starting" -Type "Info" -Component "${CmdletName}"
                    #Write-Host "File integrity check starting"
                    Test-FileIntegrity -fileSize $downloadSize -downloadedFilePath $OutFile -Checksum $Checksum -ChecksumType $Checksumtype | Out-Null
                }
                else{
                    Write-CMTraceLog -Message "Filesize check starting" -Type "Info" -Component "${CmdletName}"
                    #Write-Host "Filesize check starting"
                    Test-FileSize -fileSize $downloadSize -downloadedFilePath $OutFile | Out-Null
                }
                return $true
            }
        } catch {
            #Write-Host "Download failed: $($_.Exception.Message)"
            Write-CMTraceLog -Message "Download failed: $($_.Exception.Message)" -Type "Info" -Component "${CmdletName}"
            throw
        }
        return $false
    }
}


<#
.SYNOPSIS
    Downloads a file from a URL with automatic retry logic on failure.

.DESCRIPTION
    The Start-FileDownloadWithRetry function attempts to download a file from a specified URL with multiple retries on failure.
    It wraps the Invoke-FileDownload function and adds retry logic with configurable attempts and delay between retries.
    The function provides detailed logging of each attempt and supports file validation.

.PARAMETER URL
    Specifies the URL of the file to download. This parameter is mandatory.

.PARAMETER OutFile
    Specifies the local path where the downloaded file will be saved. This parameter is mandatory.

.PARAMETER RetryCount
    Specifies the maximum number of download attempts. Default is 3.

.PARAMETER Validate
    When specified, the function will validate the downloaded file's integrity.
    If validation fails, the download will be retried (if attempts remain).

.EXAMPLE
    Start-FileDownloadWithRetry -URL "https://example.com/file.zip" -OutFile "C:\Downloads\file.zip"
    
    Downloads file.zip with default retry settings (3 attempts).

.EXAMPLE
    Start-FileDownloadWithRetry -URL "https://example.com/file.zip" -OutFile "C:\Downloads\file.zip" -RetryCount 5 -Validate
    
    Downloads file.zip with validation enabled and up to 5 retry attempts.

.INPUTS
    None. You cannot pipe objects to Start-FileDownloadWithRetry.

.OUTPUTS
    None. The function doesn't return any output but throws an exception if all attempts fail.

.NOTES
    Author: Peter Rinnenbach
    Version: 1.1
    Date: 02/08/2025
    Prerequisite: PowerShell 5.1 or later
                    Invoke-FileDownload function must be available

.LINK
    about_Invoke-FileDownload
#>
function Save-WebFile2 {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param (
        [Parameter(Mandatory = $true)]
        [String]$URL,
        [Parameter(Mandatory = $true)]
        [String]$OutFile,
        [Parameter(Mandatory = $false)]
        [int]$RetryCount = 3,
        [Parameter(Mandatory = $false)]
        [switch]$Validate,
		[Parameter(Mandatory = $false)]
		[string]$ChecksumType,
		[Parameter(Mandatory = $false)]
		[string]$Checksum
    )
    Begin {
        [String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-Host ${CmdletName}
        $attempt = 1
    }
    Process {
        while ($attempt -le $RetryCount) {
            #Write-Host "Attempt $attempt of $RetryCount..."
            Write-CMTraceLog -Message "Attempt $attempt of $RetryCount..." -Type "Info" -Component "${CmdletName}"
            try {
                $result = Invoke-FileDownload -URL $URL -OutFile $OutFile -Validate:$Validate -ChecksumType $ChecksumType -Checksum $Checksum
                if ($result) {
                    Write-CMTraceLog -Message "Download verification succeeded on attempt $attempt." -Type "Info" -Component "${CmdletName}"
                    #Write-Host "Download verification succeeded on attempt $attempt."
                    return
                }
                Write-CMTraceLog -Message "Download failed without exception" -Type "Error" -Component "${CmdletName}"
                throw "Download failed without exception"
            } catch {
                Write-CMTraceLog -Message "Attempt $attempt failed: $($_.Exception.Message), URL = $URL" -Type "Error" -Component "${CmdletName}"
                #Write-Host "Attempt $attempt failed: $($_.Exception.Message), URL = $URL"
                $attempt++
                if ($attempt -gt $RetryCount) {
                    if (Test-Path -Path $OutFile) {
                        Write-CMTraceLog -Message "Final attempt failed. Removing downloaded file..." -Type "Error" -Component "${CmdletName}"
                        #Write-Host "Final attempt failed. Removing downloaded file..."
                        Remove-DownloadedFile -downloadedFilePath $OutFile
                    }
                    Write-CMTraceLog -Message "Download failed after $RetryCount attempts." -Type "Error" -Component "${CmdletName}"
                    throw "Download failed after $RetryCount attempts."
                }
                Write-CMTraceLog -Message "Retrying in 5 seconds..." -Type "Info" -Component "${CmdletName}"
                Write-Host "Retrying in 5 seconds..."
                Start-Sleep -Seconds 5
            }
        }
    }
}
$Global:LogFilePathSWF2 = "X:\OSD\Logs\Save-Webfile2.log"
Start-CMTraceLog -Path ""
Write-CMTraceLog -Message "Starting Save-Webfile2 Script..." -Type "Info" -Component "Save-Webfile"


<#
.SYNOPSIS
Downloads a file from the internet and returns a Get-Item Object
.DESCRIPTION
Downloads a file from the internet and returns a Get-Item Object
.LINK
https://github.com/OSDeploy/OSD/tree/master/Docs
#>
function Save-WebFile {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param
    (
        [Parameter(Position=0, Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('FileUri')]
        [System.String]
        $SourceUrl,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('FileName')]
        [System.String]
        $DestinationName,

        [Alias('Path')]
        [System.String]
        $DestinationDirectory = (Join-Path $env:TEMP 'OSD'),

        #Overwrite the file if it exists already
        #The default action is to skip the download
        [System.Management.Automation.SwitchParameter]
        $Overwrite,

        [System.Management.Automation.SwitchParameter]
        $WebClient
    )
    #=================================================
    #	Values
    #=================================================
    Write-Verbose "SourceUrl: $SourceUrl"
    Write-Verbose "DestinationName: $DestinationName"
    Write-Verbose "DestinationDirectory: $DestinationDirectory"
    Write-Verbose "Overwrite: $Overwrite"
    Write-Verbose "WebClient: $WebClient"
    #=================================================
    #	DestinationDirectory
    #=================================================
    if (Test-Path "$DestinationDirectory")
    {
        Write-Verbose "Directory already exists at $DestinationDirectory"
    }
    else {
        New-Item -Path "$DestinationDirectory" -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    #=================================================
    #	Test File
    #=================================================
    $DestinationNewItem = New-Item -Path (Join-Path $DestinationDirectory "$(Get-Random).txt") -ItemType File

    if (Test-Path $DestinationNewItem.FullName) {
        $DestinationDirectory = $DestinationNewItem | Select-Object -ExpandProperty Directory
        Write-Verbose "Destination Directory is writable at $DestinationDirectory"
        Remove-Item -Path $DestinationNewItem.FullName -Force | Out-Null
    }
    else {
        Write-Host "Unable to write to Destination Directory"
        Break
    }
    #=================================================
    #	DestinationName
    #=================================================
    if ($PSBoundParameters['DestinationName']) {
    }
    else {
        $DestinationNameUri = $SourceUrl -as [System.Uri] # Convert to Uri so we can ignore any query string
        $DestinationName = $DestinationNameUri.AbsolutePath.Split('/')[-1]
    }
    Write-Verbose "DestinationName: $DestinationName"
    #=================================================
    #	WebFileFullName
    #=================================================
    $DestinationDirectoryItem = (Get-Item $DestinationDirectory -Force).FullName
    $DestinationFullName = Join-Path $DestinationDirectoryItem $DestinationName
    #=================================================
    #	OverWrite
    #=================================================
    if ((-NOT ($PSBoundParameters['Overwrite'])) -and (Test-Path $DestinationFullName)) {
        Write-Verbose "DestinationFullName already exists"
        Get-Item $DestinationFullName -Force
    }
    else {
        #=================================================
        #	Download
        #=================================================
        $SourceUrl = [Uri]::EscapeUriString($SourceUrl.Replace('%', '~')).Replace('~', '%') # Substitute and replace '%' to avoid escaping os Azure SAS tokens
        Write-Verbose "Testing file at $SourceUrl"
        #=================================================
        #	Test for WebClient Proxy
        #=================================================
        $UseWebClient = $false
        if ($WebClient -eq $true) {
            $UseWebClient = $true
        }
        elseif (([System.Net.WebRequest]::DefaultWebProxy).Address) {
            $UseWebClient = $true
        }
        elseif (!(Test-CommandCurlExe)) {
            $UseWebClient = $true
        }

        if ($UseWebClient -eq $true) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls1
            $WebClient = New-Object System.Net.WebClient
            $WebClient.DownloadFile($SourceUrl, $DestinationFullName)
            $WebClient.Dispose()
        }
        else {
            Write-Verbose "cURL Source: $SourceUrl"
            Write-Verbose "Destination: $DestinationFullName"
    
            if ($host.name -match 'ConsoleHost') {
                Invoke-Expression "& curl.exe --insecure --location --output `"$DestinationFullName`" --url `"$SourceUrl`""
            }
            else {
                #PowerShell ISE will display a NativeCommandError, so progress will not be displayed
                $Quiet = Invoke-Expression "& curl.exe --insecure --location --output `"$DestinationFullName`" --url `"$SourceUrl`" 2>&1"
            }
        }
        #=================================================
        #	Return
        #=================================================
        if (Test-Path $DestinationFullName) {
            Get-Item $DestinationFullName -Force
        }
        else {
            Write-Host "Could not download $DestinationFullName"
            $null
        }
        #=================================================
    }
}