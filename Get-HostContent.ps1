&"$PSScriptRoot\Scroll-BufferContents.ps1"

function Get-HostContent {
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

 [System.Management.Automation.Host.Rectangle]$rectangle = New-Object -TypeName 'System.Management.Automation.Host.Rectangle' -ArgumentList ($Left, $Top, $right, $bottom)
 [System.Management.Automation.Host.BufferCell[,]]$bufferContents = $host.UI.RawUI.GetBufferContents($rectangle)

 $printBufferContent = {
  [OutputType([System.Void])]
  [System.Management.Automation.Host.Coordinates]$origin = $host.UI.RawUI.CursorPosition
  [System.Int32]$rectangleHeight = $this.Rectangle.Bottom - $this.Rectangle.Top + 1
  if (($origin.Y + $rectangleHeight) -gt $host.UI.RawUI.BufferSize.Height) {
   [System.Int32]$scrollLines = $host.UI.RawUI.CursorPosition.Y + $rectangleHeight - $host.UI.RawUI.BufferSize.Height
   $null = Scroll-BufferContents -Lines $scrollLines
   [System.Int32]$origin.Y = $host.UI.RawUI.BufferSize.Height - $rectangleHeight
  }
  [System.Management.Automation.Host.BufferCell[,]]$contents = $this.BufferContents
  $null = [System.Void]$host.UI.RawUI.SetBufferContents([System.Management.Automation.Host.Coordinates]$origin, [System.Management.Automation.Host.BufferCell[,]]$contents)
  [System.Int32]$cursorPositionY = $origin.Y + $rectangleHeight - 1
  [System.Int32]$cursorPositionX = $origin.X
  $host.UI.RawUI.CursorPosition = @{X=$cursorPositionX; Y=$cursorPositionY}
 }

 $toString = {
  [OutputType([System.String])]
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
 $bufferObject | Add-Member -MemberType 'ScriptMethod' -Name 'PrintBufferContents' -Value $printBufferContent #-TypeName 'System.Void'
 $bufferObject | Add-Member -MemberType 'ScriptMethod' -Name 'ToString' -Value $toString -Force #-TypeName 'System.String'
 $bufferObject | Add-Member -MemberType 'MemberSet' -Name 'PSStandardMembers' -Value $psStandardMembers #-TypeName 'System.Management.Automation.PSMemberInfo[]'
 $bufferObject.psobject.TypeNames.Insert(0,'System.Management.Automation.Host.PSHostRawUserInterface.BufferContents')

 if ($Echo) {
  $bufferObject.PrintBufferContents()
 }

 return $bufferObject
}

#$test = Get-HostContent -Left 1 -Top 1 -Width 20 -Height 10 -Echo
#Get-Service
#$test = Get-HostContent
