param (
 $Name = '*',
 $First = 10,
 $Property = @('PM', 'Name'),
 $AutoRefresh = $false
)

$head = '<title>Get-Process</title>'
if ($AutoRefresh) {
 $head += '<meta http-equiv="refresh" content="' + $AutoRefresh + '" />'
}

$result = Get-Process -Name $Name |
 Select-Object -Property $Property -First $First |
 Sort-Object -Property $Property -Descending |
 ConvertTo-HTML -Head $head -Body '<h2>Get-Process</h2>'

return $result

#$PSBoundParameters
#$args