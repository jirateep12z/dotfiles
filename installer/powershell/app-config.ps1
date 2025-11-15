function SetApplicationConfig {
  param (
    [string]$AppName,
    [string]$SourcePath,
    [string]$DestinationPath,
    [string[]]$Extensions = @(),
    [string[]]$Files = @()
  )
  try {
    if ($AppName) {
      LogInfo "Configuring $AppName"
    }
    if (-not (Test-Path $SourcePath)) {
      LogWarning "Source path not found: $SourcePath"
      return $false
    }
    if (Test-Path $DestinationPath) {
      if ($Extensions.Count -eq 0 -and $Files.Count -eq 0) {
        LogInfo "Cleaning destination: $DestinationPath"
        Remove-Item -Path "$DestinationPath" -Recurse -Force
        New-Item -Path "$DestinationPath" -ItemType Directory -Force | Out-Null
      } else {
        if ($Extensions.Count -gt 0) {
          foreach ($extension in $Extensions) {
            Get-ChildItem -Path "$DestinationPath" -Filter "*.$extension" -ErrorAction SilentlyContinue | Remove-Item -Force
          }
        }
        if ($Files.Count -gt 0) {
          foreach ($file in $Files) {
            $target_file = Join-Path $DestinationPath $file
            if (Test-Path $target_file) {
              Remove-Item -Path $target_file -Force
            }
          }
        }
      }
    } else {
      LogInfo "Creating destination: $DestinationPath"
      New-Item -Path "$DestinationPath" -ItemType Directory -Force | Out-Null
    }
    if ((Get-Item $SourcePath).PSIsContainer) {
      Copy-Item -Path "$SourcePath/*" -Destination "$DestinationPath" -Recurse -Force
    } else {
      Copy-Item -Path "$SourcePath" -Destination "$DestinationPath" -Recurse -Force
    }
    LogSuccess "$AppName configured successfully"
    return $true
  } catch {
    LogError "An error occurred while configuring $AppName : $_"
    return $false
  }
}

function RemoveApplicationConfig {
  param (
    [string]$AppName,
    [string]$DestinationPath,
    [string[]]$Extensions = @(),
    [string[]]$Files = @()
  )
  try {
    if ($AppName) {
      LogInfo "Removing $AppName configuration"
    }
    if (Test-Path $DestinationPath) {
      if ($Extensions.Count -eq 0 -and $Files.Count -eq 0) {
        Remove-Item -Path "$DestinationPath" -Recurse -Force
        LogSuccess "Removed $AppName configuration"
      } else {
        if ($Extensions.Count -gt 0) {
          foreach ($extension in $Extensions) {
            Get-ChildItem -Path "$DestinationPath" -Filter "*.$extension" -ErrorAction SilentlyContinue | Remove-Item -Force
          }
        }
        if ($Files.Count -gt 0) {
          foreach ($file in $Files) {
            $target_file = Join-Path $DestinationPath $file
            if (Test-Path $target_file) {
              Remove-Item -Path $target_file -Force
            }
          }
        }
        LogSuccess "Removed $AppName configuration files"
      }
    } else {
      LogWarning "Configuration path not found: $DestinationPath"
      return $false
    }
    return $true
  } catch {
    LogError "An error occurred while removing $AppName configuration: $_"
    return $false
  }
}
