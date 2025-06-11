
<#
.SYNOPSIS
Generates a report of Azure AD users with their password expiration status.

.DESCRIPTION
Connects to Microsoft Graph, fetches user data, and calculates password expiration based on a configurable validity period.
Filters available for licensed users, enabled accounts, password expiration, and recent changes.

.PARAMETER PwdNeverExpires
Filters users whose passwords are set to never expire.

.PARAMETER PwdExpired
Filters users with expired passwords.

.PARAMETER LicensedUserOnly
Filters users who are licensed.

.PARAMETER EnabledUsersOnly
Filters only enabled accounts.

.PARAMETER SoonToExpire
Shows users whose passwords are expiring in the next X days.

.PARAMETER RecentPwdChanges
Shows users who changed their password in the last X days.

.PARAMETER PwdValidityPeriod
Sets the password expiration policy in days (default: 180).

.PARAMETER OutputPath
Custom output file path for the report.

.EXAMPLE
.\password-expiry.ps1 -SoonToExpire 7 -LicensedUserOnly

.NOTES
Author: Chandra Sekhar Varma Sagiraju
#>

Param (
    [switch]$PwdNeverExpires, 
    [switch]$PwdExpired, 
    [switch]$LicensedUserOnly, 
    [int]$SoonToExpire, 
    [int]$RecentPwdChanges,
    [switch]$EnabledUsersOnly,
    [string]$OutputPath,
    [int]$PwdValidityPeriod = 180
)

try {
    Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All" | Out-Null
} catch {
    Write-Error "Unable to connect to Microsoft Graph. Ensure you have the correct permissions and are logged in."
    exit 1
}

if (-not $OutputPath) {
    $OutputPath = Join-Path -Path $PSScriptRoot -ChildPath "PasswordExpiryReport_$(Get-Date -Format yyyy-MM-dd).csv"
}

Write-Verbose "Fetching users from Microsoft Graph..."
$Users = Get-MgUser -All -Property DisplayName,UserPrincipalName,LastPasswordChangeDateTime,PasswordPolicies,AssignedLicenses,AccountEnabled | Select-Object `
    DisplayName,
    UserPrincipalName,
    @{Name="LastPasswordChangeDateTime"; Expression = { $_.LastPasswordChangeDateTime }},
    @{Name="PasswordNeverExpires"; Expression = { $_.PasswordPolicies -notlike "*None*" }},
    @{Name="LicenseStatus"; Expression = { if ($_.AssignedLicenses.Count -gt 0) { "Licensed" } else { "Unlicensed" } }},
    @{Name="AccountStatus"; Expression = { if ($_.AccountEnabled -eq $true) { "Enabled" } else { "Disabled" } }}

if (!$Users) {
    Write-Host "No users found in Azure AD."
    return
}

$Today = Get-Date
$Results = @()

foreach ($User in $Users) {
    $PwdLastChange = $User.LastPasswordChangeDateTime
    $PwdNeverExpire = $User.PasswordNeverExpires
    $DaysSinceChange = ($Today - $PwdLastChange).Days
    $DaysUntilExpiry = $PwdValidityPeriod - $DaysSinceChange

    # Apply filters
    if ($LicensedUserOnly -and $User.LicenseStatus -ne "Licensed") { continue }
    if ($EnabledUsersOnly -and $User.AccountStatus -ne "Enabled") { continue }
    if ($PwdNeverExpires -and $PwdNeverExpire) { continue }
    if ($PwdExpired -and $DaysUntilExpiry -gt 0) { continue }
    if ($SoonToExpire -and $DaysUntilExpiry -gt $SoonToExpire) { continue }
    if ($RecentPwdChanges -and $DaysSinceChange -gt $RecentPwdChanges) { continue }

    $Results += [PSCustomObject]@{
        DisplayName            = $User.DisplayName
        UserPrincipalName      = $User.UserPrincipalName
        PasswordLastSet        = $PwdLastChange
        DaysUntilExpiry        = $DaysUntilExpiry
        PasswordNeverExpires   = $PwdNeverExpire
        LicenseStatus          = $User.LicenseStatus
        AccountStatus          = $User.AccountStatus
    }
}

$Results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
Write-Host "`nReport saved to: $OutputPath"
