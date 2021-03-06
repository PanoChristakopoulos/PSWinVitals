# See the help for Set-StrictMode for the full details on what this enables.
Set-StrictMode -Version 2.0

Function Get-VitalInformation {
    <#
        .SYNOPSIS
        Retrieves system information and inventory

        .DESCRIPTION
        The following tasks are available:
        - ComponentStoreAnalysis
          Performs a component store analysis to determine current statistics and reclaimable space.

          This task requires administrator privileges.

        - ComputerInfo
          Retrieves baseline system hardware and operating system information.

          This task requires Windows PowerShell 5.1 or newer.

        - CrashDumps
          Checks for any kernel or service account crash dumps.

          This task requires administrator privileges.

        - DevicesNotPresent
          Retrieves any PnP devices which are not present.

          Devices which are not present are those with an "Unknown" state.

          This task requires Windows 10, Windows Server 2016, or newer.

        - DevicesWithBadStatus
          Retrieves any PnP devices with a bad status.

          A bad status corresponds to any device in an "Error" or "Degraded" state.

          This task requires Windows 10, Windows Server 2016, or newer.

        - EnvironmentVariables
          Retrieves environment variables for the system and current user.

        - HypervisorInfo
          Attempts to detect if the system is running under a hypervisor.

          Currently we only detect Microsoft Hyper-V and VMware hypervisors.

        - InstalledFeatures
          Retrieves information on installed Windows features.

          This task requires a Window Server operating system.

        - InstalledPrograms
          Retrieves information on installed programs.

          Only programs installed system-wide are retrieved.

        - StorageVolumes
          Retrieves information on fixed storage volumes.

          This task requires Windows 8, Windows Server 2012, or newer.

        - SysinternalsSuite
          Retrieves the version of the installed Sysinternals Suite if any.

          The version is retrieved from the Version.txt file created by Invoke-VitalMaintenance.

          The location where we check if the utilities are installed depends on the OS architecture:
          * 32-bit: The "Sysinternals" folder in the "Program Files" directory
          * 64-bit: The "Sysinternals" folder in the "Program Files (x86)" directory

        - WindowsUpdates
          Scans for any available Windows updates.

          Updates from Microsoft Update are also included if opted-in via the Windows Update configuration.

          This task requires administrator privileges and the PSWindowsUpdate module.

        The default is to run all tasks.

        .PARAMETER ExcludeTasks
        Array of tasks to exclude. The default is an empty array (i.e. run all tasks).

        .PARAMETER IncludeTasks
        Array of tasks to include. At least one task must be specified.

        .EXAMPLE
        Get-VitalInformation -IncludeTasks StorageVolumes, InstalledPrograms

        Only retrieves information on storage volumes and installed programs.

        .NOTES
        Selected inventory information is retrieved in the following order:
        - ComputerInfo
        - HypervisorInfo
        - DevicesWithBadStatus
        - DevicesNotPresent
        - StorageVolumes
        - CrashDumps
        - ComponentStoreAnalysis
        - InstalledFeatures
        - InstalledPrograms
        - EnvironmentVariables
        - WindowsUpdates
        - SysinternalsSuite

        .LINK
        https://github.com/ralish/PSWinVitals
    #>

    [CmdletBinding(DefaultParameterSetName='OptOut')]
    Param(
        [Parameter(ParameterSetName='OptOut')]
        [ValidateSet(
            'ComponentStoreAnalysis',
            'ComputerInfo',
            'CrashDumps',
            'DevicesNotPresent',
            'DevicesWithBadStatus',
            'EnvironmentVariables',
            'HypervisorInfo',
            'InstalledFeatures',
            'InstalledPrograms',
            'StorageVolumes',
            'SysinternalsSuite',
            'WindowsUpdates'
        )]
        [String[]]$ExcludeTasks,

        [Parameter(ParameterSetName='OptIn', Mandatory)]
        [ValidateSet(
            'ComponentStoreAnalysis',
            'ComputerInfo',
            'CrashDumps',
            'DevicesNotPresent',
            'DevicesWithBadStatus',
            'EnvironmentVariables',
            'HypervisorInfo',
            'InstalledFeatures',
            'InstalledPrograms',
            'StorageVolumes',
            'SysinternalsSuite',
            'WindowsUpdates'
        )]
        [String[]]$IncludeTasks
    )

    $Tasks = @{
        ComponentStoreAnalysis = $null
        ComputerInfo = $null
        CrashDumps = $null
        DevicesNotPresent = $null
        DevicesWithBadStatus = $null
        EnvironmentVariables = $null
        HypervisorInfo = $null
        InstalledFeatures = $null
        InstalledPrograms = $null
        StorageVolumes = $null
        SysinternalsSuite = $null
        WindowsUpdates = $null
    }

    foreach ($Task in @($Tasks.Keys)) {
        if ($PSCmdlet.ParameterSetName -eq 'OptOut') {
            if ($ExcludeTasks -contains $Task) {
                $Tasks[$Task] = $false
            } else {
                $Tasks[$Task] = $true
            }
        } else {
            if ($IncludeTasks -contains $Task) {
                $Tasks[$Task] = $true
            } else {
                $Tasks[$Task] = $false
            }
        }
    }

    if ($Tasks['ComponentStoreAnalysis'] -or $Tasks['CrashDumps'] -or $Tasks['WindowsUpdates']) {
        if (!(Test-IsAdministrator)) {
            throw 'You must have administrator privileges to analyse the component store, retrieve crash dumps, or retrieve Windows updates.'
        }
    }

    $VitalInformation = [PSCustomObject]@{
        ComponentStoreAnalysis = $null
        ComputerInfo = $null
        CrashDumps = $null
        DevicesNotPresent = $null
        DevicesWithBadStatus = $null
        EnvironmentVariables = $null
        HypervisorInfo = $null
        InstalledFeatures = $null
        InstalledPrograms = $null
        StorageVolumes = $null
        SysinternalsSuite = $null
        WindowsUpdates = $null
    }

    if ($Tasks['ComputerInfo']) {
        if (Get-Command -Name Get-ComputerInfo -ErrorAction Ignore) {
            Write-Host -ForegroundColor Green -Object 'Retrieving computer info ...'
            $VitalInformation.ComputerInfo = Get-ComputerInfo
        } else {
            Write-Warning -Message 'Unable to retrieve computer info as Get-ComputerInfo cmdlet not available.'
            $VitalInformation.ComputerInfo = $false
        }
    }

    if ($Tasks['HypervisorInfo']) {
        Write-Host -ForegroundColor Green -Object 'Retrieving hypervisor info ...'
        $VitalInformation.HypervisorInfo = Get-HypervisorInfo
    }

    if ($Tasks['DevicesWithBadStatus']) {
        if (Get-Module -Name PnpDevice -ListAvailable) {
            Write-Host -ForegroundColor Green -Object 'Retrieving problem devices ...'
            $VitalInformation.DevicesWithBadStatus = Get-PnpDevice | Where-Object { $_.Status -in ('Degraded', 'Error') }
        } else {
            Write-Warning -Message 'Unable to retrieve problem devices as PnpDevice module not available.'
            $VitalInformation.DevicesWithBadStatus = $false
        }
    }

    if ($Tasks['DevicesNotPresent']) {
        if (Get-Module -Name PnpDevice -ListAvailable) {
            Write-Host -ForegroundColor Green -Object 'Retrieving not present devices ...'
            $VitalInformation.DevicesNotPresent = Get-PnpDevice | Where-Object { $_.Status -eq 'Unknown' }
        } else {
            Write-Warning -Message 'Unable to retrieve not present devices as PnpDevice module not available.'
            $VitalInformation.DevicesNotPresent = $false
        }
    }

    if ($Tasks['StorageVolumes']) {
        if (Get-Module -Name Storage -ListAvailable) {
            Write-Host -ForegroundColor Green -Object 'Retrieving storage volumes summary ...'
            $VitalInformation.StorageVolumes = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' }
        } else {
            Write-Warning -Message 'Unable to retrieve storage volumes summary as Storage module not available.'
            $VitalInformation.StorageVolumes = $false
        }
    }

    if ($Tasks['CrashDumps']) {
        [PSCustomObject]$CrashDumps = [PSCustomObject]@{
            Kernel = $null
            Service = $null
        }

        Write-Host -ForegroundColor Green -Object 'Retrieving kernel crash dumps ...'
        $CrashDumps.Kernel = Get-KernelCrashDumps

        Write-Host -ForegroundColor Green -Object 'Retrieving service crash dumps ...'
        $CrashDumps.Service = Get-ServiceCrashDumps

        $VitalInformation.CrashDumps = $CrashDumps
    }

    if ($Tasks['ComponentStoreAnalysis']) {
        Write-Host -ForegroundColor Green -Object 'Running component store analysis ...'
        $VitalInformation.ComponentStoreAnalysis = Invoke-DISM -Operation AnalyzeComponentStore
    }

    if ($Tasks['InstalledFeatures']) {
        if ((Get-WindowsProductType) -gt 1) {
            if (Get-Module -Name ServerManager -ListAvailable) {
                Write-Host -ForegroundColor Green -Object 'Retrieving installed features ...'
                $VitalInformation.InstalledFeatures = Get-WindowsFeature | Where-Object { $_.Installed }
            } else {
                Write-Warning -Message 'Unable to retrieve installed features as ServerManager module not available.'
                $VitalInformation.InstalledFeatures = $false
            }
        } else {
            Write-Verbose -Message 'Unable to retrieve installed features as not running on Windows Server.'
            $VitalInformation.InstalledFeatures = $false
        }
    }

    if ($Tasks['InstalledPrograms']) {
        Write-Host -ForegroundColor Green -Object 'Retrieving installed programs ...'
        $VitalInformation.InstalledPrograms = Get-InstalledPrograms
    }

    if ($Tasks['EnvironmentVariables']) {
        [PSCustomObject]$EnvironmentVariables = [PSCustomObject]@{
            Machine = $null
            User = $null
        }

        Write-Host -ForegroundColor Green -Object 'Retrieving system environment variables ...'
        $EnvironmentVariables.Machine = [Environment]::GetEnvironmentVariables([EnvironmentVariableTarget]::Machine)

        Write-Host -ForegroundColor Green -Object 'Retrieving user environment variables ...'
        $EnvironmentVariables.User = [Environment]::GetEnvironmentVariables([EnvironmentVariableTarget]::User)

        $VitalInformation.EnvironmentVariables = $EnvironmentVariables
    }

    if ($Tasks['WindowsUpdates']) {
        if (Get-Module -Name PSWindowsUpdate -ListAvailable) {
            Write-Host -ForegroundColor Green -Object 'Retrieving Windows updates ...'
            $VitalInformation.WindowsUpdates = Get-WindowsUpdate
        } else {
            Write-Warning -Message 'Unable to retrieve Windows updates as PSWindowsUpdate module not available.'
            $VitalInformation.WindowsUpdates = $false
        }
    }

    if ($Tasks['SysinternalsSuite']) {
        if (Test-IsWindows64bit) {
            $InstallDir = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Sysinternals'
        } else {
            $InstallDir = Join-Path -Path $env:ProgramFiles -ChildPath 'Sysinternals'
        }

        if (Test-Path -Path $InstallDir -PathType Container) {
            $Sysinternals = [PSCustomObject]@{
                Path = $null
                Version = $null
                Updated = $false
            }
            $Sysinternals.Path = $InstallDir

            Write-Host -ForegroundColor Green -Object 'Retrieving Sysinternals Suite version ...'
            $VersionFile = Join-Path -Path $InstallDir -ChildPath 'Version.txt'
            if (Test-Path -Path $VersionFile -PathType Leaf) {
                $Sysinternals.Version = Get-Content -Path $VersionFile
            } else {
                Write-Warning -Message 'Unable to retrieve Sysinternals Suite version as version file is not present.'
                $Sysinternals.Version = 'Unknown'
            }

            $VitalInformation.SysinternalsSuite = $Sysinternals
        } else {
            Write-Warning -Message 'Unable to retrieve Sysinternals Suite version as it does not appear to be installed.'
            $VitalInformation.SysinternalsSuite = $false
        }
    }

    return $VitalInformation
}

