function Wait-FileSystem {
 [CmdletBinding()]
 param (
  [Parameter(Mandatory=$true)][System.String]$Path,
  [System.Management.Automation.SwitchParameter]$IncludeSubdirectories = $false,
  [System.String]$Filter = '*.*',
  [System.IO.WatcherChangeTypes]$EventName = [System.IO.WatcherChangeTypes]::All,
  [System.Int32]$TimeOut = $null
 )

 if (-not $EventName) {
  Write-Host 'Possible EventNames:'
  [System.Reflection.BindingFlags]$bindingFlags = [System.Reflection.BindingFlags]@('Public','NonPublic','Static')
  foreach ($watcherChangeType in ([System.IO.WatcherChangeTypes].GetFields([System.Reflection.BindingFlags]$bindingFlags) | Sort-Object -Property 'Name')) {
   Write-Host ($watcherChangeType.Name)
  }
  return $null
 }

 $fileSystemWatcher = New-Object -TypeName 'System.IO.FileSystemWatcher' -ArgumentList @([System.String]$Path, [System.String]$Filter)
 if ($TimeOut) {
  $fileSystemWatcher.WaitForChanged([System.IO.WatcherChangeTypes]$EventName, [System.Int32]$TimeOut)
 }
 else {
  $fileSystemWatcher.WaitForChanged([System.IO.WatcherChangeTypes]$EventName)
 }

<#
 if ($Action) {
  Register-ObjectEvent -InputObject $fileSystemWatcher -EventName 'Disposed' -Action {$Action}
 }
 if ($Action) {
  $fileSystemWatcher.EnableRaisingEvents = $true
  Register-ObjectEvent -InputObject $fileSystemWatcher -EventName ($EventName.Tostring()) -Action {$Action}
 }
 if ($Action) {
  $Action.Invoke()
 }
#>

 $null = $fileSystemWatcher.Dispose()
}

#Wait-FileSystem -Path $env:TMP -EventName All -TimeOut 5000
