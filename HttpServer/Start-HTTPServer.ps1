function Get-WindowsIdentity {
 param (
  [Parameter(Mandatory=$false)][AllowNull()][AllowEmptyString()][System.Management.Automation.PSCredential]$Credential = $null
 )

 [System.IntPtr]$userToken = [Security.Principal.WindowsIdentity]::GetCurrent().Token

 if ($ContentAccessCredential) {
  $advapi32 = Add-Type -Name advapi32 -MemberDefinition @"
   // http://msdn.microsoft.com/en-us/library/aa378184.aspx
   [DllImport("advapi32.dll", SetLastError = true)]
   public static extern bool LogonUser(string lpszUsername, string lpszDomain, string lpszPassword, int dwLogonType, int dwLogonProvider, ref IntPtr phToken);
"@ -PassThru

  if(!$advapi32::LogonUser($ContentAccessCredential.GetNetworkCredential().UserName, $ContentAccessCredential.GetNetworkCredential().Domain, $ContentAccessCredential.GetNetworkCredential().Password, 2, 0, [ref]$userToken)) {
   throw (New-Object System.ComponentModel.Win32Exception([System.Runtime.InteropServices.Marshal]::GetLastWin32Error()))
  }
 }

 return [Security.Principal.WindowsIdentity]$userToken
}


function New-HttpListener {
 param (
#  [Parameter(Mandatory=$false)][System.String[]]$Bindings = 'http://*:80/',
  [Parameter(Mandatory=$false)][System.String]$Bindings = 'http://*:80/',	# Multiple bindings logic not implemented!
  [Parameter(Mandatory=$false)][ValidateSet('Anonymous','Basic','Digest','IntegratedWindowsAuthentication','Negotiate','None','Ntlm')][System.Net.AuthenticationSchemes[]]$AuthenticationSchemes = 'Anonymous'
 )

 $httpListener = New-Object -TypeName 'System.Net.HttpListener'

 $httpListener.AuthenticationSchemes = $AuthenticationSchemes

 foreach ($binding in $Bindings) {
#  $bindingUri = [System.Uri]($binding.Replace('*', 'localhost')) # Implement check for bad URIs?

  $httpListener.Prefixes.Add($binding)
 }

 return [System.Net.HttpListener]$httpListener
}


function Get-ContentEncoding { ### FIX THIS!!! - COMPARE OBJECT FUCKED!?
 param (
  [Parameter(Mandatory=$true)][System.Byte[]]$Buffer
 )
# https://en.wikipedia.org/wiki/Byte_order_mark

 if     (-not ($Buffer[0..1] | Compare-Object -ReferenceObject ([System.Byte[]](0xFF,0xFE)))) {
  return [System.Text.Encoding]::GetEncoding('utf-16')
 }
 elseif (-not ($Buffer[0..1] | Compare-Object -ReferenceObject ([System.Byte[]](0xFE,0xFF)))) {
  return [System.Text.Encoding]::GetEncoding('utf-16BE')
 }
 elseif (-not ($Buffer[0..2] | Compare-Object -ReferenceObject ([System.Byte[]](0xEF,0xBB,0xBF)))) {
  return [System.Text.Encoding]::GetEncoding('utf-8')
 }
 elseif (-not ($Buffer[0..2] | Compare-Object -ReferenceObject ([System.Byte[]](0x2B,0x2F,0x76)))) {
  return [System.Text.Encoding]::GetEncoding('utf-7')
 }
 elseif (-not ($Buffer[0..3] | Compare-Object -ReferenceObject ([System.Byte[]](0xFF,0xFE,0x00,0x00)))) {
  return [System.Text.Encoding]::GetEncoding('utf-32')
 }
 elseif (-not ($Buffer[0..3] | Compare-Object -ReferenceObject ([System.Byte[]](0x00,0x00,0xFE,0xFF)))) {
  return [System.Text.Encoding]::GetEncoding('utf-32BE')
 }
 elseif (-not ($Buffer[0..3] | Compare-Object -ReferenceObject ([System.Byte[]](0x84,0x31,0x95,0x33)))) {
  return [System.Text.Encoding]::GetEncoding('GB18030')
 }
 else {
  return [System.Text.Encoding]::GetEncoding('us-ascii') # Null?
 }
}


