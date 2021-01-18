param (
 $Name = '*',
 $First = 10,
 $Property = @('PM', 'Name'),
 $AutoRefresh = $false
)

Add-Type -AssemblyName 'System.Web' # For [System.Web.MimeMapping] (.NET 4.5 only!)


$head = '<title>Get-Process</title>'
if ($AutoRefresh) {
 $head += "`n" + '<meta http-equiv="refresh" content="' + $AutoRefresh + '" />'
}

$body = @'
<h2>Get-Process</h2><br>
<img src="./Get-MemoryPNG.ps1"><br>
'@

$data = Get-Process -Name $Name |
 Select-Object -Property $Property -First $First |
 Sort-Object -Property $Property -Descending |
 ConvertTo-HTML -Head $head -Body $body |
 Out-String

$buffer = [System.Text.Encoding]::Default.GetBytes($data)

$result = @{
 'ContentType' = [System.Web.MimeMapping]::GetMimeMapping('.htm'); # 'text/html' # Only .NET 4.5+
 'Data' = $buffer
}

return $result

#$PSBoundParameters
#$args


<#
       $httpListenerContext.Response.StatusCode = [System.Net.HttpStatusCode]::OK
       $httpListenerContext.Response.StatusDescription = 'OK'
       $httpListenerContext.Response.ContentType = [System.Web.MimeMapping]::GetMimeMapping('.htm') # Only .NET 4.5+
       $httpListenerContext.Response.ContentEncoding = [System.Text.Encoding]::Default
       $buffer = $httpListenerContext.Response.ContentEncoding.GetBytes($result.Data)
#>