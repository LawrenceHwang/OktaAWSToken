# OktaAWSToken
This PowerShell module provides a programmatic way of retrieving temporary AWS credentials from STS [(Security Token Service)](http://docs.aws.amazon.com/STS/latest/APIReference/Welcome.html) when using federated login with [Okta](https://www.okta.com/) Idp with Multi-Factor Authentication (MFA). The following MFA options are supported and tested. The module also includes the password only authentication but never tested. Please give it a try and share your feedback.

    * Okta Verify
    * Okta Verify - Push
    * Google Authenticator

The tool will prompt for credentials (MFA supported) to authenticate against Okta. It will then parse the SAML assertion generation (from Okta) and retrieve temporary:
  * AWS Access Key IDs
  * Secret Keys
  * AWS Session Token
The temporary credential has a default 60 minutes life. You can then use the information to [set the AWS Credential for the PowerShell session](http://docs.aws.amazon.com/powershell/latest/userguide/specifying-your-aws-credentials.html).


### PREREQUISITES
* [AWSPowerShell module](https://aws.amazon.com/powershell/)
* The idp entry urls: These are the URLs for the AWS apps within Okta. The apps are configured to provide access to AWS with the desired role. Your Okta admin should be able to provide the information. For example: https://company.okta.com/home/aws/0muaa4998fDLMflMod0x7/888


## INSTALLATION
```
# First time (and also one time) module setup
  # Download the repository
  # Extract the OktaAWSToken folder to one of the $env:PSModulePath paths. For example: $env:USERPROFILE\Documents\WindowsPowerShell\Modules)

  ## If you have PowerShell 5 or above, try this instead

     Install-Module OktaAWSToken

# Import the module
    Import-Module OktaAWSToken

# Function exported by the module:
    Get-OktaAWSToken
```

## CONFIGURATION
The JSON formatted `OktaAWSToken.config` file in the  OktaAWSToken module's base directory is mandatory for the module to work properly. You will need following information:

* Organization URL. This is the web URL you use to sign into Okta. It should be: `https://<company>.okta.com`
* Accounts. Each account represent an AWS application assigned to you. The module supports multiple accounts. For each account account, you give:
    * name - This is a friendly name which will later be used in the console.
    * idprul - This is the Idp url for the application. Usually in this form `https://company.okta.com/home/aws/0muaa4998fDLMflMod0x9/888`

You should be able to get those information from your Okta login page or just ask your Okta admin. One of the following will help you to set it up:

1. Let the configuration script work for you. The `OrgConfig.ps1` will be triggered during the module import. It will help you to setup the JSON file interactively.

2. manually configure it following the example:
```
{
    "organizationurl": "company.okta.com",
    "account": [
        {
            "name": "company-production",
            "idpurl": "https://company.okta.com/home/aws/0muaa4998fDLMflMod0x7/888"
        },
        {
            "name": "company-nonproduction",
            "idpurl": "https://company.okta.com/home/aws/0muaa4998fDLMflMod0x8/888"
        },
        {
            "name": "company-playground",
            "idpurl": "https://company.okta.com/home/aws/0muaa4998fDLMflMod0x9/888"
        }
    ]
}
```

## USAGE and EXAMPLE
Once configuted, you can get the credential using the `Get-OktaAWSToken`
1. Login
![1. Login](https://github.com/LawrenceHwang/OktaAWSToken/blob/master/Media/login.PNG?raw=true)
2. Select Account
![2. Select Account](https://github.com/LawrenceHwang/OktaAWSToken/blob/master/Media/selectaccount.PNG?raw=true)
3. MFA Challenge
![3. MFA Challenge](https://github.com/LawrenceHwang/OktaAWSToken/blob/master/Media/mfa.PNG?raw=true)
4. Result
![4. Result](https://github.com/LawrenceHwang/OktaAWSToken/blob/master/Media/full.png?raw=true)

Or, you can pipe it to `Set-AWSCredentials`.
```
Get-OktaAWSToken | Set-AWSCredentials
```

## RESOURCES and THANK YOU
Without these resources, it'd take much longer to achieve the goal. Thank you Quint Van Deman for the amazing blog and Joe Keegan for the great python project.

[How to Implement a General Solution for Federated API/CLI Access Using SAML 2.0](https://aws.amazon.com/blogs/security/how-to-implement-a-general-solution-for-federated-apicli-access-using-saml-2-0/)

[OKTA_AWS_LOGIN](https://github.com/nimbusscale/okta_aws_login)

## TODO
* Separate the private functions and public functions
* Implement the timeout in the MFA auth
* Verify whether the password only authentication works
* Add parameter validation and error hanling in the OrgConfig.ps1
* Create Pester tests for each
* Connect to AppVeyor
* Publish the module to PowerShell Gallery

## NOTE
Contributions very welcome! Any thought, suggestion, question or feedback? Please do feel free to send me a note by creating an issue or reach me on [twitter](https://twitter.com/CPoweredLion)

## License
The work is distributed under the MIT license. Please see the file LICENSE.txt for terms of use and redistribution.