<#
.SYNOPSIS
    Audits generic directory account data for missing, malformed, and
    inconsistent attributes.

.DESCRIPTION
    Directory Account Auditor is a platform-independent PowerShell auditing
    tool designed to evaluate normalized directory account objects.

    The validation engine is intentionally separated from the mechanism used
    to retrieve directory information. This allows the same business logic
    to operate against CSV files, synthetic test objects, LDAP adapters, or
    other directory sources.

    This public implementation uses only synthetic examples and contains no
    organization-specific directory configuration.

.NOTES
    Project: Directory Account Auditor
    Platform: PowerShell 7+
#>

Set-StrictMode -Version Latest

#region Validation Helpers

function Test-RequiredAttribute {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter()]
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $false
    }

    if ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    return $true
}

function Test-MobileNumber {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Mobile
    )

    if ([string]::IsNullOrWhiteSpace($Mobile)) {
        return $false
    }

    $InvalidValues = @(
        'N/A'
        'NA'
        'NONE'
        'UNKNOWN'
        'NULL'
        '0'
    )

    $NormalizedValue = $Mobile.Trim().ToUpperInvariant()

    if ($NormalizedValue -in $InvalidValues) {
        return $false
    }

    # Accept common human-readable phone formats while requiring
    # at least ten numeric digits.
    $DigitsOnly = $Mobile -replace '\D', ''

    if ($DigitsOnly.Length -lt 10) {
        return $false
    }

    return $true
}

function Get-AccountClassification {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$DisplayName,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Description,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$AccountType
    )

    if (-not [string]::IsNullOrWhiteSpace($AccountType)) {
        switch ($AccountType.Trim().ToUpperInvariant()) {
            'EMPLOYEE'   { return 'Employee' }
            'CONTRACTOR' { return 'Contractor' }
            'VENDOR'     { return 'Vendor' }
        }
    }

    $CombinedText = "$DisplayName $Description"

    if ($CombinedText -match '(?i)\(C\)') {
        return 'Contractor'
    }

    if ($CombinedText -match '(?i)\(V\)') {
        return 'Vendor'
    }

    return 'Employee'
}

#endregion

#region Finding Creation

function New-AuditFinding {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$DisplayName,

        [Parameter(Mandatory)]
        [ValidateSet('MissingAttribute', 'MalformedValue', 'Inconsistency')]
        [string]$FindingType,

        [Parameter(Mandatory)]
        [string]$Attribute,

        [Parameter(Mandatory)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Severity,

        [Parameter(Mandatory)]
        [string]$Message
    )

    [PSCustomObject]@{
        DisplayName = $DisplayName
        FindingType = $FindingType
        Attribute   = $Attribute
        Severity    = $Severity
        Message     = $Message
    }
}

#endregion

#region Account Auditing

