function Speak-String {
 [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
 param (
  [Parameter(Mandatory=$false,ValueFromPipeline=$true)][string]$String = $null,
  [Parameter(Mandatory=$false)][string]$VoiceName = $null,
  [Parameter(Mandatory=$false)][int]$Rate = 0,
  [Parameter(Mandatory=$false)][int]$Volume = 100,
  [Parameter(Mandatory=$false)][switch]$ListVoices = $false,
  [Parameter(Mandatory=$false)][switch]$CancelSpeech = $true,
  [Parameter(Mandatory=$false,ValueFromPipeline=$true)]$Synthesizer = $null,
  [Parameter(Mandatory=$false)][switch]$Async = $true
 )

 if ($Synthesizer) {
  if (-not ($Synthesizer.GetType().Name -eq 'SpeechSynthesizer')) {
   Write-Verbose "Synthesizer not of type System.Speech.Synthesis.SpeechSynthesizer - assuming pipeline input is input string"
   $Synthesizer = $null
   if ($CancelSpeech) {
    Write-Verbose "Can't cancel speech without a SpeechSynthesizer object."
   }
  }
 }

 if (-not $Synthesizer) {
  Add-Type -AssemblyName System.Speech
  $synthesizer = New-Object -TypeName 'System.Speech.Synthesis.SpeechSynthesizer'

  $i = 0
  $waitTime = 50
  $timeOut = 1000
  while ($synthesizer.State -ne 'Ready') {
   if ($i -gt $timeOut) {
    throw "Speak synthesizer timed out!"
   }
   Start-Sleep -Milliseconds $waitTime
   $i += $waitTime
  }
 }

 if (-not ($ListVoices -or $String -or $CancelSpeech)) {
  Write-Warning "Nothing to say!"
 }

 if ($synthesizer.State -eq 'Speaking' -and $CancelSpeech) {
  $synthesizer.SpeakAsyncCancelAll()
 }

 if ($ListVoices) {
  Write-Host "List of installed voices:"
  foreach ($voice in $synthesizer.GetInstalledVoices()) {
   $voice.VoiceInfo
  }
 }

 if ($String) {
  if ($VoiceName) {
   $synthesizer.SelectVoice($VoiceName)
  }
  $synthesizer.Rate = $Rate
  $synthesizer.Volume = $Volume
  if ($Async) {
   $null = $synthesizer.SpeakAsync($String)
  }
  else {
   $null = $synthesizer.Speak($String)
  }
  return $synthesizer
 }
}

<#
$speak = "Pronunciations specified in an external lexicon file take precedence over the pronunciations of the speech synthesizer's internal lexicon or dictionary. However, pronunciations specified inline in prompts created with any of the AppendTextWithPronunciation, AppendSsmlMarkup, or AppendSsml methods take precedence over pronunciations specified in any lexicon. Inline pronunciations apply only to a single occurrence of a word. See Lexicons and Phonetic Alphabets for more information." | Speak-String -Voice 'Microsoft Hazel Desktop'
Start-Sleep -Seconds 2
$speak | Speak-String -String 'Hello World!'


$synth = Speak-String -String '.'
$i = 0
#$i = 1000000
while (1) {
 $i += 1000
 Start-Sleep -Seconds 4
 Speak-String -String "$i dollars accrued" -Synthesizer $synth
}
#>
