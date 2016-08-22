function Get-ParentProcess {
 param (
  $ProcessID = $PID
 )
 return (Get-Process -Id (Get-WmiObject -Query 'SELECT ParentProcessId FROM Win32_Process WHERE ProcessId = $ProcessID').ParentProcessId)
}
