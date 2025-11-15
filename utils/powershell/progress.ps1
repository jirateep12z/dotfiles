$script:DEFAULT_PROGRESS_WIDTH = 50
$script:DEFAULT_PROGRESS_FILL_CHAR = "█"
$script:DEFAULT_PROGRESS_EMPTY_CHAR = "░"
$script:DEFAULT_PROGRESS_FILL_CHAR_WIN = "#"
$script:DEFAULT_PROGRESS_EMPTY_CHAR_WIN = "-"
$script:DEFAULT_SPINNER_DELAY = 100
$script:DEFAULT_BOX_WIDTH = 60

$script:SPINNER_STYLE_DEFAULT = @('|', '/', '-', '\')
$script:SPINNER_STYLE_DOTS = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
$script:SPINNER_STYLE_ARROWS = @('←', '↖', '↑', '↗', '→', '↘', '↓', '↙')
$script:SPINNER_STYLE_CIRCLE = @('◐', '◓', '◑', '◒')
$script:SPINNER_STYLE_BOUNCE = @('⠁', '⠂', '⠄', '⡀', '⢀', '⠠', '⠐', '⠈')

function SupportsUnicode {
    try {
        if ([System.Console]::OutputEncoding.EncodingName -match "Unicode|UTF") {
            return $true
        }
        if ($env:LANG -match "UTF-8|utf8") {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

function GetTerminalWidth {
    try {
        $width = $Host.UI.RawUI.WindowSize.Width
        if ($width -gt 0) {
            return $width
        }
    } catch {
        return 80
    }
    return 80
}

function ShowProgress {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Current,
        [Parameter(Mandatory = $true)]
        [int]$Total,
        [string]$ItemName = "",
        [bool]$ShowProgress = $true,
        [int]$Width = $script:DEFAULT_PROGRESS_WIDTH,
        [ValidateSet("detailed", "simple", "minimal")]
        [string]$Style = "detailed"
    )
    if (-not $ShowProgress) {
        return
    }
    if ($Current -lt 0 -or $Total -lt 0 -or $Width -le 0) {
        Write-Error "Current and Total must be non-negative and Width must be positive"
        return
    }
    if ($Total -eq 0) {
        return
    }
    if ($Current -gt $Total) {
        $Current = $Total
    }
    $percent = [math]::Floor(($Current * 100) / $Total)
    $filled = [math]::Floor(($percent * $Width) / 100)
    $empty = $Width - $filled
    $fill_char = $script:DEFAULT_PROGRESS_FILL_CHAR
    $empty_char = $script:DEFAULT_PROGRESS_EMPTY_CHAR
    if (-not (SupportsUnicode)) {
        $fill_char = $script:DEFAULT_PROGRESS_FILL_CHAR_WIN
        $empty_char = $script:DEFAULT_PROGRESS_EMPTY_CHAR_WIN
    }
    switch ($Style) {
        "simple" {
            Write-Host -NoNewline "`r[$percent%] $ItemName"
        }
        "minimal" {
            Write-Host -NoNewline "`r$percent%"
        }
        "detailed" {
            $bar = "[" + ($fill_char * $filled) + ($empty_char * $empty) + "] $percent% ($Current/$Total)"
            if ($ItemName) {
                $bar += " $ItemName"
            }
            Write-Host -NoNewline "`r$bar"
        }
    }
}

function ClearProgress {
    param(
        [bool]$ShowProgress = $true,
        [bool]$ClearLine = $false
    )
    if ($ShowProgress) {
        if ($ClearLine) {
            $width = GetTerminalWidth
            Write-Host -NoNewline ("`r" + (' ' * $width) + "`r")
        } else {
            Write-Host ""
        }
    }
}

function ShowSpinner {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        [string]$Message = "Processing...",
        [ValidateSet("default", "dots", "arrows", "circle", "bounce")]
        [string]$Style = "default",
        [int]$Delay = $script:DEFAULT_SPINNER_DELAY
    )
    if ($Delay -lt 0) {
        Write-Error "Delay must be non-negative"
        return
    }
    $spinstr = $script:SPINNER_STYLE_DEFAULT
    switch ($Style) {
        "dots" { $spinstr = $script:SPINNER_STYLE_DOTS }
        "arrows" { $spinstr = $script:SPINNER_STYLE_ARROWS }
        "circle" { $spinstr = $script:SPINNER_STYLE_CIRCLE }
        "bounce" { $spinstr = $script:SPINNER_STYLE_BOUNCE }
    }
    if (-not (SupportsUnicode) -and $Style -ne "default") {
        $spinstr = $script:SPINNER_STYLE_DEFAULT
    }
    $job = $null
    try {
        $job = Start-Job -ScriptBlock $ScriptBlock -ErrorAction Stop
        $index = 0
        while ($job.State -eq "Running" -or $job.State -eq "NotStarted") {
            $char = $spinstr[$index % $spinstr.Count]
            Write-Host -NoNewline "`r[$char] $Message"
            Start-Sleep -Milliseconds $Delay
            $index++
            $job = Get-Job -Id $job.Id -ErrorAction Stop
        }
        return Receive-Job -Job $job -Wait -ErrorAction Stop
    } catch {
        Write-Error "Error: Spinner failed: $_"
        return
    } finally {
        if ($null -ne $job) {
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
        $width = GetTerminalWidth
        Write-Host -NoNewline ("`r" + (' ' * $width) + "`r")
    }
}

function ShowSpinnerWithTime {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        [string]$Message = "Processing..."
    )
    $start_time = Get-Date
    $spinstr = @('|', '/', '-', '\')
    $job = $null
    try {
        $job = Start-Job -ScriptBlock $ScriptBlock -ErrorAction Stop
        $index = 0
        while ($job.State -eq "Running" -or $job.State -eq "NotStarted") {
            $current_time = Get-Date
            $elapsed = [math]::Floor(($current_time - $start_time).TotalSeconds)
            $char = $spinstr[$index % $spinstr.Count]
            Write-Host -NoNewline "`r[$char] $Message (Elapsed: ${elapsed}s)"
            Start-Sleep -Milliseconds 100
            $index++
            $job = Get-Job -Id $job.Id -ErrorAction Stop
        }
        $result = Receive-Job -Job $job -Wait -ErrorAction Stop
        $end_time = Get-Date
        $total_elapsed = [math]::Floor(($end_time - $start_time).TotalSeconds)
        Write-Host "Completed in ${total_elapsed}s"
        return $result
    } catch {
        Write-Error "Error: Spinner failed: $_"
        return
    } finally {
        if ($null -ne $job) {
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
        $width = GetTerminalWidth
        Write-Host -NoNewline ("`r" + (' ' * $width) + "`r")
    }
}

function DrawBox {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [int]$Width = $script:DEFAULT_BOX_WIDTH,
        [ValidateSet("double", "single", "ascii")]
        [string]$Style = "double",
        [string]$Color = ""
    )
    if ($Width -le 0) {
        Write-Error "Width must be positive"
        return
    }
    $reset = if ([string]::IsNullOrEmpty($Color)) { "" } else { "`e[0m" }
    $top_left = "╔"
    $top_right = "╗"
    $bottom_left = "╚"
    $bottom_right = "╝"
    $horizontal = "═"
    $vertical = "║"
    if ($Style -eq "single" -and (SupportsUnicode)) {
        $top_left = "┌"
        $top_right = "┐"
        $bottom_left = "└"
        $bottom_right = "┘"
        $horizontal = "─"
        $vertical = "│"
    } elseif ($Style -eq "ascii" -or -not (SupportsUnicode)) {
        $top_left = "+"
        $top_right = "+"
        $bottom_left = "+"
        $bottom_right = "+"
        $horizontal = "-"
        $vertical = "|"
    }
    $horizontal_line = $horizontal * $Width
    $padding = [math]::Max(0, ($Width - $Title.Length) / 2)
    $left_pad = " " * [math]::Floor($padding)
    $right_pad = " " * [math]::Ceiling($padding)
    Write-Host "${Color}${top_left}${horizontal_line}${top_right}${reset}"
    Write-Host "${Color}${vertical}${left_pad}${Title}${right_pad}${vertical}${reset}"
    Write-Host "${Color}${bottom_left}${horizontal_line}${bottom_right}${reset}"
}

function DrawLine {
    param(
        [string]$Char = "═",
        [int]$Width = $script:DEFAULT_BOX_WIDTH,
        [string]$Color = ""
    )
    if ($Width -lt 0 -or [string]::IsNullOrEmpty($Char)) {
        Write-Error "Width must be non-negative and Char must not be empty"
        return
    }
    $reset = if ([string]::IsNullOrEmpty($Color)) { "" } else { "`e[0m" }
    if (-not (SupportsUnicode)) {
        switch ($Char) {
            { $_ -in @("═", "─", "━") } { $Char = "-" }
            { $_ -in @("║", "│", "┃") } { $Char = "|" }
        }
    }
    $line = $Char * $Width
    Write-Host "${Color}${line}${reset}"
}

function ShowPercentage {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Current,
        [Parameter(Mandatory = $true)]
        [int]$Total,
        [int]$Decimals = 0
    )
    if ($Current -lt 0 -or $Total -lt 0 -or $Decimals -lt 0) {
        Write-Error "Current, Total, and Decimals must be non-negative"
        return "0%"
    }
    if ($Total -eq 0) {
        return "0%"
    }
    if ($Current -gt $Total) {
        $Current = $Total
    }
    if ($Decimals -eq 0) {
        $percent = [math]::Floor(($Current * 100) / $Total)
        return "${percent}%"
    } else {
        $percent = [math]::Round(($Current * 100) / $Total, $Decimals)
        return "${percent}%"
    }
}

function FormatBytes {
    param(
        [Parameter(Mandatory = $true)]
        [long]$Bytes,
        [int]$Precision = 0
    )
    if ($Bytes -lt 0 -or $Precision -lt 0) {
        Write-Error "Bytes and Precision must be non-negative"
        return "0B"
    }
    if ($Bytes -lt 1KB) {
        return "${Bytes}B"
    } elseif ($Bytes -lt 1MB) {
        if ($Precision -gt 0) {
            $value = [math]::Round($Bytes / 1KB, $Precision)
            return "${value}KB"
        } else {
            return "$([math]::Floor($Bytes / 1KB))KB"
        }
    } elseif ($Bytes -lt 1GB) {
        if ($Precision -gt 0) {
            $value = [math]::Round($Bytes / 1MB, $Precision)
            return "${value}MB"
        } else {
            return "$([math]::Floor($Bytes / 1MB))MB"
        }
    } else {
        if ($Precision -gt 0) {
            $value = [math]::Round($Bytes / 1GB, $Precision)
            return "${value}GB"
        } else {
            return "$([math]::Floor($Bytes / 1GB))GB"
        }
    }
}

function FormatDuration {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Seconds,
        [ValidateSet("short", "long", "compact")]
        [string]$Style = "short"
    )
    if ($Seconds -lt 0) {
        Write-Error "Seconds must be non-negative"
        return "0s"
    }
    $days = [math]::Floor($Seconds / 86400)
    $hours = [math]::Floor(($Seconds % 86400) / 3600)
    $minutes = [math]::Floor(($Seconds % 3600) / 60)
    $secs = $Seconds % 60
    switch ($Style) {
        "long" {
            $result = ""
            if ($days -gt 0) { $result += "$days day(s) " }
            if ($hours -gt 0) { $result += "$hours hour(s) " }
            if ($minutes -gt 0) { $result += "$minutes minute(s) " }
            if ($secs -gt 0 -or $result -eq "") { $result += "$secs second(s)" }
            return $result.Trim()
        }
        "compact" {
            if ($days -gt 0) {
                return "${days}d${hours}h"
            } elseif ($hours -gt 0) {
                return "${hours}h${minutes}m"
            } elseif ($minutes -gt 0) {
                return "${minutes}m${secs}s"
            } else {
                return "${secs}s"
            }
        }
        "short" {
            if ($Seconds -lt 60) {
                return "${Seconds}s"
            } elseif ($Seconds -lt 3600) {
                return "$([math]::Floor($Seconds / 60))m $($Seconds % 60)s"
            } elseif ($Seconds -lt 86400) {
                return "$([math]::Floor($Seconds / 3600))h $([math]::Floor(($Seconds % 3600) / 60))m"
            } else {
                return "${days}d ${hours}h"
            }
        }
    }
}

function FormatTableCell {
    param(
        [AllowEmptyString()]
        [string]$Value,
        [Parameter(Mandatory = $true)]
        [int]$ColumnWidth
    )
    if ($null -eq $Value) {
        $Value = ""
    }
    $content_width = $ColumnWidth - 1
    if ($Value.Length -gt $content_width) {
        return $Value.Substring(0, $content_width)
    }
    return $Value.PadRight($content_width)
}

function ShowTableHeader {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Columns,
        [int]$ColumnWidth = 20
    )
    if ($ColumnWidth -lt 1) {
        Write-Error "ColumnWidth must be positive"
        return
    }
    if (SupportsUnicode) {
        $left = "┌"; $right = "┐"; $junction = "┬"; $middle_left = "├"; $middle_right = "┤"; $middle_junction = "┼"; $horizontal = "─"; $vertical = "│"
    } else {
        $left = "+"; $right = "+"; $junction = "+"; $middle_left = "+"; $middle_right = "+"; $middle_junction = "+"; $horizontal = "-"; $vertical = "|"
    }
    $segments = @($Columns | ForEach-Object { $horizontal * $ColumnWidth })
    Write-Host ($left + ($segments -join $junction) + $right)
    $cells = @($Columns | ForEach-Object { " " + (FormatTableCell -Value $_ -ColumnWidth $ColumnWidth) + $vertical })
    Write-Host ($vertical + ($cells -join ""))
    Write-Host ($middle_left + ($segments -join $middle_junction) + $middle_right)
}

