function ConvertTo-Form {
 [CmdletBinding()]
 param (
  [Parameter(Mandatory=$true)][System.Xml.XmlDocument]$Manifest,
  [System.String]$IconFile = $null, #http://tomorrow.uspeoples.org/2012/06/windows-7-icon-files.html
  [System.Int32]$IconIndex = 0,
  [System.Management.Automation.SwitchParameter]$SmallIcon = $false #Probably never needed
 )

 $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

 Add-Type -AssemblyName 'System.Windows.Forms'

 function Add-FormElement {
  param (
   [System.Xml.XmlElement]$Node
  )

  $nodeCounter = $Node
  [System.Int32]$nodeLevel = -1
  while (($nodeCounter = $nodeCounter.ParentNode) -ne $null) {
   $nodeLevel++
  }
  $indentation = (' ' * $nodeLevel)

  $bindingFlags = [System.Reflection.BindingFlags]::Instance  -bor
                  [System.Reflection.BindingFlags]::NonPublic# -bor
#                  [System.Reflection.BindingFlags]::Public

  Write-Verbose ($indentation + 'Creating Object ' + ('System.Windows.Forms.' + $Node.CreateNavigator().Name))
  $object = New-Object -TypeName ('System.Windows.Forms.' + $Node.CreateNavigator().Name)
  $objectType = $object.GetType()
  foreach ($attribute in $Node.Attributes) {
   if (-not ($member = $objectType.GetMember($attribute.Name))) {
    $member = $objectType.GetMember($attribute.Name, $bindingFlags)
   }
   if ($member.Count -gt 1) {
    Write-Warning ($indentation + ' Multiple members named ' + $attribute.Name + ' exists on ' + $objectType.FullName + ' - picking first member')
   }
   $member = $member[0]
   if ($attributeType = $member.MemberType) {
    switch ($attributeType) {
### Property ###
     ([System.Reflection.MemberTypes]::Property) {
      if (-not ($method = $member.GetSetMethod())) {
       Write-Verbose ('No Public SetMethod - getting NonPublic SetMethod')
       $method = $member.GetSetMethod($true) # NonPublic
      }
      $secondaryMethod = $member.SetValue
      [System.Type]$attributeValueType = $method.GetParameters()[0].ParameterType
     }
### Method ###
     ([System.Reflection.MemberTypes]::Method) {
      if (($member.GetParameters() | Foreach-Object {$_.ParameterType.Name.Contains('EventHandler')}) -and $member.Name.Contains('add_')) {
       $eventName = $member.Name.Replace('add_','')
       Write-Warning ($indentation + ' "' + $member.Name + '" is a Method of ' + $objectType.FullName + ' - if trying to add an event handler, assign the handling scriptblock directly to Event "' + $eventName + '"')
      }
      else {
       Write-Warning ($indentation + ' "' + $member.Name + '" is a Method of ' + $objectType.FullName + ' - you cannot assign values to methods')
      }
     }
### Event ###
     ([System.Reflection.MemberTypes]::Event) {
      if (-not ($method = $member.GetAddMethod())) {
       Write-Verbose ('No Public AddMethod - getting NonPublic AddMethod')
       $method = $member.GetAddMethod($true) # NonPublic
      }
      $secondaryMethod = $member.AddEventHandler
      [System.Type]$attributeValueType = $method.GetParameters()[0].ParameterType
     }
### Default ###
     default {
      Write-Warning ($indentation + ' ' + $attributeType + ' ' + $member.Name + ' of ' + $objectType.FullName + ' - not supported')
     }
    }
    if ($method) {
     try {
      $null = [System.Management.Automation.ScriptBlock]::Create(('Set-Variable -Scope 1 -Name ''attributeValueParsed'' -Value (' + $attribute.Value + ')')).Invoke()
#Write-Host ('[' + $attributeValueParsed.GetType().FullName + '](' + $attributeValueParsed + ')') -ForegroundColor Cyan
      $attributeValue = $attributeValueParsed -as $attributeValueType
#Write-Host ('$attributeValue = ' + $attributeValue) -ForegroundColor Cyan
     }
     catch {
      Write-Warning ($indentation + '  Value "' + $attribute.Value + '" could not be parsed as ScriptBlock (missing an '' '' enclosure?) - reverting to simple cast as ' + $attributeValueType.FullName)
      if (-not ($attributeValue = $attribute.Value -as $attributeValueType)) {
       Write-Warning ($indentation + '  Value "' + $attribute.Value + '" could not be cast as ' + $attributeValueType.FullName)
      }
     }
#Write-Host ('$attribute.Value = [' + $attribute.Value.GetType().FullName + '](' + $attribute.Value + ')') -ForegroundColor Cyan
#Write-Host ('$attributeValueParsed = [' + $attributeValueParsed.GetType().FullName + '](' + $attributeValueParsed + ')') -ForegroundColor Cyan
#Write-Host ('$attributeValue = [' + $attributeValue.GetType().FullName + '](' + $attributeValue + ')') -ForegroundColor Cyan
     Write-Verbose ($indentation + ' Setting ' + $attributeType + ' "' + $member.Name + '" of ' + $objectType.FullName + ' to (' + $attribute.Value + ') as ' + $attributeValueType.FullName)
     try {
      [System.Void]$method.Invoke($object, $attributeValue)
     }
     catch {
      Write-Verbose ($indentation + '  ' + $method.Name + ' failed - attempting ' + $secondaryMethod.Name)
      [System.Void]$secondaryMethod.Invoke($object, $attributeValue)
     }
    }
    else {
     Write-Warning ($indentation + '  No method derived from attribute ' + $member.Name + ' of ' + $objectType.FullName + ' - skipping')
    }
   }
   else {
    Write-Warning ($indentation + ' ' + $attribute.Name + ' is not a member of ' + $objectType.FullName)
   }
  }

  foreach ($childNode in $Node.ChildNodes) {
   $childObject = Add-FormElement -Node $childNode
   Write-Verbose ($indentation + ' Adding control for ' + $childObject.GetType().FullName + ' to ' + $objectType.FullName)
   [System.Void]$object.Controls.Add($childObject)
  }

  return $object
 }

 $form = Add-FormElement -Node $Manifest.FirstChild

 if ($IconFile) {
  $iconExtractorCode = '
   using System;
   using System.Drawing;
   using System.Runtime.InteropServices;

   namespace System.Drawing {
    public class IconExtractor {
     public static Icon ExtractIcon(string filePath, int index, bool smallIcon) {
      IntPtr large;
      IntPtr small;
      ExtractIconEx(filePath, index, out large, out small, 1);
      try {
       return Icon.FromHandle(smallIcon ? small : large);
      }
      catch {
       return null;
      }
     }
     [DllImport("Shell32.dll", EntryPoint = "ExtractIconExW", CharSet = CharSet.Unicode, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
     private static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);
    }
   }
  '

  Add-Type -TypeDefinition $iconExtractorCode -ReferencedAssemblies 'System.Drawing'
  $form.Icon = [System.Drawing.IconExtractor]::ExtractIcon($IconFile, $IconIndex, (-not $SmallIcon))
 }

 return $form
}


<#
$global:test = {Write-Host $this.TopLevelControl.Size}

$xml = [xml]@'
<Form DoubleBuffered="$true" Height="250" Width="500" StartPosition="'CenterScreen'" Text="'A form...'" Opacity="0.75" KeyPreview='$true' KeyDown="{switch ([System.Windows.Forms.Keys]($_.KeyCode)) {([System.Windows.Forms.Keys]::Escape) {$this.Close()}}}">
 <TableLayoutPanel Height="75" Width="400" ColumnCount="3" RowCount="1" GrowStyle="'AddRows'" BorderStyle="'FixedSingle'" CellBorderStyle="'InsetDouble'">
  <Button Height="50" Width="100" Left="0" Text="'OK'" MouseClick="{$this.TopLevelControl.DialogResult=[System.Windows.Forms.DialogResult]::OK;$this.TopLevelControl.Close()}" />
  <Button Height="30" Width="150" Left="120" Text="Test Button 2" MouseClick="$test" />
  <TextBox Multiline="$true" Height="30" Width="150" Left="120" Lines="@('Some','Lines!') " />
 </TableLayoutPanel>
</Form>
'@

$form = ConvertTo-Form -Manifest $xml -Verbose
$result = $form.ShowDialog()
#>
