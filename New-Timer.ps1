function global:New-Timer {
 [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
 Param (
  [Parameter(Mandatory=$false)][int]$Interval = 1000,
  [Parameter(Mandatory=$false)][scriptblock]$Action = {Write-Host 'Ding'},
  [Parameter(Mandatory=$false)][switch]$AutoReset = $true,
  [Parameter(Mandatory=$false)][switch]$Enabled = $false
 )

 $timer = [System.Timers.Timer]$Interval
 $timer.AutoReset = $AutoReset
 $timer.Enabled = $Enabled
 $timer | Add-Member -MemberType NoteProperty -Name 'EventJob' -Value (Register-ObjectEvent -InputObject $timer -EventName 'Elapsed' -Action $Action)
 return $timer
}
