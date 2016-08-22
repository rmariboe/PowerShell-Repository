."$PSScriptRoot\Decompress-Object.ps1"
(Decompress-Base64StringToObject -String (Get-Content -Path "$PSScriptRoot\Invoke-TokenManipulation v1.11.zip64.txt")).Invoke()


function Initiate-ChildProcess {
 [CmdletBinding()]
 param(
  [System.String]$PipeName = 'pipe_' + [System.Guid]::NewGuid().Guid,
  [System.String]$ServerAddress = $null, # $env:COMPUTERNAME
  [System.Diagnostics.ProcessWindowStyle]$WindowStyle = 'Normal', #Hidden, Maximized, Minimized, Normal
  [System.Management.Automation.SwitchParameter]$NoExit = $false,
  [System.Object]$Impersonate = $null # Get-Service -Name 'Windows Modules Installer'
 )

 $filePath = "$PSHOME\powershell.exe"

 $argumentList = [System.String]::Empty
 if ($NoExit) {
  $argumentList += "-NoExit "
 }
 if ($WindowStyle -ne [System.Diagnostics.ProcessWindowStyle]::Normal) {
  $argumentList += "-WindowStyle $WindowStyle "
 }
 $argumentList += "`$n='$PipeName'`n"
 if ($ServerAddress) {
  $argumentList += "`$a='$ServerAddress'`n"
  $argumentList += "`$p=New-Object System.IO.Pipes.NamedPipeClientStream (`$a,`$n,'In')`n"
 }
 else {
  $argumentList += "`$p=[System.IO.Pipes.NamedPipeClientStream](`$n)`n"
 }
 $argumentList += "`$p.Connect()`n"
 $argumentList += "`$s=''`n"
 $argumentList += "while(!`$p.IsConnected) {Write-Progress ('Connecting to ' + `$n);Start-Sleep -Milliseconds 10}`n"
 $argumentList += "while((`$b=`$p.ReadByte()) -notin (4,-1)){`$s+=[char]`$b}`n"
 $argumentList += "`$p.Close()`n"
 $argumentList += "`$p.Dispose()`n"
 if ($PSBoundParameters['Verbose']) {
  $argumentList += "Write-Host 'Invoke:' -ForegroundColor 'Cyan'`n"
  $argumentList += "Write-Host `$s -ForegroundColor 'Yellow'`n"
 }
 $argumentList += ". ([scriptblock]::Create(`$s))" # Dot-source script (return all variables)

 if (($filePath.Length + 1 + $argumentList.Length) -gt 1023) {
  Write-Warning ('Call length greater than 1023 chars')
 }

 Write-Host ("Starting process $filePath") -NoNewLine -ForegroundColor 'Cyan'
 if ($Impersonate) {
  Write-Host (' as ') -NoNewLine -ForegroundColor 'Cyan'
  if ($Impersonate.UserName) {
   Write-Host ($Impersonate.UserName) -NoNewLine -ForegroundColor 'Cyan'
  }
  else {
   Write-Host ($Impersonate.ToString()) -NoNewLine -ForegroundColor 'Cyan'
  }
 }
 if ($PSBoundParameters['Verbose']) {
  Write-Host (' with ArgumentList:') -ForegroundColor 'Cyan'
  Write-Host ("$argumentList") -NoNewLine -ForegroundColor 'Magenta'
 }
 Write-Host
 if ($Impersonate) {
  switch ($Impersonate.GetType().FullName) {
   'System.ServiceProcess.ServiceController' {
    $serviceName = $Impersonate.Name
    $serviceStatus = $Impersonate.Status
    if ($Impersonate.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running) {
     $serviceStopped = $true
     if ($PSBoundParameters['Verbose']) {
      Write-Host ('Starting service ' + $Impersonate.DisplayName) -ForegroundColor 'Cyan'
     }
     Start-Service -InputObject $Impersonate
     while (-not ($processId = (Get-WmiObject -Class 'Win32_Service' -Filter "Name='$serviceName'" -Property 'ProcessId').ProcessId)) {
      Write-Progress -Activity ('Starting ' + $Impersonate.DisplayName) -Status 'Waiting'
      Start-Sleep -Milliseconds 1
     }
    }
    if ($PSBoundParameters['Verbose']) {
     Write-Host ($Impersonate.DisplayName + " is running - starting process $filePath as " + $Impersonate.ToString()) -ForegroundColor 'Cyan'
    }
    $process = Invoke-TokenManipulation -CreateProcess $filePath -ProcessId $processId -ProcessArgs $argumentList -PassThru
    if ($serviceStatus -eq [System.ServiceProcess.ServiceControllerStatus]::Stopped) {
     if ($PSBoundParameters['Verbose']) {
      Write-Host ('Stopping service ' + $Impersonate.DisplayName) -ForegroundColor 'Cyan'
     }
     Stop-Service -InputObject $Impersonate
    }
   }
   'System.Diagnostics.Process' {
    $process = Invoke-TokenManipulation -CreateProcess $filePath -Process $Impersonate -ProcessArgs $argumentList -PassThru
   }
   'System.Int32' {
    $process = Invoke-TokenManipulation -CreateProcess $filePath -ProcessId $Impersonate -ProcessArgs $argumentList -PassThru
   }
   'System.String' {
    $process = Invoke-TokenManipulation -CreateProcess $filePath -UserName $Impersonate -ProcessArgs $argumentList -PassThru
   }
   'System.Management.Automation.PSCredential' {
    $process = Start-Process -FilePath $filePath -ArgumentList $argumentList -Credential $Impersonate -PassThru
   }
   default {
    throw ('Type ' + $_.FullName + ' not supported')
   }
  }
 }
 else {
  $process = Start-Process -FilePath $filePath -ArgumentList $argumentList -PassThru
 }

 if($PSBoundParameters['Verbose']) {
  Write-Host ("New NamedPipeServerStream $PipeName") -ForegroundColor 'Cyan'
 }
 $namedPipeServerStream = [System.IO.Pipes.NamedPipeServerStream]($PipeName)

 return $namedPipeServerStream
}


