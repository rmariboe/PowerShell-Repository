function Navigate-DomainTree {
 param (
  [System.DirectoryServices.DirectoryEntry]$DirectoryEntry = ('LDAP://' + (New-Object System.DirectoryServices.DirectoryEntry).distinguishedName) # Will take LDAP path or DirectoryEntry object
 )

 $iconExtractorCode = @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;

namespace System.Drawing {
 public class IconExtractor {
  public static Icon ExtractIcon(string filePath, int index, bool largeIcon) {
   IntPtr large;
   IntPtr small;
   ExtractIconEx(filePath, index, out large, out small, 1);
   try {
    return Icon.FromHandle(largeIcon ? large : small);
   }
   catch {
    return null;
   }
  }
  [DllImport("Shell32.dll", EntryPoint = "ExtractIconExW", CharSet = CharSet.Unicode, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
  private static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);
 }
}
"@

 Add-Type -TypeDefinition $iconExtractorCode -ReferencedAssemblies 'System.Drawing'

 Add-Type -AssemblyName 'System.Windows.Forms'

 function Update-DirectoryEntriesListBox {
  param (
   [System.DirectoryServices.DirectoryEntry]$DirectoryEntry = (New-Object System.DirectoryServices.DirectoryEntry)
  )
  $global:currentDirectoryEntry = $DirectoryEntry
  $form.Text = $DirectoryEntry.Path + ' - updating view...'
  $directoryEntriesListBox.Items.Clear()

  if ($DirectoryEntry.Path -and -not $DirectoryEntry.Path.StartsWith('LDAP://DC=')) {
   $directoryEntriesListBox.Items.Add($DirectoryEntry.Parent.ToString())
  }

  if ([string[]]$directoryEntriesListBoxItems = $DirectoryEntry.Children | Select-Object -ExpandProperty Path) {
   $null = $directoryEntriesListBox.Items.AddRange($directoryEntriesListBoxItems)
  }

  $form.Text = $DirectoryEntry.Path + ' - ' + ($directoryEntriesListBox.Items.Count-1) + ' elements'
 }

 function Update-DirectoryEntryInfoListBox {
  param (
   [System.DirectoryServices.DirectoryEntry]$DirectoryEntry = (New-Object System.DirectoryServices.DirectoryEntry)
  )
  $directoryEntryInfoListBox.Items.Clear()

  foreach ($key in @($DirectoryEntry.Properties.Keys | Sort-Object)) {
   $null = $directoryEntryInfoListBox.Items.Add(($key + ' = ' + $DirectoryEntry.Properties[$key]))
  }
 }

 $form = New-Object System.Windows.Forms.Form
# $form.Size = [System.Drawing.Size](@{Width=1024;Height=768})
 $form.SetDesktopBounds(0,0,1024,768)
# $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSHOME\powershell.exe")
# $form.Icon = [System.Drawing.IconExtractor]::ExtractIcon("imageres.dll", 7, $true)
# $form.Icon = [System.Drawing.IconExtractor]::ExtractIcon("imageres.dll", 13, $true)
# $form.Icon = [System.Drawing.IconExtractor]::ExtractIcon("imageres.dll", 168, $true)
# $form.Icon = [System.Drawing.IconExtractor]::ExtractIcon("imageres.dll", 204, $true)
# $form.Icon = [System.Drawing.IconExtractor]::ExtractIcon("imageres.dll", 299, $true)
# $form.Icon = [System.Drawing.IconExtractor]::ExtractIcon("shell32.dll", 22, $true)
 $form.Icon = [System.Drawing.IconExtractor]::ExtractIcon("shell32.dll", 218, $true)
 $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen

 $form.KeyPreview = $true
 $form.Add_KeyDown({switch ([System.Windows.Forms.Keys]$_.KeyCode) {
  'Enter'  {if ($directoryEntriesListBox.SelectedItem) {Update-DirectoryEntriesListBox -DirectoryEntry $directoryEntriesListBox.SelectedItem}}
  'Return' {if ($directoryEntriesListBox.SelectedItem) {Update-DirectoryEntriesListBox -DirectoryEntry $directoryEntriesListBox.SelectedItem}}
  'Back'   {if (-not $currentDirectoryEntry.Path.StartsWith('LDAP://DC=')) {Update-DirectoryEntriesListBox -DirectoryEntry $currentDirectoryEntry.Parent}}
  'Escape' {$form.Close()}
  default  {}
 }})

 $global:directoryEntriesListBox = New-Object System.Windows.Forms.ListBox
# $directoryEntriesListBox.Location = [System.Drawing.Point]@{X=$form.Margin.Left;Y=$form.Margin.Top}
 $directoryEntriesListBoxLocationX = $form.Margin.Left
 $directoryEntriesListBoxLocationY = $form.Margin.Top
 $directoryEntriesListBoxWidth = $form.Width / 2 - $form.Margin.Horizontal
 $directoryEntriesListBoxHeight = $form.Height - $form.Margin.Vertical * 2 - 25
 $directoryEntriesListBox.SetBounds($directoryEntriesListBoxLocationX, $directoryEntriesListBoxLocationY, $directoryEntriesListBoxWidth, $directoryEntriesListBoxHeight)
# $directoryEntriesListBox.AutoSize = $true
# $directoryEntriesListBoxHeight = $directoryEntriesListBox.Height - $form.Margin.Vertical
 $directoryEntriesListBox.SetBounds($directoryEntriesListBoxLocationX, $directoryEntriesListBoxLocationY, $directoryEntriesListBoxWidth, $directoryEntriesListBoxHeight)
 $null = $directoryEntriesListBox.Items.Add('directoryEntriesListBox')

 Update-DirectoryEntriesListBox -DirectoryEntry $DirectoryEntry

 $directoryEntriesListBox.add_SelectedValueChanged({Update-DirectoryEntryInfoListBox -DirectoryEntry $directoryEntriesListBox.SelectedItem})
 $directoryEntriesListBox.add_DoubleClick({if ($directoryEntriesListBox.SelectedItem) {Update-DirectoryEntriesListBox -DirectoryEntry $directoryEntriesListBox.SelectedItem}})

 $form.Controls.Add($directoryEntriesListBox) 

 $global:directoryEntryInfoListBox = New-Object System.Windows.Forms.ListBox
# $directoryEntryInfoListBox.Location = [System.Drawing.Point]@{X=$form.Width / 2 + $form.Margin.Left * 2;Y=$form.Margin.Top}
 $directoryEntryInfoListBoxLocationX = $form.Width / 2 + $form.Margin.Left * 2
 $directoryEntryInfoListBoxLocationY = $form.Margin.Top
 $directoryEntryInfoListBoxWidth = $form.Width / 2 - $form.Margin.Horizontal
 $directoryEntryInfoListBoxHeight = $form.Height - $form.Margin.Vertical * 2 - 25
 $directoryEntryInfoListBox.SetBounds($directoryEntryInfoListBoxLocationX, $directoryEntryInfoListBoxLocationY, $directoryEntryInfoListBoxWidth, $directoryEntryInfoListBoxHeight)
# $directoryEntryInfoListBox.AutoSize = $true
# $directoryEntryInfoListBoxHeight = $directoryEntryInfoListBox.Height - $form.Margin.Vertical
 $directoryEntryInfoListBox.SetBounds($directoryEntryInfoListBoxLocationX, $directoryEntryInfoListBoxLocationY, $directoryEntryInfoListBoxWidth, $directoryEntryInfoListBoxHeight)
 $null = $directoryEntryInfoListBox.Items.Add('directoryEntryInfoListBox')

 Update-DirectoryEntryInfoListBox -DirectoryEntry $DirectoryEntry

 $form.Controls.Add($directoryEntryInfoListBox)

# $form.add_Closing({return $currentDirectoryEntry}) # Find way to get item out

 $null = $form.ShowDialog()

 return $currentDirectoryEntry
}
$dirEnt = Navigate-DomainTree

