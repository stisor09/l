# Import the Active Directory module
Import-Module ActiveDirectory

# Get the current date for the filename
$date = Get-Date -Format "yyyyMMdd"
$csvPath = "C:\Users\Administrator\Downloads\UserReports$date.csv"

# Get all AD users
$users = Get-ADUser -Filter * -Properties SamAccountName, MemberOf, MobilePhone, mail, LastLogonDate

# Create an array to store user information
$userInfo = @()

foreach ($user in $users) {
    # Get the user's group memberships
    $groups = ($user.MemberOf | ForEach-Object { (Get-ADGroup $_).Name }) -join '; '
    
    # Create a custom object for each user
    $userObject = [PSCustomObject]@{
        Username     = $user.SamAccountName
        Group        = $groups
        MobileNumber = $user.MobilePhone
        EmailAddress = $user.mail
        LastLoginTime = $user.LastLogonDate
    }
    
    # Add the user object to the array
    $userInfo += $userObject
}

# Export the user information to CSV
$userInfo | Export-Csv -Path $csvPath -NoTypeInformation

Write-Host "Active Directory User Report has been exported to $csvPath"
