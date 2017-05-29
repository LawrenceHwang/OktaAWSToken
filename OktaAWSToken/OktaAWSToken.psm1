function SetAccount {
  [CmdletBinding()]
  param()
  begin {
    [string]$path = "$PSScriptRoot\OktaAWSToken.config"
    try {
      if (test-path $path -ErrorAction Stop) {
        Write-Verbose "Fetching account data from $path"
        $account = get-content $path -Raw | ConvertFrom-Json
      }
    }
    catch {
      Write-Warning "Config file $PSScriptRoot\OktaAWSToken.config missing."
      throw
    }
  }
  process {
    Write-Verbose "Account data is $account"
    do {
      for ($i = 0; $i -lt ($account.account).count; $i++) {
        write-host "[$($i+1)] $($account.account[$i].name)"
      }
      [int]$selection = Read-Host 'Select an account'

    } while ($selection -lt 1 -or $selection -gt ($account.account).count)
    $prop = @{
      organizationurl = $account.organizationurl
      appurl          = $account.account[($selection - 1)].idp_url
    }
    $oktaaccount = New-Object -TypeName psobject -Property $prop
    Write-Output $oktaaccount
  }
  end {}
} # end SetAccount

function GetSAML {
  [CmdletBinding()]
  param()
  begin {
    $cred = Get-Credential -Message 'OktaAWSToken: Please provide username and password'
    if ($cred -eq $null) {
      Write-Error 'No credential provided'
      throw
    }
    $oktaaccount = SetAccount
    $orgurl = ($oktaaccount.organizationurl -split ('://'))[-1]
    [string]$APIUrl = "https://$orgurl/api/v1/authn"
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cred.password)
    # Creating the Json object
    $BodyCred = @{"username" = $cred.username; "password" = "$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR))"} | ConvertTo-Json
  } # End begin
  process {
    try {
      $OktaSession = Invoke-WebRequest -Uri "$APIUrl" -Method Post -Body $BodyCred -ContentType "application/json" -SessionVariable okta -ErrorAction stop
    }
    catch {
      Write-Error -Message 'Error during authenticating with given username/ password.'
      throw
    }
    $status = (ConvertFrom-Json $OktaSession.Content).status
    write-host "$status"
    if ($status -like 'MFA_REQUIRED') {
      # MFA Auth
      $Content = ConvertFrom-json $OktaSession.Content
      $factor = (ConvertFrom-Json $OktaSession.Content)._embedded.factors
      do {
        for ($i = 0; $i -lt $factor.count; $i++) {
          write-host "[$($i+1)] $($factor[$i].provider) - $($factor[$i].factorType)"
        }
        [int]$selection = Read-Host 'MFA required. Select a MFA method (sms not supported currently)'
      } while ($selection -lt 1 -or $selection -gt $factor.count)
      $MFAUrl = $factor[($selection - 1)]._links.verify.href
      $MFAProvider = $factor[($selection - 1)].provider
      $MFAType = $factor[($selection - 1)].factorType
      switch -Wildcard ($("$MFAProvider$MFAType")) {
        "OKTA*push*" {
          $BodyStateToken = @{stateToken = $Content.stateToken} | ConvertTo-Json
        }
        "Google*token*" {
          $BodyStateToken = @{stateToken = "$($Content.stateToken)"; "passCode" = (Read-Host 'Please enter Google Authenticator Code')} | ConvertTo-Json
        }
        "Okta*token*" {$BodyStateToken = @{stateToken = "$($Content.stateToken)"; "passCode" = (Read-Host 'Please enter Okta Verifier Code')} | ConvertTo-Json
        }
        #"*sms" {$BodyStateToken = @{stateToken = "$($Content.stateToken)"; "passCode" = (Read-Host 'Please enter SMS Code')} | ConvertTo-Json
        #}
      } # end switch
      [string]$MFAStatus = ''
      while ($MFAStatus -notlike 'SUCCESS') {
        $MFAAuth = Invoke-WebRequest -Uri "$MFAUrl" -Method Post -Body $BodyStateToken -ContentType "application/json" -SessionVariable okta
        $MFAStatus = (ConvertFrom-Json  $MFAAuth.Content).status
        Start-Sleep 3
      } # end while

      $OneTimeToken = (ConvertFrom-Json  $MFAAuth.Content).sessiontoken

      $AuthURI = "$($oktaaccount.appurl)?onetimetoken=$OneTimeToken"
      Write-Verbose "$AuthURI is: $AuthURI"
      <#
            The -UseBasicParsing here prevents the script from opening up extra browser session caused by DCOM parsing.
            However, the response isn't fully decoded in that case. Additional steps are taken for decoding.
        #>
      $SamlAuth = Invoke-WebRequest -uri $AuthURI -SessionVariable okta -UseBasicParsing
      $SamlResponse = $SamlAuth.inputfields | Where-Object name -like "saml*" | Select-Object -ExpandProperty value
      Write-Verbose "$SamlResponse is: $SamlResponse"
      $SamlResponse = $SamlResponse.Replace("&#x2b;", "+").Replace("&#x3d;", "=")
      Write-Output $SamlResponse
    } # End if
    elseif ($status -like 'SUCCESS') {
      # Password auth. This part has not be validated.
      $AuthURI = "$($oktaaccount.appurl)"
      Write-Verbose "$AuthURI is: $AuthURI"
      <#
            The -UseBasicParsing here prevents the script from opening up extra browser session caused by DCOM parsing.
            However, the response isn't fully decoded in that case. Additional steps are taken for decoding.
        #>
      $SamlAuth = Invoke-WebRequest -uri $AuthURI -SessionVariable okta -Body $BodyCred -ContentType "application/json" -UseBasicParsing
      $SamlResponse = $SamlAuth.inputfields | Where-Object name -like "saml*" | Select-Object -ExpandProperty value
      Write-Verbose "$SamlResponse is: $SamlResponse"
      $SamlResponse = $SamlResponse.Replace("&#x2b;", "+").Replace("&#x3d;", "=")
      Write-Output $SamlResponse
    } # End elseif
    else {
      Write-Warning 'Error during status checking MFA'
      throw
    } # End else
  }
  end {}
} # end GetSAML

