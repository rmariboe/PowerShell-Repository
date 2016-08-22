function Get-ExternalIPAddress {
 param (
  $IPUrl = 'http://checkip.dyndns.com' # http://whatismyipaddress.com/
 )
 $webClient = New-Object 'System.Net.WebClient'
 $ipString = $webClient.DownloadString($IPUrl)
 try {
#  return [System.Net.IPAddress]::Parse($ipString -replace '[^\d\.]')
  return [System.Net.IPAddress]::Parse($ipString -replace '[^\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}]')
#  return ($ipString -replace '[^\d\.]')
 }
 catch {
  Write-Error ("No IP address found in response from $ipUrl" + ':' + "`n$ipString")
 }
}
Get-ExternalIPAddress # -IPUrl 'http://whatismyipaddress.com/'

<#
((New-Object 'System.Net.WebClient').DownloadString('http://checkip.dyndns.com') -replace '[^\d\.]')
([xml]((New-Object 'System.Net.WebClient').DownloadString('http://checkip.dyndns.com'))).html.body.Replace('Current IP Address: ','')

Get-SPServer | ForEach-Object {Invoke-Command -ComputerName $_.Name -ScriptBlock {[System.Net.IPAddress]::Parse(((New-Object 'System.Net.WebClient').DownloadString('http://checkip.dyndns.com') -replace '[^\d\.]'))}}
#>