Add-Type -AssemblyName System.Drawing
$path = "fonts\*.ttf"

$ttfFiles = Get-ChildItem $path

$fontCollection = new-object System.Drawing.Text.PrivateFontCollection

$ttfFiles | ForEach-Object {
    $fontCollection.AddFontFile($_.fullname)

    $fontCollection.Families[-1].Name
}
