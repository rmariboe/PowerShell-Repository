function Get-WindowsIdentity {
 param (
  [Parameter(Mandatory=$false)][AllowNull()][AllowEmptyString()][System.Management.Automation.PSCredential]$Credential = $null,
  [Parameter(Mandatory=$false)][AllowNull()][AllowEmptyString()][System.Security.Principal.WindowsIdentity]$WindowsIdentity = $null,
  [Parameter(Mandatory=$false)][System.Int32]$LogonType = 2, # 2 = LOGON32_LOGON_INTERACTIVE; 3 = LOGON32_LOGON_NETWORK
  [Parameter(Mandatory=$false)][System.Int32]$ImpersonationLevel = 2 # 0 = Anonymous; 1 = Identification; 2 = Impersonation; 3 = Delegation
 )

 $advapi32 = Add-Type -Name 'advapi32' -MemberDefinition @"
  // http://msdn.microsoft.com/en-us/library/aa378184.aspx
  [DllImport("advapi32.dll", SetLastError = true)]
  public static extern bool LogonUser(string lpszUsername, string lpszDomain, string lpszPassword, int dwLogonType, int dwLogonProvider, ref IntPtr phToken);

  [DllImport("advapi32.dll", SetLastError=true)]
  public extern static bool DuplicateToken(IntPtr ExistingTokenHandle, int SECURITY_IMPERSONATION_LEVEL, out IntPtr DuplicateTokenHandle);
"@ -PassThru

 if ($WindowsIdentity) {
  [System.IntPtr]$userToken = $WindowsIdentity.Token
 }
 else {
  [System.IntPtr]$userToken = [Security.Principal.WindowsIdentity]::GetCurrent().Token
 }
 [System.IntPtr]$userTokenDuplicate = [System.IntPtr]::new(0)

 if ($Credential) {
  $userName = $Credential.GetNetworkCredential().UserName
  $domain = $Credential.GetNetworkCredential().Domain
  $password = $Credential.GetNetworkCredential().Password
  $logonProvider = 0			# 0 = LOGON32_PROVIDER_DEFAULT

  if(!$advapi32::LogonUser($userName, $domain, $password, $LogonType, $logonProvider, [ref]$userToken)) {
   throw (New-Object System.ComponentModel.Win32Exception([System.Runtime.InteropServices.Marshal]::GetLastWin32Error()))
  }
 }

 if (!$advapi32::DuplicateToken($userToken, $ImpersonationLevel, [ref]$userTokenDuplicate)) {
  throw (New-Object System.ComponentModel.Win32Exception([System.Runtime.InteropServices.Marshal]::GetLastWin32Error()))
 }

 return [Security.Principal.WindowsIdentity]$userTokenDuplicate
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
   if(-not ($httpListenerContextIdentityName = $HttpListenerContext.User.Identity.Name)) {
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
  [Parameter(Mandatory=$false)][System.Text.Encoding]$DefaultContentEncoding = [System.Text.Encoding]::Default, # [System.Text.Encoding]::Unicode, # [System.Text.Encoding]::ASCII,
  [Parameter(Mandatory=$false)][System.Management.Automation.PSCredential]$ContentAccessCredential = $null,
  [Parameter(Mandatory=$false)][string]$LogDateFormat = 'yyyy-MM-dd HH:mm:ss',
  [Parameter(Mandatory=$false)][string]$MimeTypesCsvPath = $null,
  [Parameter(Mandatory=$false)][int]$MaxRequests = $null,
  [Parameter(Mandatory=$false)][switch]$OpenFirewall = $true
#  $SSL STUFF
 )

 Add-Type -AssemblyName 'System.Web' # For [System.Web.MimeMapping] (.NET 4.5 only!)
 try {
  $null = [System.Web.MimeMapping]
  $getMimeMappingAvailable = $true
 }
 catch {
  $getMimeMappingAvailable = $false
 }

 $ErrorActionPreference = 'Stop'

 $ContentAccessIdentity = Get-WindowsIdentity -Credential $ContentAccessCredential

### GET MIMETYPES BEGIN ###
 $mimeTypesHash = New-Object -TypeName 'System.Collections.Hashtable'

 if ($MimeTypesCsvPath) {
  Write-Verbose "Importing MIME types from $MimeTypesCsvPath..."

#  $mimeTypesHash = New-Object -TypeName 'System.Collections.Hashtable'
  $mimeTypes = Import-Csv -Path $MimeTypesCsvPath -Delimiter ';'
  foreach ($mimeType in $mimeTypes) {
   try {
    $null = $mimeTypesHash.Add($mimeType.Extension, $mimeType.MIMEType)
   }
   catch {}
  }
 }
 else {
  $mimeTypeUrl = 'http://svn.apache.org/viewvc/httpd/httpd/trunk/docs/conf/mime.types?view=co'

  Write-Verbose ("Importing MIME types from $mimeTypeUrl...")

  try {
   $mimeTypesList = (Invoke-WebRequest $mimeTypeUrl).Content
   $mimeTypesListArray = $mimeTypesList.Split("`n").Trim() | Where-Object {$_ -and -not $_.StartsWith('#')}
   foreach ($mimeTypeEntry in $mimeTypesListArray) {
    $mimeTypeEntrySplit = $mimeTypeEntry.Split("`t")
    $mimeTypeEntryName = $mimeTypeEntrySplit[0]
    $mimeTypeEntryExts = $mimeTypeEntrySplit[-1]
    $mimeTypeEntryExtsSplit = $mimeTypeEntryExts.Split(' ')
    foreach ($mimeTypeEntryExt in $mimeTypeEntryExtsSplit) {
     if ($mimeTypeEntryExt -and -not $mimeTypesHash.ContainsKey($mimeTypeEntryExt)) {
      $mimeTypesHash.Add($mimeTypeEntryExt, $mimeTypeEntryName)
     }
     else {
      Write-Verbose (' Skipping ' + $mimeTypeEntryName + ' - ' + $mimeTypeEntryExt + ' already exists: ' + $mimeTypesHash[$mimeTypeEntryExt])
     }
    }
   }
  }
  catch {
   Write-Error ("Failed to import MIME types from $mimeTypeUrl")
   Write-Error $_
  }
 }

 Write-Verbose ('Imported ' + $mimeTypesHash.Count + ' MIME types.')
### GET MIMETYPES  END  ###

### OPEN FIREWALL BEGIN ###

 if ($OpenFirewall) {
  $displayName = 'Allow Tiny HTTP Server'
  $localPort = [System.Int32[]]@()
  foreach ($binding in $Bindings) {
   $localPort += ,[System.Int32]($binding.Split(':')[-1].Split('/')[0])
  }
  $protocol = 'TCP'
  $remoteAddress = 'LocalSubnet'

  Write-Verbose ('Creating firewall rule "' + $displayName + '" for port(s) ' + [System.String]::Join(',', $localPort))

  $netFirewallRule = New-NetFirewallRule -DisplayName $displayName -Direction 'Inbound' -Protocol $protocol -LocalPort $localPort -RemoteAddress $remoteAddress -Action 'Allow'
 }

### OPEN FIREWALL  END  ###

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
    $bindingUri = [System.Uri]($binding.Replace('://*', '://localhost').Replace('://+', '://localhost')) # Only for host; allowed in path!
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
    try {
### IMPERSONATE CLIENT OR SERVER ACCOUNT BEGIN ###
     if ($httpListenerContext.User.Identity) {
      if ($httpListenerContext.User.Identity.Impersonate) {
       $windowsIdentity = $httpListenerContext.User.Identity
      }
      elseif ($httpListenerContext.User.Identity.Name -and $httpListenerContext.User.Identity.Password) {
       $userName = $httpListenerContext.User.Identity.Name
       $password = ConvertTo-SecureString -String $httpListenerContext.User.Identity.Password -AsPlainText -Force
       $psCredential = [System.Management.Automation.PSCredential]::new($userName, $password)
       $windowsIdentity = Get-WindowsIdentity -Credential $psCredential
      }
      else {
       Write-Warning -Message ('User identity provided in call but cannot figure out how to handle it')
       $windowsIdentity = $ContentAccessIdentity
      }
     }
     elseif ($ContentAccessIdentity) {
      $windowsIdentity = $ContentAccessIdentity
     }
     else {
      $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
     }
     $impersonationContext = $windowsIdentity.Impersonate()
     Write-Verbose ('Impersonating ' + [System.Security.Principal.WindowsIdentity]::GetCurrent($true).Name)
    }
    catch {
     Write-Verbose ('Impersonation of ' + [System.Security.Principal.WindowsIdentity]::GetCurrent($true).Name + " failed:`n" + $_)
     throw $_
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
   # IS DEFAULT DOCUMENT  END  #
      }
      elseif ($DirectoryListingAllowed) {
   # LIST DIRECTORY BEGIN #
       $httpListenerContext.Response.StatusCode = [System.Net.HttpStatusCode]::OK
       $httpListenerContext.Response.StatusDescription = 'OK'
       $httpListenerContext.Response.ContentType = 'text/html'
       $httpListenerContext.Response.ContentEncoding = $DefaultContentEncoding
       $childItem = Get-ChildItem -Path $item | Select-Object -Property @('Mode', 'LastWriteTime', 'Length', @{n='Name'; e={'<a href="' + $_.Name + $(if ($_.PSIsContainer) {'/'}) + '">' + $_.Name + $(if ($_.PSIsContainer) {'/'}) + '</a>'}}) | Format-Table -AutoSize | Out-String
       $httpListenerResponseString = '<html><head><title>Directory listing for ' + [System.Net.WebUtility]::UrlDecode($httpListenerContext.Request.RawUrl) + '</title></head><body><pre>' + $childItem.Trim() + '</pre></body></html>'
#       $httpListenerResponseString = '<html><head><title>Directory listing for ' + [System.Net.WebUtility]::UrlDecode($httpListenerContext.Request.RawUrl) + '</title></head><body><pre>' + [System.Net.WebUtility]::HtmlEncode(($item.EnumerateFileSystemInfos() | Sort-Object -Property ('Mode', 'Name') | Format-Table | Out-String)) + '</pre></body></html>'
       $buffer = $httpListenerContext.Response.ContentEncoding.GetBytes($httpListenerResponseString)
       $logEntry = 'Directory listing for ' + $item.FullName
   # LIST DIRECTORY  END  #
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

     if (-not $item.PSIsContainer) {
  # IS FILE BEGIN #
      if ($item.Extension -eq '.ps1') {
   # IS POWERSHELL SCRIPT BEGIN #
       $variables = New-Object -TypeName 'System.Collections.Hashtable'
       $queryDelimiters = [System.Char[]](@('&'))
       if ($httpListenerContext.Request.Url.Query) {
        foreach ($variable in $httpListenerContext.Request.Url.Query.Substring(1).Split($queryDelimiters)) {
         $equalsIndex = $variable.IndexOf('=')
         $variableName = [System.Uri]::UnescapeDataString($variable.Substring(0, $equalsIndex))
         $variableValue = [System.Uri]::UnescapeDataString($variable.Substring($equalsIndex + 1))
         $variables.Add($variableName, $variableValue)
        }
       }

       Write-Verbose ('Executing ' + $item + ($variables.Keys | ForEach-Object {' -' + $_ + ' ''' + $variables[$_] + ''''}))

    # EXECUTE PS1 BEGIN #
       $executionPolicy = Get-ExecutionPolicy
       Set-ExecutionPolicy -ExecutionPolicy 'Bypass' -Scope 'Process' -Force
       $result = .$item @variables
       Set-ExecutionPolicy -ExecutionPolicy $executionPolicy -Scope 'Process' -Force
    # EXECUTE PS1  END  #

       if ($result.GetType() -ne [System.Collections.Hashtable]) {
        $result = @{'Data' = $result}
       }

       if ($result.StatusCode) {
        $httpListenerContext.Response.StatusCode = [System.Net.HttpStatusCode]($result.StatusCode)
       }
       else {
        $httpListenerContext.Response.StatusCode = [System.Net.HttpStatusCode]::OK
       }

       if ($result.StatusDescription) {
        $httpListenerContext.Response.StatusDescription = $result.StatusDescription
       }
       else {
        $httpListenerContext.Response.StatusDescription = 'OK'
       }

       if ($result.ContentType) {
        $httpListenerContext.Response.ContentType = $result.ContentType
       }
       else {
        if ($getMimeMappingAvailable) {
         $httpListenerContext.Response.ContentType = [System.Web.MimeMapping]::GetMimeMapping('.htm') # Only .NET 4.5+
        }
        else {
         if ($mimeTypesHash.Contains($item.Extension)) {
          $httpListenerContext.Response.ContentType = $mimeTypesHash[$item.Extension]
         }
         else {
          $httpListenerContext.Response.ContentType = 'application/octet-stream'
         }
        }
       }

       if ($result.ContentEncoding) {
        $httpListenerContext.Response.ContentEncoding = $result.ContentEncoding
       }
       else {
        $httpListenerContext.Response.ContentEncoding = $DefaultContentEncoding
       }

       $verboseOutput = [System.String]::Empty
       if ($result.Data) {
        if ($result.Data.GetType() -eq [System.Byte[]]) {
         $buffer = $result.Data

         $verboseOutput = " Returned " + $result.Data.Length.ToString() + ' bytes'
        }
        else {
         $buffer = $httpListenerContext.Response.ContentEncoding.GetBytes($result.Data)

         $verboseData = $result.Data | Out-String
         $verboseDataMaxLength = 150
         $verboseOutput = if ($verboseData.Length -gt $verboseDataMaxLength) {
          $verboseData.SubString(0, $verboseDataMaxLength) + ' (...)'
         }
         else {
          $verboseOutput = " Returned`n" + $verboseData
         }
        }
       }

       Write-Verbose ($verboseOutput)

#       if ($httpListenerContext.Response.ContentType.Split('/')[0] -eq 'text') {
#        $httpListenerContext.Response.ContentEncoding = Get-ContentEncoding -Buffer ($buffer[0..3])
#       }
   # IS POWERSHELL SCRIPT  END  #
      }
      else {
   # IS REGULAR FILE BEGIN #
       $httpListenerContext.Response.StatusCode = [System.Net.HttpStatusCode]::OK
       $httpListenerContext.Response.StatusDescription = 'OK'
       if ($getMimeMappingAvailable) {
        $httpListenerContext.Response.ContentType = [System.Web.MimeMapping]::GetMimeMapping($item.FullName) # Only .NET 4.5+
       }
       else {
        if ($mimeTypesHash.Contains($item.Extension)) {
         $httpListenerContext.Response.ContentType = $mimeTypesHash[$item.Extension]
        }
        else {
         $httpListenerContext.Response.ContentType = 'application/octet-stream'
        }
       }
       $buffer = [System.IO.File]::ReadAllBytes($item.FullName)
       if ($httpListenerContext.Response.ContentType.Split('/')[0] -eq 'text') {
        $httpListenerContext.Response.ContentEncoding = Get-ContentEncoding -Buffer ($buffer[0..3])
       }
   # IS REGULAR FILE  END  #
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
    Write-Verbose ("General error catch:`n" + $_)

  # INTERNAL SERVER ERROR BEGIN #
    $httpListenerContext.Response.StatusCode = [System.Net.HttpStatusCode]::InternalServerError
    $httpListenerContext.Response.StatusDescription = 'Internal server error'
    $httpListenerContext.Response.ContentType = 'text/html'
    $httpListenerContext.Response.ContentEncoding = $DefaultContentEncoding
    $httpListenerResponseString = '<html><head><title>403</title></head><body><h1>500 - Internal server error</h1></body></html>'
    $buffer = $httpListenerContext.Response.ContentEncoding.GetBytes($httpListenerResponseString)
    $logEntry = '500 - Internal server error for ' + (Join-Path -Path $BaseDirectory -ChildPath $path)
  # INTERNAL SERVER ERROR  END  #
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

### ENSURE MIMETYPE BEGIN ###
   if ($item.Extension -and -not $httpListenerContext.Response.ContentType) {
    if ($getMimeMappingAvailable) {
     $httpListenerContext.Response.ContentType = [System.Web.MimeMapping]::GetMimeMapping($item.Extension) # Only .NET 4.5+
    }
    else {
     if ($mimeTypesHash.Contains($item.Extension)) {
      $httpListenerContext.Response.ContentType = $mimeTypesHash[$item.Extension]
     }
     else {
      $httpListenerContext.Response.ContentType = 'application/octet-stream'
     }
    }
   }
### ENSURE MIMETYPE  END  ###

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
  if ($netFirewallRule) {
   Write-Verbose ('Removing firewall rule "' + $displayName + '"')

   $netFirewallRule | Remove-NetFirewallRule
  }

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
#Start-HTTPServer -Bindings ('http://' + $env:COMPUTERNAME + ':800/') -BaseDirectory '~\httpAppTest' -DefaultDocument 'Get-Memory.htm' -MaxRequests 5 -Verbose  -AuthenticationSchemes Basic -MimeTypesCsvPath '~\Desktop\httpAppTest\MimeTypes.csv'

#$ipAddress = (Get-NetIPAddress -AddressFamily 'IPv4' -AddressState 'Preferred' | Where-Object {$_.InterfaceAlias -notlike 'Loopback*'})[0].IPAddress
#Start-HTTPServer -Bindings ('http://' + $ipAddress + ':800/') -BaseDirectory '~\Desktop\httpAppTest' -DefaultDocument 'Get-MemoryHTML.ps1' -Verbose  -AuthenticationSchemes Basic

#Set-Location -Path '~\Desktop\httpAppTest'
#Start-HTTPServer -Verbose

Start-HTTPServer -Bindings ('http://*:80/') -BaseDirectory '~\Desktop\httpAppTest' -Verbose