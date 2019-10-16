$zip = $args[0]
$target = $args[1]

Write-Verbose -Verbose "Extracting $zip to $target"
Add-Type -AssemblyName System.IO.Compression.FileSystem ; 
[System.IO.Compression.ZipFile]::ExtractToDirectory("$zip", "$target")
