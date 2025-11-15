#!/usr/bin/env bash

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/utils/file.sh" 2>/dev/null || {
  echo "Error: Cannot load file.sh utility" >&2
  exit 1
}
source "$SCRIPT_DIR/utils/progress.sh" 2>/dev/null || {
  echo "Error: Cannot load progress.sh utility" >&2
  exit 1
}
source "$SCRIPT_DIR/utils/logger.sh" 2>/dev/null || {
  echo "Error: Cannot load logger.sh utility" >&2
  exit 1
}

declare program_list=()
declare registry_paths=()
declare total_programs=0
declare missing_programs=0
declare cleanup_temp_files=()

OnScriptInterrupt() {
    LogWarning "Script interrupted by user"
    if [[ ${#cleanup_temp_files[@]} -gt 0 ]]; then
        LogInfo "Cleaning up temporary files..."
        for temp_file in "${cleanup_temp_files[@]}"; do
            [[ -f "$temp_file" ]] && rm -f "$temp_file"
        done
    fi
    exit 130
}

ValidateSystemEnvironment() {
    local os_type="$(uname -s)"
    case "${os_type}" in
        "MINGW"*|"MSYS"*|"CYGWIN"*)
            LogInfo "Windows system detected (${os_type})"
            ;;
        *)
            LogError "This script only supports Windows (detected: ${os_type})"
            return 1
            ;;
    esac
    return 0
}

CheckAdminPrivileges() {
    if command -v net >/dev/null 2>&1; then
        if net session >/dev/null 2>&1; then
            LogInfo "Running as Administrator - Registry modification allowed"
        else
            LogWarning "Not running as Administrator - Registry modification not allowed"
            return 1
        fi
    else
        LogWarning "net.exe not found - Cannot check user privileges"
        return 1
    fi
    return 0
}

FindProgramPath() {
    local program_name="$1"
    local program_path=""
    if [[ -z "${program_name}" ]]; then
        LogError "Program name not specified"
        return 1
    fi
    program_path="$(command -v "${program_name}" 2>/dev/null)"
    if [[ -n "${program_path}" ]]; then
        if _ValidateFile "${program_path}" >/dev/null 2>&1; then
            local file_size=$(GetFileSize "${program_path}" "true")
            LogDebug "Found: ${program_name} (${file_size})"
            echo "${program_path}"
            return 0
        fi
    fi
    local search_directories=(
        "/c/Program Files"
        "/c/Program Files (x86)"
        "${HOME}/AppData/Local/Programs"
    )
    for search_dir in "${search_directories[@]}"; do
        if _ValidateDirectory "${search_dir}" >/dev/null 2>&1; then
            program_path="$(find "${search_dir}" -name "${program_name}" -type f 2>/dev/null | head -1)"
            if [[ -n "${program_path}" ]] && _ValidateFile "${program_path}" >/dev/null 2>&1; then
                local file_size=$(GetFileSize "${program_path}" "true")
                LogDebug "Found: ${program_name} at ${search_dir} (${file_size})"
                echo "${program_path}"
                return 0
            fi
        fi
    done
    return 0
}

EnumerateRegistryKeys() {
    local registry_path="$1"
    local key_list=()
    if [[ -z "${registry_path}" ]]; then
        LogError "Registry path not specified"
        return 1
    fi
    if command -v reg.exe >/dev/null 2>&1; then
        while IFS= read -r registry_key; do
            if [[ -n "${registry_key}" ]]; then
                key_list+=("${registry_key}")
            fi
        done < <(reg.exe query "${registry_path}" 2>/dev/null | grep -E "^\s*HKEY" | awk -F'\\' '{print $NF}')
        printf '%s\n' "${key_list[@]}"
    else
        LogError "reg.exe not found - Cannot read Registry"
        return 1
    fi
    return 0
}

GetOpenWithPrograms() {
    local file_extension="${1:-*}"
    local registry_locations=()
    program_list=()
    registry_paths=()
    total_programs=0
    missing_programs=0
    LogInfo "Searching for programs in Open With List for ${file_extension}"
    if [[ "${file_extension}" == "*" ]]; then
        registry_locations=(
            "HKEY_CLASSES_ROOT\\*\\OpenWithList"
            "HKEY_CURRENT_USER\\SOFTWARE\\Classes\\*\\OpenWithList"
            "HKEY_CLASSES_ROOT\\Applications"
        )
    else
        registry_locations=(
            "HKEY_CLASSES_ROOT\\*\\OpenWithList"
            "HKEY_CLASSES_ROOT\\.${file_extension}\\OpenWithList"
            "HKEY_CLASSES_ROOT\\SystemFileAssociations\\.${file_extension}\\OpenWithList"
            "HKEY_CURRENT_USER\\SOFTWARE\\Classes\\*\\OpenWithList"
            "HKEY_CURRENT_USER\\SOFTWARE\\Classes\\.${file_extension}\\OpenWithList"
            "HKEY_CLASSES_ROOT\\Applications"
        )
    fi
    local location_count=0
    for registry_location in "${registry_locations[@]}"; do
        ((location_count++))
        ShowProgress "$location_count" "${#registry_locations[@]}" "Scanning registry" "true" 50 "detailed"
        LogDebug "Checking: ${registry_location}"
        local found_programs=()
        readarray -t found_programs < <(EnumerateRegistryKeys "${registry_location}")
        for program_name in "${found_programs[@]}"; do
            if [[ -n "${program_name}" ]]; then
                local program_path=""
                local status_message="Found"
                program_path="$(FindProgramPath "${program_name}")"
                if [[ -z "${program_path}" ]]; then
                    status_message="Missing"
                    ((missing_programs++))
                fi
                program_list+=("${program_name}")
                registry_paths+=("${registry_location}\\${program_name}")
                ((total_programs++))
                LogDebug "Found program: ${program_name} (${status_message})"
            fi
        done
    done
    ClearProgress "true" "true"
    LogInfo "Found ${total_programs} total programs (missing: ${missing_programs})"
    return 0
}

DisplayPrograms() {
    if [[ "${total_programs}" -eq 0 ]]; then
        LogWarning "No programs found in Open With List"
        return 1
    fi
    LogInfo "Programs in Open With List:"
    for ((i=0; i<total_programs; i++)); do
        local program_name="${program_list[i]}"
        local program_path=""
        local status_text="Found"
        program_path="$(FindProgramPath "${program_name}")"
        if [[ -z "${program_path}" ]]; then
            status_text="Missing"
        fi
        printf "%2d. %s (%s)\n" "$((i+1))" "${program_name}" "${status_text}"
    done
    LogInfo "Total: ${total_programs} | Missing: ${missing_programs}"
    return 0
}

ValidateRegistryPath() {
    local registry_key="$1"
    if [[ -z "${registry_key}" ]]; then
        LogError "Registry key not specified"
        return 1
    fi
    if ! [[ "${registry_key}" =~ ^HKEY ]]; then
        LogError "Invalid registry path format: ${registry_key}"
        return 1
    fi
    if command -v reg.exe >/dev/null 2>&1; then
        if reg.exe query "${registry_key}" >/dev/null 2>&1; then
            return 0
        else
            LogWarning "Registry key does not exist: ${registry_key}"
            return 1
        fi
    fi
    return 0
}

RemoveRegistryKey() {
    local registry_key="$1"
    if [[ -z "${registry_key}" ]]; then
        LogError "Registry key not specified"
        return 1
    fi
    if ! ValidateRegistryPath "${registry_key}"; then
        return 1
    fi
    if command -v powershell.exe >/dev/null 2>&1; then
        if powershell.exe -Command "remove-item -path 'registry::${registry_key}' -recurse -force -erroraction silentlycontinue" 2>/dev/null; then
            LogInfo "Successfully deleted Registry key: ${registry_key}"
            return 0
        else
            LogError "Failed to delete Registry key: ${registry_key}"
            return 1
        fi
    else
        LogError "powershell.exe not found"
        return 1
    fi
    return 0
}

RemoveBatchPrograms() {
    local program_indices=("$@")
    if [[ ${#program_indices[@]} -eq 0 ]]; then
        LogError "No programs specified for batch removal"
        return 1
    fi
    if ! CheckAdminPrivileges; then
        LogError "Administrator privileges required to remove entries"
        return 1
    fi
    local success_count=0
    local failed_count=0
    LogInfo "Removing ${#program_indices[@]} programs..."
    for ((idx=0; idx<${#program_indices[@]}; idx++)); do
        local i=${program_indices[idx]}
        if [[ $i -ge 0 && $i -lt $total_programs ]]; then
            local program_name="${program_list[i]}"
            local registry_path="${registry_paths[i]}"
            if RemoveRegistryKey "${registry_path}"; then
                LogInfo "Removed ${program_name}"
                ((success_count++))
            else
                LogInfo "Failed to remove ${program_name}"
                ((failed_count++))
            fi
        fi
        ShowProgress "$((idx + 1))" "${#program_indices[@]}" "Removing" "true" 50 "detailed"
    done
    ClearProgress "true" "true"
    LogInfo "Batch removal summary: Success=${success_count}, Failed=${failed_count}"
    return 0
}

CleanMissingPrograms() {
    if [[ "${missing_programs}" -eq 0 ]]; then
        LogInfo "No missing programs found"
        return 1
    fi
    LogInfo "Missing programs:"
    local missing_indices=()
    local missing_count=0
    for ((i=0; i<total_programs; i++)); do
        local program_name="${program_list[i]}"
        local program_path=""
        program_path="$(FindProgramPath "${program_name}")"
        if [[ -z "${program_path}" ]]; then
            ((missing_count++))
            missing_indices+=("$i")
            printf "%2d. %s (Missing)\n" "${missing_count}" "${program_name}"
        fi
    done
    read -p "Do you want to remove all ${missing_programs} missing programs? (Y/N): " -r confirm_removal
    if [[ "${confirm_removal^^}" != "Y" ]]; then
        LogInfo "Operation cancelled"
        return 1
    fi
    if ! CheckAdminPrivileges; then
        LogError "Administrator privileges required to remove entries"
        read -p "Restart with Administrator privileges? (Y/N): " -r restart_admin
        if [[ "${restart_admin^^}" == "Y" ]]; then
            LogInfo "Please restart the script with Administrator privileges"
            return 1
        fi
    fi
    RemoveBatchPrograms "${missing_indices[@]}"
    return 0
}

InteractiveMenu() {
    while true; do
        LogInfo "Options"
        LogInfo "[D] Delete selected entry"
        LogInfo "[B] Batch delete (comma-separated numbers)"
        LogInfo "[M] Remove all missing programs"
        LogInfo "[R] Refresh list"
        LogInfo "[V] Validate all entries"
        LogInfo "[Q] Quit program"
        read -p "Choose option (D/B/M/R/V/Q): " -r menu_choice
        menu_choice="${menu_choice^^}"
        case "${menu_choice}" in
            "D")
                if [[ "${total_programs}" -eq 0 ]]; then
                    LogWarning "No entries to delete"
                    continue
                fi
                read -p "Enter entry number to delete (1-${total_programs}): " -r entry_index
                if [[ "${entry_index}" =~ ^[0-9]+$ ]] && [[ "${entry_index}" -ge 1 ]] && [[ "${entry_index}" -le "${total_programs}" ]]; then
                    local selected_index=$((entry_index - 1))
                    local selected_program="${program_list[selected_index]}"
                    local selected_registry="${registry_paths[selected_index]}"
                    LogInfo "Selected entry:"
                    LogInfo "Program: ${selected_program}"
                    LogInfo "Registry Path: ${selected_registry}"
                    read -p "Are you sure you want to delete this entry? (Y/N): " -r confirm_delete
                    if [[ "${confirm_delete^^}" == "Y" ]]; then
                        if RemoveRegistryKey "${selected_registry}"; then
                            LogInfo "Entry deleted successfully!"
                            unset program_list[selected_index]
                            unset registry_paths[selected_index]
                            program_list=("${program_list[@]}")
                            registry_paths=("${registry_paths[@]}")
                            ((total_programs--))
                        else
                            LogError "Failed to delete entry"
                            LogInfo "You can manually delete it in Registry Editor at:"
                            LogInfo "${selected_registry}"
                        fi
                    else
                        LogInfo "Operation cancelled"
                    fi
                else
                    LogError "Invalid number"
                fi
                ;;
            "B")
                if [[ "${total_programs}" -eq 0 ]]; then
                    LogWarning "No entries to delete"
                    continue
                fi
                read -p "Enter entry numbers to delete (comma-separated, e.g. 1,3,5): " -r batch_input
                local batch_indices=()
                IFS=',' read -ra batch_indices <<< "$batch_input"
                local valid_indices=()
                for idx in "${batch_indices[@]}"; do
                    idx=$(echo "$idx" | xargs)
                    if [[ "${idx}" =~ ^[0-9]+$ ]] && [[ "${idx}" -ge 1 ]] && [[ "${idx}" -le "${total_programs}" ]]; then
                        valid_indices+=($((idx - 1)))
                    else
                        LogWarning "Skipping invalid index: ${idx}"
                    fi
                done
                if [[ ${#valid_indices[@]} -gt 0 ]]; then
                    LogInfo "Will delete ${#valid_indices[@]} entries"
                    read -p "Confirm batch deletion? (Y/N): " -r confirm_batch
                    if [[ "${confirm_batch^^}" == "Y" ]]; then
                        RemoveBatchPrograms "${valid_indices[@]}"
                    fi
                else
                    LogError "No valid indices provided"
                fi
                ;;
            "M")
                CleanMissingPrograms
                ;;
            "R")
                LogInfo "Refreshing list..."
                read -p "Enter file extension to check (leave blank for all types): " -r file_extension
                if [[ -z "${file_extension}" ]]; then
                    file_extension="*"
                fi
                GetOpenWithPrograms "${file_extension}"
                DisplayPrograms
                ;;
            "V")
                LogInfo "Validating all registry entries..."
                local valid_count=0
                local invalid_count=0
                for ((i=0; i<total_programs; i++)); do
                    if ValidateRegistryPath "${registry_paths[i]}"; then
                        ((valid_count++))
                    else
                        ((invalid_count++))
                        LogWarning "Invalid: ${program_list[i]}"
                    fi
                done
                LogInfo "Validation complete: Valid=${valid_count}, Invalid=${invalid_count}"
                ;;
            "Q")
                LogInfo "Exiting program"
                break
                ;;
            *)
                LogError "Please choose D, B, M, R, V, or Q"
                ;;
        esac
    done
    return 0
}

Main() {
    LogInfo "Open With List Manager"
    ValidateSystemEnvironment
    if CheckAdminPrivileges; then
        LogInfo "Running as Administrator - Can modify entries"
    else
        LogInfo "Not running as Administrator - Cannot modify entries"
        LogInfo "(You can view and open Registry Editor to manually edit)"
    fi
    LogInfo "Retrieving data from Registry..."
    read -p $'Enter file extension to check (leave blank for all types): ' -r file_extension
    if [[ -z "${file_extension}" ]]; then
        file_extension="*"
    fi
    GetOpenWithPrograms "${file_extension}"
    DisplayPrograms
    if [[ "${total_programs}" -gt 0 ]]; then
        InteractiveMenu
    else
        LogWarning "No entries found"
    fi
    return 0
}

Main