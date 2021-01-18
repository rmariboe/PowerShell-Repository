param (
 $Name = '*',
 $First = 10,
 $Property = @('PM', 'Name'),
 $AutoRefresh = $false
)

Add-Type -AssemblyName 'System.Web' # For [System.Web.MimeMapping] (.NET 4.5 only!)


$data = Get-Process -Name $Name |
 Select-Object -Property $Property -First $First |
 Sort-Object -Property $Property -Descending |
 Out-PieChart -ValueProperty 'PM' -ReturnImage

$result = @{
 'ContentType' = [System.Web.MimeMapping]::GetMimeMapping('.png'); # 'image/png' # Only .NET 4.5+
 'Data' = [System.Byte[]]$data
}

return $result

#$PSBoundParameters
#$args


<#
       $httpListenerContext.Response.StatusCode = [System.Net.HttpStatusCode]::OK
       $httpListenerContext.Response.StatusDescription = 'OK'
       $httpListenerContext.Response.ContentType = [System.Web.MimeMapping]::GetMimeMapping('.htm') # Only .NET 4.5+
       $httpListenerContext.Response.ContentEncoding = [System.Text.Encoding]::Default
       $buffer = $httpListenerContext.Response.ContentEncoding.GetBytes($data)
#>