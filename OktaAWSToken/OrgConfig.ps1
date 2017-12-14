<#
    .SYNOPSIS
    This helper function assists user to create the config OktaAWSToken.config JSON file.
    The script will be executed upon importing the module.
#>
if (-not (test-path $PSScriptRoot\OktaAWSToken.config)) {
  Write-Warning "Initializing config file: $PSScriptRoot\OktaAWSToken.config."

  $accounts = @()
  [string]$org = ''
  while ($org -eq '') {
    $org = Read-host 'Enter the organization URL: E.g. https://company.okta.com'
  }
  while ($true) {
    [string]$name = ''
    [string]$idpurl = ''

    $name = Read-Host 'Enter friendly name of the idp. Leave blank and enter to finish.'
    if ($name -eq '') {
      break
    }
    while ($idpurl -eq '') {
      $idpurl = Read-Host "Enter idp url for $name"
    }
    $accounts += @{
      name    = $name
      idp_url = $idpurl
    }
  }
  $prop = @{
    organizationurl = $org
    account        = $accounts
  }

  $result = New-Object -TypeName psobject -Property $prop
  Write-Verbose -Message "Writing the information to $PSScriptRoot\OktaAWSToken.config"
  $result | ConvertTo-Json -Depth 3 | out-file $PSScriptRoot\OktaAWSToken.config -Force -Verbose
}
