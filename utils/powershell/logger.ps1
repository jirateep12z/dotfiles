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
        try {
            Add-Content -LiteralPath $log_file -Value $plain_output -ErrorAction Stop
        } catch {
            Write-Error "Error: Failed to write log file: $log_file"
        }
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
    $log_dir = [System.IO.Path]::GetDirectoryName($FilePath)
    if (-not [string]::IsNullOrWhiteSpace($log_dir) -and -not (Test-Path -LiteralPath $log_dir)) {
        try {
            [void][System.IO.Directory]::CreateDirectory($log_dir)
        } catch {
            LogError -Message "Failed to create log directory: $log_dir"
            return
        }
    }
    try {
        $stream = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
        $stream.Dispose()
    } catch {
        LogError -Message "Failed to open log file: $FilePath"
        return
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
    if ($Width -lt 0 -or [string]::IsNullOrEmpty($Char)) {
        Write-Error "Error: Width must be non-negative and Char must not be empty"
        return
    }
    $color_var = "COLOR_$($ColorName.ToUpper())"
    $color = if (Get-Variable -Name $color_var -Scope Script -ErrorAction SilentlyContinue) {
        (Get-Variable -Name $color_var -Scope Script).Value
    } else {
        $script:COLOR_GRAY
    }
    $reset = ""
    if ($script:DEFAULT_USE_COLOR -and (SupportsColor)) {
        $reset = $script:COLOR_RESET
    } else {
        $color = ""
    }
    $line = $Char * $Width
    Write-Host "${color}${line}${reset}"
}

function LogHeader {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [int]$Width = 60
    )
    if ($Width -lt 0) {
        Write-Error "Error: Width must be non-negative"
        return
    }
    $line = "=" * $Width
    $padding = [math]::Max(0, ($Width - $Title.Length) / 2)
    $left_pad = " " * [math]::Floor($padding)
    $right_pad = " " * [math]::Ceiling($padding)
    $color = ""
    $reset = ""
    if ($script:DEFAULT_USE_COLOR -and (SupportsColor)) {
        $color = $script:COLOR_BOLD_CYAN
        $reset = $script:COLOR_RESET
    }
    Write-Host "${color}${line}${reset}"
    Write-Host "${color}${left_pad}${Title}${right_pad}${reset}"
    Write-Host "${color}${line}${reset}"
}

function LogIndent {
    param(
        [Parameter(Mandatory = $true)]
        [int]$IndentLevel,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$LogType = "INFO"
    )
    if ($IndentLevel -lt 0) {
        Write-Error "Error: IndentLevel must be non-negative"
        return
    }
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
    $previous_error_action = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Stop'
        $global:LASTEXITCODE = 0
        $command_block = [scriptblock]::Create($Command)
        if ($ShowOutput) {
            $output = @(& $command_block 2>&1)
            $invocation_succeeded = $?
            $exit_code = if ($invocation_succeeded) { [int]$LASTEXITCODE } else { 1 }
            foreach ($line in $output) {
                LogDebug -Message "  $line"
            }
        } else {
            & $command_block | Out-Null
            $invocation_succeeded = $?
            $exit_code = if ($invocation_succeeded) { [int]$LASTEXITCODE } else { 1 }
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
    } finally {
        $ErrorActionPreference = $previous_error_action
    }
}

if ($MyInvocation.MyCommand.ScriptBlock.Module) {
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
}
