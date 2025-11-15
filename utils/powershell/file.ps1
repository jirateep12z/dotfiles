$script:DEFAULT_HASH_METHOD = "MD5"
$script:DEFAULT_BACKUP_COMPRESS = $false
$script:DEFAULT_MIN_SIZE = 0
$script:DEFAULT_MAX_SIZE = 0
$script:DEFAULT_MIN_AGE_DAYS = 0

$script:ERR_INVALID_PATH = 1
$script:ERR_PATH_NOT_FOUND = 2
$script:ERR_INVALID_PARAM = 3
$script:ERR_OPERATION_FAILED = 4
$script:ERR_PERMISSION_DENIED = 5

function ValidateDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Error "Error: Path parameter is required"
        return $script:ERR_INVALID_PARAM
    }
    if (-not (Test-Path -Path $Path)) {
        Write-Error "Error: Path does not exist: $Path"
        return $script:ERR_PATH_NOT_FOUND
    }
    if (-not (Test-Path -Path $Path -PathType Container)) {
        Write-Error "Error: Path is not a directory: $Path"
        return $script:ERR_INVALID_PATH
    }
    try {
        [void](Get-ChildItem -Path $Path -ErrorAction Stop)
    } catch {
        Write-Error "Error: Permission denied: $Path"
        return $script:ERR_PERMISSION_DENIED
    }
    return 0
}

function ValidateFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Error "Error: Path parameter is required"
        return $script:ERR_INVALID_PARAM
    }
    if (-not (Test-Path -Path $Path)) {
        Write-Error "Error: File does not exist: $Path"
        return $script:ERR_PATH_NOT_FOUND
    }
    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        Write-Error "Error: Path is not a file: $Path"
        return $script:ERR_INVALID_PATH
    }
    try {
        [void](Get-Content -Path $Path -TotalCount 1 -ErrorAction Stop)
    } catch {
        Write-Error "Error: Permission denied: $Path"
        return $script:ERR_PERMISSION_DENIED
    }
    return 0
}

function GetDirectorySize {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,
        [bool]$HumanReadable = $true
    )
    $validation_result = ValidateDirectory -Path $DirectoryPath
    if ($validation_result -ne 0) {
        return $null
    }
    try {
        $size = (Get-ChildItem -Path $DirectoryPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if ($null -eq $size) {
            $size = 0
        }
        if ($HumanReadable) {
            return FormatBytes -Bytes $size
        }
        return $size
    } catch {
        Write-Error "Error: Failed to calculate directory size"
        return $null
    }
}

function CountFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,
        [int]$MaxDepth = -1
    )
    $validation_result = ValidateDirectory -Path $DirectoryPath
    if ($validation_result -ne 0) {
        return 0
    }
    try {
        if ($MaxDepth -gt 0) {
            $count = (Get-ChildItem -Path $DirectoryPath -File -Depth $MaxDepth -ErrorAction SilentlyContinue | Measure-Object).Count
        } else {
            $count = (Get-ChildItem -Path $DirectoryPath -File -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
        }
        return $count
    } catch {
        return 0
    }
}

function CountDirectories {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,
        [int]$MaxDepth = -1,
        [bool]$ExcludeSelf = $true
    )
    $validation_result = ValidateDirectory -Path $DirectoryPath
    if ($validation_result -ne 0) {
        return 0
    }
    try {
        if ($MaxDepth -gt 0) {
            $count = (Get-ChildItem -Path $DirectoryPath -Directory -Depth $MaxDepth -ErrorAction SilentlyContinue | Measure-Object).Count
        } else {
            $count = (Get-ChildItem -Path $DirectoryPath -Directory -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
        }
        if ($ExcludeSelf -and $count -gt 0) {
            $count--
        }
        return $count
    } catch {
        return 0
    }
}

function GetFileSize {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [bool]$HumanReadable = $false
    )
    $validation_result = ValidateFile -Path $FilePath
    if ($validation_result -ne 0) {
        return 0
    }
    try {
        $size = (Get-Item -Path $FilePath).Length
        if ($HumanReadable) {
            return FormatBytes -Bytes $size
        }
        return $size
    } catch {
        Write-Error "Error: Failed to get file size"
        return 0
    }
}

function GetFileMD5 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    $validation_result = ValidateFile -Path $FilePath
    if ($validation_result -ne 0) {
        return ""
    }
    try {
        $hash = Get-FileHash -Path $FilePath -Algorithm MD5
        return $hash.Hash
    } catch {
        Write-Error "Error: Failed to calculate MD5 hash"
        return ""
    }
}

