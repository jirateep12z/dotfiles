function InvokePackageCommand {
  param (
    [string]$CommandText,
    [string]$Package,
    [string]$AdditionalParams = ""
  )
  if ([string]::IsNullOrWhiteSpace($CommandText)) {
    LogError "Package command is empty"
    return $false
  }
  $command_parts = $CommandText -split '\s+'
  $command_name = $command_parts[0]
  $arguments = @()
  if ($command_parts.Count -gt 1) {
    $arguments += $command_parts[1..($command_parts.Count - 1)]
  }
  $arguments += ($Package -split '\s+')
  if (-not [string]::IsNullOrWhiteSpace($AdditionalParams)) {
    $arguments += ($AdditionalParams -split '\s+')
  }
  try {
    $command_info = Get-Command $command_name -ErrorAction Stop
    $invoke_arguments = $arguments
    if ($command_info.CommandType -eq "Cmdlet") {
      $invoke_arguments += @("-ErrorAction", "Stop")
    }
    if ($command_info.CommandType -eq "Application" -or $command_info.CommandType -eq "ExternalScript") {
      $executable_path = $command_info.Source
      if ($command_info.CommandType -eq "ExternalScript") {
        $application_command = Get-Command "$command_name.cmd" -ErrorAction SilentlyContinue
        if ($application_command) {
          $executable_path = $application_command.Source
        }
      }
      $process = Start-Process -FilePath $executable_path -ArgumentList $invoke_arguments -NoNewWindow -Wait -PassThru
      return ($process.ExitCode -eq 0)
    }
    & $command_name @invoke_arguments
    return $true
  } catch {
    LogError "Command failed: $CommandText $Package $AdditionalParams : $_"
    return $false
  }
}

function InstallPackage {
  param (
    [string]$PackageName,
    [string]$PackageListPath,
    [string]$InstallCommand,
    [string]$AdditionalParams = ""
  )
  try {
    if (-not (Test-Path $PackageListPath)) {
      LogWarning "Package list not found: $PackageListPath"
      return $false
    }
    if ($PackageName) {
      LogInfo "Installing $PackageName"
    }
    $packages = @(Get-Content $PackageListPath | Where-Object { $_ -and $_ -notmatch '^\s*#' })
    $total = $packages.Count
    $current = 0
    $failed_packages = @()
    foreach ($package in $packages) {
      $current++
      LogInfo "[$current/$total] Installing: $package"
      if (-not (InvokePackageCommand -CommandText $InstallCommand -Package $package -AdditionalParams $AdditionalParams)) {
        $failed_packages += $package
        LogError "Failed to install: $package"
      }
    }
    if ($failed_packages.Count -gt 0) {
      LogError "Failed to install $PackageName : $($failed_packages -join ', ')"
      return $false
    }
    LogSuccess "Completed installing $PackageName"
    return $true
  } catch {
    LogError "An error occurred while installing $PackageName : $_"
    return $false
  }
}

function UninstallPackage {
  param (
    [string]$PackageName,
    [string]$PackageListPath,
    [string]$UninstallCommand
  )
  try {
    if (-not (Test-Path $PackageListPath)) {
      LogWarning "Package list not found: $PackageListPath"
      return $false
    }
    if ($PackageName) {
      LogInfo "Uninstalling $PackageName"
    }
    $packages = @(Get-Content $PackageListPath | Where-Object { $_ -and $_ -notmatch '^\s*#' })
    $total = $packages.Count
    $current = 0
    $failed_packages = @()
    foreach ($package in $packages) {
      $current++
      LogInfo "[$current/$total] Uninstalling: $package"
      if (-not (InvokePackageCommand -CommandText $UninstallCommand -Package $package)) {
        $failed_packages += $package
        LogError "Failed to uninstall: $package"
      }
    }
    if ($failed_packages.Count -gt 0) {
      LogError "Failed to uninstall $PackageName : $($failed_packages -join ', ')"
      return $false
    }
    LogSuccess "Completed uninstalling $PackageName"
    return $true
  } catch {
    LogError "An error occurred while uninstalling $PackageName : $_"
    return $false
  }
}
