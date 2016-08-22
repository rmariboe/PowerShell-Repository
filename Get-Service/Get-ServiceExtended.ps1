function Get-ServiceExtended {
 [CmdletBinding(DefaultParameterSetName='InputObject')] 
 param (
  [Parameter(ParameterSetName='Name')][System.String[]]$Name,
  [System.String[]]$ComputerName = $env:COMPUTERNAME,
  [System.Management.Automation.SwitchParameter]$DependentServices,
  [System.String[]]$Exclude,
  [System.String[]]$Include,
  [Parameter(ParameterSetName='InputObject', ValueFromPipeline=$true)][System.Object[]]$InputObject,	# [System.ServiceProcess.ServiceController[]] does not exist until Get-Service has added type.
  [System.Management.Automation.SwitchParameter]$RequiredServices,
  [Parameter(ParameterSetName='DisplayName')][System.String[]]$DisplayName
 )

 $defaultProperties = @('Status', 'Name', 'DisplayName')
 $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultProperties)
 $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)

### DescriptionScript BEGIN ###
 $get_DescriptionScript = {
  if ($this.Win32_Service.Name -ne $this.ServiceName) {$this.Win32_Service.Refresh()}
  return $this.Win32_Service.Description
 }

 $set_DescriptionScript = {
  param ([System.String]$Description)
  if ($this.Win32_Service.Name -ne $this.ServiceName) {$this.Win32_Service.Refresh()}
  $this.Win32_Service.Description = $Description
  $return = $this.Win32_Service.Commit($true)
 }
### DescriptionScript  END  ###

### PathNameScript BEGIN ###
 $get_PathNameScript = {
  if ($this.Win32_Service.Name -ne $this.ServiceName) {$this.Win32_Service.Refresh()}
  $this.Win32_Service.PathName
 }

 $set_PathNameScript = {
  param ([System.String]$PathName)
  if ($this.Win32_Service.Name -ne $this.ServiceName) {$this.Win32_Service.Refresh()}
  $this.Win32_Service.PathName = $PathName
  $return = $this.Win32_Service.Commit($true)
 }
### PathNameScript  END  ###