function GetFileSHA256 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    $validation_result = ValidateFile -Path $FilePath
    if ($validation_result -ne 0) {
        return ""
    }
    try {
        $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
        return $hash.Hash
    } catch {
        Write-Error "Error: Failed to calculate SHA256 hash"
        return ""
    }
}

function GetFileAge {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [ValidateSet("seconds", "minutes", "hours", "days")]
        [string]$Unit = "days"
    )
    $validation_result = ValidateFile -Path $FilePath
    if ($validation_result -ne 0) {
        return 0
    }
    try {
        $file_time = (Get-Item -Path $FilePath).LastWriteTime
        $current_time = Get-Date
        $age_span = $current_time - $file_time
        switch ($Unit) {
            "seconds" { return [int]$age_span.TotalSeconds }
            "minutes" { return [int]$age_span.TotalMinutes }
            "hours" { return [int]$age_span.TotalHours }
            "days" { return [int]$age_span.TotalDays }
        }
    } catch {
        Write-Error "Error: Failed to calculate file age"
        return 0
    }
}

function GetTrashPath {
    param(
        [string]$CustomPath = ""
    )
    if (-not [string]::IsNullOrWhiteSpace($CustomPath)) {
        return $CustomPath
    }
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
        return "$env:USERPROFILE\AppData\Local\Temp\RecycleBin"
    } elseif ($IsMacOS) {
        return "$env:HOME/.Trash"
    } elseif ($IsLinux) {
        return "$env:HOME/.local/share/Trash/files"
    } else {
        Write-Error "Error: Unsupported operating system"
        return $null
    }
}

function MoveToTrash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [string]$CustomTrashPath = "",
        [bool]$AddTimestamp = $true
    )
    if ([string]::IsNullOrWhiteSpace($SourcePath)) {
        Write-Error "Error: Source path parameter is required"
        return $script:ERR_INVALID_PARAM
    }
    if (-not (Test-Path -Path $SourcePath)) {
        Write-Error "Error: Source path does not exist: $SourcePath"
        return $script:ERR_PATH_NOT_FOUND
    }
    $trash_path = GetTrashPath -CustomPath $CustomTrashPath
    if ([string]::IsNullOrWhiteSpace($trash_path)) {
        Write-Error "Error: Could not determine trash path"
        return $script:ERR_OPERATION_FAILED
    }
    if (-not (Test-Path -Path $trash_path)) {
        New-Item -Path $trash_path -ItemType Directory -Force | Out-Null
    }
    $item_name = Split-Path -Path $SourcePath -Leaf
    $dest_name = $item_name
    if ($AddTimestamp) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $dest_name = "${item_name}_${timestamp}"
    }
    $dest_path = Join-Path -Path $trash_path -ChildPath $dest_name
    try {
        Move-Item -Path $SourcePath -Destination $dest_path -Force
        return 0
    } catch {
        Write-Error "Error: Failed to move to trash: $SourcePath"
        return $script:ERR_OPERATION_FAILED
    }
}

function CreateBackup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$BackupDirectory,
        [bool]$Compress = $false,
        [string]$TimestampFormat = "yyyyMMdd_HHmmss",
        [bool]$KeepStructure = $true
    )
    if ([string]::IsNullOrWhiteSpace($SourcePath)) {
        Write-Error "Error: Source path parameter is required"
        return $null
    }
    if ([string]::IsNullOrWhiteSpace($BackupDirectory)) {
        Write-Error "Error: Backup directory parameter is required"
        return $null
    }
    if (-not (Test-Path -Path $SourcePath)) {
        Write-Error "Error: Source path does not exist: $SourcePath"
        return $null
    }
    $timestamp = Get-Date -Format $TimestampFormat
    $backup_subdir = $BackupDirectory
    if ($KeepStructure) {
        $backup_subdir = Join-Path -Path $BackupDirectory -ChildPath $timestamp
    }
    if (-not (Test-Path -Path $backup_subdir)) {
        New-Item -Path $backup_subdir -ItemType Directory -Force | Out-Null
    }
    $item_name = Split-Path -Path $SourcePath -Leaf
    try {
        if ($Compress) {
            $archive_path = Join-Path -Path $backup_subdir -ChildPath "${item_name}_${timestamp}.zip"
            Compress-Archive -Path $SourcePath -DestinationPath $archive_path -Force
            return $archive_path
        } else {
            $backup_path = Join-Path -Path $backup_subdir -ChildPath $item_name
            Copy-Item -Path $SourcePath -Destination $backup_path -Recurse -Force
            return $backup_path
        }
    } catch {
        Write-Error "Error: Failed to create backup: $_"
        return $null
    }
}

