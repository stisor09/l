

# PowerShell script for remote maintenance tasks on Windows servers

# Function to check service status and perform maintenance
function Perform-RemoteMaintenance {
    param (
        [string]$ServerName
    )

    # Check if W32Time service is running
    $w32TimeStatus = Get-Service -ComputerName $ServerName -Name "W32Time" -ErrorAction SilentlyContinue

    if ($w32TimeStatus.Status -eq "Running") {
        Write-Host "W32Time service is running on $ServerName. Proceeding with maintenance."

        # Check for and install updates
        $session = New-PSSession -ComputerName $ServerName
        Invoke-Command -Session $session -ScriptBlock {
            $updates = Start-WUScan -SearchCriteria "IsInstalled=0 and Type='Software'" -ScanType 1
            if ($updates.Updates.Count -gt 0) {
                Write-Host "Installing updates on $using:ServerName"
                Install-WUUpdates -Updates $updates.Updates
                
                # Check if reboot is required
                if (Get-WUIsPendingReboot) {
                    Write-Host "Reboot required for $using:ServerName"
                    # Schedule reboot for next maintenance window (e.g., Sunday at 2 AM)
                    $nextSunday = (Get-Date).AddDays(7 - (Get-Date).DayOfWeek.value__) 
                    $rebootTime = $nextSunday.Date.AddHours(2)
                    Schedule-RebootTask -ComputerName $using:ServerName -RebootTime $rebootTime
                }
            } else {
                Write-Host "No updates available for $using:ServerName"
            }
        }
        Remove-PSSession $session
    } else {
        Write-Host "W32Time service is not running on $ServerName. Skipping maintenance."
    }
}

# Function to schedule a reboot task
function Schedule-RebootTask {
    param (
        [string]$ComputerName,
        [datetime]$RebootTime
    )

    $action = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "/r /f /t 0"
    $trigger = New-ScheduledTaskTrigger -Once -At $RebootTime
    $settings = New-ScheduledTaskSettingsSet -WakeToRun

    Register-ScheduledTask -ComputerName $ComputerName -TaskName "MaintenanceReboot" -Action $action -Trigger $trigger -Settings $settings -User "SYSTEM" -Force
}

# List of servers to maintain
$servers = @("STI-SVR-NOGUI01")  # Replace with your server names

# Perform maintenance on each server
foreach ($server in $servers) {
    Perform-RemoteMaintenance -ServerName $server
}

# Create a scheduled task to run this script weekly
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"$PSCommandPath`""
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 1AM
$settings = New-ScheduledTaskSettingsSet -WakeToRun -RunOnlyIfNetworkAvailable

Register-ScheduledTask -TaskName "WeeklyServerMaintenance" -Action $action -Trigger $trigger -Settings $settings -User "SYSTEM" -Force
