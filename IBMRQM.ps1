function Invoke-JazzApi {
    param([Parameter(Mandatory)]$ComputerName, $Port=9443, [Parameter(Mandatory)]$Path, [PSCredential]$Credential)

    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $request = invoke-webrequest -Uri "https://$($ComputerName):$port/qm/service/com.ibm.rqm.integration.service.IIntegrationService/$Path" -WebSession $session
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

function Get-JazzTestCase {
    param([Parameter(Mandatory)]$ComputerName, $Port=9443, [Parameter(Mandatory)]$Project, [PSCredential]$Credential)

    [Xml]$TestCases = Invoke-JazzApi -ComputerName $ComputerName -Path resources/$([System.Web.HttpUtility]::UrlEncode($Project))/testcase -Credential $Credential -Port $Port

    foreach($TestCase in $TestCases.feed.entry)
    {
        [PSCustomObject]@{
            Title = $TestCase.Title.'#text'
            Summary = $TestCase.Summary.'#text'
        }
    }
}