Function Invoke-VitalChecks {
    <#
        .SYNOPSIS
        Performs system health checks

        .DESCRIPTION
        The following tasks are available:
        - ComponentStoreScan
          Scans the component store and repairs any corruption.

          If the -VerifyOnly parameter is specified then no repairs will be performed.

          This task requires administrator privileges.

        - FileSystemScans
          Scans all non-removable storage volumes with supported file systems and repairs any corruption.

          If the -VerifyOnly parameter is specified then no repairs will be performed.

          Volumes using FAT file systems are only supported with -VerifyOnly as they do not support online repair.

          This task requires administrator privileges and Windows 8, Windows Server 2012, or newer.

        - SystemFileChecker
          Scans system files and repairs any corruption.

          If the -VerifyOnoly parameter is specified then no repairs will be performed.

          This task requires administrator privileges.

        The default is to run all tasks.

        .PARAMETER ExcludeTasks
        Array of tasks to exclude. The default is an empty array (i.e. run all tasks).

        .PARAMETER IncludeTasks
        Array of tasks to include. At least one task must be specified.

        .PARAMETER VerifyOnly
        Modifies the behaviour of health checks to not repair any issues.

        .EXAMPLE
        Invoke-VitalChecks -IncludeTasks FileSystemScans -VerifyOnly

        Only runs file system scans without performing any repairs.

        .NOTES
        Selected health checks are run in the following order:
        - FileSystemScans
        - SystemFileChecker
        - ComponentStoreScan

        .LINK
        https://github.com/ralish/PSWinVitals
    #>

    [CmdletBinding(DefaultParameterSetName='OptOut')]
    Param(
        [Parameter(ParameterSetName='OptOut')]
        [ValidateSet(
            'ComponentStoreScan',
            'FileSystemScans',
            'SystemFileChecker'
        )]
        [String[]]$ExcludeTasks,

        [Parameter(ParameterSetName='OptIn', Mandatory)]
        [ValidateSet(
            'ComponentStoreScan',
            'FileSystemScans',
            'SystemFileChecker'
        )]
        [String[]]$IncludeTasks,

        [Switch]$VerifyOnly
    )

    if (!(Test-IsAdministrator)) {
        throw 'You must have administrator privileges to perform system health checks.'
    }

    $Tasks = @{
        ComponentStoreScan = $null
        FileSystemScans = $null
        SystemFileChecker = $null
    }

    foreach ($Task in @($Tasks.Keys)) {
        if ($PSCmdlet.ParameterSetName -eq 'OptOut') {
            if ($ExcludeTasks -contains $Task) {
                $Tasks[$Task] = $false
            } else {
                $Tasks[$Task] = $true
            }
        } else {
            if ($IncludeTasks -contains $Task) {
                $Tasks[$Task] = $true
            } else {
                $Tasks[$Task] = $false
            }
        }
    }

    $VitalChecks = [PSCustomObject]@{
        ComponentStoreScan = $null
        FileSystemScans = $null
        SystemFileChecker = $null
    }

    if ($Tasks['FileSystemScans']) {
        if (Get-Module -Name Storage -ListAvailable) {
            Write-Host -ForegroundColor Green -Object 'Running file system scans ...'
            if ($VerifyOnly) {
                $VitalChecks.FileSystemScans = Invoke-CHKDSK -Operation Verify
            } else {
                $VitalChecks.FileSystemScans = Invoke-CHKDSK -Operation Scan
            }
        } else {
            Write-Warning -Message 'Unable to run file system scans as Storage module not available.'
            $VitalChecks.FileSystemScans = $false
        }
    }

    if ($Tasks['SystemFileChecker']) {
        Write-Host -ForegroundColor Green -Object 'Running System File Checker ...'
        if ($VerifyOnly) {
            $VitalChecks.SystemFileChecker = Invoke-SFC -Operation Verify
        } else {
            $VitalChecks.SystemFileChecker = Invoke-SFC -Operation Scan
        }
    }

    if ($Tasks['ComponentStoreScan']) {
        Write-Host -ForegroundColor Green -Object 'Running component store scan ...'
        if ($VerifyOnly) {
            $VitalChecks.ComponentStoreScan = Invoke-DISM -Operation ScanHealth
        } else {
            $VitalChecks.ComponentStoreScan = Invoke-DISM -Operation RestoreHealth
        }
    }

    return $VitalChecks
}

