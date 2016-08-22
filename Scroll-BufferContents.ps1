function Scroll-BufferContents {
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

#Scroll-BufferContents;Write-Host 'afd' -NoNewLine;Scroll-BufferContents;Write-Host 'afd' -NoNewLine;Scroll-BufferContents

