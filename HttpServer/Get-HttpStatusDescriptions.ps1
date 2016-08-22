# IANAXML
function Get-HttpStatusDescriptions {
 [System.Uri]$httpStatusCodesUri = 'http://www.iana.org/assignments/http-status-codes/http-status-codes.xml'
 [System.Xml.XmlDocument]$httpStatusCodesXml = Invoke-WebRequest -Uri $httpStatusCodesUri -UseBasicParsing
 $httpStatusCodesXml.registry.registry.note

 $maxHttpStatusCode = $httpStatusCodesXml.registry.registry.record | ForEach-Object {[System.Management.Automation.ScriptBlock]::Create($_.Value.Replace('-', '..')).Invoke()} | Measure-Object -Maximum | Select-Object -ExpandProperty 'Maximum'

 $httpStatusDescriptions = New-Object -TypeName 'System.String[]' -ArgumentList ($maxHttpStatusCode + 1)

 foreach ($httpStatusCodeRecord in $httpStatusCodesXml.registry.registry.record) {
  if ($httpStatusCodeRecord.xref) {
   foreach ($httpStatusCode in [System.Management.Automation.ScriptBlock]::Create($httpStatusCodeRecord.Value.Replace('-', '..')).Invoke()) {
    $httpStatusDescriptions[$httpStatusCode] = $httpStatusCodeRecord.description
   }
  }
 }

 return $httpStatusDescriptions
}


# IANACSV
function Get-HttpStatusDescriptions {
 [System.Uri]$httpStatusCodesUri = 'http://www.iana.org/assignments/http-status-codes/http-status-codes-1.csv'
 $httpStatusCodes = New-Object -TypeName 'System.Collections.Hashtable'
 foreach ($httpStatusCode in (Invoke-WebRequest -Uri $httpStatusCodesUri -UseBasicParsing | ConvertFrom-Csv)) {
  if ($httpStatusCodeInt = $httpStatusCode.Value -as [System.Int32]) {
   $httpStatusCodes.Add($httpStatusCodeInt, $httpStatusCode.Description)
  }
 }

 return $httpStatusCodes
}


#DOTNET
function Get-HttpStatusDescriptions {
 $ErrorActionPreference = 'Stop'
 $httpStatusCodes = New-Object -TypeName 'System.Collections.Hashtable'
 foreach ($httpStatusCode in [System.Net.HttpStatusCode].GetFields([System.Reflection.BindingFlags]'Public,Static')) {
  try {
   $httpStatusCodes.Add($httpStatusCode.GetRawConstantValue(), $httpStatusCode.Name)
  }
  catch {
#   $httpStatusCodes.Add(($httpStatusCode.GetRawConstantValue() + 0.1), $httpStatusCode.Name)
  }
 }
 $ErrorActionPreference = 'Continue'

 return $httpStatusCodes
}