### ProcessIdScript BEGIN ###
 $get_ProcessIdScript = {
  if ($this.Win32_Service.Name -ne $this.ServiceName) {$this.Win32_Service.Refresh()}
  return $this.Win32_Service.ProcessId
 }

 $set_ProcessIdScript = {
  if ($this.Win32_Service.Name -ne $this.ServiceName) {$this.Win32_Service.Refresh()}
  throw ('''ProcessId'' is a ReadOnly property.')
 }
### ProcessIdScript  END ###

### StartModeScript BEGIN ###
 $get_StartModeScript = {
  if ($this.Win32_Service.Name -ne $this.ServiceName) {$this.Win32_Service.Refresh()}
  $startMode = $this.Win32_Service.StartMode
  switch ($this.Win32_Service.StartMode) {
   'Auto' {
    $startMode += 'matic'
    if ($this.Win32_Service.DelayedAutoStart) { # https://msdn.microsoft.com/en-us/library/aa394418(v=vs.85).aspx : Windows Server 2012 R2, Windows 8.1, Windows Server 2012, Windows 8, Windows Server 2008 R2, Windows 7, Windows Server 2008, Windows Vista, and Windows Server 2003:  This property is not supported before Windows Server Technical Preview and Windows 10 Insider Preview.
     $startMode += ' (Delayed Start)'
    }
   }
   'Boot' {}
   'Disabled' {}
   'Manual' {}
   'System' {}
   default {}
  }
  return $startMode
 }

 $set_StartModeScript = {
  param ($StartMode)
  if ($this.Win32_Service.Name -ne $this.ServiceName) {$this.Win32_Service.Refresh()}

  $returnValues = @( # https://msdn.microsoft.com/en-us/library/aa384896(v=vs.85).aspx
   'The request was accepted.',
   'The request is not supported.',
   'The user did not have the necessary access.',
   'The service cannot be stopped because other services that are running are dependent on it.',
   'The requested control code is not valid, or it is unacceptable to the service.',
   'The requested control code cannot be sent to the service because the state of the service (Win32_BaseService State property) is equal to 0, 1, or 2.',
   'The service has not been started.',
   'The service did not respond to the start request in a timely fashion.',
   'Unknown failure when starting the service.',
   'The directory path to the service executable file was not found.',
   'The service is already running.',
   'The database to add a new service is locked.',
   'A dependency this service relies on has been removed from the system.',
   'The service failed to find the service needed from a dependent service.',
   'The service has been disabled from the system.',
   'The service does not have the correct authentication to run on the system.',
   'This service is being removed from the system.',
   'The service has no execution thread.',
   'The service has circular dependencies when it starts.',
   'A service is running under the same name.',
   'The service name has invalid characters.',
   'Invalid parameters have been passed to the service.',
   'The account under which this service runs is either invalid or lacks the permissions to run the service.',
   'The service exists in the database of services available from the system.',
   'The service is currently paused in the system.'
  )

  $startModeSet = @('Automatic', 'Automatic (Delayed Start)', 'Boot', 'Disabled', 'Manual', 'System') # ([System.ServiceProcess.ServiceStartMode]) # ([System.ServiceProcess.ServiceStartMode]) - 'Automatic (Delayed Start)' only with Win10
  if ($StartMode -eq 'Automatic (Delayed Start)') {
   $this.Win32_Service.DelayedAutoStart = $true
   $this.Win32_Service.Commit()
   $StartMode = 'Automatic'
  }
  $return = $this.Win32_Service.ChangeStartMode($StartMode)
  switch ($return.ReturnValue) {
   0 {}
   21 {throw ($returnValues[$return.ReturnValue] + " StartMode must be one of '" + ($startModeSet -join "', '") + "'")}
   default {throw $returnValues[$return.ReturnValue]}
  }

  $null = $this.Refresh()
  $null = $this.Win32_Service.Refresh()
 }
### StartModeScript  END  ###

### StartNameScript BEGIN ###
 $get_StartNameScript = {
  if ($this.Win32_Service.Name -ne $this.ServiceName) {$this.Win32_Service.Refresh()}
  $this.Win32_Service.StartName
 }

 $set_StartNameScript = {
  param ([System.String]$StartName)
  if ($this.Win32_Service.Name -ne $this.ServiceName) {$this.Win32_Service.Refresh()}
  $this.Win32_Service.StartName = $StartName
  $return = $this.Win32_Service.Commit($true)
 }
### StartNameScript  END  ###

### StartPasswordScript BEGIN ###
 $get_StartPasswordScript = {
  if ($this.Win32_Service.Name -ne $this.ServiceName) {$this.Win32_Service.Refresh()}
  return $this.Win32_Service.StartPassword
 }

 $set_StartPasswordScript = {
  param ([AllowEmptyString()][AllowNull()][System.Object]$StartPassword)
  if ($this.Win32_Service.Name -ne $this.ServiceName) {$this.Win32_Service.Refresh()}
  if ($StartPassword) {
   if ($StartPassword.GetType() -eq [System.Security.SecureString]) {
    $this.Win32_Service.StartPassword = $StartPassword
   }
   else {
    $this.Win32_Service.StartPassword = ConvertTo-SecureString -String $StartPassword -AsPlainText -Force
   }
  }
  else {
   $this.Win32_Service.StartPassword = $StartPassword
  }
  if ($this.Win32_Service.StartPassword -ne $null) {
   $return = $this.Win32_Service.Commit($true)
  }
 }
### StartPasswordScript  END  ###

### Win32StatusScript BEGIN ###
 $get_Win32StatusScript = {
  if ($this.Win32_Service.Name -ne $this.ServiceName) {$this.Win32_Service.Refresh()}
  return $this.Win32_Service.Status
 }

 $set_Win32StatusScript = {
  param ($Status)
  if ($this.Win32_Service.Name -ne $this.ServiceName) {$this.Win32_Service.Refresh()}
  $this.Win32_Service.Status = $Status
  $return = $this.Win32_Service.Commit($true)
 }
### Win32StatusScript  END  ###

### Win32_ServiceScript BEGIN ###
 $get_Win32_ServiceScript = {
 ### RefreshScript BEGIN ###
  $refreshScript = {
   $refreshScript = $this.Refresh.Script
   $commitScript = $this.Commit.Script
   if ($this.Name -eq $this.Service.ServiceName) {
    $startPassword = $this.StartPassword
   }
   else {
    $startPassword = $null
   }
   $service = $this.Service

   $wmiServiceObject = New-Object -TypeName 'System.Management.Automation.PSObject' -ArgumentList (Get-WmiObject -Class 'Win32_Service' -Filter ("Name='" + $service.ServiceName + "'")) | ForEach-Object {$_|
    Add-Member -MemberType 'ScriptMethod' -Name 'Refresh'       -Value $refreshScript -PassThru |
    Add-Member -MemberType 'ScriptMethod' -Name 'Commit'        -Value $commitScript  -PassThru |
    Add-Member -MemberType 'NoteProperty' -Name 'StartPassword' -Value $StartPassword -PassThru |
    Add-Member -MemberType 'NoteProperty' -Name 'Service'       -Value $service       -PassThru
   }
   if ($startPassword) {
    $wmiServiceObject | Add-Member -MemberType 'NoteProperty' -Name 'StartPassword' -Value $startPassword
   }
   $service | Add-Member -MemberType 'NoteProperty' -Name 'Win32_Service' -Value $wmiServiceObject -Force
  }
 ### RefreshScript  END  ###

 ### CommitScript BEGIN ###
  $commitScript = {
   param ([System.Boolean]$RefreshAfterCommit = $false)

   $returnValues = @( # https://msdn.microsoft.com/en-us/library/aa384896(v=vs.85).aspx
    'The request was accepted.',
    'The request is not supported.',
    'The user did not have the necessary access.',
    'The service cannot be stopped because other services that are running are dependent on it.',
    'The requested control code is not valid, or it is unacceptable to the service.',
    'The requested control code cannot be sent to the service because the state of the service (Win32_BaseService State property) is equal to 0, 1, or 2.',
    'The service has not been started.',
    'The service did not respond to the start request in a timely fashion.',
    'Unknown failure when starting the service.',
    'The directory path to the service executable file was not found.',
    'The service is already running.',
    'The database to add a new service is locked.',
    'A dependency this service relies on has been removed from the system.',
    'The service failed to find the service needed from a dependent service.',
    'The service has been disabled from the system.',
    'The service does not have the correct authentication to run on the system.',
    'This service is being removed from the system.',
    'The service has no execution thread.',
    'The service has circular dependencies when it starts.',
    'A service is running under the same name.',
    'The service name has invalid characters.',
    'Invalid parameters have been passed to the service.',
    'The account under which this service runs is either invalid or lacks the permissions to run the service.',
    'The service exists in the database of services available from the system.',
    'The service is currently paused in the system.'
   )

   $serviceTypes = @{
    'Kernel Driver'       = [System.UInt32]0x1;
    'File System Driver'  = [System.UInt32]0x2;
    'Adapter'             = [System.UInt32]0x4;
    'Recognizer Driver'   = [System.UInt32]0x8;
    'Own Process'         = [System.UInt32]0x10;
    'Share Process'       = [System.UInt32]0x20;
    'Interactive Process' = [System.UInt32]0x100
   }
   $ServiceType = $serviceTypes[$this.ServiceType]

   $errorControls = @{
    'Ignore'   = [System.UInt32]0;
    'Normal'   = [System.UInt32]1;
    'Severe'   = [System.UInt32]2;
    'Critical' = [System.UInt32]3
   }
   $ErrorControl = $errorControls[$this.ErrorControl]

   # If StartName = NULL, LocalSystem or default object name created by the I/O system based on the service name
   [System.String]$StartName = $this.StartName
   if ($StartName -in ('NetworkService', 'Network Service', 'LocalService', 'Local Service')) {
    $StartName = 'NT AUTHORITY\' + $StartName
   }
   elseif ($StartName -in ('Local System', 'NT AUTHORITY\Local System', 'NT AUTHORITY\LocalSystem')) {
    $StartName = 'LocalSystem'
   }
   if ($StartName -eq 'LocalSystem') {
    [System.String]$StartName = $null
   }

   # If Password = NULL, will not change. Password = "" for no password.
   if ($this.StartPassword) {
    if ($StartPassword.GetType() -eq [System.Security.SecureString]) {
     [System.String]$startPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($this.StartPassword))
    }
    else {
     [System.String]$startPassword = $this.StartPassword
    }
   }
   else {
    [System.String]$startPassword = $this.StartPassword
   }
   if ($StartName -in ('LocalSystem', 'NT AUTHORITY\NetworkService', 'NT AUTHORITY\Network Service')) {
    $startPassword = [System.String]::Empty # When changing a service from a local system to a network, or from a network to a local system, StartPassword must be an empty string ("") and not NULL.
   }
   elseif (-not $startPassword) {
    $startPassword = $null
   }

   [System.String]$LoadOrderGroup = $null
   [System.String[]]$LoadOrderGroupDependencies = $null # Doubly NULL terminated unless NULL
   [System.String[]]$ServiceDependencies = $this.Service.ServicesDependedOn.Name
   [System.String[]]$ServiceDependencies += [System.String]$null
   if ($ServiceDependencies.Count -gt 1) {
    $ServiceDependencies += @([System.String]$null) # Doubly NULL terminated unless NULL
   }

   $return = $this.Change( # https://msdn.microsoft.com/en-us/library/aa384901(v=vs.85).aspx
    [System.String]$this.DisplayName,
    [System.String]$this.PathName,
    [System.UInt32]$ServiceType, # Docs say UInt32, overload says Byte!?
    [System.UInt32]$ErrorControl, # Docs say UInt32, overload says Byte!?
    [System.String]$this.Service.StartMode, # "Auto" vs "Automatic"?
    [System.Boolean]$this.DesktopInteract,
    [System.String]$this.StartName,
    [System.String]$startPassword,
    [System.String]$LoadOrderGroup,
    [System.String[]]$LoadOrderGroupDependencies,
    [System.String[]]$ServiceDependencies
   )

   switch ($return.ReturnValue) {
    0 {
     if ($RefreshAfterCommit) {
      $null = $this.Refresh() # Necessary?
     }
     return $return
    }
    default {
     throw $returnValues[$return.ReturnValue]
    }
   }
  }
 ### CommitScript  END  ###

  $service = $this   # Gets values on first lookup rather than second (triggers object... somehow:)
  $wmiServiceObject = New-Object -TypeName 'System.Management.Automation.PSObject' -ArgumentList (Get-WmiObject -Class 'Win32_Service' -Filter ("Name='" + $service.ServiceName + "'")) | ForEach-Object {$_|
   Add-Member -MemberType 'ScriptMethod' -Name 'Refresh'           -Value $refreshScript -PassThru |
   Add-Member -MemberType 'ScriptMethod' -Name 'Commit'            -Value $commitScript  -PassThru |
   Add-Member -MemberType 'NoteProperty' -Name 'StartPassword'     -Value $null          -PassThru |
   Add-Member -MemberType 'NoteProperty' -Name 'Service'           -Value $service       -PassThru
  }
  $service | Add-Member -MemberType 'NoteProperty' -Name 'Win32_Service' -Value $wmiServiceObject -Force

  return $service.Win32_Service
 }
### Win32_ServiceScript  END  ###

<#
 $serviceObjects = @()
 foreach ($serviceObject in (Get-Service @PSBoundParameters)) {
# $serviceObject | Add-Member -MemberType 'ScriptProperty' -Name 'Caption'                 -Value $get_CaptionScript                     -SecondValue $set_CaptionScript                 -Force		$this.Win32_Service.Caption (get, set)
  $serviceObject | Add-Member -MemberType 'ScriptProperty' -Name 'Description'             -Value $get_DescriptionScript                 -SecondValue $set_DescriptionScript             -Force
# $serviceObject | Add-Member -MemberType 'ScriptProperty' -Name 'DestopInteract'          -Value $get_DestopInteractScript              -SecondValue $set_DestopInteractScript          -Force		$this.Win32_Service.DestopInteract (get, set)
# $serviceObject | Add-Member -MemberType 'ScriptProperty' -Name 'ExitCode'                -Value $get_ExitCodeScript                    -SecondValue $set_ExitCodeScript                -Force		$this.Win32_Service.ExitCode (no set)
  $serviceObject | Add-Member -MemberType 'ScriptProperty' -Name 'PathName'                -Value $get_PathNameScript                    -SecondValue $set_PathNameScript                -Force
  $serviceObject | Add-Member -MemberType 'ScriptProperty' -Name 'ProcessId'               -Value $get_ProcessIdScript                   -SecondValue $set_ProcessIdScript               -Force
# $serviceObject | Add-Member -MemberType 'ScriptProperty' -Name 'ServiceSpecificExitCode' -Value $get_ServiceSpecificExitCodeCodeScript -SecondValue $set_ServiceSpecificExitCodeScript -Force		$this.Win32_Service.ServiceSpecificExitCode (no set?)
  $serviceObject | Add-Member -MemberType 'ScriptProperty' -Name 'StartMode'               -Value $get_StartModeScript                   -SecondValue $set_StartModeScript               -Force
  $serviceObject | Add-Member -MemberType 'ScriptProperty' -Name 'StartName'               -Value $get_StartNameScript                   -SecondValue $set_StartNameScript               -Force
  $serviceObject | Add-Member -MemberType 'ScriptProperty' -Name 'StartPassword'           -Value $get_StartPasswordScript               -SecondValue $set_StartPasswordScript           -Force
  $serviceObject | Add-Member -MemberType 'ScriptProperty' -Name 'Win32Status'             -Value $get_Win32StatusScript                 -SecondValue $set_Win32StatusScript             -Force
# $serviceObject | Add-Member -MemberType 'ScriptProperty' -Name 'Win32ServiceType'        -Value $get_Win32ServiceTypeScript            -SecondValue $set_Win32ServiceTypeScript        -Force		Covered by $this.ServiceType (overwrite? get, set)
  $serviceObject | Add-Member -MemberType 'ScriptProperty' -Name 'Win32_Service'           -Value $get_Win32_ServiceScript               -SecondValue $set_Win32_ServiceScript           -Force
# $serviceObject | Add-Member -MemberType 'MemberSet'      -Name 'PSStandardMembers'       -Value $PSStandardMembers                                                                     -Force
  $serviceObjects += $serviceObject
 }
 return $serviceObjects
#>

<#
 (,(Get-Service @PSBoundParameters)).ForEach({$_|
  Add-Member -MemberType 'ScriptProperty' -Name 'Description'   -Value $get_DescriptionScript   -SecondValue $set_DescriptionScript   -Force -PassThru |
  Add-Member -MemberType 'ScriptProperty' -Name 'PathName'      -Value $get_PathNameScript      -SecondValue $set_PathNameScript      -Force -PassThru |
  Add-Member -MemberType 'ScriptProperty' -Name 'ProcessId'     -Value $get_ProcessIdScript     -SecondValue $set_ProcessIdScript     -Force -PassThru |
  Add-Member -MemberType 'ScriptProperty' -Name 'StartMode'     -Value $get_StartModeScript     -SecondValue $set_StartModeScript     -Force -PassThru |
  Add-Member -MemberType 'ScriptProperty' -Name 'StartName'     -Value $get_StartNameScript     -SecondValue $set_StartNameScript     -Force -PassThru |
  Add-Member -MemberType 'ScriptProperty' -Name 'StartPassword' -Value $get_StartPasswordScript -SecondValue $set_StartPasswordScript -Force -PassThru |
  Add-Member -MemberType 'ScriptProperty' -Name 'Win32Status'   -Value $get_Win32StatusScript   -SecondValue $set_Win32StatusScript   -Force -PassThru |
  Add-Member -MemberType 'ScriptProperty' -Name 'Win32_Service' -Value $get_Win32_ServiceScript -SecondValue $set_Win32_ServiceScript -Force -PassThru
 })
#>

 Get-Service @PSBoundParameters | ForEach-Object {$_|
# Add-Member -MemberType 'ScriptProperty' -Name 'Caption'                 -Value $get_CaptionScript                     -SecondValue $set_CaptionScript                 -Force -PassThru | $this.Win32_Service.Caption (get, set)
  Add-Member -MemberType 'ScriptProperty' -Name 'Description'             -Value $get_DescriptionScript                 -SecondValue $set_DescriptionScript             -Force -PassThru |
# Add-Member -MemberType 'ScriptProperty' -Name 'DestopInteract'          -Value $get_DestopInteractScript              -SecondValue $set_DestopInteractScript          -Force -PassThru | $this.Win32_Service.DestopInteract (get, set)
# Add-Member -MemberType 'ScriptProperty' -Name 'ExitCode'                -Value $get_ExitCodeScript                    -SecondValue $set_ExitCodeScript                -Force -PassThru | $this.Win32_Service.ExitCode (no set)
  Add-Member -MemberType 'ScriptProperty' -Name 'PathName'                -Value $get_PathNameScript                    -SecondValue $set_PathNameScript                -Force -PassThru |
  Add-Member -MemberType 'ScriptProperty' -Name 'ProcessId'               -Value $get_ProcessIdScript                   -SecondValue $set_ProcessIdScript               -Force -PassThru |
# Add-Member -MemberType 'ScriptProperty' -Name 'ServiceSpecificExitCode' -Value $get_ServiceSpecificExitCodeCodeScript -SecondValue $set_ServiceSpecificExitCodeScript -Force -PassThru | $this.Win32_Service.ServiceSpecificExitCode (no set?)
  Add-Member -MemberType 'ScriptProperty' -Name 'StartMode'               -Value $get_StartModeScript                   -SecondValue $set_StartModeScript               -Force -PassThru |
  Add-Member -MemberType 'ScriptProperty' -Name 'StartName'               -Value $get_StartNameScript                   -SecondValue $set_StartNameScript               -Force -PassThru |
  Add-Member -MemberType 'ScriptProperty' -Name 'StartPassword'           -Value $get_StartPasswordScript               -SecondValue $set_StartPasswordScript           -Force -PassThru |
  Add-Member -MemberType 'ScriptProperty' -Name 'Win32Status'             -Value $get_Win32StatusScript                 -SecondValue $set_Win32StatusScript             -Force -PassThru |
# Add-Member -MemberType 'ScriptProperty' -Name 'Win32ServiceType'        -Value $get_Win32ServiceTypeScript            -SecondValue $set_Win32ServiceTypeScript        -Force -PassThru | Covered by $this.ServiceType (overwrite? get, set)
  Add-Member -MemberType 'ScriptProperty' -Name 'Win32_Service'           -Value $get_Win32_ServiceScript               -SecondValue $set_Win32_ServiceScript           -Force -PassThru #|
# Add-Member -MemberType 'MemberSet'      -Name 'PSStandardMembers'       -Value $PSStandardMembers                                                                     -Force -PassThru
 }
}

#$faxService = Get-ServiceExtended -Name 'Fax'
#$faxService | Select-Object *


<#
https://msdn.microsoft.com/en-us/library/aa394418(v=vs.85).aspx
CIMWin32.Win32_Service.Win32_BaseService
  UInt32   CheckPoint;				maybe .Win32_Service.Refresh() before each readout
#  string   CreationClassName;
#  boolean  DelayedAutoStart;			included in .StartMode
  string   ErrorControl;
  datetime InstallDate;
  System.Management.ManagementPath Path;	= .Win32_Service.ToString()
#  boolean  Started;				covered by .Status
  string   Status;				Hmm! .State? :) .Win32Status!
#  string   SystemCreationClassName;
  UInt32   TagId;
  UInt32   WaitHint;				maybe .Win32_Service.Refresh() before each readout
#>