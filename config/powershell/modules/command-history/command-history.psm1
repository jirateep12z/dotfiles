function ReadHistoryFileSignature {
  param (
    [Parameter(Mandatory = $true)]
    [string]$history_file_path
  )
  try {
    $history_file_info = [System.IO.FileInfo]::new($history_file_path)
    if (-not $history_file_info.Exists) {
      return "missing"
    }
    return "$($history_file_info.LastWriteTimeUtc.Ticks):$($history_file_info.Length)"
  } catch {
    return $null
  }
}

function ReadKnownHistoryEntries {
  param (
    [Parameter(Mandatory = $true)]
    [string]$history_file_path,
    [Parameter(Mandatory = $true)]
    [AllowEmptyCollection()]
    [System.Collections.Generic.HashSet[string]]$known_entries
  )
  $known_entries.Clear()
  $history_signature = ReadHistoryFileSignature -history_file_path $history_file_path
  try {
    if ([System.IO.File]::Exists($history_file_path)) {
      foreach ($history_line in [System.IO.File]::ReadAllLines($history_file_path)) {
        if (-not [string]::IsNullOrWhiteSpace($history_line)) {
          [void]$known_entries.Add($history_line)
        }
      }
    }
    return $history_signature
  } catch {
    $known_entries.Clear()
    return $null
  }
}

function WriteSortedHistory {
  param (
    [Parameter(Mandatory = $true)]
    [string]$history_file_path,
    [Parameter(Mandatory = $true)]
    [AllowEmptyCollection()]
    [System.Collections.Generic.HashSet[string]]$pending_entries,
    [string]$mutex_name = "Local\powershell-command-history",
    [int]$mutex_timeout_ms = 500,
    [AllowEmptyCollection()]
    [System.Collections.Generic.HashSet[string]]$known_entries = $null
  )
  $history_mutex = $null
  $is_mutex_acquired = $false
  $temp_file_path = "$history_file_path.tmp"
  try {
    $history_mutex = new-object System.Threading.Mutex($false, $mutex_name)
    try {
      $is_mutex_acquired = $history_mutex.WaitOne($mutex_timeout_ms)
    } catch [System.Threading.AbandonedMutexException] {
      $is_mutex_acquired = $true
    }
    if (-not $is_mutex_acquired) {
      return $false
    }
    $existing_lines = [string[]]@()
    if ([System.IO.File]::Exists($history_file_path)) {
      $existing_lines = [System.IO.File]::ReadAllLines($history_file_path)
    }
    $sorted_entries = new-object 'System.Collections.Generic.SortedSet[string]' ([System.StringComparer]::Ordinal)
    foreach ($existing_line in $existing_lines) {
      if (-not [string]::IsNullOrWhiteSpace($existing_line)) {
        [void]$sorted_entries.Add($existing_line)
      }
    }
    foreach ($pending_entry in $pending_entries) {
      [void]$sorted_entries.Add($pending_entry)
    }
    $sorted_lines = [string[]]@($sorted_entries)
    $is_file_canonical = [string]::Equals(($existing_lines -join "`n"), ($sorted_lines -join "`n"), [System.StringComparison]::Ordinal)
    if (-not $is_file_canonical) {
      [System.IO.File]::WriteAllLines($temp_file_path, $sorted_lines, (new-object System.Text.UTF8Encoding($false)))
      if ([System.IO.File]::Exists($history_file_path)) {
        [System.IO.File]::Replace($temp_file_path, $history_file_path, [NullString]::Value)
      } else {
        [System.IO.File]::Move($temp_file_path, $history_file_path)
      }
    }
    $pending_entries.Clear()
    if ($null -ne $known_entries) {
      $known_entries.Clear()
      $known_entries.UnionWith($sorted_entries)
    }
    return $true
  } catch {
    return $false
  } finally {
    try {
      if ([System.IO.File]::Exists($temp_file_path)) {
        [System.IO.File]::Delete($temp_file_path)
      }
    } catch {
    }
    if ($is_mutex_acquired) {
      $history_mutex.ReleaseMutex()
    }
    if ($null -ne $history_mutex) {
      $history_mutex.Dispose()
    }
  }
}

function AddSortedHistoryEntry {
  param (
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$command_line,
    [Parameter(Mandatory = $true)]
    [string]$history_file_path,
    [Parameter(Mandatory = $true)]
    [AllowEmptyCollection()]
    [System.Collections.Generic.HashSet[string]]$pending_entries,
    [Parameter(Mandatory = $true)]
    [AllowEmptyCollection()]
    [System.Collections.Generic.HashSet[string]]$known_entries,
    [Parameter(Mandatory = $true)]
    [hashtable]$history_state,
    [string]$mutex_name = "Local\powershell-command-history",
    [int]$mutex_timeout_ms = 500
  )
  $default_option = [Microsoft.PowerShell.PSConsoleReadLine]::GetDefaultAddToHistoryOption($command_line)
  if ($default_option -ne [Microsoft.PowerShell.AddToHistoryOption]::MemoryAndFile) {
    return $default_option
  }
  if ([string]::IsNullOrWhiteSpace($command_line)) {
    return [Microsoft.PowerShell.AddToHistoryOption]::SkipAdding
  }
  if ($command_line.Contains("`n")) {
    return [Microsoft.PowerShell.AddToHistoryOption]::MemoryOnly
  }
  $current_signature = ReadHistoryFileSignature -history_file_path $history_file_path
  $is_file_changed_externally = ($null -eq $current_signature -or $current_signature -ne $history_state.signature)
  if ($is_file_changed_externally) {
    $history_state.signature = ReadKnownHistoryEntries -history_file_path $history_file_path -known_entries $known_entries
  }
  if (-not $known_entries.Contains($command_line)) {
    [void]$pending_entries.Add($command_line)
  }
  if ($pending_entries.Count -gt 0 -or $is_file_changed_externally) {
    $is_write_succeeded = WriteSortedHistory -history_file_path $history_file_path -pending_entries $pending_entries -mutex_name $mutex_name -mutex_timeout_ms $mutex_timeout_ms -known_entries $known_entries
    if ($is_write_succeeded) {
      $history_state.signature = ReadHistoryFileSignature -history_file_path $history_file_path
    }
  }
  return [Microsoft.PowerShell.AddToHistoryOption]::MemoryOnly
}

$HISTORY_FILE_PATH = (get-psreadlineoption).HistorySavePath
$pending_history_entries = new-object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
$known_history_entries = new-object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
$history_file_state = @{ signature = (ReadKnownHistoryEntries -history_file_path $HISTORY_FILE_PATH -known_entries $known_history_entries) }
set-psreadlineoption -addtohistoryhandler {
  param ([string]$command_line)
  AddSortedHistoryEntry -command_line $command_line -history_file_path $HISTORY_FILE_PATH -pending_entries $pending_history_entries -known_entries $known_history_entries -history_state $history_file_state
}
[void](register-engineevent -sourceidentifier PowerShell.Exiting -action {
    & (get-module command-history) {
      if ($pending_history_entries.Count -gt 0) {
        [void](WriteSortedHistory -history_file_path $HISTORY_FILE_PATH -pending_entries $pending_history_entries)
      }
    }
  })

export-modulemember -function @()
