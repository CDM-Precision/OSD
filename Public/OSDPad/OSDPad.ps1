function Get-OSDPad {
    [CmdletBinding(DefaultParameterSetName = 'Standalone')]
    param (
        [Parameter(ParameterSetName = 'GitHub', Mandatory = $true, Position = 0)]
        [Alias('Owner','GitOwner')]
        [string]$RepoOwner,
        
        [Parameter(ParameterSetName = 'GitHub', Mandatory = $true, Position = 1)]
        [Alias('Repository','GitRepo')]
        [string]$RepoName,
        
        [Parameter(ParameterSetName = 'GitHub', Position = 2)]
        [Alias('GitPath','Folder')]
        [string]$RepoFolder,
        
        [Parameter(ParameterSetName = 'GitHub')]
        [Alias('OAuthToken')]
        [string]$OAuth,

        [Alias('BrandingTitle')]
        [string]$Brand = 'OSDPad',
        [Alias('BrandingColor')]
        [string]$Color = '#01786A',
        
        [ValidateSet('Branding','Script')]
        [string[]]$Hide
    )
    #================================================
    #   Branding
    #================================================
    $Global:OSDPadBranding = $null
    $Global:OSDPadBranding = @{
        Title   = $Brand
        Color   = $Color
    }
    #================================================
    #   Certificate Workaround
    #================================================
    #region: Workaround for SelfSigned Cert and force TLS 1.2
Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    [System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    #endregion
    #================================================
    #   GitHub
    #================================================
    if ($PSCmdlet.ParameterSetName -eq 'GitHub') {
        $Uri = "https://api.github.com/repos/$RepoOwner/$RepoName/contents/$RepoFolder"
        Write-Host -ForegroundColor DarkCyan $Uri

        if ($OAuth) {
            $Params = @{
                Headers = @{Authorization = "Bearer $OAuth"}
                Method = 'GET'
                Uri = $Uri
                UseBasicParsing = $true
            }
        }
        else {
            $GitHubApiRateLimit = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/rate_limit' -Method Get
            Write-Host -ForegroundColor DarkGray "You have used $($GitHubApiRateLimit.rate.used) of your $($GitHubApiRateLimit.rate.limit) GitHub API Requests"
            Write-Host -ForegroundColor DarkGray "You can create an OAuth Token at https://github.com/settings/tokens"
            Write-Host -ForegroundColor DarkGray 'Use the OAuth parameter to enable OSDPad Child-Item support'
            $Params = @{
                Method = 'GET'
                Uri = $Uri
                UseBasicParsing = $true
            }
        }

        $GitHubApiContent = @()
        try {
            $GitHubApiContent = Invoke-RestMethod @Params -ErrorAction Stop
        }
        catch {
            Write-Warning $_
            Break
        }      
        
        if ($OAuth) {
            foreach ($Item in $GitHubApiContent) {
                if ($Item.type -eq 'dir') {
                    Write-Host -ForegroundColor DarkCyan $Item.url
                    $GitHubApiContent += Invoke-RestMethod -UseBasicParsing -Uri $Item.url -Method Get -Headers @{Authorization = "Bearer $OAuth" }
                }
            }
        }

        #$GitHubApiContent = $GitHubApiContent | Where-Object {$_.type -eq 'file'} | Where-Object {($_.name -match 'README.md') -or ($_.name -like "*.ps1")}
        $GitHubApiContent = $GitHubApiContent | Where-Object {($_.type -eq 'dir') -or ($_.name -like "*.md") -or ($_.name -like "*.ps1")}

        Write-Host -ForegroundColor DarkGray "========================================================================="
        $Results = foreach ($Item in $GitHubApiContent) {
            #$FileContent = Invoke-RestMethod -UseBasicParsing -Uri $Item.git_url
            if ($Item.type -eq 'dir') {
                Write-Host -ForegroundColor DarkCyan "GitHub Directory: OSDPad $RepoOwner $RepoName $($Item.name)"
                
                $ObjectProperties = @{
                    RepoOwner       = $RepoOwner
                    RepoName        = $RepoName
                    RepoFolder      = $RepoFolder
                    Name            = $Item.name
                    Type            = $Item.type
                    Guid            = New-Guid
                    Path            = $Item.path
                    Size            = $Item.size
                    SHA             = $Item.sha
                    Git             = $Item.git_url
                    Download        = $Item.download_url
                    ContentRAW      = $null
                    #NodeId         = $FileContent.node_id
                    #Content        = $FileContent.content
                    #Encoding       = $FileContent.encoding
                }
                #New-Object -TypeName PSObject -Property $ObjectProperties
            }
            else {
                Write-Host -ForegroundColor DarkGray $Item.download_url
                try {
                    $ScriptWebRequest = Invoke-WebRequest -Uri $Item.download_url -UseBasicParsing -ErrorAction Ignore
                }
                catch {
                    Write-Warning $_
                    $ScriptWebRequest = $null
                    Continue
                }
        
                $ObjectProperties = @{
                    RepoOwner       = $RepoOwner
                    RepoName        = $RepoName
                    RepoFolder      = $RepoFolder
                    Name            = $Item.name
                    Type            = $Item.type
                    Guid            = New-Guid
                    Path            = $Item.path
                    Size            = $Item.size
                    SHA             = $Item.sha
                    Git             = $Item.git_url
                    Download        = $Item.download_url
                    ContentRAW      = $ScriptWebRequest.Content
                    #NodeId         = $FileContent.node_id
                    #Content        = $FileContent.content
                    #Encoding       = $FileContent.encoding
                }
                New-Object -TypeName PSObject -Property $ObjectProperties
            }
        }
        $Global:OSDPad = $Results
        
    }
    else {
        $Global:OSDPad = $null
    }
    #================================================
    #   OSDPad.ps1
    #================================================
    & "$($MyInvocation.MyCommand.Module.ModuleBase)\Projects\OSDPad.ps1"
    #================================================
}
function Start-OSDCloudToolbox {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$RepoFolder,

        [Alias('OAuthToken')]
        [string]$OAuth
    )
    #region Initialize

    #Start the Transcript
    $Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-Toolbox.log"
    $null = Start-Transcript -Path (Join-Path "$env:SystemRoot\Temp" $Transcript) -ErrorAction Ignore

    #Determine the proper Windows environment
    if ($env:SystemDrive -eq 'X:') { $WindowsPhase = 'WinPE' }
    else {
        $ImageState = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -ErrorAction Ignore).ImageState
        if ($env:UserName -eq 'defaultuser0') { $WindowsPhase = 'OOBE' }
        elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_OOBE') { $WindowsPhase = 'Specialize' }
        elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT') { $WindowsPhase = 'AuditMode' }
        else { $WindowsPhase = 'Windows' }
    }

    #Finish initialization
    Write-Host -ForegroundColor DarkGray "WindowsPhase: $WindowsPhase"
    if (-not ($RepoFolder)) {
        $RepoFolder = $WindowsPhase
    }

    #Load OSDCloud Functions
    #Invoke-Expression -Command (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/CDM-Precision/OSD/refs/heads/master/cloud/functions.ps1')

    #endregion
    
    #region Run Command
    if ($OAuth) {
        $OSDPadParams = @{
            Brand      = "OSDCloud Toolbox - $RepoFolder"
            RepoOwner  = 'OSDeploy'
            RepoName   = 'OSDCloudToolbox'
            RepoFolder = $RepoFolder
            OAuth      = $OAuth
        }
    }
    else {
        $OSDPadParams = @{
            Brand      = "OSDCloud Toolbox - $RepoFolder"
            RepoOwner  = 'OSDeploy'
            RepoName   = 'OSDCloudToolbox'
            RepoFolder = $RepoFolder
        }
    }
    Start-OSDPad @OSDPadParams
    #endregion
}
function Start-OSDCloudCommunity {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$RepoFolder,

        [Alias('OAuthToken')]
        [string]$OAuth
    )
    #region Initialize

    #Start the Transcript
    $Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-Toolbox.log"
    $null = Start-Transcript -Path (Join-Path "$env:SystemRoot\Temp" $Transcript) -ErrorAction Ignore

    #Determine the proper Windows environment
    if ($env:SystemDrive -eq 'X:') { $WindowsPhase = 'WinPE' }
    else {
        $ImageState = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -ErrorAction Ignore).ImageState
        if ($env:UserName -eq 'defaultuser0') { $WindowsPhase = 'OOBE' }
        elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_OOBE') { $WindowsPhase = 'Specialize' }
        elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT') { $WindowsPhase = 'AuditMode' }
        else { $WindowsPhase = 'Windows' }
    }

    #Finish initialization
    Write-Host -ForegroundColor DarkGray "WindowsPhase: $WindowsPhase"
    if (-not ($RepoFolder)) {
        $RepoFolder = $WindowsPhase
    }

    #Load OSDCloud Functions
    #Invoke-Expression -Command (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/CDM-Precision/OSD/refs/heads/master/cloud/functions.ps1')

    #endregion
    
    #region Run Command
    if ($OAuth) {
        $OSDPadParams = @{
            Brand      = "OSDCloud Toolbox - $RepoFolder"
            RepoOwner  = 'OSDeploy'
            RepoName   = 'OSDCloudToolbox'
            RepoFolder = $RepoFolder
            OAuth      = $OAuth
        }
    }
    else {
        $OSDPadParams = @{
            Brand      = "OSDCloud Toolbox - $RepoFolder"
            RepoOwner  = 'OSDeploy'
            RepoName   = 'OSDCloudToolbox'
            RepoFolder = $RepoFolder
        }
    }
    Start-OSDPadC @OSDPadParams
    #endregion
}
function Start-OSDeployPad {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$RepoFolder,

        [Alias('OAuthToken')]
        [string]$OAuth
    )

    if ($OAuth) {
        $OSDPadParams = @{
            Brand      = "OSDeploy OSDPad $RepoFolder"
            RepoOwner  = 'OSDeploy'
            RepoName   = 'OSDPad'
            RepoFolder = $RepoFolder
            OAuth      = $OAuth
        }
    }
    else {
        $OSDPadParams = @{
            Brand      = "OSDeploy OSDPad $RepoFolder"
            RepoOwner  = 'OSDeploy'
            RepoName   = 'OSDPad'
            RepoFolder = $RepoFolder
        }
    }
    Start-OSDPad @OSDPadParams
}
function Start-OSDPad {
    [CmdletBinding(DefaultParameterSetName = 'Standalone')]
    param (
        [Parameter(ParameterSetName = 'GitHub', Mandatory = $true, Position = 0)]
        [Alias('Owner', 'GitOwner')]
        [string]$RepoOwner,
        
        [Parameter(ParameterSetName = 'GitHub', Mandatory = $true, Position = 1)]
        [Parameter(ParameterSetName = 'GitLab', Mandatory = $true, Position = 0)]        
        [Alias('Repository', 'GitRepo')]
        [string]$RepoName,
        
        [Parameter(ParameterSetName = 'GitHub', Position = 2)]
        [Parameter(ParameterSetName = 'GitLab', Position = 1)]
        [Alias('GitPath', 'Folder')]
        [string]$RepoFolder,
        
        [Parameter(ParameterSetName = 'GitLab', Mandatory = $true)]
        [Alias('GitLabUri')]
        [string]$RepoDomain,

        [Parameter(ParameterSetName = 'GitHub')]
        [Parameter(ParameterSetName = 'GitLab')]
        [Alias('OAuthToken')]
        [string]$OAuth,

        [Alias('BrandingTitle')]
        [string]$Brand = 'OSDPad',

        [Alias('BrandingColor')]
        [string]$Color = '#01786A',
        
        [ValidateSet('Branding', 'Script')]
        [string[]]$Hide
    )
    #================================================
    #   Branding
    #================================================
    $Global:OSDPadBranding = $null
    $Global:OSDPadBranding = @{
        Title = $Brand
        Color = $Color
    }
    #================================================
    #   GitHub
    #================================================
    if ($PSCmdlet.ParameterSetName -eq 'GitHub') {
        $RepoType = 'GitHub'

        # Set api URL
        if ($RepoFolder) {
            $Uri = "https://api.github.com/repos/$RepoOwner/$RepoName/contents/$RepoFolder"
        }
        else {
            $Uri = "https://api.github.com/repos/$RepoOwner/$RepoName/contents"
        }
        Write-Host -ForegroundColor DarkCyan $Uri

        if ($OAuth) {
            $Params = @{
                Headers         = @{Authorization = "Bearer $OAuth" }
                Method          = 'GET'
                Uri             = $Uri
                UseBasicParsing = $true
            }
        }
        else {
            $GitHubApiRateLimit = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/rate_limit' -Method Get
            Write-Host -ForegroundColor DarkGray "You have used $($GitHubApiRateLimit.rate.used) of your $($GitHubApiRateLimit.rate.limit) GitHub API Requests"
            Write-Host -ForegroundColor DarkGray 'You can create an OAuth Token at https://github.com/settings/tokens'
            Write-Host -ForegroundColor DarkGray 'Use the OAuth parameter to enable OSDPad Child-Item support'
            $Params = @{
                Method          = 'GET'
                Uri             = $Uri
                UseBasicParsing = $true
            }
        }

        $GitHubApiContent = @()
        try {
            $GitHubApiContent = Invoke-RestMethod @Params -ErrorAction Stop
        }
        catch {
            Write-Warning $_
            Break
        }      
        
        if ($OAuth) {
            foreach ($Item in $GitHubApiContent) {
                if ($Item.type -eq 'dir') {
                    Write-Host -ForegroundColor DarkCyan $Item.url
                    $GitHubApiContent += Invoke-RestMethod -UseBasicParsing -Uri $Item.url -Method Get -Headers @{Authorization = "Bearer $OAuth" }
                }
            }
        }

        $GitHubApiContent = $GitHubApiContent | Where-Object { ($_.type -eq 'dir') -or ($_.name -like '*.md') -or ($_.name -like '*.ps1') }

        Write-Host -ForegroundColor DarkGray '========================================================================='
        $Results = foreach ($Item in $GitHubApiContent) {
            #$FileContent = Invoke-RestMethod -UseBasicParsing -Uri $Item.git_url
            if ($Item.type -eq 'dir') {
                Write-Host -ForegroundColor DarkCyan "Directory: Start-OSDPad $RepoOwner $RepoName $($Item.name)"
                
                $ObjectProperties = @{
                    RepoOwner  = $RepoOwner
                    RepoName   = $RepoName
                    RepoFolder = $RepoFolder
                    Name       = $Item.name
                    Type       = $Item.type
                    Guid       = New-Guid
                    Path       = $Item.path
                    Size       = $Item.size
                    SHA        = $Item.sha
                    Git        = $Item.git_url
                    Download   = $Item.download_url
                    ContentRAW = $null
                    #NodeId         = $FileContent.node_id
                    #Content        = $FileContent.content
                    #Encoding       = $FileContent.encoding
                }
                #New-Object -TypeName PSObject -Property $ObjectProperties
            }
            else {
                Write-Host -ForegroundColor DarkGray $Item.download_url
                try {
                    $ScriptWebRequest = Invoke-WebRequest -Uri $Item.download_url -UseBasicParsing -ErrorAction Ignore
                }
                catch {
                    Write-Warning $_
                    $ScriptWebRequest = $null
                    Continue
                }
        
                $ObjectProperties = @{
                    RepoType   = $RepoType
                    RepoOwner  = $RepoOwner
                    RepoName   = $RepoName
                    RepoFolder = $RepoFolder
                    Name       = $Item.name
                    Type       = $Item.type
                    Guid       = New-Guid
                    Path       = $Item.path
                    Size       = $Item.size
                    SHA        = $Item.sha
                    Git        = $Item.git_url
                    Download   = $Item.download_url
                    ContentRAW = $ScriptWebRequest.Content
                    #NodeId         = $FileContent.node_id
                    #Content        = $FileContent.content
                    #Encoding       = $FileContent.encoding
                }
                New-Object -TypeName PSObject -Property $ObjectProperties
            }
        }
        $Global:OSDPad = $Results
        
    }
    #================================================
    #   GitLab
    #================================================
    elseif ($PSCmdlet.ParameterSetName -eq 'GitLab') {        
        $RepoType = 'GitLab'
        $RestAPI = "api/v4/projects/$RepoName/repository/tree?path=$RepoFolder&recursive=true"
        $Uri = "https://$RepoDomain/$RestAPI"       
        Write-Host -ForegroundColor DarkCyan $Uri
        
        $Params = @{
            Method          = 'GET'
            Uri             = $Uri
            UseBasicParsing = $true
        }
        If ($OAuth) { 
            $Params.add('Headers', @{'PRIVATE-TOKEN' = "$OAuth" }) 
        }  
        
        $GitLabApiContent = @()
        try {
            $GitLabApiContent = Invoke-RestMethod @Params -ErrorAction Stop
        }
        catch {
            Write-Warning $_
            Break
        }      

        $GitLabApiContent = $GitLabApiContent | Where-Object { ($_.name -like '*.md') -or ($_.name -like '*.ps1') }
        
        Write-Host -ForegroundColor DarkGray '========================================================================='
        $Results = foreach ($Item in $GitLabApiContent) {
            #$FileContent = Invoke-RestMethod -UseBasicParsing -Uri $Item.git_url
            if ($Item.type -eq 'tree') {
                Write-Host -ForegroundColor DarkCyan "Directory: Start-OSDPad $RepoDomain $RepoName $($Item.name)"
                
                $ObjectProperties = @{
                    RepoOwner  = $RepoOwner
                    RepoName   = $RepoName
                    RepoFolder = $RepoFolder
                    Name       = $Item.name
                    Type       = $Item.type
                    Guid       = New-Guid
                    Path       = $Item.path
                    Size       = $Item.size
                    SHA        = $Item.sha
                    Git        = $Item.git_url
                    Download   = $Item.download_url
                    ContentRAW = $null
                    #NodeId         = $FileContent.node_id
                    #Content        = $FileContent.content
                    #Encoding       = $FileContent.encoding
                }
                #New-Object -TypeName PSObject -Property $ObjectProperties
            }
            else {
                $filePath = [System.Web.HttpUtility]::UrlEncode($Item.path)
                $RestAPI = "api/v4/projects/$RepoName/repository/files/$filePath/raw?ref=main"
                $Uri = "https://$RepoDomain/$RestAPI"
                Write-Host -ForegroundColor DarkGray $Uri
                
                $Params = @{
                    Method          = 'GET'
                    Uri             = $Uri
                    UseBasicParsing = $true
                }
                IF ($OAuth) { 
                    $Params.add('Headers', @{'PRIVATE-TOKEN' = "$OAuth" }) 
                }                

                try {
                    $ScriptWebRequest = Invoke-RestMethod @Params -ErrorAction Ignore
                }
                catch {
                    Write-Warning $_
                    $ScriptWebRequest = $null
                    Continue
                }
        
                $ObjectProperties = @{
                    RepoType   = $RepoType
                    RepoDomain = $RepoDomain
                    #RepoOwner  = $RepoOwner
                    RepoName   = $RepoName
                    RepoFolder = $RepoFolder
                    Name       = $Item.name
                    Type       = $Item.type
                    Guid       = $Item.id
                    Path       = $Item.path
                    #Size       = $Item.size
                    #SHA        = $Item.sha
                    #Git        = $Item.git_url
                    #Download   = $Item.download_url
                    ContentRAW = $ScriptWebRequest
                    #NodeId         = $FileContent.node_id
                    #Content        = $FileContent.content
                    #Encoding       = $FileContent.encoding
                }
                New-Object -TypeName PSObject -Property $ObjectProperties
            }
        }
        $Global:OSDPad = $Results
    }
    else {
        $Global:OSDPad = $null
    }
    #================================================
    #   OSDPad.ps1
    #================================================
    & "$($MyInvocation.MyCommand.Module.ModuleBase)\Projects\OSDPad.ps1"
    #================================================
}
function Start-OSDPadCategories {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Owner', 'GitOwner')]
        [string]$RepoOwner,
        
        [Parameter(Mandatory = $true, Position = 1)]     
        [Alias('Repository', 'GitRepo')]
        [string]$RepoName,

        [Parameter(ParameterSetName = 'GitHub')]
        [Alias('OAuthToken')]
        [string]$OAuth
    )
    #================================================
    #   Set Global Variables
    #================================================
    $Global:OSDPadRepository = @{
        Owner = $RepoOwner
        Name  = $RepoName
    }
    $Global:OSDPadBranding = @{
        Title = $RepoName
        Color = '#01786A'
    }
    #================================================
    #   GitHub
    #================================================
    # Set Params
    $Params = @{
        Method          = 'GET'
        Uri             = "https://api.github.com/repos/$RepoOwner/$RepoName/contents"
        UseBasicParsing = $true
    }

    if ($OAuth) {
        $Params.add('Headers', @{'PRIVATE-TOKEN' = "$OAuth" })
    }
    else {
        $GitHubApiRateLimit = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/rate_limit' -Method Get
        Write-Host -ForegroundColor DarkGray "You have used $($GitHubApiRateLimit.rate.used) of your $($GitHubApiRateLimit.rate.limit) GitHub API Requests"
        Write-Host -ForegroundColor DarkGray 'You can create an OAuth Token at https://github.com/settings/tokens'
    }


    $Global:OSDPadCategories = @()
    try {
        $Global:OSDPadCategories = Invoke-RestMethod @Params -ErrorAction Stop
    }
    catch {
        Write-Warning $_
        Break
    }
    $Global:OSDPadCategories = $Global:OSDPadCategories | Where-Object { ($_.type -eq 'dir') } | Sort-Object Name
    $Global:OSDPad = $null
    #================================================
    #   OSDPadCategories.ps1
    #================================================
    & "$($MyInvocation.MyCommand.Module.ModuleBase)\Projects\OSDPadCategories.ps1"
    #================================================
}