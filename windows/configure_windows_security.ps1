# PowerShell script to configure Windows security settings for POS System
# Run as Administrator

param(
    [switch]$AddFirewallRule,
    [switch]$AddDefenderExclusion,
    [switch]$ConfigureUAC,
    [string]$AppPath = "$env:ProgramFiles\Offline POS System"
)

Write-Host "Windows Security Configuration for POS System" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Add Windows Firewall Rule
if ($AddFirewallRule) {
    Write-Host "`nAdding Windows Firewall Rule..." -ForegroundColor Yellow
    try {
        $ruleName = "Offline POS System"
        $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        
        if ($existingRule) {
            Write-Host "Firewall rule already exists. Removing old rule..." -ForegroundColor Yellow
            Remove-NetFirewallRule -DisplayName $ruleName
        }
        
        New-NetFirewallRule -DisplayName $ruleName `
            -Direction Inbound `
            -Program "$AppPath\offline_pos_system.exe" `
            -Action Allow `
            -Profile Domain,Private,Public `
            -Description "Allow Offline POS System network communication"
        
        Write-Host "Firewall rule added successfully!" -ForegroundColor Green
    } catch {
        Write-Host "Error adding firewall rule: $_" -ForegroundColor Red
    }
}

# Add Windows Defender Exclusion
if ($AddDefenderExclusion) {
    Write-Host "`nAdding Windows Defender Exclusion..." -ForegroundColor Yellow
    try {
        $exclusionPath = $AppPath
        if (Test-Path $exclusionPath) {
            Add-MpPreference -ExclusionPath $exclusionPath
            Write-Host "Defender exclusion added for: $exclusionPath" -ForegroundColor Green
        } else {
            Write-Host "App path not found: $exclusionPath" -ForegroundColor Yellow
            Write-Host "Please update the path and run again." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error adding Defender exclusion: $_" -ForegroundColor Red
        Write-Host "Note: This requires Windows Defender to be active." -ForegroundColor Yellow
    }
}

# Configure UAC (User Account Control)
if ($ConfigureUAC) {
    Write-Host "`nUAC Configuration:" -ForegroundColor Yellow
    Write-Host "Current UAC Level:" -ForegroundColor Cyan
    $uacLevel = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin").ConsentPromptBehaviorAdmin
    
    switch ($uacLevel) {
        0 { Write-Host "  Never notify" -ForegroundColor Red }
        2 { Write-Host "  Notify only when apps try to make changes (default)" -ForegroundColor Green }
        5 { Write-Host "  Always notify" -ForegroundColor Yellow }
        default { Write-Host "  Level: $uacLevel" -ForegroundColor Yellow }
    }
    
    Write-Host "`nNote: UAC settings should be configured via Group Policy or manually." -ForegroundColor Yellow
    Write-Host "The app will request elevation when needed." -ForegroundColor Yellow
}

# Display summary
Write-Host "`n=============================================" -ForegroundColor Green
Write-Host "Configuration Summary:" -ForegroundColor Green
Write-Host "  Firewall Rule: $(if ($AddFirewallRule) { 'Added' } else { 'Skipped' })" -ForegroundColor Cyan
Write-Host "  Defender Exclusion: $(if ($AddDefenderExclusion) { 'Added' } else { 'Skipped' })" -ForegroundColor Cyan
Write-Host "  UAC Check: $(if ($ConfigureUAC) { 'Completed' } else { 'Skipped' })" -ForegroundColor Cyan
Write-Host "`nTo run all configurations:" -ForegroundColor Yellow
Write-Host "  .\configure_windows_security.ps1 -AddFirewallRule -AddDefenderExclusion -ConfigureUAC" -ForegroundColor White

