$user = "$($args[0])"
$password = "$($args[1])"

$CertName = $env:computername
$CSRPath = "$($CertName)_.csr"
$CertPath = "$($CertName)_.crt"
$INFPath = "$($CertName)_.inf"
$Signature = '$Windows NT$'

if (Test-Path $CSRPath) {Remove-Item $CSRPath}
if (Test-Path $INFPath) {Remove-Item $INFPath}
if (Test-Path $CertPath) {Remove-Item $CertPath}

$INF =
@"
[Version]
Signature= "$Signature"

[NewRequest]
Subject = "CN=$CertName, OU=Ascent Global Logistics, O=IT, L=Downers Grove, S=Illinois, C=US"
KeySpec = 1
KeyLength = 2048
Exportable = TRUE
MachineKeySet = TRUE
SMIME = False
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
ProviderType = 12
RequestType = PKCS10
KeyUsage = 0xa0

[EnhancedKeyUsageExtension]

OID=1.3.6.1.5.5.7.3.1
"@

$INF | out-file -filepath $INFPath -force
certreq -new $INFPath $CSRPath

$invocation = (Get-Variable MyInvocation).Value
$directorypath = Split-Path $invocation.MyCommand.Path
$csr = [IO.File]::ReadAllText("$directoryPath\$($CertName)_.csr")

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add('Content-Type','application/json;charset=utf-8')
$headers.Add('customerUri','AGL')
$headers.Add('login',$user)
$headers.Add('password',$password)

$body = @{
      orgId = 16273
      csr = $csr
      certType = 14528
}

$response = Invoke-RestMethod https://cert-manager.com/api/device/v1/enroll -Headers $headers -Body ($body|ConvertTo-Json) -Method POST
$order = $response.orderNumber

$cert = Invoke-RestMethod https://cert-manager.com/api/device/v1/collect/$order/x509CO -Headers $headers -Method GET
Write-Output $cert | Out-File $CertPath

$ca = Invoke-RestMethod https://cert-manager.com/api/device/v1/collect/$order/x509IO -Headers $headers -Method GET

$certs = $ca | select-string -AllMatches '(?sm)-----BEGIN CERTIFICATE-----(.*?)-----END CERTIFICATE-----'
$certs.Matches[0] | Out-File root.crt
$certs.Matches[1] | Out-File ca.crt

certutil -addstore "Root" root.crt
certutil -addstore "CA" ca.crt
certreq -Accept $CertPath