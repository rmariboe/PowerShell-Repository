function Unpack-GZip {
 param (
  [System.Byte[]]$Buffer
 )
 Add-Type -Assembly 'System.IO.Compression'

 [System.IO.MemoryStream]$gZipMemoryStream = [System.IO.MemoryStream]([System.Byte[]]$Buffer)
 [System.IO.Compression.GZipStream]$gZipStream = New-Object -TypeName 'System.IO.Compression.GZipStream' -ArgumentList ([System.IO.Stream]$gZipMemoryStream, [System.IO.Compression.CompressionMode]::Decompress)

 [System.IO.MemoryStream]$memoryStream = New-Object -TypeName 'System.IO.MemoryStream'
 [System.Int32]$unpackBufferSize = 1024
 [System.Byte[]]$unpackBuffer = New-Object -TypeName 'System.Byte[]' -ArgumentList ([System.Int32]$unpackBufferSize)
 while ([System.Int32]$count = $gZipStream.Read([System.Byte[]]$unpackBuffer, [System.Int32]0, [System.Int32]$unpackBufferSize)) {
  $memoryStream.Write([System.Byte[]]$unpackBuffer, [System.Int32]0, [System.Int32]$count)
 }

 $gZipStream.Close()
 $gZipStream.Dispose()

 $gZipMemoryStream.Close()
 $gZipMemoryStream.Dispose()

 [System.Byte[]]$buffer = [System.Byte[]]($memoryStream.GetBuffer()[0..($memoryStream.Length-1)])
 $memoryStream.Close()
 $memoryStream.Dispose()

 return [System.Byte[]]$buffer
}


function Decompress-Base64StringToObject {
 param (
  [System.String]$String
 )

 [System.Byte[]]$serializedGZip = [System.Convert]::FromBase64String([System.String]$String)
 [System.Byte[]]$serializedBuffer = Unpack-GZip -Buffer ([System.Byte[]]$serializedGZip)
 [System.IO.MemoryStream]$memoryStream = [System.IO.MemoryStream]$serializedBuffer

 [System.Runtime.Serialization.Formatters.Binary.BinaryFormatter]$binaryFormatter = New-Object -TypeName 'System.Runtime.Serialization.Formatters.Binary.BinaryFormatter'

 return [System.Object]$binaryFormatter.Deserialize([System.IO.Stream]$memoryStream)
}