Function Invoke-VitalMaintenance {
    <#
        .SYNOPSIS
        Performs system maintenance tasks

        .DESCRIPTION
        The following tasks are available:
        - ClearInternetExplorerCache
          Clears all cached Internet Explorer data for the user.

        - ComponentStoreCleanup
          Performs a component store clean-up to remove obsolete Windows updates.

          This task requires administrator privileges.

        - DeleteErrorReports
          Deletes all error reports (queued & archived) for the system and user.

          This task requires administrator privileges.

        - DeleteTemporaryFiles
          Recursively deletes all data in the following locations:
          * The "TEMP" environment variable path for the system
          * The "TEMP" environment variable path for the user

          This task requires administrator privileges.

        - EmptyRecycleBin
          Empties the Recycle Bin for the user.

          This task requires Windows 10, Windows Server 2016, or newer.

        - PowerShellHelp
          Updates PowerShell help for all modules.

          This task requires administrator privileges.

        - SysinternalsSuite
          Downloads and installs the latest Sysinternals Suite.

          The installation process itself consists of the following steps:
          * Download the latest Sysinternals Suite archive from download.sysinternals.com
          * Determine the version based off the date of the most recently modified file in the archive
          * If the downloaded version is newer than the installed version (if any is present) then:
          | * Remove any existing files in the installation directory and decompress the downloaded archive
          | * Write a Version.txt file in the installation directory with earlier determined version date
          * Add the installation directory to the system path environment variable if it's not already present

          The location where the utilities will be installed depends on the OS architecture:
          * 32-bit: The "Sysinternals" folder in the "Program Files" directory
          * 64-bit: The "Sysinternals" folder in the "Program Files (x86)" directory

          This task requires administrator privileges.

        - WindowsUpdates
          Downloads and installs all available Windows updates.

          Updates from Microsoft Update are also included if opted-in via the Windows Update configuration.

          This task requires administrator privileges and the PSWindowsUpdate module.

        The default is to run all tasks.

        .EXAMPLE
        Invoke-VitalMaintenance -IncludeTasks WindowsUpdates, SysinternalsSuite

        Only install Windows updates and the latest Sysinternals utilities.

        .NOTES
        Selected maintenance tasks are run in the following order:
        - WindowsUpdates
        - ComponentStoreCleanup
        - PowerShellHelp
        - SysinternalsSuite
        - ClearInternetExplorerCache
        - DeleteErrorReports
        - DeleteTemporaryFiles
        - EmptyRecycleBin

        .LINK
        https://github.com/ralish/PSWinVitals
    #>

    [CmdletBinding(DefaultParameterSetName='OptOut')]
    Param(
        [Parameter(ParameterSetName='OptOut')]
        [ValidateSet(
            'ComponentStoreCleanup',
            'ClearInternetExplorerCache',
            'DeleteErrorReports',
            'DeleteTemporaryFiles',
            'EmptyRecycleBin',
            'PowerShellHelp',
            'SysinternalsSuite',
            'WindowsUpdates'
        )]
        [String[]]$ExcludeTasks,

        [Parameter(ParameterSetName='OptIn', Mandatory)]
        [ValidateSet(
            'ComponentStoreCleanup',
            'ClearInternetExplorerCache',
            'DeleteErrorReports',
            'DeleteTemporaryFiles',
            'EmptyRecycleBin',
            'PowerShellHelp',
            'SysinternalsSuite',
            'WindowsUpdates'
        )]
        [String[]]$IncludeTasks
    )

    if (!(Test-IsAdministrator)) {
        throw 'You must have administrator privileges to perform system maintenance.'
    }

    $Tasks = @{
        ClearInternetExplorerCache = $null
        ComponentStoreCleanup = $null
        DeleteErrorReports = $null
        DeleteTemporaryFiles = $null
        EmptyRecycleBin = $null
        PowerShellHelp = $null
        SysinternalsSuite = $null
        WindowsUpdates = $null
    }

    foreach ($Task in @($Tasks.Keys)) {
        if ($PSCmdlet.ParameterSetName -eq 'OptOut') {
            if ($ExcludeTasks -contains $Task) {
                $Tasks[$Task] = $false
            } else {
                $Tasks[$Task] = $true
            }
        } else {
            if ($IncludeTasks -contains $Task) {
                $Tasks[$Task] = $true
            } else {
                $Tasks[$Task] = $false
            }
        }
    }

    $VitalMaintenance = [PSCustomObject]@{
        ClearInternetExplorerCache = $null
        ComponentStoreCleanup = $null
        DeleteErrorReports = $null
        DeleteTemporaryFiles = $null
        EmptyRecycleBin = $null
        PowerShellHelp = $null
        SysinternalsSuite = $null
        WindowsUpdates = $null
    }

    if ($Tasks['WindowsUpdates']) {
        if (Get-Module -Name PSWindowsUpdate -ListAvailable) {
            Write-Host -ForegroundColor Green -Object 'Installing Windows updates ...'
            $VitalMaintenance.WindowsUpdates = Install-WindowsUpdate -IgnoreReboot -AcceptAll
        } else {
            Write-Warning -Message 'Unable to install Windows updates as PSWindowsUpdate module not available.'
            $VitalMaintenance.WindowsUpdates = $false
        }
    }

    if ($Tasks['ComponentStoreCleanup']) {
        Write-Host -ForegroundColor Green -Object 'Running component store clean-up ...'
        $VitalMaintenance.ComponentStoreCleanup = Invoke-DISM -Operation StartComponentCleanup
    }

    if ($Tasks['PowerShellHelp']) {
        Write-Host -ForegroundColor Green -Object 'Updating PowerShell help ...'
        try {
            Update-Help -Force -ErrorAction Stop
            $VitalMaintenance.PowerShellHelp = $true
        } catch {
            # Often we'll fail to update help data for a few modules because they haven't defined
            # the HelpInfoUri key in their manifest. There's nothing that can be done to fix this.
            $VitalMaintenance.PowerShellHelp = $_.Exception.Message
        }
    }

    if ($Tasks['SysinternalsSuite']) {
        Write-Host -ForegroundColor Green -Object 'Updating Sysinternals Suite ...'
        $VitalMaintenance.SysinternalsSuite = Update-Sysinternals
    }

    if ($Tasks['ClearInternetExplorerCache']) {
        if (Get-Command -Name inetcpl.cpl -ErrorAction Ignore) {
            Write-Host -ForegroundColor Green -Object 'Clearing Internet Explorer cache ...'
            # More details on the bitmask here: https://github.com/SeleniumHQ/selenium/blob/master/cpp/iedriver/BrowserFactory.cpp
            $RunDll32Path = Join-Path -Path $env:SystemRoot -ChildPath 'System32\rundll32.exe'
            Start-Process -FilePath $RunDll32Path -ArgumentList @('inetcpl.cpl,ClearMyTracksByProcess', '9FF') -Wait
            $VitalMaintenance.ClearInternetExplorerCache = $true
        } else {
            Write-Warning -Message 'Unable to clear Internet Explorer cache as Control Panel applet not available.'
            $VitalMaintenance.ClearInternetExplorerCache = $false
        }
    }

    if ($Tasks['DeleteErrorReports']) {
        Write-Host -ForegroundColor Green -Object 'Deleting system error reports ...'
        $SystemReports = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\WER'
        $SystemQueue = Join-Path -Path $SystemReports -ChildPath 'ReportQueue'
        $SystemArchive = Join-Path -Path $SystemReports -ChildPath 'ReportArchive'
        foreach ($Path in @($SystemQueue, $SystemArchive)) {
            if (Test-Path -Path $Path -PathType Container) {
                Remove-Item -Path "$Path\*" -Recurse -ErrorAction Ignore
            }
        }

        Write-Host -ForegroundColor Green -Object ('Deleting {0} error reports ...' -f $env:USERNAME)
        $UserReports = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Windows\WER'
        $UserQueue = Join-Path -Path $UserReports -ChildPath 'ReportQueue'
        $UserArchive = Join-Path -Path $UserReports -ChildPath 'ReportArchive'
        foreach ($Path in @($UserQueue, $UserArchive)) {
            if (Test-Path -Path $Path -PathType Container) {
                Remove-Item -Path "$Path\*" -Recurse -ErrorAction Ignore
            }
        }

        $VitalMaintenance.DeleteErrorReports = $true
    }

    if ($Tasks['DeleteTemporaryFiles']) {
        Write-Host -ForegroundColor Green -Object 'Deleting system temporary files ...'
        $SystemTemp = [Environment]::GetEnvironmentVariable('Temp', [EnvironmentVariableTarget]::Machine)
        Remove-Item -Path "$SystemTemp\*" -Recurse -ErrorAction Ignore

        Write-Host -ForegroundColor Green -Object ('Deleting {0} temporary files ...' -f $env:USERNAME)
        Remove-Item -Path "$env:TEMP\*" -Recurse -ErrorAction Ignore

        $VitalMaintenance.DeleteTemporaryFiles = $true
    }

    if ($Tasks['EmptyRecycleBin']) {
        if (Get-Command -Name Clear-RecycleBin -ErrorAction Ignore) {
            Write-Host -ForegroundColor Green -Object 'Emptying Recycle Bin ...'
            try {
                Clear-RecycleBin -Force -ErrorAction Stop
                $VitalMaintenance.EmptyRecycleBin = $true
            } catch [ComponentModel.Win32Exception] {
                # Sometimes clearing the Recycle Bin fails with an exception which seems to indicate
                # the Recycle Bin folder doesn't exist. If that happens we only get a generic E_FAIL
                # exception, so checking the actual exception message seems to be the best method.
                if ($_.Exception.Message -eq 'The system cannot find the path specified') {
                    $VitalMaintenance.EmptyRecycleBin = $true
                } else {
                    $VitalMaintenance.EmptyRecycleBin = $_.Exception.Message
                }
            }
        } else {
            Write-Warning -Message 'Unable to empty Recycle Bin as Clear-RecycleBin cmdlet not available.'
            $VitalMaintenance.EmptyRecycleBin = $false
        }
    }

    return $VitalMaintenance
}