function FindDuplicates {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,
        [ValidateSet("MD5", "SHA256")]
        [string]$HashMethod = "MD5",
        [ValidateSet("list", "grouped")]
        [string]$OutputFormat = "list",
        [int]$MinSize = 0
    )
    $validation_result = ValidateDirectory -Path $DirectoryPath
    if ($validation_result -ne 0) {
        return @()
    }
    $file_hashes = @{}
    $duplicates = @()
    $files = Get-ChildItem -Path $DirectoryPath -File -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        if ($MinSize -gt 0 -and $file.Length -lt $MinSize) {
            continue
        }
        try {
            $hash = ""
            if ($HashMethod -eq "SHA256") {
                $hash = GetFileSHA256 -FilePath $file.FullName
            } else {
                $hash = GetFileMD5 -FilePath $file.FullName
            }
            if (-not [string]::IsNullOrWhiteSpace($hash)) {
                if ($file_hashes.ContainsKey($hash)) {
                    if ($OutputFormat -eq "grouped") {
                        $duplicates += "$($file_hashes[$hash])|$($file.FullName)"
                    } else {
                        $duplicates += $file.FullName
                    }
                } else {
                    $file_hashes[$hash] = $file.FullName
                }
            }
        } catch {
            continue
        }
    }
    return $duplicates
}

function CheckFilePattern {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string]$Pattern,
        [bool]$CaseSensitive = $true
    )
    $file_name = Split-Path -Path $FilePath -Leaf
    if ($Pattern -eq "*") {
        return $true
    }
    if ($CaseSensitive) {
        return $file_name -clike $Pattern
    } else {
        return $file_name -like $Pattern
    }
}

function CheckFileSize {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [int]$MinSize = 0,
        [int]$MaxSize = 0
    )
    $validation_result = ValidateFile -Path $FilePath
    if ($validation_result -ne 0) {
        return $false
    }
    $file_size = GetFileSize -FilePath $FilePath
    if ($MinSize -gt 0 -and $file_size -lt $MinSize) {
        return $false
    }
    if ($MaxSize -gt 0 -and $file_size -gt $MaxSize) {
        return $false
    }
    return $true
}

function CheckFileAge {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [int]$MinAge = 0,
        [ValidateSet("seconds", "minutes", "hours", "days")]
        [string]$Unit = "days"
    )
    $validation_result = ValidateFile -Path $FilePath
    if ($validation_result -ne 0) {
        return $false
    }
    $file_age = GetFileAge -FilePath $FilePath -Unit $Unit
    if ($MinAge -gt 0 -and $file_age -lt $MinAge) {
        return $false
    }
    return $true
}

function GetFileExtension {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        Write-Error "Error: FilePath parameter is required"
        return ""
    }
    return [System.IO.Path]::GetExtension($FilePath).TrimStart('.')
}

function GetFileBasename {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        Write-Error "Error: FilePath parameter is required"
        return ""
    }
    return [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
}

function CompareFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$File1,
        [Parameter(Mandatory = $true)]
        [string]$File2,
        [ValidateSet("hash", "content", "size")]
        [string]$Method = "hash"
    )
    $validation1 = ValidateFile -Path $File1
    $validation2 = ValidateFile -Path $File2
    if ($validation1 -ne 0 -or $validation2 -ne 0) {
        return $false
    }
    switch ($Method) {
        "hash" {
            $hash1 = GetFileMD5 -FilePath $File1
            $hash2 = GetFileMD5 -FilePath $File2
            return $hash1 -eq $hash2
        }
        "content" {
            $content1 = Get-Content -Path $File1 -Raw
            $content2 = Get-Content -Path $File2 -Raw
            return $content1 -eq $content2
        }
        "size" {
            $size1 = GetFileSize -FilePath $File1
            $size2 = GetFileSize -FilePath $File2
            return $size1 -eq $size2
        }
    }
}