function Write-HttpServerLog {
 param (
  [Parameter(Mandatory=$true)][System.String][ValidateSet('ServerStarted', 'Serving', 'Served', 'Aborted', 'ServerStopped')]$Event,
  [Parameter(Mandatory=$false)][System.String]$LogEntry = $null,
  [Parameter(Mandatory=$false)][System.Net.HttpListener]$HttpListener = $null,
  [Parameter(Mandatory=$false)][System.Net.HttpListenerContext]$HttpListenerContext,
  [Parameter(Mandatory=$false)][System.String]$ServerName = 'Tiny PowerShell .Net HTTP server',
  [Parameter(Mandatory=$false)][System.String]$LogDateFormat = 'yyyy-MM-dd HH:mm:ss'
 )

 $logDate = Get-Date -Format $LogDateFormat
 $bindings = $HttpListener.Prefixes -join ', '

 Write-Host ($logDate + ': ') -ForegroundColor 'DarkGray' -NoNewLine

 switch ($Event) {
  'ServerStarted' {
   Write-Host ("$ServerName started. Listening on $bindings") -ForegroundColor 'Green'
  }
  'ServerStopped' {
   Write-Host ("$ServerName stopped.") -ForegroundColor 'Green'
  }
  default {
   if(-not ($httpListenerContextIdentityName = $HttpListenerContext.Identity.Name)) {
    $httpListenerContextIdentityName = 'Anonymous'
   }
   Write-Host ("$Event ")          -ForegroundColor 'Green'    -NoNewLine; Write-Host ($LogEntry)                                                      -ForegroundColor 'White' -NoNewLine
   Write-Host (' as ')             -ForegroundColor 'DarkGray' -NoNewLine; Write-Host ($httpListenerContext.Response.ContentType)                      -ForegroundColor 'White' -NoNewLine; Write-Host (' (' + $httpListenerContext.Response.ContentEncoding.EncodingName + ')') -ForegroundColor 'White' -NoNewLine
   Write-Host (' to ')             -ForegroundColor 'DarkGray' -NoNewLine; Write-Host ($httpListenerContext.Request.RemoteEndPoint.Address.ToString()) -ForegroundColor 'Green' -NoNewLine
   Write-Host (' on request for ') -ForegroundColor 'DarkGray' -NoNewLine; Write-Host ($httpListenerContext.Request.Url)                               -ForegroundColor 'Green' -NoNewLine
   Write-Host (' by ')             -ForegroundColor 'DarkGray' -NoNewLine; Write-Host ($httpListenerContextIdentityName)                               -ForegroundColor 'Green'
  }
 }
}


