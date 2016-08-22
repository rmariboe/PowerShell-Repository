function Get-ContentLength {
 param (
  [System.Uri]$Uri
 )

 [System.Net.WebRequest]$webRequest = [System.Net.WebRequest]::Create([System.Uri]$Uri)

 switch ($webRequest.GetType()) {
  [System.Net.HttpWebRequest] {
   $webRequest.Method = [System.Net.WebRequestMethods+Http]::Head
  }

  [System.Net.FtpWebRequest] {
   $webRequest.Method = [System.Net.WebRequestMethods+Ftp]::GetFileSize
  }

  [System.Net.FileWebRequest] {
   throw ('Can''t get content length from "File" request')
  }
 }

 [System.Net.WebResponse]$webResponse = $webRequest.GetResponse()
 [System.Int64]$contentLength = $webResponse.ContentLength

 return $contentLength
}