Function Get-HypervisorInfo {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '')]
    [CmdletBinding()]
    Param()

    $LogPrefix = 'HypervisorInfo'
    $HypervisorInfo = [PSCustomObject]@{
        Vendor = $null
        Hypervisor = $null
        ToolsVersion = $null
    }

    $ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
    $Manufacturer = $ComputerSystem.Manufacturer
    $Model = $ComputerSystem.Model

    # Useful: http://git.annexia.org/?p=virt-what.git;a=blob_plain;f=virt-what.in;hb=HEAD
    if ($Manufacturer -eq 'Microsoft Corporation' -and $Model -eq 'Virtual Machine') {
        $HypervisorInfo.Vendor = 'Microsoft'
        $HypervisorInfo.Hypervisor = 'Hyper-V'

        $IntegrationServicesVersion = $false
        $VMInfoRegPath = 'HKLM:\Software\Microsoft\Virtual Machine\Auto'
        if (Test-Path -Path $VMInfoRegPath -PathType Container) {
            $VMInfo = Get-ItemProperty -Path $VMInfoRegPath
            if ($VMInfo.PSObject.Properties['IntegrationServicesVersion']) {
                $IntegrationServicesVersion = $VMInfo.IntegrationServicesVersion
            }
        }

        if ($IntegrationServicesVersion) {
            $HypervisorInfo.ToolsVersion = $VMinfo.IntegrationServicesVersion
        } else {
            Write-Warning -Message ('[{0}] Detected Microsoft Hyper-V but unable to determine Integration Services version.' -f $LogPrefix)
        }
    } elseif ($Manufacturer -eq 'VMware, Inc.' -and $Model -match '^VMware') {
        $HypervisorInfo.Vendor = 'VMware'
        $HypervisorInfo.Hypervisor = 'Unknown'

        $VMwareToolboxCmd = Join-Path -Path $env:ProgramFiles -ChildPath 'VMware\VMware Tools\VMwareToolboxCmd.exe'
        if (Test-Path -Path $VMwareToolboxCmd -PathType Leaf) {
            $HypervisorInfo.ToolsVersion = & $VMwareToolboxCmd -v
        } else {
            Write-Warning -Message ('[{0}] Detected a VMware hypervisor but unable to determine VMware Tools version.' -f $LogPrefix)
        }
    } else {
        Write-Verbose -Message ('[{0}] Either not running in a hypervisor or hypervisor not recognised.' -f $LogPrefix)
        return $false
    }

    return $HypervisorInfo
}

