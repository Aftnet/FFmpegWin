$apiUrl = 'https://ci.appveyor.com/api'
$headers = @{
    'Content-type' = 'application/json'
}

$downloadDirectory = "Build"
New-Item -Path $downloadDirectory -ItemType directory -Force
$account = "Aftnet"
$project = "ffmpegwin"
$projectObject = Invoke-RestMethod -Method Get -Uri "$apiUrl/projects/$account/$project" -Headers $headers

foreach($i in $projectObject.build.jobs) {
    $jobId = $i.jobId
    $artifacts = Invoke-RestMethod -Method Get -Uri "$apiUrl/buildjobs/$jobId/artifacts" -Headers $headers
    foreach($j in $artifacts) {
        if($j.type -eq "Zip") {
            $artifactUrl = "$apiUrl/buildjobs/$jobId/artifacts/$($j.fileName)"
            $localArtifactPath = Join-Path $downloadDirectory $j.fileName
            echo "Downloading $artifactUrl to $localArtifactPath"
            Invoke-RestMethod -Method Get -Uri $artifactUrl -OutFile $localArtifactPath -Headers $headers
            $localArtifactDir = $localArtifactPath.Replace(".zip", "")
            Expand-Archive -Path $localArtifactPath -DestinationPath $localArtifactDir
        }
    }
}