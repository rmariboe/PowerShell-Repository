try {
 Add-Type -Namespace 'System' -Name 'WinAPI' -ErrorAction 'Stop' -MemberDefinition '
  [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hWnd);
  [DllImport("gdi32.dll")] public static extern IntPtr CreateDC(string lpszDriver, string lpszDevice, string lpszOutput, IntPtr lpInitData);
  public struct RECT {
   public int left;
   public int top;
   public int right;
   public int bottom;
  }
  [DllImport("user32.dll")]public static extern IntPtr GetWindowRect(IntPtr hWnd, ref RECT rect);
  public enum ProcessDPIAwareness {
   ProcessDPIUnaware = 0,
   ProcessSystemDPIAware = 1,
   ProcessPerMonitorDPIAware = 2
  }
  [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(ProcessDPIAwareness value);
  [DllImport("shcore.dll")] public static extern void GetProcessDpiAwareness(IntPtr hProcess, ref ProcessDPIAwareness awareness);
 '
}
catch {
}
$processDPIAwareness = [System.WinAPI+ProcessDPIAwareness]::ProcessPerMonitorDPIAware
$processDPIAwarenessResult = [System.WinAPI]::SetProcessDPIAwareness($processDPIAwareness)

Add-Type -AssemblyName 'System.Drawing'

function New-Graphics {
 [CmdletBinding()]
 param (
  [System.IntPtr]$WindowHandle = (Get-Process –Id $PID).MainWindowHandle, # [System.IntPtr]::Zero for Desktop
  [System.Management.Automation.SwitchParameter]$Unbuffered = $false,
  [System.Drawing.Rectangle]$TargetRectangle = [System.Drawing.Rectangle]::Empty
 )

 if ($WindowHandle -eq [System.IntPtr]::Zero) {
  [System.IntPtr]$deviceContext = [System.WinAPI]::CreateDC('DISPLAY', $null, $null, [System.IntPtr]::Zero) # Entire desktop
  [System.Drawing.Graphics]$graphics = [System.Drawing.Graphics]::FromHdc($deviceContext)
  [System.Int32]$width = (Get-WmiObject -Class 'Win32_VideoController').CurrentHorizontalResolution
  [System.Int32]$height = (Get-WmiObject -Class 'Win32_VideoController').CurrentVerticalResolution
 }
 else {
#  Add-Type -Namespace 'System' -Name 'WinAPI' -MemberDefinition '[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out IntPtr lpRect);' # Find rect osv osv osv

  $windowRect = New-Object -TypeName 'System.WinAPI+RECT'
  $null = [System.WinAPI]::GetWindowRect([System.IntPtr]$WindowHandle, [ref]$windowRect)

  [System.Drawing.Graphics]$graphics = [System.Drawing.Graphics]::FromHwnd($WindowHandle) # Pass zero to this instead for main display
  [System.Int32]$width = $graphics.VisibleClipBounds.Width
  [System.Int32]$height = $graphics.VisibleClipBounds.Height
 }

 if ($Unbuffered) {
  return $graphics
 }
 else {
  if ($TargetRectangle -eq [System.Drawing.Rectangle]::Empty) {
   [System.Drawing.Rectangle]$TargetRectangle = [System.Drawing.Rectangle](@{X=[System.Int32]0;Y=[System.Int32]0;Width=[System.Int32]$width;Height=[System.Int32]$height})
  }
  [System.Drawing.BufferedGraphicsContext]$bufferedGraphicsContext = [System.Drawing.BufferedGraphicsContext](@{MaximumBuffer=@{Width=$graphics.VisibleClipBounds.Width;Height=$graphics.VisibleClipBounds.Height}})
#  [System.Drawing.BufferedGraphics]$bufferedGraphics = $bufferedGraphicsContext.Allocate([System.IntPtr]$deviceContext, [System.Drawing.Rectangle]$TargetRectangle)
  [System.Drawing.BufferedGraphics]$bufferedGraphics = $bufferedGraphicsContext.Allocate([System.Drawing.Graphics]$graphics, [System.Drawing.Rectangle]$TargetRectangle)

  if ($WindowHandle -eq [System.IntPtr]::Zero) {	# Don't know how to get window position/size - yet :) [System.Windows.Window] - https://msdn.microsoft.com/en-us/library/system.windows.window(v=vs.110).aspx
   [System.Int32]$sourceX = $TargetRectangle.X
   [System.Int32]$sourceY = $TargetRectangle.Y
   [System.Int32]$destinationX = 0
   [System.Int32]$destinationY = 0
   [System.Drawing.Size]$blockRegionSize = @{Width=[System.Int32]$width;Height=[System.Int32]$height}
   [System.Drawing.CopyPixelOperation]$CopyPixelOperation = [System.Drawing.CopyPixelOperation]::SourceCopy
   $bufferedGraphics.Graphics.CopyFromScreen([System.Int32]$sourceX, [System.Int32]$sourceY, [System.Int32]$destinationX, [System.Int32]$destinationY, [System.Drawing.Size]$blockRegionSize, [System.Drawing.CopyPixelOperation]$copyPixelOperation)
  }
  else {						# Now I know :) [System.Windows.Window] - https://msdn.microsoft.com/en-us/library/system.windows.window(v=vs.110).aspx ## Add-Type -AssemblyName 'PresentationFramework' is the correct one - these are wrong: ## Add-Type -AssemblyName 'PresentationCore' ## Add-Type -Path 'C:\Windows\Microsoft.NET\assembly\GAC_MSIL\System.Windows\v4.0_4.0.0.0__b03f5f7f11d50a3a\System.Windows.dll' ## Add-Type -Path 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Windows.dll'
   [System.Int32]$sourceX = $windowRect.left + $TargetRectangle.X + 6
   [System.Int32]$sourceY = $windowRect.top + $TargetRectangle.Y + 35
   [System.Int32]$destinationX = 0 -5
   [System.Int32]$destinationY = 0 -5
   [System.Drawing.Size]$blockRegionSize = @{Width=[System.Int32]$width;Height=[System.Int32]$height}
   [System.Drawing.CopyPixelOperation]$CopyPixelOperation = [System.Drawing.CopyPixelOperation]::SourceCopy
   $bufferedGraphics.Graphics.CopyFromScreen([System.Int32]$sourceX, [System.Int32]$sourceY, [System.Int32]$destinationX, [System.Int32]$destinationY, [System.Drawing.Size]$blockRegionSize, [System.Drawing.CopyPixelOperation]$copyPixelOperation)
  }
							# But it doesn't matter :o| ## Yes it does! :)

  return $bufferedGraphics
 }
}
#$graphics = New-Graphics -WindowHandle 0 -TargetRectangle ([System.Drawing.Rectangle](@{X=400;Y=400;Width=300;Height=200}))
#$graphics = New-Graphics -WindowHandle (Get-Process -Id $PID).MainWindowHandle
