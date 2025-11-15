$script:COLOR_RESET = "`e[0;00m"
$script:COLOR_RED = "`e[0;31m"
$script:COLOR_GREEN = "`e[0;32m"
$script:COLOR_YELLOW = "`e[0;33m"
$script:COLOR_BLUE = "`e[0;34m"
$script:COLOR_MAGENTA = "`e[0;35m"
$script:COLOR_CYAN = "`e[0;36m"
$script:COLOR_WHITE = "`e[0;37m"
$script:COLOR_GRAY = "`e[0;90m"

$script:COLOR_BOLD_RED = "`e[1;31m"
$script:COLOR_BOLD_GREEN = "`e[1;32m"
$script:COLOR_BOLD_YELLOW = "`e[1;33m"
$script:COLOR_BOLD_BLUE = "`e[1;34m"
$script:COLOR_BOLD_MAGENTA = "`e[1;35m"
$script:COLOR_BOLD_CYAN = "`e[1;36m"
$script:COLOR_BOLD_WHITE = "`e[1;37m"

$script:LOG_LEVEL_DEBUG = 0
$script:LOG_LEVEL_INFO = 1
$script:LOG_LEVEL_WARNING = 2
$script:LOG_LEVEL_ERROR = 3
$script:LOG_LEVEL_SUCCESS = 4

$script:DEFAULT_LOG_LEVEL = $script:LOG_LEVEL_INFO
$script:DEFAULT_TIMESTAMP_FORMAT = 'yyyy-MM-dd HH:mm:ss'
$script:DEFAULT_LOG_FILE = ""
$script:DEFAULT_SHOW_TIMESTAMP = $true
$script:DEFAULT_SHOW_LEVEL = $true
$script:DEFAULT_USE_COLOR = $true

$script:CURRENT_LOG_LEVEL = $script:DEFAULT_LOG_LEVEL
$script:CURRENT_LOG_FILE = $script:DEFAULT_LOG_FILE

function GetLogLevelName {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Level
    )
    switch ($Level) {
        $script:LOG_LEVEL_DEBUG { return "DEBUG" }
        $script:LOG_LEVEL_INFO { return "INFO" }
        $script:LOG_LEVEL_WARNING { return "WARNING" }
        $script:LOG_LEVEL_ERROR { return "ERROR" }
        $script:LOG_LEVEL_SUCCESS { return "SUCCESS" }
        default { return "UNKNOWN" }
    }
}

function GetLogLevelNumber {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LevelName
    )
    switch ($LevelName.ToUpper()) {
        "DEBUG" { return $script:LOG_LEVEL_DEBUG }
        "INFO" { return $script:LOG_LEVEL_INFO }
        "WARNING" { return $script:LOG_LEVEL_WARNING }
        "WARN" { return $script:LOG_LEVEL_WARNING }
        "ERROR" { return $script:LOG_LEVEL_ERROR }
        "SUCCESS" { return $script:LOG_LEVEL_SUCCESS }
        default { return $script:LOG_LEVEL_INFO }
    }
}

function SupportsColor {
    if ($Host.UI.SupportsVirtualTerminal) {
        return $true
    }
    if ($env:TERM -match "xterm|color") {
        return $true
    }
    return $false
}

function GetTimestamp {
    param(
        [string]$Format = $script:DEFAULT_TIMESTAMP_FORMAT
    )
    return Get-Date -Format $Format
}

function Logger {
    param(
        [string]$Type = "INFO",
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [bool]$NoTimestamp = $false,
        [bool]$NoColor = $false,
        [string]$File = "",
        [bool]$Bold = $false
    )
    if ([string]::IsNullOrWhiteSpace($Message)) {
        Write-Error "Error: -Message parameter is required"
        return
    }
    $level_number = GetLogLevelNumber -LevelName $Type
    if ($level_number -lt $script:CURRENT_LOG_LEVEL) {
        return
    }
    $timestamp = ""
    if (-not $NoTimestamp) {
        $timestamp = "[$(GetTimestamp)]"
    }
    $color = ""
    $reset = ""
    $use_color = -not $NoColor -and (SupportsColor)
    if ($use_color) {
        $reset = $script:COLOR_RESET
        switch ($Type.ToUpper()) {
            "ERROR" {
                $color = if ($Bold) { $script:COLOR_BOLD_RED } else { $script:COLOR_RED }
            }
            "SUCCESS" {
                $color = if ($Bold) { $script:COLOR_BOLD_GREEN } else { $script:COLOR_GREEN }
            }
            "WARNING" {
                $color = if ($Bold) { $script:COLOR_BOLD_YELLOW } else { $script:COLOR_YELLOW }
            }
            "WARN" {
                $color = if ($Bold) { $script:COLOR_BOLD_YELLOW } else { $script:COLOR_YELLOW }
            }
            "INFO" {
                $color = if ($Bold) { $script:COLOR_BOLD_CYAN } else { $script:COLOR_CYAN }
            }
            "DEBUG" {
                $color = if ($Bold) { $script:COLOR_BOLD_MAGENTA } else { $script:COLOR_MAGENTA }
            }
            default {
                $color = if ($Bold) { $script:COLOR_BOLD_WHITE } else { $script:COLOR_WHITE }
            }
        }
    }
    $level_tag = ""
    if (-not [string]::IsNullOrWhiteSpace($Type)) {
        $level_tag = "[$($Type.ToUpper())]: "
    }
    $output = "${color}${timestamp} - ${level_tag}${Message}${reset}"
    if ($Type.ToUpper() -eq "ERROR") {
        Write-Host $output -ForegroundColor Red
    } else {
        Write-Host $output
    }
    $log_file = if ([string]::IsNullOrWhiteSpace($File)) { $script:CURRENT_LOG_FILE } else { $File }
    if (-not [string]::IsNullOrWhiteSpace($log_file)) {
        $plain_output = "${timestamp} - ${level_tag}${Message}"
        Add-Content -Path $log_file -Value $plain_output -ErrorAction SilentlyContinue
    }
}

