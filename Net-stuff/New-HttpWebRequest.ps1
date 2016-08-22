function New-HttpWebRequest {
 <#
  .LINK
  https://msdn.microsoft.com/en-us/library/system.net.httpwebrequest.aspx
 #>
 [OutputType([System.Net.HttpWebRequest])]
 param (
# The Uniform Resource Identifier (URI) of the Internet resource that actually responds to the request.
  [Parameter(Mandatory=$true)][System.Uri]$Address,
# Indicates whether the request should follow redirection responses.
  [System.Management.Automation.SwitchParameter]$AllowAutoRedirect = $false,
# A System.Net.CookieContainer object that contains the cookies associated with this request.
# Set to $null to disable cookies.
# https://msdn.microsoft.com/en-us/library/system.net.httpwebrequest.cookiecontainer
# https://msdn.microsoft.com/en-us/library/system.net.cookiecontainer.aspx
  [AllowNull()][System.Net.CookieContainer]$CookieContainer = (New-Object -TypeName 'System.Net.CookieContainer'),
# Authentication information for the request.
# https://msdn.microsoft.com/en-us/library/system.net.networkcredential.aspx
  [System.Net.NetworkCredential]$Credentials = $null,
# The Host header value to use in an HTTP request independent from the request URI.
  [Alias('Host')][System.String]$HostName = ([System.Uri]$Address).Host,
# Indicates whether to make a persistent connection to the Internet resource.
  [System.Management.Automation.SwitchParameter]$KeepAlive,
# The method for the request.
  [ValidateSet('GET', 'CONNECT', 'HEAD', 'PUT', 'POST', 'MKCOL')][System.String]$Method = [System.Net.WebRequestMethods+Http]::Get,
# Controls whether default credentials are sent with requests.
  [System.Management.Automation.SwitchParameter]$UseDefaultCredentials,
# The User-agent HTTP header.
  [System.String]$UserAgent = $null
 )

 Write-Verbose ("Creating HttpWebRequest object for address '$Address'")
 [System.Net.HttpWebRequest]$httpWebRequest = [System.Net.WebRequest]::CreateHttp([System.Uri]$Address)
 Write-Verbose ("AllowAutoRedirect = '$AllowAutoRedirect'")
 $httpWebRequest.AllowAutoRedirect = [System.Boolean]$AllowAutoRedirect
 if (-not $Credentials.Domain) { # Always $env:USERDOMAIN ?
  Write-Verbose ("Credentials = '" + $Credentials.UserName + "'")
 }
 else {
  Write-Verbose ("Credentials = '" + [System.String]::Join('\', @($Credentials.Domain, $Credentials.UserName)) + "'")
 }
 $httpWebRequest.Credentials = [System.Net.NetworkCredential]$Credentials
 Write-Verbose ("Host = '$HostName'")
 $httpWebRequest.Host = [System.String]$HostName
 Write-Verbose ("KeepAlive = '$KeepAlive'")
 $httpWebRequest.KeepAlive = $KeepAlive
 Write-Verbose ("Method = '$Method'")
 $httpWebRequest.Method = $Method
 Write-Verbose ("UseDefaultCredentials = '$UseDefaultCredentials'")
 $httpWebRequest.UseDefaultCredentials = $UseDefaultCredentials
 Write-Verbose ("UserAgent = '$UserAgent'")
 $httpWebRequest.UserAgent = $UserAgent

 return $httpWebRequest
}


function Read-IOStream {
 param (
  [Parameter(Mandatory=$true)][System.IO.Stream]$Stream,
  [System.Int32]$BufferSize = 64kB
 )

 [System.Byte[]]$buffer = New-Object -TypeName 'System.Byte[]' -ArgumentList $BufferSize
 [System.Int32]$offset = 0
 [System.Int32]$size = $buffer.Count
 do {
  [System.Int32]$read = $connectStream.Read([System.Byte[]]$buffer, [System.Int32]$offset, [System.Int32]$size)
  Write-Verbose ('Bytes read: ' + $read)
  [System.Byte[]]$buffer[0..($read-1)]
 }
 while ($read -gt 0) # -and $buffer[-1] -ne [System.Byte]0
}


function Return-Html {
 param(
  [Parameter(Mandatory=$true)]$Address
 )

 [System.Net.HttpWebRequest]$httpWebRequest = New-HttpWebRequest -Address $Address -AllowAutoRedirect
 [System.Net.HttpWebResponse]$httpWebResponse = $httpWebRequest.GetResponse()
 [System.IO.Stream]$connectStream = $httpWebResponse.GetResponseStream()
 [System.Object[]]$output = Read-IOStream -Stream $connectStream
 $connectStream.Close()
 $connectStream.Dispose()
 $httpWebResponse.Close()
 $httpWebResponse.Dispose()

 return [System.String]::Join('', [System.Char[]]$output[0..($output.Count-3)])
}

