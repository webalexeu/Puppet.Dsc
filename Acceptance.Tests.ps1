BeforeDiscovery {
}
BeforeAll {
  $ModuleRoot = Split-Path $PSCommandPath -Parent | Join-Path -ChildPath 'src'
  . .\src\internal\functions\Invoke-PdkCommand.ps1
  Import-Module "$ModuleRoot/puppet.dsc.psd1"
  $Script = $PSCommandPath.Replace('5.Tests.ps1','.ps1')
}

Describe "Acceptance Tests" -Tag 'acceptance' {
  BeforeDiscovery {
    $PSDscRunAsCredentialUsername = 'Foo'
    $PSDscRunAsCredentialPassword = 'This is a pretty long phrase, to be quite honest! :)'
    $Scenarios = @(
      @{
        Scenario         = 'puppetizing a module with script DSC Resources'
        # We need to know where the module will be built and what properties to build it with
        expected_base    = '../bar/powershellget'
        PuppetModuleName = 'powershellget'
        BuildParameters  = @{
          PowerShellModuleName    = 'PowerShellGet'
          PowerShellModuleVersion = '2.1.3'
          PuppetModuleAuthor      = 'testuser'
          OutputDirectory         = '../bar'
        }
        # An newly created resources need to be cleaned up prior to each test run
        DscResetInvocations = @(
          @{
            Name       ='PSRepository'
            Method     ='Set'
            Property   = @{ Name = 'Foo'; Ensure = 'Absent' }
            ModuleName = @{
              ModuleName = 'C:/ProgramData/PuppetLabs/code/modules/powershellget/lib/puppet_x/powershellget/dsc_resources/PowerShellGet/PowerShellGet.psd1'
              RequiredVersion = '2.1.3'
            }
          },
          @{
            Name       ='PSRepository'
            Method     ='Set'
            Property   = @{ Name = 'baz'; Ensure = 'Absent' }
            ModuleName = @{
              ModuleName = 'C:/ProgramData/PuppetLabs/code/modules/powershellget/lib/puppet_x/powershellget/dsc_resources/PowerShellGet/PowerShellGet.psd1'
              RequiredVersion = '2.1.3'
            }
          }
        )
        # The module should be uninstalled prior to each run if it exists
        PdkModuleUninstallationInvocationParameters = @{
          Path                = '../bar/powershellget'
          Command             = 'pdk bundle exec puppet module uninstall testuser-powershellget'
          SuccessFilterScript = { $true }
        }
        # Each of these types should be created and defined for puppet
        TypesToValidateTestCases = @(
          @{ Type = 'dsc_psmodule' }
          @{ Type = 'dsc_psrepository'}
        )
        # We need to validate that `puppet resource` works with the built module
        TestResource        = 'dsc_psrepository'
        MinimalProperties   = 'dsc_name=PSGallery'
        MinimalExpectation  = "dsc_name => 'PSGallery'"
        PropertyExpectation = "dsc_installationpolicy => 'Trusted'"
        # These are scenarios for child contexts that validate expected invocation behavior
        ApplicationScenarios = @(
          @{
            ApplicationScenarioTitle = 'when managing an existing repository with "puppet apply"'
            ApplicationScenarioTestCases = @(
              @{
                TestName = "doesn't do anything"
                ManifestFileName = 'confirm.pp'
                ManifestFileValue = "dsc_psrepository { 'PSGallery': }`n"
                PdkErrorFilterScript = { $_ -match 'Notice:.*Dsc_psrepository\[PSGallery\]' }
              }
            )
          }
          @{
            ApplicationScenarioTitle = 'when creating a new repository with "puppet apply"'
            ApplicationScenarioTestCases = @(
              @{
                TestName = 'works'
                ManifestFileName = 'new_repo.pp'
                ManifestFileValue = @(
                  'dsc_psrepository { "Foo":'
                  '  dsc_name               => "Foo",'
                  '  dsc_ensure             => "Present",'
                  '  dsc_sourcelocation     => "c:\\program files",'
                  '  dsc_installationpolicy => "Untrusted",'
                  "}`n"
                ) -join "`n"
                PdkSuccessFilterScript = { $_ -match 'Creating: Finished' }
                PdkErrorFilterScript   = { $_ -match 'Error' }
              }
              @{
                TestName = 'works with non-canonical elements'
                ManifestFileName = 'new_repo_non_canonical.pp'
                ManifestFileValue = @(
                  'dsc_psrepository { "bar":'
                  '  dsc_name               => "baz",'
                  '  dsc_ensure             => "Present",'
                  '  dsc_sourcelocation     => "C:\\Program Files (x86)",'
                  '  dsc_installationpolicy => "Untrusted",'
                  "}`n"
                ) -join "`n"
                PdkSuccessFilterScript = { $_ -match 'Creating: Finished' }
                PdkErrorFilterScript   = { $_ -match 'Error' }
              }
              @{
                TestName = 'is idempotent'
                ManifestFileName = 'new_repo_non_canonical.pp'
                ManifestFileValue = @(
                  'dsc_psrepository { "bar":'
                  '  dsc_name               => "baz",'
                  '  dsc_ensure             => "Present",'
                  '  dsc_sourcelocation     => "C:\\Program Files (x86)",'
                  '  dsc_installationpolicy => "Untrusted",'
                  "}`n"
                ) -join "`n"
                PdkErrorFilterScript   = { $_ -match 'Notice:.*Dsc_psrepository' }
              }
            )
          }
          @{
            ApplicationScenarioTitle = 'when a valid manifest causes a run-time error'
            ApplicationScenarioTestCases = @(
              @{
                TestName = 'reports the error'
                ManifestFileName = 'reuse_repo.pp'
                ManifestFileValue = @(
                  'dsc_psrepository { "foo2":'
                  '  dsc_name               => "foo2",'
                  '  dsc_ensure             => "Present",'
                  '  dsc_sourcelocation     => "c:\\program files",'
                  '  dsc_installationpolicy => "Untrusted",'
                  "}`n"
                ) -join "`n"
                SuccessFilterScript = { $_ -match "The repository could not be registered because there exists a registered repository with Name" }
              }
            )
          }
        )
        # Information Needed for PSDscRunAsCredential
        PSDscRunAsCredentialScenario = @(
          @{
            Username = $PSDscRunAsCredentialUsername
            Password = $PSDscRunAsCredentialPassword
            ManifestFileName  = 'psdscrunascredential.pp'
            ManifestFileValue = @(
              'dsc_psrepository { "Foo":'
              '  dsc_name               => "Foo",'
              '  dsc_ensure             => "Present",'
              '  dsc_sourcelocation     => "c:\\program files",'
              '  dsc_installationpolicy => "Untrusted",'
              '  dsc_psdscrunascredential => {'
              "    user     => '$PSDscRunAsCredentialUsername',"
              "    password => Sensitive('$PSDscRunAsCredentialPassword'),"
              '  },'
              "}`n"
            ) -join "`n"
            FirstRunSuccessFilterScript      = { $_ -match 'Creating: Finished' }
            FirstRunErrorFilterScript        = { $_ -match '(Error|has not provided canonicalized values)' }
            IdempotentRunErrorFilterScript   = { $_ -match 'Notice:.*Dsc_psrepository' }
          }
        )
      }
      # TODO: Class-based resource scenario
    )
  }
  Context "when passing in invalid values" {
    It "reports the error" {
      { New-PuppetDscModule -PowerShellModuleName "____DoesNotExist____" -OutputDirectory "C:\foo" -ErrorAction Stop } | Should -Throw
    }
  }
  Context "validating <scenario>" -Foreach $Scenarios {
    BeforeAll {
      Remove-Item $expected_base -Force -Recurse -ErrorAction Ignore

      New-PuppetDscModule @BuildParameters

      # remove test instances left over from a previous run
      ForEach ($ResetInvocationParameters in $DscResetInvocations) {
        try {
          Invoke-DscResource @ResetInvocationParameters -ErrorAction SilentlyContinue
        }
        catch {
          # ignore cleanup errors
        }
      }

      # cleanup a previously installed test module before the test, ignoring any result
      Invoke-PdkCommand @PdkModuleUninstallationInvocationParameters
    }

    It "creates a module" {
      Test-Path "$expected_base\metadata.json" | Should -BeTrue
    }
    It "has a REFERENCE.md" {
      Test-Path "$expected_base\REFERENCE.md" | Should -BeTrue
    }
    It "generates a type file for <Type>" -TestCases $TypesToValidateTestCases {
      Test-Path "$expected_base\lib\puppet\type\$Type.rb" | Should -BeTrue
    }

    Context "when inside the module" {
      # It '`pdk validate metadata` runs successfully' {
      #   Invoke-PdkCommand -Path $expected_base -Command 'pdk validate metadata' -SuccessFilterScript { $_ -match "Using Puppet" } -ErrorFilterScript { $_ -match "error:" }
      # }
      # It '`pdk validate puppet` runs successfully' {
      #   Invoke-PdkCommand -Path $expected_base -Command 'pdk validate puppet' -SuccessFilterScript { $_ -match "Using Puppet" } -ErrorFilterScript { $_ -match "error:" }
      # }
      # It '`pdk validate tasks` runs successfully' {
      #   Invoke-PdkCommand -Path $expected_base -Command 'pdk validate tasks' -SuccessFilterScript { $_ -match "Using Puppet" } -ErrorFilterScript { $_ -match "error:" }
      # }
      # It '`pdk validate yaml` runs successfully' {
      #   Invoke-PdkCommand -Path $expected_base -Command 'pdk validate yaml' -SuccessFilterScript { $_ -match "Using Puppet" } -ErrorFilterScript { $_ -match "error:" }
      # }
      It "is buildable" {
        Invoke-PdkCommand -Path $expected_base -Command 'pdk build' -SuccessFilterScript {
          $_ -match "Build of testuser-$PuppetModuleName has completed successfully."
        }
      }
      It "is installable" {
        Invoke-PdkCommand -Path $expected_base -Command 'pdk bundle exec puppet module install --verbose pkg/*.tar.gz' -SuccessFilterScript {
          $_ -match "Installing -- do not interrupt"
        }
      }
      It "lists all <TestResource> resources" -Pending {
        Invoke-PdkCommand -Path $expected_base -Command "pdk bundle exec puppet resource $TestResource" -SuccessFilterScript {
          $_ -match "$TestResource {"
        }
      }
      Context "<ApplicationScenarioTitle>" -Foreach $ApplicationScenarios {
        It '<TestName>' -TestCases $ApplicationScenarioTestCases {
          Set-Content -Path "$expected_base\$ManifestFileName" -Value $ManifestFileValue
          If ($null -eq $PdkSuccessFilterScript) {
            Invoke-PdkCommand -Path $expected_base -Command "pdk bundle exec puppet apply --color=false $ManifestFileName" -ErrorFilterScript $PdkErrorFilterScript
          } Else {
            Invoke-PdkCommand -Path $expected_base -Command "pdk bundle exec puppet apply --color=false $ManifestFileName" -ErrorFilterScript $PdkErrorFilterScript -SuccessFilterScript $PdkSuccessFilterScript
          }
        }
      }
      Context 'validating PSDscRunAsCredential' -Foreach $PSDscRunAsCredentialScenario {
        BeforeAll {
          New-LocalUser -Name $Username -Password (ConvertTo-SecureString -AsPlainText -Force $Password)
          Add-LocalGroupMember -Group Administrators -Member $Username
          Set-Content -Path "$expected_base\$ManifestFileName" -Value $ManifestFileValue
        }
        AfterAll {
          Remove-LocalGroupMember -Group Administrators -Member $Username
          Remove-LocalUser -Name $Username
        }
        It "works" {
          Invoke-PdkCommand -Path $expected_base -Command "pdk bundle exec puppet apply --color=false $ManifestFileName" -ErrorFilterScript $FirstRunErrorFilterScript -SuccessFilterScript $FirstRunSuccessFilterScript
        }
        It 'is idempotent' {
          Invoke-PdkCommand -Path $expected_base -Command "pdk bundle exec puppet apply --color=false $ManifestFileName" -ErrorFilterScript $IdempotentRunErrorFilterScript
        }
      }
      Context "with a Sensitive value" {
        It "does not print the value in regular mode" -Pending { }
        It "does not print the value in debug mode" -Pending { }
      }
      It "shows a specific <TestResource> resource" {
        $Result = Invoke-PdkCommand -Path $expected_base -Command "pdk bundle exec puppet resource $TestResource title $MinimalProperties" -PassThru -SuccessFilterScript {
          $_ -match "$TestResource { 'title'"
        }
        $Result -match $MinimalExpectation | Should -BeTrue
      }
      It "shows a specific <TestResource> resource with attributes" -Pending {
        $Result = Invoke-PdkCommand -Path $expected_base -Command "pdk bundle exec puppet resource $TestResource title $MinimalProperties" -PassThru -SuccessFilterScript {
          $_ -match "$TestResource { 'title'"
        }
        $Result -match $MinimalExpectation -and $Result -match $PropertyExpectation | Should -BeTrue
      }
    }
  }

}
