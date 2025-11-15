function ShowMenu {
  if (Test-Path "$SCRIPT_DIR/ascii.txt") {
    Write-Host ""
    Get-Content "$SCRIPT_DIR/ascii.txt" -Encoding UTF8
    Write-Host ""
  }
  Write-Host "INSTALL:"
  Write-Host "  1. Install PowerShell modules"
  Write-Host "  2. Install Scoop packages"
  Write-Host "  3. Install Node.js LTS version"
  Write-Host "  4. Install NPM packages"
  Write-Host "  5. Install VSCode extensions"
  Write-Host "  6. Install Skills"
  Write-Host "  7. Install all packages"
  Write-Host ""
  Write-Host "UNINSTALL:"
  Write-Host "  8. Uninstall PowerShell modules"
  Write-Host "  9. Uninstall Scoop packages"
  Write-Host " 10. Uninstall Node.js LTS version"
  Write-Host " 11. Uninstall NPM packages"
  Write-Host " 12. Uninstall VSCode extensions"
  Write-Host " 13. Uninstall Skills"
  Write-Host " 14. Uninstall all packages"
  Write-Host ""
  Write-Host "CONFIGURE:"
  Write-Host " 15. Configure PowerShell"
  Write-Host " 16. Configure Windows Terminal"
  Write-Host " 17. Configure Script"
  Write-Host " 18. Configure Python (pip)"
  Write-Host " 19. Configure Warp"
  Write-Host " 20. Configure Vim"
  Write-Host " 21. Configure Neovim"
  Write-Host " 22. Configure Git"
  Write-Host " 23. Configure Lazygit"
  Write-Host " 24. Configure Commitizen"
  Write-Host " 25. Configure VSCode"
  Write-Host " 26. Configure PHP"
  Write-Host " 27. Configure all applications"
  Write-Host ""
  Write-Host "REMOVE:"
  Write-Host " 28. Remove PowerShell configuration"
  Write-Host " 29. Remove Windows Terminal configuration"
  Write-Host " 30. Remove Script configuration"
  Write-Host " 31. Remove Python configuration"
  Write-Host " 32. Remove Warp configuration"
  Write-Host " 33. Remove Vim configuration"
  Write-Host " 34. Remove Neovim configuration"
  Write-Host " 35. Remove Git configuration"
  Write-Host " 36. Remove Lazygit configuration"
  Write-Host " 37. Remove Commitizen configuration"
  Write-Host " 38. Remove VSCode configuration"
  Write-Host " 39. Remove PHP configuration"
  Write-Host " 40. Remove all configurations"
  Write-Host ""
  Write-Host "  q. Quit"
  Write-Host ""
}

function InvokeMenuAction {
  param (
    [scriptblock]$Action
  )
  & $Action
}
