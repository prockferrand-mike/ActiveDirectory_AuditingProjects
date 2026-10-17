 {
    . "$PSScriptRoot/../src/DirectoryAccountAuditor.ps1"

    $ExampleCsv = "$PSScriptRoot/../examples/ExampleUsers.csv"
}

Describe 'Test-RequiredAttribute' {

    It 'returns false for null' {
        Test-RequiredAttribute -Value $null |
            Should -BeFalse
    }

    It 'returns false for an empty string' {
        Test-RequiredAttribute -Value '' |
            Should -BeFalse
    }

    It 'returns false for whitespace' {
        Test-RequiredAttribute -Value '   ' |
            Should -BeFalse
    }

    It 'returns true for a populated value' {
        Test-RequiredAttribute -Value 'Example Value' |
            Should -BeTrue
    }

    It 'returns true for numeric zero because the value exists' {
        Test-RequiredAttribute -Value 0 |
            Should -BeTrue
    }
}

Describe 'Test-MobileNumber' {

    It 'returns false for null' {
        Test-MobileNumber -Mobile $null |
            Should -BeFalse
    }

    It 'returns false for an empty value' {
        Test-MobileNumber -Mobile '' |
            Should -BeFalse
    }

    It 'returns false for whitespace' {
        Test-MobileNumber -Mobile '   ' |
            Should -BeFalse
    }

    It 'returns false for N/A' {
        Test-MobileNumber -Mobile 'N/A' |
            Should -BeFalse
    }

    It 'returns false for zero' {
        Test-MobileNumber -Mobile '0' |
            Should -BeFalse
    }

    It 'returns false for a number containing fewer than ten digits' {
        Test-MobileNumber -Mobile '555-1234' |
            Should -BeFalse
    }

    It 'accepts a dashed ten-digit synthetic number' {
        Test-MobileNumber -Mobile '555-010-1001' |
            Should -BeTrue
    }

    It 'accepts a number containing parentheses' {
        Test-MobileNumber -Mobile '(555) 010-1001' |
            Should -BeTrue
    }

    It 'accepts an international-style prefix' {
        Test-MobileNumber -Mobile '+1 (555) 010-1001' |
            Should -BeTrue
    }
}

Describe 'Get-AccountClassification' {

    It 'uses an explicit Employee AccountType' {
        Get-AccountClassification `
            -DisplayName 'Alice Example' `
            -Description '' `
            -AccountType 'Employee' |
            Should -Be 'Employee'
    }

    It 'uses an explicit Contractor AccountType' {
        Get-AccountClassification `
            -DisplayName 'Example User' `
            -Description '' `
            -AccountType 'Contractor' |
            Should -Be 'Contractor'
    }

    It 'uses an explicit Vendor AccountType' {
        Get-AccountClassification `
            -DisplayName 'Example User' `
            -Description '' `
            -AccountType 'Vendor' |
            Should -Be 'Vendor'
    }

    It 'detects contractor designation in DisplayName' {
        Get-AccountClassification `
            -DisplayName 'Charlie Example (C)' `
            -Description '' `
            -AccountType '' |
            Should -Be 'Contractor'
    }

    It 'detects contractor designation in Description' {
        Get-AccountClassification `
            -DisplayName 'Charlie Example' `
            -Description 'External worker (C)' `
            -AccountType '' |
            Should -Be 'Contractor'
    }

    It 'detects vendor designation in DisplayName' {
        Get-AccountClassification `
            -DisplayName 'Dana Example (V)' `
            -Description '' `
            -AccountType '' |
            Should -Be 'Vendor'
    }

    It 'defaults to Employee when no external designation exists' {
        Get-AccountClassification `
            -DisplayName 'Alice Example' `
            -Description 'Standard account' `
            -AccountType '' |
            Should -Be 'Employee'
    }
}

Describe 'New-AuditFinding' {

    It 'creates a structured finding' {

        $Finding = New-AuditFinding `
            -DisplayName 'Alice Example' `
            -FindingType 'MissingAttribute' `
            -Attribute 'Mobile' `
            -Severity 'Warning' `
            -Message 'Mobile number is missing.'

        $Finding.DisplayName |
            Should -Be 'Alice Example'

        $Finding.FindingType |
            Should -Be 'MissingAttribute'

        $Finding.Attribute |
            Should -Be 'Mobile'

        $Finding.Severity |
            Should -Be 'Warning'
    }
}