Function Get-InstalledPrograms {
    [CmdletBinding()]
    Param()

    $Results = @()
    $TypeName = 'PSWinVitals.InstalledProgram'

    Update-TypeData -TypeName $TypeName -DefaultDisplayPropertySet @('Name', 'Publisher', 'Version') -Force

    # Programs installed system-wide in native bitness
    $ComputerNativeRegPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    # Programs installed system-wide under the 32-bit emulation layer (64-bit Windows only)
    $ComputerWow64RegPath = 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

    # Retrieve all installed programs from available keys
    $UninstallKeys = Get-ChildItem -Path $ComputerNativeRegPath
    if (Test-Path -Path $ComputerWow64RegPath -PathType Container) {
        $UninstallKeys += Get-ChildItem -Path $ComputerWow64RegPath
    }

    # Filter out all the uninteresting installation results
    foreach ($UninstallKey in $UninstallKeys) {
        $Program = Get-ItemProperty -Path $UninstallKey.PSPath

        # Skip any program which doesn't define a display name
        if (!$Program.PSObject.Properties['DisplayName']) {
            continue
        }

        # Ensure the program either:
        # - Has an uninstall command
        # - Is marked as non-removable
        if (!($Program.PSObject.Properties['UninstallString'] -or ($Program.PSObject.Properties['NoRemove'] -and $Program.NoRemove -eq 1))) {
            continue
        }

        # Skip any program which defines a parent program
        if ($Program.PSObject.Properties['ParentKeyName'] -or $Program.PSObject.Properties['ParentDisplayName']) {
            continue
        }

        # Skip any program marked as a system component
        if ($Program.PSObject.Properties['SystemComponent'] -and $Program.SystemComponent -eq 1) {
            continue
        }

        # Skip any program which defines a release type
        if ($Program.PSObject.Properties['ReleaseType']) {
            continue
        }

        $Result = [PSCustomObject]@{
            PSTypeName      = $TypeName
            PSPath          = $Program.PSPath
            Name            = $Program.DisplayName
            Publisher       = $null
            InstallDate     = $null
            EstimatedSize   = $null
            Version         = $null
            Location        = $null
            Uninstall       = $null
        }

        if ($Program.PSObject.Properties['Publisher']) {
            $Result.Publisher = $Program.Publisher
        }

        if ($Program.PSObject.Properties['InstallDate']) {
            $Result.InstallDate = $Program.InstallDate
        }

        if ($Program.PSObject.Properties['EstimatedSize']) {
            $Result.EstimatedSize = $Program.EstimatedSize
        }

        if ($Program.PSObject.Properties['DisplayVersion']) {
            $Result.Version = $Program.DisplayVersion
        }

        if ($Program.PSObject.Properties['InstallLocation']) {
            $Result.Location = $Program.InstallLocation
        }

        if ($Program.PSObject.Properties['UninstallString']) {
            $Result.Uninstall = $Program.UninstallString
        }

        $Results += $Result
    }

    return ($Results | Sort-Object -Property Name)
}

