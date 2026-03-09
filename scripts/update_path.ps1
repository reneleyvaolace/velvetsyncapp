$PathToAdd = "C:\src\flutter\bin"
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$PathToAdd*") {
    $NewPath = "$UserPath;$PathToAdd"
    [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
    Write-Host "PATH actualizado con: $PathToAdd"
} else {
    Write-Host "PATH ya contiene: $PathToAdd"
}