function ShowTableRow {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Values,
        [int]$ColumnWidth = 20
    )
    if ($ColumnWidth -lt 1) {
        Write-Error "ColumnWidth must be positive"
        return
    }
    $vertical = if (SupportsUnicode) { "│" } else { "|" }
    $cells = @($Values | ForEach-Object { " " + (FormatTableCell -Value $_ -ColumnWidth $ColumnWidth) + $vertical })
    Write-Host ($vertical + ($cells -join ""))
}

function ShowTableFooter {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ColumnCount,
        [int]$ColumnWidth = 20
    )
    if ($ColumnCount -lt 0 -or $ColumnWidth -lt 1) {
        Write-Error "ColumnCount must be non-negative and ColumnWidth must be positive"
        return
    }
    if (SupportsUnicode) {
        $left = "└"; $right = "┘"; $junction = "┴"; $horizontal = "─"
    } else {
        $left = "+"; $right = "+"; $junction = "+"; $horizontal = "-"
    }
    $segments = @()
    for ($i = 0; $i -lt $ColumnCount; $i++) {
        $segments += $horizontal * $ColumnWidth
    }
    Write-Host ($left + ($segments -join $junction) + $right)
}

if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'ShowProgress',
        'ClearProgress',
        'ShowSpinner',
        'ShowSpinnerWithTime',
        'DrawBox',
        'DrawLine',
        'ShowPercentage',
        'FormatBytes',
        'FormatDuration',
        'ShowTableHeader',
        'ShowTableRow',
        'ShowTableFooter'
    )
}
