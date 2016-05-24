Add-Type -AssemblyName System.Web

function Invoke-RQMApi {
    param([Parameter(Mandatory)]$ComputerName, $Port=9443, [Parameter(Mandatory, ParameterSetName='Path')]$Path, [PSCredential]$Credential, [Parameter(Mandatory, ParameterSetName='FullUri')]$FullUri)

    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

    if ($FullUri -eq $Null)
    {
        $FullUri = "https://$($ComputerName):$port/qm/service/com.ibm.rqm.integration.service.IIntegrationService/$Path"
    }

    $request = invoke-webrequest -Uri $FullUri -WebSession $session
    if ($request.Headers['X-com-ibm-team-repository-web-auth-msg'] -eq 'authrequired')
    {
        $Body = "j_username=" + [System.Web.HttpUtility]::UrlEncode($Credential.UserName)
        $Body += '&'
        $Body += "j_password=" + [System.Web.HttpUtility]::UrlEncode($Credential.GetNetworkCredential().Password)
        $Cookie = $request.BaseResponse.Cookies | where name -eq 'jazzformauth'
        $session.Cookies.Add($COokie)
    }

    (invoke-webrequest -Uri https://$($ComputerName):$Port/qm/service/com.ibm.rqm.integration.service.IIntegrationService/j_security_check -Method POST -ContentType 'application/x-www-form-urlencoded' -Body $Body -WebSession $session).Content
}

function Get-RQMTestSuite {
    param([Parameter(Mandatory)]$ComputerName, $Port=9443, [Parameter(Mandatory)]$Project, [PSCredential]$Credential)

    [Xml]$TestSuites = Invoke-RQMApi -ComputerName $ComputerName -Path resources/$([System.Web.HttpUtility]::UrlEncode($Project))/testsuite -Credential $Credential -Port $Port

    foreach($TestSuite in $TestSuites.feed.entry)
    {
        [xml]$FullInfo = Invoke-RQMApi -ComputerName $ComputerName -FullUri $TestSuite.Id -Credential $Credential

        $TestCases = foreach($element in $FulLInfo.testsuite.suiteelements.suiteelement)
        {
            Get-RQMTestCase -Id $element.testcase.href -ComputerName $ComputerName -Port $Port -Credential $Credential
        }

        [PSCustomObject]@{
            Title = $FullInfo.testsuite.Title
            Description = $FullInfo.testsuite.Description
            TestCases = $TestCases
        }
    }
}

function Get-RQMTestCase {
    param([Parameter(Mandatory)]$ComputerName, $Port=9443, [Parameter(Mandatory,ParameterSetName='Project')]$Project, [Parameter(Mandatory, ParameterSetName='Id')]$Id, [PSCredential]$Credential)

    function ConvertTo-TestCase {
        param($Uri, [Parameter(Mandatory)]$ComputerName, $Port=9443, [PSCredential]$Credential)

        [xml]$FullInfo = Invoke-RQMApi -ComputerName $ComputerName -FullUri $Uri -Credential $Credential
        [xml]$TestScript = Invoke-RQMApi -ComputerName $ComputerName -FullUri $FullInfo.testcase.testscript.href -Credential $Credential

        [PSCustomObject]@{
            Title = $FullInfo.Title
            Description = $FullInfo.Description
            ProjectArea = [System.Web.HttpUtility]::UrlDecode($FullInfo.testcase.projectArea.alias)
            State = $FullInfo.testcase.state.'#text'
            Owner = $FullInfo.testcase.Owner
            Priority = $FullInfo.testcase.priority.'#text'
            TestScript = [PSCustomObject]@{
                Type = $TestScript.testscript.scripttype
                Category = $TestScript.testscript.category.value
                Steps = $TestScript.testscript.steps.step
            }
        }
    }

    if ($Id -eq $null)
    {
        [Xml]$TestCases = Invoke-RQMApi -ComputerName $ComputerName -Path resources/$([System.Web.HttpUtility]::UrlEncode($Project))/testcase -Credential $Credential -Port $Port

        foreach($TestCase in $TestCases.feed.entry)
        {
            ConvertTo-TestCase -Uri $TestCase.Id -ComputerName $ComputerName -Port $Port -Credential $Credential
        }
    }
    else
    {
        ConvertTo-TestCase -Uri $Id -ComputerName $ComputerName -Port $Port -Credential $Credential
    }
}