function Boot-ChildProcess {
 [CmdletBinding()]
 param (
  [System.IO.Pipes.NamedPipeServerStream]$PipeStream,
  [System.Management.Automation.ScriptBlock]$RemoteInvocation = {},
  [System.Management.Automation.SwitchParameter]$ReturnHostBufferOnExit = $false
 )

 if($PSBoundParameters['Verbose']) {
  Write-Host ('WaitForConnection') -ForegroundColor 'Cyan'
 }
 $PipeStream.WaitForConnection()
 if($PSBoundParameters['Verbose']) {
  Write-Host ('(Established)') -ForegroundColor 'Cyan'
 }

 [System.String[]]$remoteScripts = @()

 $remoteScripts += @'
  function Connect-Parent {
   [CmdletBinding()]
   param (
    $PipeName = $n
   )

   Write-Host ("New NamedPipeClientStream $PipeName") -ForegroundColor 'Cyan'
   $pipeStream = [System.IO.Pipes.NamedPipeClientStream]($PipeName)

   Write-Host ('Connect') -ForegroundColor 'Cyan'
   $pipeStream.Connect()

   if ($pipeStream.IsConnected) {
    Write-Host ('(Established)') -ForegroundColor 'Cyan'
   }
   else {
    Write-Error ("Could not connect to Named Pipe '$PipeName'")
   }

   return $pipeStream
  }
'@

 $remoteScripts += @'
  function global:Write-Parent {
   [CmdletBinding()]
   param (
    [Parameter(ValueFromPipeline=$true)][Alias('Object')][System.Object]$InputObject = $null,
    [ValidateSet('Binary','Text')][System.String]$Mode = 'Binary'
   )

   begin {
    [System.IO.Pipes.NamedPipeClientStream]$pipeStream = $ParentStream
   }

   process {
    if (-not $ParentStream.IsConnected) {
     Write-Warning ('No connection to parent process')
     return $null
    }
#    foreach ($Object in $InputObject) {
    if ($Object = $InputObject) {
     switch ($Mode) {
      'Binary' {
       try {
        [System.IO.Stream]$SerializationStream = (New-Object -TypeName 'System.IO.MemoryStream')
        [System.Object]$graph = $Object
        [System.Runtime.Serialization.Formatters.Binary.BinaryFormatter]$binaryFormatter = New-Object -TypeName 'System.Runtime.Serialization.Formatters.Binary.BinaryFormatter'
        [System.Void]$binaryFormatter.Serialize([System.IO.Stream]$SerializationStream, [System.Object]$graph)
        [System.Byte[]]$serializedBuffer = $serializationStream.GetBuffer()
        [System.Void]$serializationStream.Close()

        if ($PSBoundParameters['Verbose']) {
         Write-Host ('WriteByte: ') -NoNewLine -ForegroundColor 'Cyan' -ChildOnly
         Write-Host (' DLE ') -BackgroundColor 'Magenta' -ChildOnly
        }
        $pipeStream.WriteByte(16)

        [System.UInt32]$serializedBufferLengthBufferLength = [System.UInt32]$serializedBuffer.Count
        [System.Byte[]]$serializedBufferLengthBuffer = [System.BitConverter]::GetBytes([System.UInt32]$serializedBuffer.Count)
        [System.Int32]$serializedBufferLengthBufferOffset = 0

        if ($PSBoundParameters['Verbose']) {
         Write-Host ('Serialized Buffer Length Buffer Length: ') -NoNewLine -ForegroundColor 'Cyan' -ChildOnly
         Write-Host $serializedBufferLengthBufferLength -ForegroundColor 'Magenta' -ChildOnly
         Write-Host ('Write: ') -NoNewLine -ForegroundColor 'Cyan' -ChildOnly
         Write-Host $serializedBufferLengthBuffer -ForegroundColor 'Magenta' -ChildOnly
        }
        $pipeStream.Write([System.Byte[]]$serializedBufferLengthBuffer, [System.Int32]$serializedBufferLengthBufferOffset, [System.Int32]$serializedBufferLengthBuffer.Count)

        [System.Int32]$serializedBufferOffset = 0

#        if ($PSBoundParameters['Verbose']) {
#         Write-Host ('Write: ') -NoNewLine -ForegroundColor 'Cyan' -ChildOnly
#         Write-Host $serializedBuffer -ForegroundColor 'Magenta' -ChildOnly
#        }
        $pipeStream.Write([System.Byte[]]$serializedBuffer, [System.Int32]$serializedBufferOffset, [System.Int32]$serializedBuffer.Count)
       }
       catch {
        throw $_
       }
      }
      'Text' {
       [System.Byte[]]$buffer = [System.Char[]]($Object.ToString())

       if ($PSBoundParameters['Verbose']) {
        Write-Host ('WriteByte: ') -NoNewLine -ForegroundColor 'Cyan' -ChildOnly
        Write-Host (' STX ') -BackgroundColor 'Magenta' -ChildOnly
       }
       $pipeStream.WriteByte(2)

       if ($PSBoundParameters['Verbose']) {
        Write-Host ('Write: ') -NoNewLine -ForegroundColor 'Cyan' -ChildOnly
        Write-Host $Object -NoNewLine -ForegroundColor 'Magenta' -ChildOnly
       }
       $pipeStream.Write($buffer, 0, $buffer.Count)

       $NoNewLine = $true
       if (-not $NoNewLine) {
        if ($PSBoundParameters['Verbose']) {
         Write-Host ('WriteByte: ') -NoNewLine -ForegroundColor 'Cyan' -ChildOnly
         Write-Host (' CR ') -BackgroundColor 'Magenta' -ChildOnly
        }
        $pipeStream.WriteByte(13)

        if ($PSBoundParameters['Verbose']) {
         Write-Host ('WriteByte: ') -NoNewLine -ForegroundColor 'Cyan' -ChildOnly
         Write-Host (' LF ') -BackgroundColor 'Magenta' -ChildOnly
        }
        $pipeStream.WriteByte(10)
       }

       if ($PSBoundParameters['Verbose']) {
        Write-Host ('WriteByte: ') -NoNewLine -ForegroundColor 'Cyan' -ChildOnly
        Write-Host (' ETX ') -BackgroundColor 'Magenta' -ChildOnly
       }
       $pipeStream.WriteByte(3)
      }
      default {
      }
     }
    }
   }

   end {
    return $null
   }
  }
'@

 $remoteScripts += @'
  function global:Disconnect-Parent {
   [CmdletBinding()]
   param (
   )
   [System.IO.Pipes.NamedPipeClientStream]$pipeStream = $ParentStream

   if ($PSBoundParameters['Verbose']) {
    Write-Host ('WriteByte: ') -NoNewLine -ForegroundColor 'Cyan' -ChildOnly
    Write-Host (' EOT ') -BackgroundColor 'Magenta' -ChildOnly
   }
   $pipeStream.WriteByte(4)

   Write-Host ('Close') -ForegroundColor 'Cyan' -ChildOnly
   $pipeStream.Close()

   if ($PSBoundParameters['Verbose']) {
    Write-Host ('Dispose') -ForegroundColor 'Cyan' -ChildOnly
   }
   $pipeStream.Dispose()
  }
'@

### Scroll-BufferContents ###
 $remoteScripts += @'
  function global:Scroll-BufferContents {
   param (
    [System.Int32]$Lines = 1
   )

   [System.Management.Automation.Host.Coordinates]$cursorPosition = $host.UI.RawUI.CursorPosition
   try {
    $host.UI.RawUI.CursorPosition = @{X=$cursorPosition.X; Y=$cursorPosition.Y-$Lines}
   }
   catch {}

   $source = New-Object -TypeName 'System.Management.Automation.Host.Rectangle'
   $source.Left = $host.UI.RawUI.WindowPosition.X
   $source.Top = $host.UI.RawUI.WindowPosition.Y
   $source.Right = $host.UI.RawUI.WindowPosition.X + $Host.UI.RawUI.BufferSize.Width - 1
   $source.Bottom = $host.UI.RawUI.WindowPosition.Y + $Host.UI.RawUI.BufferSize.Height - 1

   $destination = New-Object -TypeName 'System.Management.Automation.Host.Coordinates'
   $destination = $host.UI.RawUI.WindowPosition
   $destination.Y -= $Lines

   $clip = New-Object -TypeName 'System.Management.Automation.Host.Rectangle'
   $clip = $source

   [System.Char]$character = ' '
   [System.ConsoleColor]$foregroundColor = $Host.UI.RawUI.ForegroundColor
   [System.ConsoleColor]$backgroundColor = $Host.UI.RawUI.BackgroundColor
   [System.Management.Automation.Host.BufferCellType]$bufferCellType = [System.Management.Automation.Host.BufferCellType]::Complete
   $fill = New-Object -TypeName 'System.Management.Automation.Host.BufferCell' -ArgumentList ([System.Char]$character, [System.ConsoleColor]$foregroundColor, [System.ConsoleColor]$backgroundColor, [System.Management.Automation.Host.BufferCellType]$bufferCellType)

   [System.Void]$host.UI.RawUI.ScrollBufferContents(
    [System.Management.Automation.Host.Rectangle]$source,
    [System.Management.Automation.Host.Coordinates]$destination,
    [System.Management.Automation.Host.Rectangle]$clip,
    [System.Management.Automation.Host.BufferCell]$fill
   )
  }
'@

### Get-HostContent ###
 $remoteScripts += @'
  function global:Get-HostContent {
   param (
    [switch]$Absolute = $false,
    [int]$Left = 0,
    [int]$Top = 0,
    [int]$Width = $(if($Absolute) {$host.UI.RawUI.BufferSize.Width-$Left} else {$host.UI.RawUI.WindowSize.Width-$Left}),
    [int]$Height = $(if($Absolute) {$host.UI.RawUI.BufferSize.Height-$Top} else {$host.UI.RawUI.WindowSize.Height-$Top}),
    [switch]$Echo
   )

   if (-not $Absolute) {
    $Left += $host.UI.RawUI.WindowPosition.X
    $Top += $host.UI.RawUI.WindowPosition.Y
   }
   $right = $Left + $Width - 1
   $bottom = $Top + $Height - 1

   $rectangle = New-Object -TypeName 'System.Management.Automation.Host.Rectangle' -ArgumentList ($Left, $Top, $right, $bottom)
   $bufferContents = $host.UI.RawUI.GetBufferContents($rectangle)

   $printBufferContent = {
    [System.Management.Automation.Host.Coordinates]$origin = $host.UI.RawUI.CursorPosition
    [System.Int32]$rectangleHeight = $this.Rectangle.Bottom - $this.Rectangle.Top + 1
    if (($origin.Y + $rectangleHeight) -gt $host.UI.RawUI.BufferSize.Height) {
     [System.Int32]$scrollLines = $host.UI.RawUI.CursorPosition.Y + $rectangleHeight - $host.UI.RawUI.BufferSize.Height
     $null = Scroll-BufferContents -Lines $scrollLines
     [System.Int32]$origin.Y = $host.UI.RawUI.BufferSize.Height - $rectangleHeight
    }
    [System.Management.Automation.Host.BufferCell[,]]$contents = $this.BufferContents
    [System.Void]$host.UI.RawUI.SetBufferContents([System.Management.Automation.Host.Coordinates]$origin, [System.Management.Automation.Host.BufferCell[,]]$contents)
    [System.Int32]$cursorPositionY = $origin.Y + $rectangleHeight - 1
    [System.Int32]$cursorPositionX = $origin.X
    $host.UI.RawUI.CursorPosition = @{X=$cursorPositionX; Y=$cursorPositionY}
    return $null
   }

   $toString = {
    [System.String[]]$lines = @()
    for ($x=0; $x -lt $this.Rectangle.Bottom-$this.Rectangle.Top; $x++) {
     [System.String]$line = [System.String]::Empty
     for ($y=0; $y -lt $this.Rectangle.Right-$this.Rectangle.Left; $y++) {
      $line += $this.BufferContents[$x,$y].Character
     }
     $lines += $line
    }
    return ($lines -join "`n")
   }

   $defaultProperties = @('Rectangle','BufferContents')
   $defaultDisplayPropertySet = New-Object -TypeName 'System.Management.Automation.PSPropertySet' -ArgumentList ([System.String]'DefaultDisplayPropertySet', [System.String[]]$defaultProperties)
   $psStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)

   $bufferObject = New-Object -TypeName 'System.Management.Automation.PSObject'
   $bufferObject | Add-Member -MemberType 'NoteProperty' -Name 'Rectangle' -Value $rectangle -TypeName 'System.Management.Automation.Host.Rectangle'
   $bufferObject | Add-Member -MemberType 'NoteProperty' -Name 'BufferContents' -Value $bufferContents -TypeName 'System.Management.Automation.Host.BufferCell[,]'
   $bufferObject | Add-Member -MemberType 'ScriptMethod' -Name 'PrintBufferContents' -Value $printBufferContent -TypeName 'System.Void'
   $bufferObject | Add-Member -MemberType 'ScriptMethod' -Name 'ToString' -Value $toString -TypeName 'System.String' -Force
   $bufferObject | Add-Member -MemberType 'MemberSet' -Name 'PSStandardMembers' -Value $psStandardMembers -TypeName 'System.Management.Automation.PSMemberInfo[]'
   $bufferObject.psobject.TypeNames.Insert(0,'System.Management.Automation.Host.PSHostRawUserInterface.BufferContent')

   if ($Echo) {
    $bufferObject.PrintBufferContents()
   }

   return $bufferObject
  }
