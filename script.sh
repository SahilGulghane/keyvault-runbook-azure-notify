param (
    [Parameter (Mandatory = $false)]
    [object] $WebhookData
)

try {
    # Define the Service Principal credentials
    $tenantId = "----"
    $clientId = "-----"
    $clientSecret = "-----"

    # Login using the Service Principal
    az login --service-principal --username $clientId --password $clientSecret --tenant $tenantId | Out-Null

    Write-Output "Successfully authenticated to Azure."

    # Get the current date and time in UTC
    $currentDate = Get-Date

    # Calculate the date one month from now
    $oneMonthFromNow = $currentDate.AddMonths(3)

    # Get all Key Vaults in the subscription
    $keyVaults = az keyvault list --query '[].{VaultName:name}' --output json | ConvertFrom-Json

    # Initialize an empty array to store expiring objects
    $expiringObjects = @()

    foreach ($vault in $keyVaults) {
        $vaultName = $vault.VaultName

        # Get all secrets
        $secrets = az keyvault secret list --vault-name $vaultName --query '[].{Name:name, Expiry:attributes.expires}' --output json | ConvertFrom-Json
foreach ($secret in $secrets) {
    $expiryDate = $secret.Expiry
    if ($expiryDate) {
        $parsedDate = $null
        try {
            $parsedDate = [DateTime]::ParseExact($expiryDate, 'yyyy-MM-ddTHH:mm:ssZ', $null, [System.Globalization.DateTimeStyles]::AssumeUniversal)
        }
        catch {
            try {
                $parsedDate = [DateTime]::ParseExact($expiryDate, 'MM/dd/yyyy HH:mm:ss', $null)
            }
            catch {
                Write-Warning "Could not parse expiry date for secret: $expiryDate"
            }
        }
        
        if ($parsedDate -and ($parsedDate -lt $oneMonthFromNow)) {
            $expiringObjects += [PSCustomObject]@{
                Type       = "Secret"
                Name       = $secret.Name  # Use Name directly
                ExpiryDate = $parsedDate
                VaultName  = $vaultName
                ExpiryDateIST = if ($parsedDate) {
                    ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($parsedDate, "India Standard Time")).ToString("yyyy-MM-dd HH:mm:ss")
                }
            }
        }
    }
}
        # Get all keys
        $keys = az keyvault key list --vault-name $vaultName --query '[].{Name:name, Expiry:attributes.expires}' --output json | ConvertFrom-Json
        foreach ($key in $keys) {
            $expiryDate = $key.Expiry
            if ($expiryDate) {
                $parsedDate = $null
                try {
                    $parsedDate = [DateTime]::ParseExact($expiryDate, 'yyyy-MM-ddTHH:mm:ssZ', $null, [System.Globalization.DateTimeStyles]::AssumeUniversal)
                }
                catch {
                    try {
                        $parsedDate = [DateTime]::ParseExact($expiryDate, 'MM/dd/yyyy HH:mm:ss', $null)
                    }
                    catch {
                        Write-Warning "Could not parse expiry date for key: $expiryDate"
                    }
                }
                
                if ($parsedDate -and ($parsedDate -lt $oneMonthFromNow)) {
                    $expiringObjects += [PSCustomObject]@{
                        Type       = "Key"
                        Name       = $key.Name
                        ExpiryDate = $parsedDate
                        VaultName  = $vaultName
                        ExpiryDateIST = if ($parsedDate) {
                            ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($parsedDate, "India Standard Time")).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                    }
                }
            }
        }

        # Get all certificates
        $certificates = az keyvault certificate list --vault-name $vaultName --query '[].{Name:name, Expiry:attributes.expires}' --output json | ConvertFrom-Json
        foreach ($certificate in $certificates) {
            $expiryDate = $certificate.Expiry
            if ($expiryDate) {
                $parsedDate = $null
                try {
                    $parsedDate = [DateTime]::ParseExact($expiryDate, 'yyyy-MM-ddTHH:mm:ssZ', $null, [System.Globalization.DateTimeStyles]::AssumeUniversal)
                }
                catch {
                    try {
                        $parsedDate = [DateTime]::ParseExact($expiryDate, 'MM/dd/yyyy HH:mm:ss', $null)
                    }
                    catch {
                        Write-Warning "Could not parse expiry date for certificate: $expiryDate"
                    }
                }
                
                if ($parsedDate -and ($parsedDate -lt $oneMonthFromNow)) {
                    $expiringObjects += [PSCustomObject]@{
                        Type       = "Certificate"
                        Name       = $certificate.Name
                        ExpiryDate = $parsedDate
                        VaultName  = $vaultName
                        ExpiryDateIST = if ($parsedDate) {
                            ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($parsedDate, "India Standard Time")).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                    }
                }
            }
        }
    }

    # Output expiring objects
    Write-Output "Found the following expiring objects:"
    $expiringObjects | ConvertTo-Json -Depth 10

    # Send the data to the Logic App webhook
    $webhookUrl = "-----"
    $expiringObjectsJson = $expiringObjects | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType "application/json" -Body $expiringObjectsJson
    Write-Output "Notification sent to the client via Logic App."

    # Debug output for WebhookData
    Write-Output "WebhookData: $WebhookData"
}
catch {
    Write-Error "An error occurred: $_"
    throw
}