Function Get-KernelCrashDumps {
    [CmdletBinding()]
    Param()

    $LogPrefix = 'KernelCrashDumps'
    $KernelCrashDumps = [PSCustomObject]@{
        MemoryDump = $null
        Minidumps = $null
    }

    $CrashControlRegPath = 'HKLM:\System\CurrentControlSet\Control\CrashControl'

    if (Test-Path -Path $CrashControlRegPath -PathType Container) {
        $CrashControl = Get-ItemProperty -Path $CrashControlRegPath

        if ($CrashControl.PSObject.Properties['DumpFile']) {
            $DumpFile = $CrashControl.DumpFile
        } else {
            $DumpFile = Join-Path -Path $env:SystemRoot -ChildPath 'MEMORY.DMP'
            Write-Warning -Message ("[{0}] The DumpFile value doesn't exist in CrashControl so we're guessing the location." -f $LogPrefix)
        }

        if ($CrashControl.PSObject.Properties['MinidumpDir']) {
            $MinidumpDir = $CrashControl.MinidumpDir
        } else {
            $DumpFile = Join-Path -Path $env:SystemRoot -ChildPath 'Minidump'
            Write-Warning -Message ("[{0}]The MinidumpDir value doesn't exist in CrashControl so we're guessing the location." -f $LogPrefix)
        }
    } else {
        Write-Warning -Message ("[{0}]The CrashControl key doesn't exist in the Registry so we're guessing dump locations." -f $LogPrefix)
    }

    if (Test-Path -Path $DumpFile -PathType Leaf) {
        $KernelCrashDumps.MemoryDump = Get-Item -Path $DumpFile
    }

    if (Test-Path -Path $MinidumpDir -PathType Container) {
        $KernelCrashDumps.Minidumps = Get-ChildItem -Path $MinidumpDir
    }

    return $KernelCrashDumps
}

