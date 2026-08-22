# GetLatest-FEVersion.ps1 (GHA output directly)

try {
    Write-Host "Fetching latest version of Fiddler Everywhere..."

    $baseUrl = "https://www.telerik.com/support/whats-new/fiddler-everywhere/release-history"
    $cacheBust = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $url = "${baseUrl}?cacheBust=$cacheBust"

    $headers = @{
        "Cache-Control" = "no-cache"
        "Pragma"        = "no-cache"
        "User-Agent"    = "Mozilla/5.0"
    }

    $response = Invoke-WebRequest `
        -Uri $url `
        -Method Get `
        -Headers $headers

    $foundVersions = [regex]::Matches(
        $response.Content,
        'Fiddler Everywhere v(\d+\.\d+\.\d+)'
    ) | ForEach-Object {
        [version]$_.Groups[1].Value
    }

    if (-not $foundVersions) {
        throw "Could not find a Fiddler Everywhere version."
    }

    $version = (
        $foundVersions |
        Sort-Object -Descending |
        Select-Object -First 1
    )

    # The release-history page can be stale on some CDN nodes. Probe a
    # bounded number of subsequent patch installers on the official CDN.
    for ($attempt = 0; $attempt -lt 10; $attempt++) {
        $candidate = [version]::new(
            $version.Major,
            $version.Minor,
            $version.Build + 1
        )
        $fileName = [Uri]::EscapeDataString("Fiddler Everywhere $candidate.exe")
        $downloadUrl = "https://downloads.getfiddler.com/win/$fileName"

        try {
            $probe = Invoke-WebRequest `
                -Uri $downloadUrl `
                -Method Head `
                -ErrorAction Stop

            if ($probe.StatusCode -ne 200) {
                break
            }

            $version = $candidate
        }
        catch {
            break
        }
    }

    $version = $version.ToString()

    Write-Host "Latest Version Found: $version"

    if ($env:GITHUB_OUTPUT) {
        "scraped_version=$version" |
            Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    }
    else {
        Write-Host "Running locally; GitHub Actions output was not written."
    }
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