function Start-HTTPServer {
 param (
  [Parameter(Mandatory=$false)][string]$ServerName = 'Tiny PowerShell .Net HTTP server',
#  [Parameter(Mandatory=$false)][string[]]$Bindings = 'http://*:80/',
  [Parameter(Mandatory=$false)][string]$Bindings = 'http://*:80/',	# Multiple bindings logic not implemented!
  [Parameter(Mandatory=$false)][string]$BaseDirectory = (Get-Item .).FullName,
  [Parameter(Mandatory=$false)][string]$DefaultDocument = 'index.htm',
  [Parameter(Mandatory=$false)][switch]$DirectoryListingAllowed = $false,
#  [Parameter(Mandatory=$false)][string[]]$HttpStatusResponses = (Get-HttpStatusDescriptions),
  [Parameter(Mandatory=$false)][ValidateSet('Anonymous','Basic','Digest','IntegratedWindowsAuthentication','Negotiate','None','Ntlm')][System.Net.AuthenticationSchemes[]]$AuthenticationSchemes = 'Anonymous',
  [Parameter(Mandatory=$false)][System.Text.Encoding]$DefaultContentEncoding = [System.Text.Encoding]::Unicode,
  [Parameter(Mandatory=$false)][System.Management.Automation.PSCredential]$ContentAccessCredential = $null,
  [Parameter(Mandatory=$false)][string]$LogDateFormat = 'yyyy-MM-dd HH:mm:ss',
  [Parameter(Mandatory=$false)][string]$MimeTypesCsvPath = $null,
  [Parameter(Mandatory=$false)][int]$MaxRequests = $null
#  $SSL STUFF
 )

 Add-Type -AssemblyName 'System.Web' # For [System.Web.MimeMapping] (.NET 4.5 only!)


 $ErrorActionPreference = 'Stop'

 $ContentAccessIdentity = Get-WindowsIdentity -Credential $ContentAccessCredential

### GET MIMETYPES BEGIN ###
 if ($MimeTypesCsvPath) {
  Write-Verbose "Importing MIME types from $MimeTypesCsvPath..."

  $mimeTypesHash = New-Object -TypeName 'System.Collections.Hashtable'
  $mimeTypes = Import-Csv -Path $MimeTypesCsvPath -Delimiter ';'
  foreach ($mimeType in $mimeTypes) {
   try {
    $null = $mimeTypesHash.Add($mimeType.Extension, $mimeType.MIMEType)
   }
   catch {}
  }
 }
 else {
  $mimeTypeUrl = 'http://www.stdicon.com/mimetypes'

  Write-Verbose "Importing MIME types from $mimeTypeUrl..."

  $mimeTypesJSON = (Invoke-WebRequest $mimeTypeUrl).Content					# Broken "JSON" coming from this
  $mimeTypesJSON = $mimeTypesJSON -replace '\\(.)', '$1'
  $mimeTypesJSON = $mimeTypesJSON.Replace('[{','{').Replace('}, {',', ').Replace('}]','}')	# Now it's real JSON
  [System.Collections.Hashtable]$mimeTypesHash = [System.Management.Automation.ScriptBlock]::Create('@' + $mimeTypesJSON.Replace('": "','"="').Replace('", "','"; "')).Invoke()[0]

<#  $mimeTypesJSON = Invoke-WebRequest $mimeTypeUrl | ConvertFrom-Json
  $mimeTypesHash = New-Object hashtable
  for($i = 0; $i -lt $j.Count; $i++) {
   try {
    $mimeTypeDefinition = ($j[$i]|gm)[-1].Definition.Replace('System.String ','').Split('=')
    $null = $mimeTypesHash.Add($mimeTypeDefinition[0], $mimeTypeDefinition[1])
   }
   catch {}
  }#>
 }

 Write-Verbose ('Imported ' + $mimeTypesHash.Count + ' MIME types.')
### GET MIMETYPES  END  ###

 [System.Net.HttpListener]$httpListener = New-HttpListener -Bindings $Bindings -AuthenticationSchemes $AuthenticationSchemes

 $requestCount = 0

 try {
  $httpListener.Start()
  Write-HttpServerLog -Event 'ServerStarted' -HttpListener $httpListener -LogDateFormat $LogDateFormat -ServerName $ServerName
  do {
   $item = $null

   $Bindings = $httpListener.Prefixes -join ', '

   Write-Progress -Activity $ServerName -Status "Listening on $Bindings" -CurrentOperation 'Awaiting request...'

### GET HTTPLISTENERCONTEXT BEGIN ###
   $httpListenerContextAsync = $httpListener.GetContextAsync()
   do {
    $requestReceived = $httpListenerContextAsync.Wait(1000)
   }
   while (-not $requestReceived)
   [System.Net.HttpListenerContext]$httpListenerContext = $httpListenerContextAsync.Result
   $requestCount++
### GET HTTPLISTENERCONTEXT  END  ###

   Write-Progress -Activity $ServerName -Status "Listening on $Bindings" -CurrentOperation ('Serving request from ' + $httpListenerContext.Request.RemoteEndPoint.Address.ToString() + ' for ' + $httpListenerContext.Request.Url + '...')

### PARSE AND SECURE AGAINST ABOVE TOP REQUESTS BEGIN ###
   foreach ($binding in $httpListener.Prefixes) {
#    if ($httpListenerContext.Request.Url.AbsoluteUri.Length -gt $binding.Length) {
#     $path = '/' + [System.Net.WebUtility]::UrlDecode($httpListenerContext.Request.Url.AbsoluteUri.Remove(0, $binding.Length))
    $bindingUri = [System.Uri]$binding
#   .Replace('+','localhost') # Only for host; allowed in path!
    if ($httpListenerContext.Request.Url.LocalPath.Length -gt $bindingUri.LocalPath.Length) {
     $path = '/' + [System.Net.WebUtility]::UrlDecode($httpListenerContext.Request.Url.LocalPath.Remove(0, $bindingUri.LocalPath.Length))
    }
    else {
     $path = '/'
    }
   }
### PARSE AND SECURE AGAINST ABOVE TOP REQUESTS  END ###

   $impersonationContext = $null
   try {
### IMPERSONATE CLIENT OR SERVER ACCOUNT BEGIN ###
    if ($httpListenerContext.User.Identity) {
     $impersonationContext = $httpListenerContext.User.Identity.Impersonate()
    }
    else {
     $impersonationContext = $ContentAccessIdentity.Impersonate()
    }
### IMPERSONATE CLIENT OR SERVER ACCOUNT  END  ###

    if (Test-Path -Path (Join-Path -Path $BaseDirectory -ChildPath $path)) {
 ## EXISTS BEGIN ##
     $item = Get-Item -Path (Join-Path -Path $BaseDirectory -ChildPath $path)
     if ($item.PSIsContainer) {
  # IS DIRECTORY BEGIN #
      if (Test-Path -Path (Join-Path -Path $item -ChildPath $DefaultDocument)) {
   # IS DEFAULT DOCUMENT BEGIN #
       $item = Get-Item -Path (Join-Path -Path $item -ChildPath $DefaultDocument)
       $httpListenerContext.Response.StatusCode = [System.Net.HttpStatusCode]::OK
       $httpListenerContext.Response.StatusDescription = 'OK'
       $httpListenerContext.Response.ContentType = [System.Web.MimeMapping]::GetMimeMapping($item.FullName) # Only .NET 4.5+
       $buffer = [System.IO.File]::ReadAllBytes($item.FullName)
       if ($httpListenerContext.Response.ContentType.Split('/')[0] -eq 'text') {
        $httpListenerContext.Response.ContentEncoding = Get-ContentEncoding -Buffer ($buffer[0..3])
       }
       $logEntry = $item.FullName
   # IS DEFAULT DOCUMENT  END  #
      }
      elseif ($DirectoryListingAllowed) {
       $httpListenerContext.Response.StatusCode = [System.Net.HttpStatusCode]::OK
       $httpListenerContext.Response.StatusDescription = 'OK'
       $httpListenerContext.Response.ContentType = 'text/html'
       $httpListenerContext.Response.ContentEncoding = $DefaultContentEncoding
       $childItem = Get-ChildItem -Path $item | Select-Object -Property @('Mode', 'LastWriteTime', 'Length', @{n='Name'; e={'<a href="' + $_.Name + $(if ($_.PSIsContainer) {'/'}) + '">' + $_.Name + $(if ($_.PSIsContainer) {'/'}) + '</a>'}}) | Format-Table -AutoSize | Out-String
       $httpListenerResponseString = '<html><head><title>Directory listing for ' + [System.Net.WebUtility]::UrlDecode($httpListenerContext.Request.RawUrl) + '</title></head><body><pre>' + $childItem.Trim() + '</pre></body></html>'
#       $httpListenerResponseString = '<html><head><title>Directory listing for ' + [System.Net.WebUtility]::UrlDecode($httpListenerContext.Request.RawUrl) + '</title></head><body><pre>' + [System.Net.WebUtility]::HtmlEncode(($item.EnumerateFileSystemInfos() | Sort-Object -Property ('Mode', 'Name') | Format-Table | Out-String)) + '</pre></body></html>'
       $buffer = $httpListenerContext.Response.ContentEncoding.GetBytes($httpListenerResponseString)
       $logEntry = 'Directory listing for ' + $item.FullName
      }
      else {
       $httpListenerContext.Response.StatusCode = [System.Net.HttpStatusCode]::Forbidden
       $httpListenerContext.Response.StatusDescription = 'Directory listing forbidden'
       $httpListenerContext.Response.ContentType = 'text/html'
       $httpListenerContext.Response.ContentEncoding = $DefaultContentEncoding
       $httpListenerResponseString = '<html><head><title>403.14</title></head><body><h1>403.14 - Directory listing forbidden</h1></body></html>'
       $buffer = $httpListenerContext.Response.ContentEncoding.GetBytes($httpListenerResponseString)
       $logEntry = '403.14 - Directory listing forbidden for ' + $item.FullName
      }
  # IS DIRECTORY  END  #
     }
     else {
  # IS FILE BEGIN #
      $httpListenerContext.Response.StatusCode = [System.Net.HttpStatusCode]::OK
      $httpListenerContext.Response.StatusDescription = 'OK'
      $httpListenerContext.Response.ContentType = [System.Web.MimeMapping]::GetMimeMapping($item.FullName) # Only .NET 4.5+
      $buffer = [System.IO.File]::ReadAllBytes($item.FullName)
      if ($httpListenerContext.Response.ContentType.Split('/')[0] -eq 'text') {
       $httpListenerContext.Response.ContentEncoding = Get-ContentEncoding -Buffer ($buffer[0..3])
      }
      $logEntry = $item.FullName
  # IS FILE  END  #
     }
 ## EXISTS  END  ##
    }
    else {
 ## NOT FOUND BEGIN ##
     $httpListenerContext.Response.StatusCode = [System.Net.HttpStatusCode]::NotFound
     $httpListenerContext.Response.StatusDescription = 'Not Found'
     $httpListenerContext.Response.ContentType = 'text/html'
     $httpListenerContext.Response.ContentEncoding = $DefaultContentEncoding
     $httpListenerResponseString = '<html><head><title>404</title></head><body><h1>404 - Not found</h1></body></html>'
     $buffer = $httpListenerContext.Response.ContentEncoding.GetBytes($httpListenerResponseString)
     $logEntry = '404 - Not found for ' + (Join-Path -Path $BaseDirectory -ChildPath $path)
 ## NOT FOUND  END  ##
    }
   }
   catch {
 ## GENERAL ERROR CATCHING BEGIN ##

  # CAN NOT IMPERSONATE OR CAN NOT ACCESS ITEM BEGIN #
    $httpListenerContext.Response.StatusCode = [System.Net.HttpStatusCode]::Forbidden
    $httpListenerContext.Response.StatusDescription = 'Access forbidden'
    $httpListenerContext.Response.ContentType = 'text/html'
    $httpListenerContext.Response.ContentEncoding = $DefaultContentEncoding
    $httpListenerResponseString = '<html><head><title>403</title></head><body><h1>403 - Access forbidden</h1></body></html>' #403.2 = Read access forbidden
    $buffer = $httpListenerContext.Response.ContentEncoding.GetBytes($httpListenerResponseString)
    $logEntry = '403 - Access forbidden for ' + (Join-Path -Path $BaseDirectory -ChildPath $path)
  # CAN NOT IMPERSONATE OR CAN NOT ACCESS ITEM  END  #
 ## GENERAL ERROR CATCHING  END ##
   }
   finally {
    if ($impersonationContext) {
### UNDO IMPERSONATION OF CLIENT OR SERVER ACCOUNT BEGIN ###
     $impersonationContext.Undo()
### UNDO IMPERSONATION OF CLIENT OR SERVER ACCOUNT  END  ###
    }
   }

   $httpListenerContext.Response.KeepAlive = $false

### SET MIMETYPE BEGIN ###
   if ($item.Extension -and -not $httpListenerContext.Response.ContentType) {
    if ($mimeTypesHash.Contains($item.Extension)) {
     $httpListenerContext.Response.ContentType = $mimeTypesHash[$item.Extension]
    }
    else {
     $httpListenerContext.Response.ContentType = 'application/octet-stream'
    }
   }
### SET MIMETYPE  END  ###

### ENSURE CONTENTENCODING BEGIN ###
   if (-not $httpListenerContext.Response.ContentEncoding) {
    $httpListenerContext.Response.ContentEncoding = $DefaultContentEncoding
   }
### ENSURE CONTENTENCODING  END  ###

   try {
### SERVE CONTENT BEGIN ###
#    Write-HttpServerLog -Event 'Serving' -LogEntry $logEntry -HttpListenerContext $httpListenerContext -LogDateFormat $LogDateFormat
    $httpListenerContext.Response.ContentLength64 = $buffer.Length
    [System.IO.Stream]$outputStream = $httpListenerContext.Response.OutputStream
    $outputStream.Write($buffer, 0, $buffer.Length)
    $outputStream.Close()
    Write-HttpServerLog -Event 'Served' -LogEntry $logEntry -HttpListenerContext $httpListenerContext -LogDateFormat $LogDateFormat
### SERVE CONTENT  END  ###
   }
   catch {
    if ($_.Exception.InnerException.Message -eq 'The I/O operation has been aborted because of either a thread exit or an application request') {
     Write-HttpServerLog -Event 'Aborted' -LogEntry $logEntry -HttpListenerContext $httpListenerContext -LogDateFormat $LogDateFormat
    }
    else {
     $_
    }
   }

  }
  while (-not $MaxRequests -or ($requestCount -lt $MaxRequests)) # Lidt overflødig med Async og dermed Ctrl+C shutdown
 }
 catch {
  Write-Host $_ -ForegroundColor 'Red' -BackgroundColor 'Black'
 }
 finally {
  if ($httpListener.IsListening) {
   $httpListener.Stop()

   Write-HttpServerLog -Event 'ServerStopped' -LogDateFormat $LogDateFormat
  }
  $httpListener.Close()
 }

 $ErrorActionPreference = 'Continue'

 return $null
}

# Binding to hostnames + or * or to port 80 requires local admin!