Function Get-ServiceCrashDumps {
    [CmdletBinding()]
    Param()

    $LogPrefix = 'ServiceCrashDumps'
    $ServiceCrashDumps = [PSCustomObject]@{
        LocalSystem = $null
        LocalService = $null
        NetworkService = $null
    }

    $LocalSystemPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\Config\SystemProfile\AppData\Local\CrashDumps'
    $LocalServicePath = Join-Path -Path $env:SystemRoot -ChildPath 'ServiceProfiles\LocalService\AppData\Local\CrashDumps'
    $NetworkServicePath = Join-Path -Path $env:SystemRoot -ChildPath 'ServiceProfiles\NetworkService\AppData\Local\CrashDumps'

    if (Test-Path -Path $LocalSystemPath -PathType Container) {
        $ServiceCrashDumps.LocalSystem = Get-ChildItem -Path $LocalSystemPath
    } else {
        Write-Verbose -Message ("[{0}] The crash dumps path for the LocalSystem account doesn't exist." -f $LogPrefix)
    }

    if (Test-Path -Path $LocalServicePath -PathType Container) {
        $ServiceCrashDumps.LocalService = Get-ChildItem -Path $LocalServicePath
    } else {
        Write-Verbose -Message ("[{0}] The crash dumps path for the LocalService account doesn't exist." -f $LogPrefix)
    }

    if (Test-Path -Path $NetworkServicePath -PathType Container) {
        $ServiceCrashDumps.NetworkService = Get-ChildItem -Path $NetworkServicePath
    } else {
        Write-Verbose -Message ("[{0}] The crash dumps path for the NetworkService account doesn't exist." -f $LogPrefix)
    }

    return $ServiceCrashDumps
}

Function Invoke-CHKDSK {
    [CmdletBinding()]
    Param(
        [ValidateSet('Scan', 'Verify')]
        [String]$Operation = 'Scan'
    )

    # We could use the Repair-Volume cmdlet introduced in Windows 8/Server 2012, but it's just a
    # thin wrapper around CHKDSK and only exposes a small subset of its underlying functionality.
    $LogPrefix = 'CHKDSK'

    # File systems we are able to check for errors (Verify)
    $SupportedFileSystems = @('exFAT', 'FAT', 'FAT16', 'FAT32', 'NTFS', 'NTFS4', 'NTFS5')
    # File systems we are able to fix any errors (Scan)
    #
    # FAT volumes don't support online repair so fixing errors means dismounting the volume. As
    # CHKDSK has no option equivalent to "dismount only if safe" we don't support fixing errors.
    $ScanSupportedFileSystems = @('NTFS', 'NTFS4', 'NTFS5')

    $Volumes = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.FileSystem -in $SupportedFileSystems }

    [PSCustomObject[]]$Results = $null
    foreach ($Volume in $Volumes) {
        $VolumePath = $Volume.Path.TrimEnd('\')

        if ($Operation -eq 'Scan' -and $Volume.FileSystem -notin $ScanSupportedFileSystems) {
            Write-Warning -Message ('[{0}] Skipping volume as non-interactive repair of {1} file systems is unsupported: {2}' -f $LogPrefix, $Volume.FileSystem, $VolumePath)
            continue
        }

        $CHKDSK = [PSCustomObject]@{
            Operation = $Operation
            VolumePath = $VolumePath
            Output = $null
            ExitCode = $null
        }

        Write-Verbose -Message ('[{0}] Running {1} operation on: {2}' -f $LogPrefix, $Operation.ToLower(), $VolumePath)
        $ChkDskPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\chkdsk.exe'
        if ($Operation -eq 'Scan') {
            $CHKDSK.Output += & $ChkDskPath "$VolumePath" /scan
        } else {
            $CHKDSK.Output += & $ChkDskPath "$VolumePath"
        }
        $CHKDSK.ExitCode = $LASTEXITCODE

        switch ($CHKDSK.ExitCode) {
            0 { continue }
            2 { Write-Warning -Message ('[{0}] Volume requires cleanup: {1}' -f $LogPrefix, $VolumePath) }
            3 { Write-Warning -Message ('[{0}] Volume contains errors: {1}' -f $LogPrefix, $VolumePath) }
            default { Write-Error -Message ('[{0}] Unexpected exit code: {1}' -f $LogPrefix, $CHKDSK.ExitCode) }
        }

        $Results += $CHKDSK
    }

    return $Results
}

Function Invoke-DISM {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateSet('AnalyzeComponentStore', 'RestoreHealth', 'ScanHealth', 'StartComponentCleanup')]
        [String]$Operation
    )

    # The Dism PowerShell module doesn't appear to expose the /Cleanup-Image family of parameters
    # available in the underlying Dism.exe utility, so we have to fallback to invoking it directly.
    $LogPrefix = 'DISM'
    $DISM = [PSCustomObject]@{
        Operation = $Operation
        Output = $null
        ExitCode = $null
    }

    Write-Verbose -Message ('[{0}] Running {1} operation ...' -f $LogPrefix, $Operation)
    $DismPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\dism.exe'
    $DISM.Output = & $DismPath /Online /Cleanup-Image /$Operation
    $DISM.ExitCode = $LASTEXITCODE

    switch ($DISM.ExitCode) {
        0 { continue }
        -2146498554 { Write-Warning -Message ('[{0}] The operation could not be completed due to pending operations.' -f $LogPrefix, $DISM.ExitCode) }
        default { Write-Error -Message ('[{0}] Returned non-zero exit code: {1}' -f $LogPrefix, $DISM.ExitCode) }
    }

    return $DISM
}