function GetArn {
  [CmdletBinding()]
  param(
    $SamlResponse
  )
  [xml]$SamlResponseDecode = [System.Text.Encoding]::ASCII.GetString([convert]::FromBase64String("$SamlResponse"))
  $arns = $SamlResponseDecode.Response.Assertion.AttributeStatement.Attribute.attributevalue | Select-Object -ExpandProperty "`#text"  | Where-Object {$_ -like 'arn*'}
  Write-Output $arns
} # end GetArn

<#
.SYNOPSIS
The Get-OktaAWSToken retrieves temporary AWS credentials from AWS STS

.DESCRIPTION
This is a quick and dirty PowerShell module to provide a programmatic way of retrieving temporary AWS credentials from STS (Security Token Service) when using federated login with Okta Idp with Multi-Factor Authentication (MFA). The following MFA options are supported and tested. The module also includes the password only authentication but never tested. Please give it a try and share your feedback.

* Okta Verify
* Okta Verify - Push
* Google Authenticator
The tool will prompt for credentials (MFA supported) to authenticate against Okta. It will then parse the SAML assertion generation (from Okta) and retrieve temporary:

* AWS Access Key IDs
* Secret Keys
* AWS Session Token The temporary credential has a default 60 minutes life. You can then use the information to set the AWS Credential for the PowerShell session.

.EXAMPLE
In this example, the module is imported manually.
And then we use the Get-OktaAWSToken to pipe the temporary credentail to Set-AWSCredentials cmdlet in the AWSPowerShell module.

PS:/> Import-module c:\<path-to-module>\OktaAWSToken
PS:/> Get-OktaAWSToken | Set-AWSCredentials

#>
function Get-OktaAWSToken {
  [CmdletBinding()]
  param()
  Write-Verbose -Message 'Getting SAML response'
  $SamlResponse = GetSAML
  Write-Verbose -Message 'Parsing arn'
  [string[]]$arn = GetArn -SamlResponse $SamlResponse
  for ($i = 0; $i -lt $arn.count ; $i++) {
    write-host "[$($i+1)] $($arn[$i].Split('/')[2])"
  }
  Write-Verbose -Message 'Asking user to select a role'
  do {
    [int]$selection = Read-Host "Select the role"
  } while ($selection -lt 1 -or $selection -gt $arn.count)

  $PrincipalArn = $arn[$($selection - 1)].Split(',')[0]
  $RoleArn = $arn[$($selection - 1)].Split(',')[1]

  Write-Verbose -Message 'Hitting the AWS STS'
  $resp = Use-STSRoleWithSAML -PrincipalArn $PrincipalArn -RoleArn $RoleArn  -SAMLAssertion $SamlResponse

  # Ouput the returned credential
  write-output $resp.Credentials
}


Export-ModuleMember -Function Get-OktaAWSToken