'@

### Setup variables, events ###
 $remoteScripts += @'
  [System.IO.Pipes.NamedPipeClientStream]$pipeStream = Connect-Parent -PipeName $n
  Set-Variable -Name 'ParentStream' -Value $pipeStream -Description 'PipeStream to parent process' -Option 'Constant' -Scope 'Global'
  $powerShellExitingEvent = Register-EngineEvent -SourceIdentifier 'PowerShell.Exiting' -Action {Disconnect-Parent}
'@

### Write instructions to screen ###
 $remoteScripts += @'
  Write-Host -Object 'The following new functions and variable have been exposed: ' -NoNewLine -ForegroundColor 'Cyan'
  Write-Host -Object 'Write-Parent, Disconnect-Parent, $ParentStream' -ForegroundColor 'Yellow'
  Write-Host -Object 'The following functions have been extended with redirects to parent process: ' -NoNewLine -ForegroundColor 'Cyan'
  Write-Host -Object 'Write-Host, Write-Output' -ForegroundColor 'Yellow'
'@

### Write-Host override ###
 $remoteScripts += @'
#  $writeHostParameters = (Get-Command -Name 'Write-Host').Parameters.Values | Where-Object {$_.Name -notin [System.Management.Automation.Internal.CommonParameters].GetProperties().Name}
  function global:Write-Host {
   [CmdletBinding()]
   param (
    [System.Object]$Object = [System.String]::Empty,
    [System.Management.Automation.SwitchParameter]$NoNewline = $false,
    [System.Object]$Separator = ' ',
    [System.ConsoleColor]$ForegroundColor = $host.UI.RawUI.ForegroundColor,
    [System.ConsoleColor]$BackgroundColor = $host.UI.RawUI.BackgroundColor,
    [System.Management.Automation.SwitchParameter]$ChildOnly = $
'@ + $ReturnHostBufferOnExit.ToString() + @'
   )

<#   DynamicParam {
    $runtimeDefinedParameterDictionary = New-Object -TypeName 'System.Management.Automation.RuntimeDefinedParameterDictionary'
    $parameters = $writeHostParameters
    foreach ($parameter in $parameters) {
     $attributeCollection = New-Object -TypeName 'System.Collections.ObjectModel.Collection`1[System.Attribute]'
     foreach ($parameterAttribute in $parameter.Attributes) {
      $attributeCollection.Add($parameterAttribute)
     }
     $runtimeDefinedParameter = New-Object -TypeName 'System.Management.Automation.RuntimeDefinedParameter' -ArgumentList ([System.String]$parameter.Name, [System.Type]$parameter.ParameterType, [System.Collections.ObjectModel.Collection`1[System.Attribute]]$attributeCollection)
     $runtimeDefinedParameterDictionary.Add($runtimeDefinedParameter.Name, [System.Management.Automation.RuntimeDefinedParameter]$runtimeDefinedParameter)
    }
    return $runtimeDefinedParameterDictionary
   }#>

   Begin {
#    foreach ($psBoundParameter in $PSBoundParameters.GetEnumerator()) {Set-Variable -Name $psBoundParameter.Key -Value $psBoundParameter.Value}
   }
   Process {
    [System.String]$value = $Object -join $Separator
    if (-not $NoNewLine) {[System.String]$value += "`r`n"}
    if (-not $ChildOnly) {
     Write-Parent -Mode 'Text' -Object $value -Verbose:(-not -not $PSBoundParameters['Verbose'])
    }
    $Host.UI.Write([System.ConsoleColor]$ForegroundColor, [System.ConsoleColor]$BackgroundColor, [System.String]$value)
   }
   End {}
  }
'@

### Write-Output override ###
$remoteScripts += @'
#  $writeOutputParameters = (Get-Command -Name 'Write-Output').Parameters.Values | Where-Object {$_.Name -notin [System.Management.Automation.Internal.CommonParameters].GetProperties().Name}
  function global:Write-Output {
   [CmdletBinding()]
   param (
    [System.Management.Automation.PSObject[]][AllowEmptyCollection()][AllowNull()]$InputObject,
    [System.Management.Automation.SwitchParameter]$NoEnumerate,
    [System.Management.Automation.SwitchParameter]$ChildOnly
   )

<#   DynamicParam {
    $runtimeDefinedParameterDictionary = New-Object -TypeName 'System.Management.Automation.RuntimeDefinedParameterDictionary'
    $parameters = $writeOutputParameters
    foreach ($parameter in $parameters) {
     $attributeCollection = New-Object -TypeName 'System.Collections.ObjectModel.Collection`1[System.Attribute]'
     foreach ($parameterAttribute in $parameter.Attributes) {
      $attributeCollection.Add($parameterAttribute)
     }
     $runtimeDefinedParameter = New-Object -TypeName 'System.Management.Automation.RuntimeDefinedParameter' -ArgumentList ([System.String]$parameter.Name, [System.Type]$parameter.ParameterType, [System.Collections.ObjectModel.Collection`1[System.Attribute]]$attributeCollection)
     $runtimeDefinedParameterDictionary.Add($runtimeDefinedParameter.Name, [System.Management.Automation.RuntimeDefinedParameter]$runtimeDefinedParameter)
    }
    return $runtimeDefinedParameterDictionary
   }#>

   Begin {
#    foreach ($psBoundParameter in $PSBoundParameters.GetEnumerator()) {Set-Variable -Name $psBoundParameter.Key -Value $psBoundParameter.Value}
   }
   Process {
    if ($NoEnumerate) {}
    if (-not $ChildOnly) {
     Write-Parent -Mode 'Binary' -InputObject $InputObject -Verbose:(-not -not $PSBoundParameters['Verbose'])
    }
    return $InputObject
   }
   End {}
  }
'@

 $remoteScriptString = ($remoteScripts -join "`r`n")
 if ($RemoteInvocation.ToString()) {
  $remoteScriptString += $RemoteInvocation.ToString() + "`r`n"
 }

 [System.Byte[]]$buffer = [System.Char[]]$remoteScriptString

 if ($PSBoundParameters['Verbose']) {
  Write-Host ('Write:') -ForegroundColor 'Cyan'
  Write-Host $remoteScriptString -ForegroundColor 'Magenta'
 }
 else {
  Write-Host ('Booting child process') -ForegroundColor 'Cyan'
 }
 $PipeStream.Write($buffer, 0, $buffer.Count)

 if ($PSBoundParameters['Verbose']) {
  Write-Host ('WriteByte: ') -NoNewLine -ForegroundColor 'Cyan'
  Write-Host (' EOT ') -BackgroundColor 'Magenta'
 }
 $PipeStream.WriteByte(4)

 if ($PSBoundParameters['Verbose']) {
  Write-Host ('WaitForPipeDrain') -ForegroundColor 'Cyan'
 }
 $PipeStream.WaitForPipeDrain()
 Write-Host ('(Done)') -ForegroundColor 'Cyan'

 if($PSBoundParameters['Verbose']) {
  Write-Host ('Disconnect') -ForegroundColor 'Cyan'
 }
 $PipeStream.Disconnect()

 return $null
}


function Start-ParentListener {
 [CmdletBinding()]
 param(
  [System.IO.Pipes.NamedPipeServerStream]$PipeStream,
  [System.Management.Automation.SwitchParameter]$PrintControlCharacters = $false
 )

 $controlChars = @{
   0 = 'NUL';
   1 = 'SOH';
   2 = 'STX';
   3 = 'ETX';
   4 = 'EOT';
   5 = 'ENQ';
   6 = 'ACK';
   7 = 'BEL';
   8 =  'BS';
   9 =  'HT';
  10 =  'LF';
  11 =  'VT';
  12 =  'FF';
  13 =  'CR';
  14 =  'SO';
  15 =  'SI';
  16 = 'DLE';
  17 = 'DC1';
  18 = 'DC2';
  19 = 'DC3';
  20 = 'DC4';
  21 = 'NAK';
  22 = 'SYN';
  23 = 'ETB';
  24 = 'CAN';
  25 =  'EM';
  26 = 'SUB';
  27 = 'ESC';
  28 =  'FS';
  29 =  'GS';
  30 =  'RS';
  31 =  'US'
 }
 foreach ($controlChar in $controlChars.Clone().GetEnumerator()) {
  $controlChars.Add($controlChar.Value, $controlChar.Key)
 }

 $controlCharsDescription = @{
   0 = 'Null';
   1 = 'Start Of Heading';
   2 = 'Start Of Text';
   3 = 'End Of Text';
   4 = 'End Of Transmission';
   5 = 'Enquiry';
   6 = 'Acknowledge';
   7 = 'Bell';
   8 = 'Backspace';
   9 = 'Horizontal Tab';
  10 = 'Line Feed/New Line';
  11 = 'Vertical Tab';
  12 = 'Form Feed/New Page';
  13 = 'Carriage Return';
  14 = 'Shift Out';
  15 = 'Shift In';
  16 = 'Data Line Escape';
  17 = 'Device Control 1/X-On';
  18 = 'Device Control 2';
  19 = 'Device Control 3/X-Off';
  20 = 'Device Control 4';
  21 = 'Negative Acknowledge';
  22 = 'Synchronous Idle';
  23 = 'End of Transmission Block';
  24 = 'Cancel';
  25 = 'End of Medium';
  26 = 'Substitute';
  27 = 'Escape';
  28 = 'File Separator';
  29 = 'Group Separator';
  30 = 'Record Separator';
  31 = 'Unit Separator'
 }

 if($PSBoundParameters['Verbose']) {
  Write-Host ('WaitForConnection') -ForegroundColor 'Cyan'
 }
 $PipeStream.WaitForConnection()
 if($PSBoundParameters['Verbose']) {
  Write-Host ('(Established)') -ForegroundColor 'Cyan'
 }

 if ($PSBoundParameters['Verbose']) {
  Write-Host ('ReadByte:') -ForegroundColor 'Cyan'
 }
 else {
  Write-Host ('Output from child process:') -ForegroundColor 'Cyan'
 }
 $string = [System.String]::Empty
 $strings = @()
 while ($PipeStream.IsConnected) {
  [int]$byte = $PipeStream.ReadByte()

  if ($byte -eq -1) {
   Write-Warning -Message 'Broken pipe'
  }
  elseif ($controlChar = $controlChars[$byte]) {
   if ($PrintControlCharacters) {
    Write-Host -Object " $controlChar " -ForegroundColor 'Black' -BackgroundColor 'Yellow' -NoNewLine
    Write-Verbose -Message $controlCharsDescription[$byte]
   }
   else {
    switch ($controlChar) {
     'NUL' {<#Write-Host -Object "`0" -NoNewLine#>}
     '-SOH' {<#Set header flag (go to print state)?#>}
     'STX' {$string = [System.String]::Empty <#Flush header, Set text flag (go to print state)?#>}
     'ETX' {[System.String[]]$strings += [System.String]$string <#Flush text, Await new instruction?#>}
     'EOT' {<#Write-Host; #>if ($PSBoundParameters['Verbose']) {Write-Host ('Flush') -ForegroundColor 'Cyan'}; $PipeStream.Flush(); Write-Host ('Disconnect') -ForegroundColor 'Cyan'; $PipeStream.Disconnect()}
     '-ENQ' {<#Get variable, Set execute flag?#>}
     '-ACK' {<#"Success" response?#>}
     'BEL' {[System.Char]7 <#Write-Host -Object "`a" -NoNewLine#>}
     '-BS'  {<#Write-Host -Object "`b" -NoNewLine; if ($string.Length -gt 1) {$string = [System.String]::Join('', $string[0..($string.Length-2)])} else {$string = [System.String]::Empty}#> <#Clear last char?#>}
     'HT'  {Write-Host -Object "`t" -NoNewLine}
     'LF'  {[System.Management.Automation.Host.Coordinates]$cursorPosition = $host.UI.RawUI.CursorPosition; Write-Host -Object "`n" -NoNewLine; if ($cursorPosition.Y -lt $Host.UI.RawUI.BufferSize.Height - 1) {$offset = 1} else {$offset = 0}; $host.UI.RawUI.CursorPosition = @{X=$cursorPosition.X; Y=$cursorPosition.Y+$offset} <#Write-Host -Object "`n" = "`r`n"#>}
     '-VT'  {<#Write-Host -Object "`v"#>}
     'FF'  {Clear-Host <#Write-Host -Object "`f" -NoNewLine#> <#Scroll instead?#>}
     'CR'  {$host.UI.RawUI.CursorPosition = @{X=0; Y=$host.UI.RawUI.CursorPosition.Y} <#Write-Host -Object "`r"#>}
     '-SO' {<#Shift Out#>}
     '-SI' {<#Shift In#>}
     'DLE' {
            if ($PSBoundParameters['Verbose']) {
             Write-Host $controlCharsDescription[$byte] -ForegroundColor 'Black' -BackgroundColor 'Yellow'
            }

            [System.Type]$serializedDataBufferLengthBufferType = [System.Byte]
            [System.Int32]$serializedDataBufferLengthBufferLength = [System.Runtime.InteropServices.Marshal]::SizeOf([System.UInt32]$null)
            [System.Byte[]]$serializedDataBufferLengthBuffer = [System.Array]::CreateInstance([System.Type]$serializedDataBufferLengthBufferType, [System.Int32]$serializedDataBufferLengthBufferLength);
            [System.Int32]$serializedDataBufferLengthBufferOffset = 0
            if ($PSBoundParameters['Verbose']) {
             Write-Host ('Read: ') -NoNewLine -ForegroundColor 'Cyan'
            }
            [System.Int32]$serializedDataBufferLengthBufferBytesRead = $PipeStream.Read([System.Byte[]]$serializedDataBufferLengthBuffer, [System.Int32]$serializedDataBufferLengthBufferOffset, [System.Int32]$serializedDataBufferLengthBuffer.Count);

            if ($PSBoundParameters['Verbose']) {
             Write-Host ($serializedDataBufferLengthBuffer) -ForegroundColor 'Yellow'
            }

            [System.Int32]$serializedDataBufferLengthBufferStartIndex = 0
            [System.UInt32]$serializedDataBufferLength = [System.BitConverter]::ToUInt32([System.Byte[]]$serializedDataBufferLengthBuffer, [System.Int32]$serializedDataBufferLengthBufferStartIndex)

            if ($PSBoundParameters['Verbose']) {
             Write-Host ('Serialized Data Buffer Length: ') -NoNewLine -ForegroundColor 'Cyan'
             Write-Host ($serializedDataBufferLength) -ForegroundColor 'Yellow'
            }

            [System.Type]$serializedDataBufferType = [System.Byte]
            [System.Byte[]]$serializedDataBuffer = [System.Array]::CreateInstance([System.Type]$serializedDataBufferType, [System.Int32]$serializedDataBufferLength);
            [System.Int32]$serializedDataBufferOffset = 0;
            [System.Int32]$serializedDataBufferBytesRead = $PipeStream.Read([System.Byte[]]$serializedDataBuffer, [System.Int32]$serializedDataBufferOffset, [System.Int32]$serializedDataBuffer.Count);

#            if ($PSBoundParameters['Verbose']) {
#             Write-Host ('Serialized Data Buffer: ') -NoNewLine -ForegroundColor 'Cyan'
#             Write-Host ($serializedDataBuffer) -ForegroundColor 'Yellow'
#            }

            [System.IO.Stream]$serializationStream = [System.IO.MemoryStream]$serializedDataBuffer
            [System.Runtime.Serialization.Formatters.Binary.BinaryFormatter]$binaryFormatter = New-Object -TypeName 'System.Runtime.Serialization.Formatters.Binary.BinaryFormatter'
            try {
             [System.Object]$deserializedObject = $binaryFormatter.Deserialize([System.IO.Stream]$serializationStream)
             if ($PSBoundParameters['Verbose']) {
              Write-Host ('Deserialized object: ') -NoNewLine -ForegroundColor 'Cyan'
             }
             Write-Output -InputObject $deserializedObject
            }
            catch {
             Write-Warning $_
            }
            <#Data Link Escape - receive serialized byte stream#>
           }
     '-DC1' {<#Flush header, Set execute flag?#>}
     '-DC2' {<#Device Control 2#>}
     '-DC3' {<#Execute, Clear execute flag?#>}
     '-DC4' {<#Device Control 4#>}
     '-NAK' {<#"Failure" response?#>}
     '-SYN' {<#Keep alive?#>}
     '-ETB' {<#Execute/print,        Clear execute/print flag, Await new instruction?#>}
     '-CAN' {<#Cancel execute/print, Clear execute/print flag, Await new instruction?#>}
     '-EM'  {<#End of Medium#>}
     '-SUB' {<#Substitute#>}
     '-ESC' {<#Escape (preceding escape characters)#>}
     '-FS'  {<#File Separator#>}
     '-GS'  {<#Group Separator#>}
     '-RS'  {<#Record Separator#>}
     '-US'  {<#Unit Separator#>}
     default {
      [System.Char]$char = [System.Char]$byte
      Write-Warning -Message "Action not defined for character $byte"
      $string += [System.String]$char
     }
    }
   }
  }
  else {
   [System.Char]$char = [System.Char]$byte
   Write-Host -Object $char -NoNewLine -ForegroundColor 'Yellow'
   $string += [System.String]$char
  }

  <#
   Respond to flags, execute?
  #>
 }

 if ($PSBoundParameters['Verbose']) {
  Write-Host ('Close') -ForegroundColor 'Cyan'
 }
 $PipeStream.Close()

 if ($PSBoundParameters['Verbose']) {
  Write-Host ('Dispose') -ForegroundColor 'Cyan'
 }
 $PipeStream.Dispose()
}


function Start-ProcessWithPipe {
 [CmdletBinding()]
 param(
  [System.String]$ServerAddress = $null, # $env:COMPUTERNAME
  [System.Management.Automation.ScriptBlock]$RemoteInvocation = {},
  [System.Diagnostics.ProcessWindowStyle]$WindowStyle = 'Normal', #Hidden, Maximized, Minimized, Normal
  [System.Management.Automation.SwitchParameter]$NoExit = $false,
  [System.Management.Automation.SwitchParameter]$PrintControlCharacters = $false,
  [System.Object]$Impersonate = $null,
  [System.Management.Automation.SwitchParameter]$ReturnHostBufferOnExit = $false
 )

 $initiateChildParameters = [hashtable]$PSBoundParameters
 $initiateChildParameters.Remove('RemoteInvocation')
 $initiateChildParameters.Remove('ReturnHostBufferOnExit')
 [System.IO.Pipes.NamedPipeServerStream]$pipeStream = Initiate-ChildProcess @initiateChildParameters

 $bootChildParameters = [hashtable]$PSBoundParameters
 $bootChildParameters.Add('PipeStream', $pipeStream)
 $bootChildParameters.Remove('ServerAddress')
 $bootChildParameters.Remove('WindowStyle')
 $bootChildParameters.Remove('NoExit')
 $bootChildParameters.Remove('PrintControlCharacters')
 $bootChildParameters.Remove('Impersonate')
 Boot-ChildProcess @bootChildParameters # -PipeStream $pipeStream -RemoteInvocation $RemoteInvocation -ReturnHostBufferOnExit:$ReturnHostBufferOnExit = $false #-Verbose

 $startParentParameters = [hashtable]$PSBoundParameters
 $startParentParameters.Add('PipeStream', $pipeStream)
 $startParentParameters.Remove('ServerAddress')
 $startParentParameters.Remove('RemoteInvocation')
 $startParentParameters.Remove('WindowStyle')
 $startParentParameters.Remove('NoExit')
 $startParentParameters.Remove('Impersonate')
 $startParentParameters.Remove('ReturnHostBufferOnExit')
 Start-ParentListener @startParentParameters # -PipeStream $pipeStream # -Verbose
}

#Start-ProcessWithPipe -RemoteInvocation {Write-Output (Get-Process)[0..4]} -NoExit -Verbose
#Start-ProcessWithPipe -RemoteInvocation {Write-Output (Get-Process)[0]} -Impersonate (Get-Credential) -NoExit -Verbose
#Start-ProcessWithPipe -RemoteInvocation {Write-Output (Get-Process)[0..4]} -Impersonate (Get-Service 'TrustedInstaller') -NoExit -Verbose # (Service account must be Adminstrator)
#Start-ProcessWithPipe -RemoteInvocation {Write-Output (Get-Process)[0..4]} -Impersonate (Get-Process 'powershell')[0] -NoExit -Verbose # (Must be running as Adminstrator)
#Start-ProcessWithPipe -RemoteInvocation {Write-Output (Get-Process)[0..4]} -Impersonate $PID -NoExit -Verbose # (Must be running as Adminstrator)

