function Write-HostCoordinates {
 param (
  [Object]$Object,
  [System.ConsoleColor]$ForegroundColor = $host.UI.RawUI.ForegroundColor,
  [System.ConsoleColor]$BackgroundColor = $host.UI.RawUI.BackgroundColor,
  [int]$X = $null, # $Host.UI.RawUI.WindowSize.Width-$Object.ToString().Length,
  [int]$Y = $null,
  [ValidateSet('RelativeToWindow','RelativeToCursor','Absolute')][string]$Positioning = 'RelativeToWindow',
  [switch]$ReturnObject = $false
 )

 switch ($Object.GetType()) {
  ([System.Management.Automation.Host.BufferCell[,]]) {
   $hostBufferCellArray = $Object
  }
<#  ([System.Management.Automation.Host.BufferCell[]]) {
   foreach ($hostBufferCell in $Object) {
   }
   $hostBufferCellArray = $Object
  }#>
  ([System.Management.Automation.Host.BufferCell]) {
   $hostBufferCellArray = $Host.UI.RawUI.NewBufferCellArray($Object.Character, $Object.ForegroundColor, $Object.BackgroundColor)
  }
  ([System.String[]]) {
   $hostBufferCellArray = $Host.UI.RawUI.NewBufferCellArray([System.String[]]$Object, $ForegroundColor, $BackgroundColor)
  }
  ([System.String]) {
   $hostBufferCellArray = $Host.UI.RawUI.NewBufferCellArray($Object.Split("`n"), $ForegroundColor, $BackgroundColor)
  }
  default {
   $hostBufferCellArray = $Host.UI.RawUI.NewBufferCellArray($Object.ToString(), $ForegroundColor, $BackgroundColor)
  }
 }
 switch ($Positioning) {
  'Absolute' {
   if ($Y -eq $null) {
    $Y = $Host.UI.RawUI.CursorPosition.Y
   }
   if ($X -eq $null) {
    $X = 0
   }
  }
  'RelativeToCursor' {
   if ($Y -eq $null) {
    $Y = 0
   }
   if ($X -eq $null) {
#    $X = (prompt).Length
    $X = 0
   }
   $X += $Host.UI.RawUI.CursorPosition.X
   $Y += $Host.UI.RawUI.CursorPosition.Y
  }
  'RelativeToWindow' {
   if ($Y -eq $null) {
    $Y = $Host.UI.RawUI.CursorPosition.Y-$Host.UI.RawUI.WindowPosition.Y
   }
   if ($X -eq $null) {
    $X = 0
   }
   $X += $Host.UI.RawUI.WindowPosition.X
   $Y += $Host.UI.RawUI.WindowPosition.Y
  }
  default {
  }
 }
 if (($X -eq 0) -and ($Y -eq $Host.UI.RawUI.CursorPosition.Y)) {
  Write-Host
 }
 $hostCoordinates = New-Object System.Management.Automation.Host.Coordinates ($X, $Y)

 if ($ReturnObject) {
  $hostRectangle = New-Object System.Management.Automation.Host.Rectangle ([int]$X, [int]$Y, [int]([int]$X+[int]$hostBufferCellArray.Count), [int]$Y)
  $originalHostBufferContents = $host.UI.RawUI.GetBufferContents($hostRectangle)

  $defaultProperties = @('HostRectangle','WrittenHostBufferCellArray','OriginalHostBufferContents')
  $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultProperties)
  $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)

  $writeHostObject = New-Object -TypeName PSObject
  $writeHostObject | Add-Member -MemberType NoteProperty -Name 'HostRectangle' -Value $hostRectangle
  $writeHostObject | Add-Member -MemberType NoteProperty -Name 'WrittenHostBufferCellArray' -Value $hostBufferCellArray
  $writeHostObject | Add-Member -MemberType NoteProperty -Name 'OriginalHostBufferContents' -Value $originalHostBufferContents

  $writeHostObject
 }

 $host.UI.RawUI.SetBufferContents($hostCoordinates, $hostBufferCellArray)
}
#$wh = Write-HostCoordinates -Object (Get-Service)[4] -ForegroundColor 'Blue' -BackgroundColor 'Yellow' -X 4 -Y 3 -ReturnObject
#Write-HostCoordinates -Object $wh.OriginalHostBufferContents -X $wh.HostRectangle.Left -Y $wh.HostRectangle.Top -Positioning Absolute
#Write-HostCoordinates -Object (Get-Service)[4] -ForegroundColor 'Blue' -BackgroundColor 'Yellow' -Positioning 'RelativeToCursor' -X 1 -Y 1