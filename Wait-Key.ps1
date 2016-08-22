function global:Wait-Key {
 param(
  [switch]$AllowCtrlC,
  [switch]$Echo,
  [switch]$IncludeKeyDown,
  [switch]$IncludeKeyUp,
  [switch]$PassThru,
  [System.Char[]]$Char = $null
 )

 $readKeyOptions = @()

 if ($IncludeKeyUp) {
  $readKeyOptions += [System.Management.Automation.Host.ReadKeyOptions]::IncludeKeyUp
 }
 if ($IncludeKeyDown -or -not $IncludeKeyUp) {
  $readKeyOptions += [System.Management.Automation.Host.ReadKeyOptions]::IncludeKeyDown
 }
 if ($AllowCtrlC) {
  $readKeyOptions += [System.Management.Automation.Host.ReadKeyOptions]::AllowCtrlC
 }
 if (-not $Echo) {
  $readKeyOptions += [System.Management.Automation.Host.ReadKeyOptions]::NoEcho
 }

 do {
  $keyInfo = $host.UI.RawUI.ReadKey($readKeyOptions)
  if ($PassThru) {
   $keyInfo
  }
 }
 while ($Char -and -not ($keyInfo.Character -in $Char))

 if ($Echo -and -not $PassThru) {
  Write-Host
 }
}
