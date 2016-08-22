&"$PSScriptRoot\New-Timer.ps1"

function Write-DownloadProgress {
 [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
 Param (
  [Parameter(Mandatory=$true)][string]$Url,
  [Parameter(Mandatory=$true)][string]$Path,
  [Parameter(Mandatory=$false)][int]$UpdateTimeout = 100,
  [Parameter(Mandatory=$true)][string]$ProgressSourceIdentifier,
  [Parameter(Mandatory=$true)][string]$CompletedSourceIdentifier,
  [Parameter(Mandatory=$false)][int32]$ProgressBarID = [math]::Abs($ProgressSourceIdentifier.GetHashCode()),
  [Parameter(Mandatory=$false)][array]$EventTicks = @(),
  [Parameter(Mandatory=$false)][array]$EventBytes = @(),
  [Parameter(Mandatory=$false)][int32]$MeasuringPoints = (1000/$UpdateTimeout)*10,
  [Parameter(Mandatory=$false)][double]$MBytesToRecieve = 0
 )

 if ($progress = Get-LastEvent -SourceIdentifier $ProgressSourceIdentifier) {
  $EventTicks += $progress.TimeGenerated.Ticks
  $EventBytes += $progress.SourceEventArgs.BytesReceived
  if ($EventTicks.Count -gt $MeasuringPoints) {
   $EventTicks = $EventTicks[($EventTicks.Count-$MeasuringPoints)..($EventTicks.Count-1)]
   $EventBytes = $EventBytes[($EventBytes.Count-$MeasuringPoints)..($EventBytes.Count-1)]
  }

  $MBytesToRecieve = [math]::Round(($progress.SourceEventArgs.TotalBytesToReceive / 1024 / 1024), 2)
 }
 $mBytesDownloaded = [math]::Round($EventBytes[-1] / 1024 / 1024, 2)

 try {
  $lastEvent = -1
  $firstEvent = -[math]::Min($EventTicks.Count,$MeasuringPoints)
  $bandWidth = [math]::Round((($EventBytes[$lastEvent] - $EventBytes[$firstEvent]) / 1024 / (($EventTicks[$lastEvent] - $EventTicks[$firstEvent]) / 10000000)),2)
  $secondsRemaining = (($MBytesToRecieve - $mBytesDownloaded) / ($bandWidth / 1024))
 }
 catch {
  $bandWidth = 'Calculating'
  $secondsRemaining = -1
 }

 if ($completed = Get-LastEvent -SourceIdentifier $CompletedSourceIdentifier -Purge:$false) {
  if ($completed.SourceEventArgs.Cancelled) {
   $reason = 'cancelled'
  }
  else {
   $reason = 'completed'
  }
  Write-Progress -Activity "Downloading $Url to $Path" -Status "$mBytesDownloaded of $MBytesToRecieve MB downloaded" -CurrentOperation "Download $reason" -Id $ProgressBarID -ParentId -1
 }
 elseif ($progress) {
  Write-Progress -Activity "Downloading $Url to $Path" -Status "$mBytesDownloaded of $MBytesToRecieve MB downloaded" -CurrentOperation "$bandWidth kB/s" -Id $ProgressBarID -ParentId -1 -PercentComplete $progress.SourceEventArgs.ProgressPercentage -SecondsRemaining $secondsRemaining
 }

 if (-not $completed) {
  $eventTicksSerialized = '@(' + [string]::Join(',',$EventTicks) + ')'
  $eventBytesSerialized = '@(' + [string]::Join(',',$EventBytes) + ')'
  $timerAction = [scriptblock]::Create("Write-DownloadProgress -Url $Url -Path $Path -UpdateTimeout $UpdateTimeout -ProgressSourceIdentifier $ProgressSourceIdentifier -CompletedSourceIdentifier $CompletedSourceIdentifier -ProgressBarID $ProgressBarID -EventTicks $eventTicksSerialized -EventBytes $eventBytesSerialized -MBytesToRecieve $MBytesToRecieve")
  $null = New-Timer -Interval $UpdateTimeout -Action $timerAction -AutoReset:$false -Enabled:$true
 }
}


&"$PSScriptRoot\Get-LastEvent.ps1"

function Download-FileAsync {
 [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
 param (
  [Parameter(Mandatory=$true)][uri]$Uri,
  [Parameter(Mandatory=$false)]$Path = (Get-Item .),
  [Parameter(Mandatory=$false)][string]$Filename = $Uri.Segments[-1],
  [Parameter(Mandatory=$false)][System.Net.WebClient]$WebClient = (New-Object System.Net.WebClient),
  [Parameter(Mandatory=$false)][switch]$WriteProgress = $true,
  [Parameter(Mandatory=$false)][switch]$ChimeOnCompleted = $true
 )
 $Path = (Get-Item $Path).FullName

 if (-not (Test-Path -Path $Path)) {
  New-Item -Path $Path -Type Directory
 }

 $downloadGuid = [guid]::NewGuid().Guid

 $null = Register-ObjectEvent -InputObject $WebClient -EventName DownloadProgressChanged -SourceIdentifier "Download-$downloadGuid-Progress"

 if ($ChimeOnCompleted) {
  $null = Register-ObjectEvent -InputObject $WebClient -EventName DownloadFileCompleted -SourceIdentifier "Download-$downloadGuid-CompletedChime" -Action {Write-Host $([char]7) -NoNewline}
 }
 $null = Register-ObjectEvent -InputObject $WebClient -EventName DownloadFileCompleted -SourceIdentifier "Download-$downloadGuid-Completed"

 $defaultProperties = @('Uri','Path','Status','ProgressPercentage')
 $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultProperties)
 $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)

 $downloadObject = New-Object -TypeName PSObject
 $downloadObject | Add-Member -MemberType NoteProperty -Name 'Uri' -Value $Uri
 $downloadObject | Add-Member -MemberType NoteProperty -Name 'Path' -Value ($Path+'\'+$Filename)
 $downloadObject | Add-Member -MemberType ScriptProperty -Name 'Status' -Value {if ($this.LastFileCompletedEvent) {if ($this.LastFileCompletedEvent.SourceEventArgs.Cancelled) {'Cancelled'} else {'Completed'}} else {if ($this.ProgressPercentage -ne $null) {'Downloading'} else {'Waiting'}}}
 $downloadObject | Add-Member -MemberType ScriptProperty -Name 'ProgressPercentage' -Value {$this.LastProgressChangedEvent.SourceEventArgs.ProgressPercentage}
 $downloadObject | Add-Member -MemberType ScriptProperty -Name 'TotalBytesToReceive' -Value {$this.LastProgressChangedEvent.SourceEventArgs.TotalBytesToReceive}
 $downloadObject | Add-Member -MemberType ScriptProperty -Name 'BytesReceived' -Value {$this.LastProgressChangedEvent.SourceEventArgs.BytesReceived}
 $downloadObject | Add-Member -MemberType ScriptMethod -Name 'CancelDownload' -Value {param ([switch]$KeepFile=$false); $this.WebClient.CancelAsync(); if(-not $KeepFile) {Remove-Item -Path $this.Path}}
 $downloadObject | Add-Member -MemberType NoteProperty -Name 'WebClient' -Value $WebClient
 $downloadObject | Add-Member -MemberType ScriptProperty -Name 'DownloadProgressChangedEventJob' -Value ([scriptblock]::Create("Get-EventSubscriber -SourceIdentifier 'Download-$downloadGuid-Progress'"))
 $downloadObject | Add-Member -MemberType ScriptProperty -Name 'DownloadFileCompletedEventJob' -Value ([scriptblock]::Create("Get-EventSubscriber -SourceIdentifier 'Download-$downloadGuid-Completed'"))
 $downloadObject | Add-Member -MemberType ScriptProperty -Name 'LastProgressChangedEvent' -Value {Get-LastEvent -SourceIdentifier $this.DownloadProgressChangedEventJob.SourceIdentifier}
 $downloadObject | Add-Member -MemberType ScriptProperty -Name 'LastFileCompletedEvent' -Value {Get-LastEvent -SourceIdentifier $this.DownloadFileCompletedEventJob.SourceIdentifier -Purge:$false}
 $downloadObject | Add-Member -MemberType MemberSet -Name 'PSStandardMembers' -Value $PSStandardMembers

 $WebClient.DownloadFileAsync($Uri.AbsoluteUri, ($Path+'\'+$Filename))

 if ($WriteProgress) {
  Write-DownloadProgress -Url $Uri -Path ($Path+'\'+$Filename) -ProgressSourceIdentifier "Download-$downloadGuid-Progress" -CompletedSourceIdentifier "Download-$downloadGuid-Completed"
 }

 return $downloadObject
}

<#
$DownloadObject = Download-File -URI 'http://download.microsoft.com/download/1/C/8/1C826863-3927-4FB9-ABC8-1191377CBC9D/oserversp2010-kb2687453-fullfile-x64-da-dk.exe'
$DownloadObject2 = Download-File -URI 'http://download.microsoft.com/download/7/7/F/77F250DC-F7A3-47AF-8B20-DDA8EE110AB4/wacserver.img'
$DownloadObject3 = Download-File -URI 'http://download.microsoft.com/download/6/7/D/67D80164-7DD0-48AF-86E3-DE7A182D6815/rewrite_amd64_en-US.msi'
$DownloadObject4 = Download-File -URI 'http://download.microsoft.com/download/3/4/1/3415F3F9-5698-44FE-A072-D4AF09728390/webfarm_amd64_en-US.msi'
$DownloadObject5 = Download-File -URI 'http://download.microsoft.com/download/A/A/E/AAE77C2B-ED2D-4EE1-9AF7-D29E89EA623D/requestRouter_amd64_en-US.msi'
$DownloadObject6 = Download-File -URI 'http://download.microsoft.com/download/3/4/1/3415F3F9-5698-44FE-A072-D4AF09728390/ExternalDiskCache_amd64_en-US.msi'
$DownloadObject7 = Download-File -URI 'http://go.microsoft.com/fwlink/?LinkId=255386' -Filename 'WebPI.exe'
$DownloadObject = Download-File -URI 'http://download.microsoft.com/download/1/C/8/1C826863-3927-4FB9-ABC8-1191377CBC9D/oserversp2010-kb2687453-fullfile-x64-da-dk.exe' -Path 'C:\install'

$test = Download-FileAsync -Uri 'http://care.dlservice.microsoft.com/dl/download/C/3/0/C30FD525-BE4A-45CB-83A9-02D7530F5B0B/ProjectServer_x64_en-us.img' -ChimeOnCompleted:$true -WriteProgress:$true
#>