function FindFilesByExtension {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,
        [Parameter(Mandatory = $true)]
        [string]$Extension,
        [int]$MaxDepth = -1
    )
    $validation_result = ValidateDirectory -Path $DirectoryPath
    if ($validation_result -ne 0) {
        return @()
    }
    $extension = $Extension.TrimStart('.')
    try {
        if ($MaxDepth -gt 0) {
            return Get-ChildItem -Path $DirectoryPath -Filter "*.$extension" -File -Depth $MaxDepth -ErrorAction SilentlyContinue
        } else {
            return Get-ChildItem -Path $DirectoryPath -Filter "*.$extension" -File -Recurse -ErrorAction SilentlyContinue
        }
    } catch {
        return @()
    }
}

function FindEmpty {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,
        [ValidateSet("files", "dirs", "both")]
        [string]$Type = "both"
    )
    $validation_result = ValidateDirectory -Path $DirectoryPath
    if ($validation_result -ne 0) {
        return @()
    }
    $results = @()
    try {
        switch ($Type) {
            "files" {
                $results = Get-ChildItem -Path $DirectoryPath -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Length -eq 0 }
            }
            "dirs" {
                $results = Get-ChildItem -Path $DirectoryPath -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { (Get-ChildItem -Path $_.FullName -ErrorAction SilentlyContinue).Count -eq 0 }
            }
            "both" {
                $empty_files = Get-ChildItem -Path $DirectoryPath -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Length -eq 0 }
                $empty_dirs = Get-ChildItem -Path $DirectoryPath -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { (Get-ChildItem -Path $_.FullName -ErrorAction SilentlyContinue).Count -eq 0 }
                $results = $empty_files + $empty_dirs
            }
        }
    } catch {
        return @()
    }
    return $results
}

function GetDirectoryTree {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,
        [int]$MaxDepth = 3,
        [bool]$ShowHidden = $false
    )
    $validation_result = ValidateDirectory -Path $DirectoryPath
    if ($validation_result -ne 0) {
        return
    }
    try {
        if ($ShowHidden) {
            Get-ChildItem -Path $DirectoryPath -Recurse -Depth $MaxDepth -Force -ErrorAction SilentlyContinue | Sort-Object FullName
        } else {
            Get-ChildItem -Path $DirectoryPath -Recurse -Depth $MaxDepth -ErrorAction SilentlyContinue | Sort-Object FullName
        }
    } catch {
        Write-Error "Error: Failed to get directory tree"
    }
}

function CleanOldFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,
        [Parameter(Mandatory = $true)]
        [int]$MinAgeDays,
        [string]$Pattern = "*",
        [bool]$DryRun = $true
    )
    $validation_result = ValidateDirectory -Path $DirectoryPath
    if ($validation_result -ne 0) {
        return
    }
    $count = 0
    $files = Get-ChildItem -Path $DirectoryPath -File -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        if (CheckFileAge -FilePath $file.FullName -MinAge $MinAgeDays -Unit "days") {
            if (CheckFilePattern -FilePath $file.FullName -Pattern $Pattern) {
                if ($DryRun) {
                    Write-Host "Would delete: $($file.FullName)"
                } else {
                    try {
                        Remove-Item -Path $file.FullName -Force
                        Write-Host "Deleted: $($file.FullName)"
                    } catch {
                        Write-Error "Failed to delete: $($file.FullName)"
                    }
                }
                $count++
            }
        }
    }
    Write-Host "Total files processed: $count"
}

function FormatBytes {
    param(
        [Parameter(Mandatory = $true)]
        [long]$Bytes,
        [int]$Precision = 2
    )
    if ($Bytes -lt 1KB) {
        return "${Bytes}B"
    } elseif ($Bytes -lt 1MB) {
        $value = [math]::Round($Bytes / 1KB, $Precision)
        return "${value}KB"
    } elseif ($Bytes -lt 1GB) {
        $value = [math]::Round($Bytes / 1MB, $Precision)
        return "${value}MB"
    } else {
        $value = [math]::Round($Bytes / 1GB, $Precision)
        return "${value}GB"
    }
}

Export-ModuleMember -Function @(
    'ValidateDirectory',
    'ValidateFile',
    'GetDirectorySize',
    'CountFiles',
    'CountDirectories',
    'GetFileSize',
    'GetFileMD5',
    'GetFileSHA256',
    'GetFileAge',
    'GetTrashPath',
    'MoveToTrash',
    'CreateBackup',
    'FindDuplicates',
    'CheckFilePattern',
    'CheckFileSize',
    'CheckFileAge',
    'GetFileExtension',
    'GetFileBasename',
    'CompareFiles',
    'FindFilesByExtension',
    'FindEmpty',
    'GetDirectoryTree',
    'CleanOldFiles',
    'FormatBytes'
)
