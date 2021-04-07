#Get certificate from Local Machine\Personal store issued by the Ascent CA
$cert = Get-ChildItem -Path Cert:\LocalMachine\My\ | Where-Object {$_.Subject -like "*Ascent*"}

#Get key info from certificate
$rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
$fileName = $rsa.key.UniqueName

#Path to key
$filePath = "$env:ALLUSERSPROFILE\Microsoft\Crypto\RSA\MachineKeys\$fileName"

#Get permissions of key
$perms = Get-Acl -Path $filePath

#Define access rule
$rule = New-Object Security.AccessControl.FileSystemAccessRule "Authenticated Users","FullControl","Allow"

#Add access rule to permissions
$perms.AddAccessRule($rule)

#Apply updated permissions to key
Set-Acl -Path $filePath -AclObject $perms