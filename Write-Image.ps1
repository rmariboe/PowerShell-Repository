function Write-Image {
 [CmdletBinding()]
 param (
  [System.Drawing.Image]$Image,
  [System.Int32]$Width = 0,
  [System.Int32]$Height = 0,
  [System.Int32]$Left = [System.Console]::CursorLeft,
  [System.Drawing.Drawing2D.InterpolationMode]$InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
 )

 Add-Type -AssemblyName 'System.Drawing'

 $graphics = New-Graphics -WindowHandle (Get-Process -Id $PID).MainWindowHandle -Unbuffered
 $graphics.InterpolationMode = $InterpolationMode

 $maxDrawWidth = $graphics.VisibleClipBounds.Width
 $maxDrawHeight = $graphics.VisibleClipBounds.Height
 $drawScaleWidth = $maxDrawWidth / $Image.Width
 $drawScaleHeight = $maxDrawHeight / $Image.Height
 $drawScale = [System.Math]::Min($drawScaleWidth, $drawScaleHeight)
 $drawWidth = $Image.Width*$drawScale
 $drawHeight = $Image.Height*$drawScale

 $imageScale = $Image.Width / $Image.Height
 if ($Height) {
  $drawHeight = $Height
  if (-not $Width) {
   $drawWidth = $drawHeight * $imageScale
  }
 }
 if ($Width) {
  $drawWidth = $Width
  if (-not $Height) {
   $drawHeight = $drawWidth / $imageScale
  }
 }

 $drawX = $Left

 $lineHeight = $graphics.VisibleClipBounds.Height / $Host.UI.RawUI.WindowSize.Height
 $imageLineHeight = [System.Math]::Ceiling($drawHeight / $lineHeight)
 [System.Console]::SetCursorPosition(0, [System.Console]::CursorTop + $imageLineHeight + 1)

 $cursorPositionRelative = $Host.UI.RawUI.CursorPosition.Y - $Host.UI.RawUI.WindowPosition.Y + 1
 $cursorPositionRelativePixels = $cursorPositionRelative * $lineHeight
 $drawY = $cursorPositionRelativePixels - $lineHeight * ($imageLineHeight + 2)

# $graphics.Flush([System.Drawing.Drawing2D.FlushIntention]::Sync)
 $graphics.DrawImage($Image, $drawX, $drawY, $drawWidth, $drawHeight)
}
#Write-Image -Image $Image -Width 90