function Test-DirectoryAccount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSObject]$Account
    )

    process {
        $Findings = [System.Collections.Generic.List[object]]::new()

        $DisplayName = if (
            $Account.PSObject.Properties.Name -contains 'DisplayName' -and
            (Test-RequiredAttribute $Account.DisplayName)
        ) {
            [string]$Account.DisplayName
        }
        else {
            '<Unknown Account>'
        }

        $Description = if ($Account.PSObject.Properties.Name -contains 'Description') {
            [string]$Account.Description
        }
        else {
            ''
        }

        $AccountType = if ($Account.PSObject.Properties.Name -contains 'AccountType') {
            [string]$Account.AccountType
        }
        else {
            ''
        }

        $Classification = Get-AccountClassification `
            -DisplayName $DisplayName `
            -Description $Description `
            -AccountType $AccountType

        # Required DisplayName
        if (
            -not ($Account.PSObject.Properties.Name -contains 'DisplayName') -or
            -not (Test-RequiredAttribute $Account.DisplayName)
        ) {
            $Findings.Add(
                (New-AuditFinding `
                    -DisplayName $DisplayName `
                    -FindingType 'MissingAttribute' `
                    -Attribute 'DisplayName' `
                    -Severity 'Error' `
                    -Message 'DisplayName is missing.')
            )
        }

        # Required EmployeeID
        if (
            -not ($Account.PSObject.Properties.Name -contains 'EmployeeID') -or
            -not (Test-RequiredAttribute $Account.EmployeeID)
        ) {
            $Findings.Add(
                (New-AuditFinding `
                    -DisplayName $DisplayName `
                    -FindingType 'MissingAttribute' `
                    -Attribute 'EmployeeID' `
                    -Severity 'Error' `
                    -Message 'EmployeeID is missing.')
            )
        }

        # Required Company
        if (
            -not ($Account.PSObject.Properties.Name -contains 'Company') -or
            -not (Test-RequiredAttribute $Account.Company)
        ) {
            $Findings.Add(
                (New-AuditFinding `
                    -DisplayName $DisplayName `
                    -FindingType 'MissingAttribute' `
                    -Attribute 'Company' `
                    -Severity 'Warning' `
                    -Message 'Company is missing.')
            )
        }

        # Required Office
        if (
            -not ($Account.PSObject.Properties.Name -contains 'Office') -or
            -not (Test-RequiredAttribute $Account.Office)
        ) {
            $Findings.Add(
                (New-AuditFinding `
                    -DisplayName $DisplayName `
                    -FindingType 'MissingAttribute' `
                    -Attribute 'Office' `
                    -Severity 'Warning' `
                    -Message 'Office is missing.')
            )
        }

        # Mobile validation
        $Mobile = if ($Account.PSObject.Properties.Name -contains 'Mobile') {
            [string]$Account.Mobile
        }
        else {
            ''
        }

        if ([string]::IsNullOrWhiteSpace($Mobile)) {
            $Findings.Add(
                (New-AuditFinding `
                    -DisplayName $DisplayName `
                    -FindingType 'MissingAttribute' `
                    -Attribute 'Mobile' `
                    -Severity 'Warning' `
                    -Message 'Mobile number is missing.')
            )
        }
        elseif (-not (Test-MobileNumber -Mobile $Mobile)) {
            $Findings.Add(
                (New-AuditFinding `
                    -DisplayName $DisplayName `
                    -FindingType 'MalformedValue' `
                    -Attribute 'Mobile' `
                    -Severity 'Warning' `
                    -Message "Mobile number '$Mobile' is not considered valid.")
            )
        }

        # Classification consistency checks.
        if ($Classification -eq 'Contractor') {
            if (
                $DisplayName -notmatch '(?i)\(C\)' -and
                $Description -notmatch '(?i)\(C\)'
            ) {
                $Findings.Add(
                    (New-AuditFinding `
                        -DisplayName $DisplayName `
                        -FindingType 'Inconsistency' `
                        -Attribute 'AccountType' `
                        -Severity 'Warning' `
                        -Message 'Account is classified as Contractor but no contractor designation was found in DisplayName or Description.')
                )
            }
        }

        if ($Classification -eq 'Vendor') {
            if (
                $DisplayName -notmatch '(?i)\(V\)' -and
                $Description -notmatch '(?i)\(V\)'
            ) {
                $Findings.Add(
                    (New-AuditFinding `
                        -DisplayName $DisplayName `
                        -FindingType 'Inconsistency' `
                        -Attribute 'AccountType' `
                        -Severity 'Warning' `
                        -Message 'Account is classified as Vendor but no vendor designation was found in DisplayName or Description.')
                )
            }
        }

        foreach ($Finding in $Findings) {
            $Finding
        }
    }
}

#endregion

#region Batch Auditing

function Invoke-DirectoryAccountAudit {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSObject[]]$Account
    )

    begin {
        $Accounts = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($Item in $Account) {
            $Accounts.Add($Item)
        }
    }

    end {
        foreach ($Item in $Accounts) {
            Test-DirectoryAccount -Account $Item
        }
    }
}

#endregion

#region CSV Interface

function Import-DirectoryAccountCsv {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )

    Import-Csv -Path $Path
}

function Export-AuditReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSObject[]]$Finding,

        [Parameter(Mandatory)]
        [string]$Path
    )

    begin {
        $Findings = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($Item in $Finding) {
            $Findings.Add($Item)
        }
    }

    end {
        $ParentDirectory = Split-Path -Path $Path -Parent

        if (
            -not [string]::IsNullOrWhiteSpace($ParentDirectory) -and
            -not (Test-Path $ParentDirectory)
        ) {
            New-Item -ItemType Directory -Path $ParentDirectory -Force |
                Out-Null
        }

        $Findings |
            Sort-Object DisplayName, Severity, FindingType, Attribute |
            Export-Csv -Path $Path -NoTypeInformation
    }
}

#endregion

#region Summary

function Get-AuditSummary {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSObject[]]$Finding
    )

    begin {
        $Findings = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($Item in $Finding) {
            $Findings.Add($Item)
        }
    }

    end {
        [PSCustomObject]@{
            TotalFindings        = $Findings.Count
            AccountsWithFindings = @(
                $Findings.DisplayName |
                    Sort-Object -Unique
            ).Count
            Errors               = @(
                $Findings |
                    Where-Object Severity -eq 'Error'
            ).Count
            Warnings             = @(
                $Findings |
                    Where-Object Severity -eq 'Warning'
            ).Count
            MissingAttributes    = @(
                $Findings |
                    Where-Object FindingType -eq 'MissingAttribute'
            ).Count
            MalformedValues      = @(
                $Findings |
                    Where-Object FindingType -eq 'MalformedValue'
            ).Count
            Inconsistencies      = @(
                $Findings |
                    Where-Object FindingType -eq 'Inconsistency'
            ).Count
        }
    }
}

#endregion
POWERSHELL