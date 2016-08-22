function Get-LastEvent {
 [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
 Param (
  [Parameter(Mandatory=$true)][string]$SourceIdentifier,
  [Parameter(Mandatory=$false)][switch]$Purge = $true,
  [Parameter(Mandatory=$false)][switch]$PreserveLast = $true
 )

$ErrorActionPreference = 'Stop'

 $event = $null
 do {
  try {
   $event = (Get-Event -SourceIdentifier $SourceIdentifier)[-1]
  }
  catch {
   if ($_.Exception.GetBaseException().Message -ne 'Collection was modified; enumeration operation may not execute.') { ## Probably "Event with source identifier '$SourceIdentifier' does not exist."
    return $null
   }
  }
 }
 while (-not $event)

 if ($Purge) {
  Remove-Event -SourceIdentifier $SourceIdentifier
  if ($PreserveLast) {
   $null = New-Event -SourceIdentifier $event.SourceIdentifier -Sender $event.Sender -EventArguments $event.SourceArgs
  }
 }

 $ErrorActionPreference = 'Continue'

 return $event
}