Function Invoke-SFC {
    [CmdletBinding()]
    Param(
        [ValidateSet('Scan', 'Verify')]
        [String]$Operation = 'Scan'
    )

    $LogPrefix = 'SFC'
    $SFC = [PSCustomObject]@{
        Operation = $Operation
        Output = $null
        ExitCode = $null
    }

    Write-Verbose -Message ('[{0}] Running {1} operation ...' -f $LogPrefix, $Operation.ToLower())
    $SfcPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\sfc.exe'
    # SFC output is UTF-16 in contrast to most built-in Windows console applications? We're probably
    # using ASCII (or similar), so if we don't change this, the text output will be somewhat broken.
    $DefaultOutputEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = [Text.Encoding]::Unicode
    if ($Operation -eq 'Scan') {
        $SFC.Output = & $SfcPath /SCANNOW
    } else {
        $SFC.Output = & $SfcPath /VERIFYONLY
    }
    $SFC.ExitCode = $LASTEXITCODE
    [Console]::OutputEncoding = $DefaultOutputEncoding

    switch ($SFC.ExitCode) {
        0 { continue }
        default { Write-Error -Message ('[{0}] Returned non-zero exit code: {1}' -f $LogPrefix, $SFC.ExitCode) }
    }

    return $SFC
}

Function Update-Sysinternals {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    Param(
        [ValidatePattern('^http[Ss]?://.*')]
        [String]$DownloadUrl = 'https://download.sysinternals.com/files/SysinternalsSuite.zip'
    )

    $LogPrefix = 'Sysinternals'
    $Sysinternals = [PSCustomObject]@{
        Path = $null
        Version = $null
        Updated = $false
    }

    $DownloadDir = $env:TEMP
    $DownloadFile = Split-Path -Path $DownloadUrl -Leaf
    $DownloadPath = Join-Path -Path $DownloadDir -ChildPath $DownloadFile

    if (Test-IsWindows64bit) {
        $InstallDir = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Sysinternals'
    } else {
        $InstallDir = Join-Path -Path $env:ProgramFiles -ChildPath 'Sysinternals'
    }
    $Sysinternals.Path = $InstallDir

    $ExistingVersion = $false
    $VersionFile = Join-Path -Path $InstallDir -ChildPath 'Version.txt'
    if (Test-Path -Path $VersionFile -PathType Leaf) {
        $ExistingVersion = Get-Content -Path $VersionFile
    }

    Write-Verbose -Message ('[{0}] Downloading latest version from: {1}' -f $LogPrefix, $DownloadUrl)
    $null = New-Item -Path $DownloadDir -ItemType Directory -ErrorAction Ignore
    $WebClient = New-Object -TypeName Net.WebClient
    try {
        $WebClient.DownloadFile($DownloadUrl, $DownloadPath)
    } catch {
        # Return immediately with the error message if the download fails
        return $_.Exception.Message
    }

    Write-Verbose -Message ('[{0}] Determining downloaded version ...' -f $LogPrefix)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $Archive = [IO.Compression.ZipFile]::OpenRead($DownloadPath)
    $DownloadedVersion = ($Archive.Entries.LastWriteTime | Sort-Object | Select-Object -Last 1).ToString('yyyyMMdd')
    $Archive.Dispose()

    if (!$ExistingVersion -or ($DownloadedVersion -gt $ExistingVersion)) {
        Write-Verbose -Message ('[{0}] Extracting archive to: {1}' -f $LogPrefix, $InstallDir)
        Remove-Item -Path $InstallDir -Recurse -ErrorAction Ignore
        Expand-ZipFile -FilePath $DownloadPath -DestinationPath $InstallDir
        Set-Content -Path $VersionFile -Value $DownloadedVersion
        Remove-Item -Path $DownloadPath

        $Sysinternals.Version = $DownloadedVersion
        $Sysinternals.Updated = $true
    } elseif ($DownloadedVersion -eq $ExistingVersion) {
        Write-Verbose -Message ('[{0}] Not updating as existing version is latest: {1}' -f $LogPrefix, $ExistingVersion)
        $Sysinternals.Version = $ExistingVersion
    } else {
        Write-Warning -Message ('[{0}] Installed version newer than downloaded version: {1}' -f $LogPrefix, $ExistingVersion)
        $Sysinternals.Version = $ExistingVersion
    }

    $SystemPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::Machine)
    $RegEx = [Regex]::Escape($InstallDir)
    if (!($SystemPath -match "^;*$RegEx;" -or $SystemPath -match ";$RegEx;" -or $SystemPath -match ";$RegEx;*$")) {
        Write-Verbose -Message ('[{0}] Updating system path ...' -f $LogPrefix)
        if (!$SystemPath.EndsWith(';')) {
            $SystemPath += ';'
        }
        $SystemPath += $InstallDir
        [Environment]::SetEnvironmentVariable('Path', $SystemPath, [EnvironmentVariableTarget]::Machine)
    }

    return $Sysinternals
}

Function Expand-ZipFile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$FilePath,

        [Parameter(Mandatory)]
        [String]$DestinationPath
    )

    # The Expand-Archive cmdlet is only available from v5.0
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        Expand-Archive -Path $FilePath -DestinationPath $DestinationPath
    } else {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($FilePath, $DestinationPath)
    }
}

Function Get-WindowsProductType {
    [CmdletBinding()]
    [OutputType([int])]
    Param()

    return (Get-CimInstance -ClassName Win32_OperatingSystem).ProductType
}

Function Test-IsAdministrator {
    [CmdletBinding()]
    [OutputType([bool])]
    Param()

    $User = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if ($User.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        return $true
    }
    return $false
}

Function Test-IsWindows64bit {
    [CmdletBinding()]
    [OutputType([bool])]
    Param()

    if ((Get-CimInstance -ClassName Win32_OperatingSystem).OSArchitecture -eq '64-bit') {
        return $true
    }
    return $false
}