function LogDebug {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$File = ""
    )
    $log_file = if ([string]::IsNullOrWhiteSpace($File)) { $script:CURRENT_LOG_FILE } else { $File }
    Logger -Type "DEBUG" -Message $Message -File $log_file
}

function LogInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$File = ""
    )
    $log_file = if ([string]::IsNullOrWhiteSpace($File)) { $script:CURRENT_LOG_FILE } else { $File }
    Logger -Type "INFO" -Message $Message -File $log_file
}

function LogWarning {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$File = ""
    )
    $log_file = if ([string]::IsNullOrWhiteSpace($File)) { $script:CURRENT_LOG_FILE } else { $File }
    Logger -Type "WARNING" -Message $Message -File $log_file
}

function LogError {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$File = ""
    )
    $log_file = if ([string]::IsNullOrWhiteSpace($File)) { $script:CURRENT_LOG_FILE } else { $File }
    Logger -Type "ERROR" -Message $Message -File $log_file
}

function LogSuccess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$File = ""
    )
    $log_file = if ([string]::IsNullOrWhiteSpace($File)) { $script:CURRENT_LOG_FILE } else { $File }
    Logger -Type "SUCCESS" -Message $Message -File $log_file
}

function SetLogLevel {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LevelName
    )
    $script:CURRENT_LOG_LEVEL = GetLogLevelNumber -LevelName $LevelName
    LogDebug -Message "Log level set to: $LevelName"
}

function SetLogFile {
    param(
        [string]$FilePath = ""
    )
    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        $script:CURRENT_LOG_FILE = ""
        return
    }
    $log_dir = Split-Path -Path $FilePath -Parent
    if (-not (Test-Path -Path $log_dir)) {
        try {
            New-Item -Path $log_dir -ItemType Directory -Force | Out-Null
        } catch {
            LogError -Message "Failed to create log directory: $log_dir"
            return
        }
    }
    $script:CURRENT_LOG_FILE = $FilePath
    LogInfo -Message "Log file set to: $FilePath"
}

function LogSeparator {
    param(
        [string]$Char = "=",
        [int]$Width = 60,
        [string]$ColorName = "GRAY"
    )
    $color_var = "COLOR_$($ColorName.ToUpper())"
    $color = if (Get-Variable -Name $color_var -Scope Script -ErrorAction SilentlyContinue) {
        (Get-Variable -Name $color_var -Scope Script).Value
    } else {
        $script:COLOR_GRAY
    }
    $line = $Char * $Width
    Write-Host "${color}${line}$($script:COLOR_RESET)"
}

function LogHeader {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [int]$Width = 60
    )
    $line = "=" * $Width
    $padding = [math]::Max(0, ($Width - $Title.Length) / 2)
    $left_pad = " " * [math]::Floor($padding)
    $right_pad = " " * [math]::Ceiling($padding)
    Write-Host "$($script:COLOR_BOLD_CYAN)${line}$($script:COLOR_RESET)"
    Write-Host "$($script:COLOR_BOLD_CYAN)${left_pad}${Title}${right_pad}$($script:COLOR_RESET)"
    Write-Host "$($script:COLOR_BOLD_CYAN)${line}$($script:COLOR_RESET)"
}

function LogIndent {
    param(
        [Parameter(Mandatory = $true)]
        [int]$IndentLevel,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$LogType = "INFO"
    )
    $indent = " " * ($IndentLevel * 2)
    Logger -Type $LogType -Message "${indent}${Message}"
}

function LogKeyValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [string]$LogType = "INFO"
    )
    Logger -Type $LogType -Message "${Key}: ${Value}"
}

function LogArray {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Array,
        [string]$LogType = "INFO"
    )
    $index = 0
    foreach ($item in $Array) {
        Logger -Type $LogType -Message "  [$index] $item"
        $index++
    }
}

function LogCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [bool]$ShowOutput = $false
    )
    LogInfo -Message "Executing: $Command"
    try {
        if ($ShowOutput) {
            $output = Invoke-Expression $Command 2>&1
            foreach ($line in $output) {
                LogDebug -Message "  $line"
            }
            $exit_code = $LASTEXITCODE
        } else {
            Invoke-Expression $Command | Out-Null
            $exit_code = $LASTEXITCODE
        }
        if ($exit_code -eq 0 -or $null -eq $exit_code) {
            LogSuccess -Message "Command completed successfully"
        } else {
            LogError -Message "Command failed with exit code: $exit_code"
        }
        return $exit_code
    } catch {
        LogError -Message "Command failed with error: $_"
        return 1
    }
}

Export-ModuleMember -Function @(
    'GetTimestamp',
    'Logger',
    'LogDebug',
    'LogInfo',
    'LogWarning',
    'LogError',
    'LogSuccess',
    'SetLogLevel',
    'SetLogFile',
    'LogSeparator',
    'LogHeader',
    'LogIndent',
    'LogKeyValue',
    'LogArray',
    'LogCommand'
)