Describe 'Test-DirectoryAccount' {

    It 'returns no findings for a valid employee' {

        $Account = [PSCustomObject]@{
            DisplayName = 'Alice Example'
            Description = 'Standard employee account'
            EmployeeID  = '100001'
            Company     = 'Example Corp'
            Office      = 'Site-A'
            Mobile      = '555-010-1001'
            AccountType = 'Employee'
        }

        $Findings = @(
            Test-DirectoryAccount -Account $Account
        )

        $Findings.Count |
            Should -Be 0
    }

    It 'detects a missing EmployeeID' {

        $Account = [PSCustomObject]@{
            DisplayName = 'Frank Example'
            Description = 'Standard employee account'
            EmployeeID  = ''
            Company     = 'Example Corp'
            Office      = 'Site-A'
            Mobile      = '555-010-1006'
            AccountType = 'Employee'
        }

        $Findings = @(
            Test-DirectoryAccount -Account $Account
        )

        $Findings.Attribute |
            Should -Contain 'EmployeeID'
    }

    It 'detects a missing mobile number' {

        $Account = [PSCustomObject]@{
            DisplayName = 'Bob Example'
            Description = 'Standard employee account'
            EmployeeID  = '100002'
            Company     = 'Example Corp'
            Office      = 'Site-B'
            Mobile      = ''
            AccountType = 'Employee'
        }

        $Findings = @(
            Test-DirectoryAccount -Account $Account
        )

        $MobileFinding = $Findings |
            Where-Object Attribute -eq 'Mobile'

        $MobileFinding.FindingType |
            Should -Be 'MissingAttribute'
    }

    It 'detects a malformed mobile value' {

        $Account = [PSCustomObject]@{
            DisplayName = 'Erin Example'
            Description = 'Standard employee account'
            EmployeeID  = '100005'
            Company     = 'Example Corp'
            Office      = 'Site-C'
            Mobile      = 'N/A'
            AccountType = 'Employee'
        }

        $Findings = @(
            Test-DirectoryAccount -Account $Account
        )

        $MobileFinding = $Findings |
            Where-Object Attribute -eq 'Mobile'

        $MobileFinding.FindingType |
            Should -Be 'MalformedValue'
    }

    It 'detects an explicit Contractor without designation' {

        $Account = [PSCustomObject]@{
            DisplayName = 'Morgan Example'
            Description = 'Temporary external worker'
            EmployeeID  = 'C100012'
            Company     = 'Example Consulting'
            Office      = 'Site-C'
            Mobile      = '555-010-1012'
            AccountType = 'Contractor'
        }

        $Findings = @(
            Test-DirectoryAccount -Account $Account
        )

        $ConsistencyFinding = $Findings |
            Where-Object FindingType -eq 'Inconsistency'

        $ConsistencyFinding.Count |
            Should -BeGreaterThan 0
    }

    It 'does not flag a properly designated contractor' {

        $Account = [PSCustomObject]@{
            DisplayName = 'Charlie Contractor (C)'
            Description = 'Temporary contractor (C)'
            EmployeeID  = 'C100003'
            Company     = 'Example Consulting'
            Office      = 'Site-A'
            Mobile      = '555-010-1003'
            AccountType = 'Contractor'
        }

        $Findings = @(
            Test-DirectoryAccount -Account $Account
        )

        @(
            $Findings |
                Where-Object FindingType -eq 'Inconsistency'
        ).Count |
            Should -Be 0
    }
}

Describe 'Import-DirectoryAccountCsv' {

    It 'imports the synthetic dataset' {

        $Accounts = @(
            Import-DirectoryAccountCsv -Path $ExampleCsv
        )

        $Accounts.Count |
            Should -BeGreaterThan 0
    }

    It 'contains only the expected example company names' {

        $Accounts = @(
            Import-DirectoryAccountCsv -Path $ExampleCsv
        )

        $UnexpectedCompanies = @(
            $Accounts |
                Where-Object {
                    $_.Company -and
                    $_.Company -notin @(
                        'Example Corp'
                        'Example Consulting'
                        'Example Supplier'
                    )
                }
        )

        $UnexpectedCompanies.Count |
            Should -Be 0
    }
}

Describe 'Invoke-DirectoryAccountAudit' {

    It 'produces findings from the synthetic dataset' {

        $Accounts = @(
            Import-DirectoryAccountCsv -Path $ExampleCsv
        )

        $Findings = @(
            $Accounts |
                Invoke-DirectoryAccountAudit
        )

        $Findings.Count |
            Should -BeGreaterThan 0
    }

    It 'produces findings containing required report properties' {

        $Accounts = @(
            Import-DirectoryAccountCsv -Path $ExampleCsv
        )

        $Findings = @(
            $Accounts |
                Invoke-DirectoryAccountAudit
        )

        $FirstFinding = $Findings[0]

        $FirstFinding.PSObject.Properties.Name |
            Should -Contain 'DisplayName'

        $FirstFinding.PSObject.Properties.Name |
            Should -Contain 'FindingType'

        $FirstFinding.PSObject.Properties.Name |
            Should -Contain 'Attribute'

        $FirstFinding.PSObject.Properties.Name |
            Should -Contain 'Severity'

        $FirstFinding.PSObject.Properties.Name |
            Should -Contain 'Message'
    }
}

Describe 'Get-AuditSummary' {

    It 'generates summary statistics' {

        $Accounts = @(
            Import-DirectoryAccountCsv -Path $ExampleCsv
        )

        $Findings = @(
            $Accounts |
                Invoke-DirectoryAccountAudit
        )

        $Summary = $Findings |
            Get-AuditSummary

        $Summary.TotalFindings |
            Should -Be $Findings.Count

        $Summary.AccountsWithFindings |
            Should -BeGreaterThan 0
    }
}

Describe 'Export-AuditReport' {

    BeforeEach {
        $OutputPath = Join-Path `
            $TestDrive `
            'reports/audit.csv'
    }

    It 'creates a CSV report' {

        $Accounts = @(
            Import-DirectoryAccountCsv -Path $ExampleCsv
        )

        $Findings = @(
            $Accounts |
                Invoke-DirectoryAccountAudit
        )

        $Findings |
            Export-AuditReport -Path $OutputPath

        Test-Path $OutputPath |
            Should -BeTrue
    }

    It 'exports the same number of records as findings' {

        $Accounts = @(
            Import-DirectoryAccountCsv -Path $ExampleCsv
        )

        $Findings = @(
            $Accounts |
                Invoke-DirectoryAccountAudit
        )

        $Findings |
            Export-AuditReport -Path $OutputPath

        $Exported = @(
            Import-Csv $OutputPath
        )

        $Exported.Count |
            Should -Be $Findings.Count
    }
}
POWERSHELL