# Import the Active Directory module (ensure RSAT tools are installed)
Import-Module ActiveDirectory

# Function to generate a random password meeting the AD policy
function Generate-Password {
    $length = 16
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+"
    $password = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count $length | ForEach-Object {[char]$_})
    $password += (Get-Random -InputObject "!@#$%^&*()-_=+" -Count 1) # Ensures at least one special character
    return $password
}

# Function to ensure unique UserPrincipalName
function Get-UniqueUPN {
    param (
        [string]$baseUPN,
        [string]$domain
    )
    
    $upn = $baseUPN + $domain
    $counter = 1
    
    while (Get-ADUser -Filter { UserPrincipalName -eq $upn }) {
        # Modify the base UPN with the counter before the domain part
        $upn = $baseUPN + $counter + $domain
        $counter++
    }
    
    return $upn
}

# Import users from the CSV file
$users = Import-Csv -Path "C:\Users\Administrator\Downloads\Users.csv"

# Loop through each user in the CSV and create a new AD user
foreach ($user in $users) {
    # Prepare the UserPrincipalName by combining the first 3 letters of GivenName and Surname
    $givenNamePart = if ($user.GivenName.Length -ge 3) { $user.GivenName.Substring(0, 3) } else { $user.GivenName }
    $surnamePart = if ($user.Surname.Length -ge 3) { $user.Surname.Substring(0, 3) } else { $user.Surname }
    
    # Handle Norwegian characters (Æ -> AE, Ø -> O, Å -> A)
    $baseUPN = ($givenNamePart + $surnamePart).Replace('Æ', 'AE').Replace('Ø', 'O').Replace('Å', 'A')
    $domain = "@stisor09.com"
    
    # Ensure the UPN is unique by passing only the baseUPN and the domain separately
    $userPrincipalName = Get-UniqueUPN -baseUPN $baseUPN -domain $domain

    # Generate a compliant password
    $password = Generate-Password
    
    # Create the new AD user
    New-ADUser `
        -GivenName $user.GivenName `
        -Surname $user.Surname `
        -Initials $user.Initials `
        -UserPrincipalName $userPrincipalName `
        -MobilePhone $user.MobilePhone `
        -Name ($user.GivenName + " " + $user.Surname) `
        -AccountPassword (ConvertTo-SecureString $password -AsPlainText -Force) `
        -Enabled $true `
        -PasswordNeverExpires $false `
        -ChangePasswordAtLogon $true

    # Ensure the user object is fully created before adding to groups
    $createdUser = Get-ADUser -Filter { UserPrincipalName -eq $userPrincipalName }

    if ($createdUser) {
        # Add user to groups if any are specified
        if ($user.MemberOf) {
            $groups = $user.MemberOf -split ';' # Assuming multiple groups are separated by semicolons
            foreach ($group in $groups) {
                # Trim any extra spaces around the group names
                $group = $group.Trim()

                # Check if the group exists in AD
                if (Get-ADGroup -Filter { Name -eq $group }) {
                    try {
                        Add-ADGroupMember -Identity $group -Members $createdUser
                        Write-Host "Added $userPrincipalName to group: $group"
                    } catch {
                        Write-Host "Error adding $userPrincipalName to group $group{}: $_"
                    }
                } else {
                    Write-Host "Group not found: $group for user $userPrincipalName"
                }
            }
        }
    } else {
        Write-Host "User $userPrincipalName could not be retrieved from AD."
    }
    
    # Output the username and password for logging purposes (you may want to store this securely)
    Write-Host "User created: $userPrincipalName, Password: $password"
}

Write-Host "Users imported successfully."
