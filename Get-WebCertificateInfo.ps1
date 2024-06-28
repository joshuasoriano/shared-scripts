function Get-WebCertificateInfo {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$HostName
    )

    begin {
        function Convert-ToUrlFormat {
            param (
                [string]$inputString
            )
        
            if ($inputString -match '^https?://') {
                return $inputString
            }
            else {
                return "https://$inputString"
            }
        }
        
        function Get-TimeRemaining {
            param (
                [datetime]$targetDate
            )
        
            # Get the current date
            $currentDate = Get-Date
        
            # Calculate time span
            $timeRemaining = $targetDate - $currentDate
        
            # If the target date is in the future, return all values as zeroes
            if ($timeRemaining -lt 0) {
                return [PSCustomObject]@{
                    Years  = 0
                    Months = 0
                    Weeks  = 0
                    Days   = 0
                }
            }
        
            # Calculate time remaining in different units
            [PSCustomObject]@{
                Years  = [math]::Floor($timeRemaining.Days / 365)
                Months = [math]::Floor($timeRemaining.Days / 30)
                Weeks  = [math]::Floor($timeRemaining.Days / 7)
                Days   = [math]::Floor($timeRemaining.Days)
            }
        }
        
        $outputTemplate = New-Object PSObject -Property @{
            Hostname        = $HostName
            Address         = $null
            ProtocolVersion = $null
            ConnectionName  = $null
            Certificate     = "Not Available"
            Issuer          = $null
            Subject         = $null
            NotBefore       = $null
            NotAfter        = $null
            TimeRemaining   = $null
        }
    }

    process {
        try {
            $uri = [System.Uri]::new((Convert-ToUrlFormat $HostName))
            $tcpClient = New-Object System.Net.Sockets.TcpClient($uri.Host, $uri.Port)
            $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, { $true })
            $sslStream.AuthenticateAsClient($uri.Host)
            $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($sslStream.RemoteCertificate)

            $expirationDate = $certificate.NotAfter
        
            $output = $outputTemplate | Select-Object *
            $output.Hostname = $HostName
            $output.Address = $response.RequestMessage.RequestUri.Host
            $output.ProtocolVersion = $response.Version
            $output.ConnectionName = $response.RequestMessage.RequestUri.ServicePoint.ConnectionName
            #$output.Certificate = $certificate
            $output.Issuer = $certificate.Issuer
            $output.Subject = $certificate.Subject
            $output.NotBefore = $certificate.NotBefore
            $output.NotAfter = $certificate.NotAfter
            $output.TimeRemaining = (Get-TimeRemaining $expirationDate)
        }
        catch {
            $output = $outputTemplate
        }

        $output
    }
}
