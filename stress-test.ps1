#!/usr/bin/env pwsh
# Stress Test Script for AKS Application
# This script sends multiple concurrent requests to trigger Horizontal Pod Autoscaler

#############################################################
# Parameters and Configuration
#############################################################

# Get the complete application URL from user
function Get-ApplicationURL {
    $userURL = Read-Host "Enter the complete application URL including endpoint (e.g., http://your-app-ip/stress)"
    if ($userURL -notmatch "^https?://") {
        $userURL = "http://$userURL"
    }
    return $userURL
}

# Get test parameters from user
function Get-TestParameters {
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "     Stress Test Configuration" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    # Determine if we're using stress or stress-light endpoint based on URL
    $params = @{}
    
    Write-Host "`nEndpoint Parameter Configuration:" -ForegroundColor Yellow
    if ($appUrl -like "*/stress") {
        Write-Host "Detected CPU-intensive stress test endpoint" -ForegroundColor Green
        Write-Host "This endpoint consumes CPU resources for a specified duration" -ForegroundColor White
        
        $duration = Read-Host "Enter duration in milliseconds [default: 5000]"
        if ([string]::IsNullOrWhiteSpace($duration)) {
            $duration = 5000
        }
        $params["duration"] = $duration
    } 
    elseif ($appUrl -like "*/stress-light") {
        Write-Host "Detected Light stress test endpoint" -ForegroundColor Green
        Write-Host "This endpoint performs non-blocking workload in chunks" -ForegroundColor White
        
        $chunks = Read-Host "Enter number of chunks [default: 10]"
        if ([string]::IsNullOrWhiteSpace($chunks)) {
            $chunks = 10
        }
        $params["chunks"] = $chunks
    }
    else {
        Write-Host "Using custom endpoint: $appUrl" -ForegroundColor Yellow
        Write-Host "No specific parameters configured for this endpoint" -ForegroundColor White
    }
    
    # Ask for concurrent requests
    $concurrentRequests = Read-Host "Enter number of concurrent requests [default: 20]"
    if ([string]::IsNullOrWhiteSpace($concurrentRequests) -or -not ($concurrentRequests -match "^\d+$")) {
        $concurrentRequests = 20
    }
    
    # Ask for test duration
    $testDuration = Read-Host "Enter test duration in seconds [default: 60]"
    if ([string]::IsNullOrWhiteSpace($testDuration) -or -not ($testDuration -match "^\d+$")) {
        $testDuration = 60
    }
    
    return @{
        "params" = $params;
        "concurrentRequests" = [int]$concurrentRequests;
        "testDuration" = [int]$testDuration;
    }
}

# Monitor HPA during the test
function Monitor-HPA {
    param (
        [int]$durationSeconds,
        [int]$intervalSeconds = 5
    )
    
    $iterations = [math]::Ceiling($durationSeconds / $intervalSeconds)
    
    Write-Host "`nStarting HPA monitoring for $durationSeconds seconds..." -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "Time     | Deployment | CPU  | Memory | Min | Max | Replicas" -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $iterations; $i++) {
        $timeElapsed = $i * $intervalSeconds
        $formattedTime = "{0,4:N0}s" -f $timeElapsed
        
        try {
            $hpaInfo = kubectl get hpa -n app -o json | ConvertFrom-Json
            
            if ($hpaInfo.items.Count -gt 0) {
                foreach ($hpa in $hpaInfo.items) {
                    $deployment = $hpa.spec.scaleTargetRef.name
                    $cpu = "N/A"
                    $memory = "N/A"
                    
                    # Extract CPU and memory utilization
                    foreach ($metric in $hpa.status.currentMetrics) {
                        if ($metric.type -eq "Resource" -and $metric.resource.name -eq "cpu") {
                            if ($metric.resource.PSObject.Properties["currentAverageUtilization"]) {
                                $cpu = "$($metric.resource.currentAverageUtilization)%"
                            }
                        } elseif ($metric.type -eq "Resource" -and $metric.resource.name -eq "memory") {
                            if ($metric.resource.PSObject.Properties["currentAverageUtilization"]) {
                                $memory = "$($metric.resource.currentAverageUtilization)%"
                            }
                        }
                    }
                    
                    $minPods = $hpa.spec.minReplicas
                    $maxPods = $hpa.spec.maxReplicas
                    $currentPods = $hpa.status.currentReplicas
                    
                    Write-Host ("{0} | {1,-10} | {2,-4} | {3,-6} | {4,-3} | {5,-3} | {6}" -f `
                        $formattedTime, $deployment, $cpu, $memory, $minPods, $maxPods, $currentPods)
                }
            } else {
                Write-Host "$formattedTime | No HPA found in the namespace"
            }
        } catch {
            Write-Host "$formattedTime | Error retrieving HPA information: $_"
        }
        
        if ($i -lt $iterations - 1) {
            Start-Sleep -Seconds $intervalSeconds
        }
    }
    
    Write-Host "============================================================" -ForegroundColor Cyan
}

# Run parallel requests to the application
function Invoke-ParallelRequests {
    param (
        [string]$baseUrl,
        [string]$endpoint,
        [hashtable]$queryParams,
        [int]$concurrentRequests,
        [int]$durationSeconds
    )
    
    $url = "$baseUrl$endpoint"
    
    # Build query string
    if ($queryParams.Count -gt 0) {
        $query = "?"
        foreach ($key in $queryParams.Keys) {
            $query += "$key=$($queryParams[$key])&"
        }
        $url += $query.TrimEnd("&")
    }
    
    Write-Host "`nStarting stress test with $concurrentRequests concurrent requests" -ForegroundColor Yellow
    Write-Host "URL: $url" -ForegroundColor White
    Write-Host "Test will run for $durationSeconds seconds" -ForegroundColor White
    
    # Start monitoring in background job
    $monitorJob = Start-Job -ScriptBlock {
        param($duration, $interval)
        $iterations = [math]::Ceiling($duration / $interval)
        for ($i = 0; $i -lt $iterations; $i++) {
            $timeElapsed = $i * $interval
            $hpaInfo = kubectl get hpa -n app -o json | ConvertFrom-Json
            $output = @{
                TimeElapsed = $timeElapsed
                HPAs = $hpaInfo
            }
            Write-Output $output
            Start-Sleep -Seconds $interval
        }
    } -ArgumentList $durationSeconds, 5
    
    # Run the test using curl with multiple processes
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($durationSeconds)
    
    try {
        # Create a runspace pool
        $pool = [runspacefactory]::CreateRunspacePool(1, $concurrentRequests)
        $pool.Open()
        
        $runspaces = @()
        $requestCounter = 0
        
        while ((Get-Date) -lt $endTime) {
            # Add more runspaces if we have less than concurrent limit
            while ($runspaces.Count -lt $concurrentRequests -and (Get-Date) -lt $endTime) {
                $requestCounter++
                
                $powerShell = [powershell]::Create()
                $powerShell.RunspacePool = $pool
                
                # Invoke-RestMethod script block
                [void]$powerShell.AddScript({
                    param($url, $requestId)
                    try {
                        $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 30
                        return @{
                            RequestId = $requestId
                            Success = $true
                            Response = $response
                        }
                    } catch {
                        return @{
                            RequestId = $requestId
                            Success = $false
                            Error = $_.Exception.Message
                        }
                    }
                })
                
                # Add parameters
                [void]$powerShell.AddParameter("url", $url)
                [void]$powerShell.AddParameter("requestId", $requestCounter)
                
                # Begin invocation and store in collection
                $handle = $powerShell.BeginInvoke()
                $runspaces += [PSCustomObject]@{
                    PowerShell = $powerShell
                    Handle = $handle
                    StartTime = Get-Date
                    RequestId = $requestCounter
                }
            }
            
            # Check for completed runspaces
            $completedRunspaces = @($runspaces | Where-Object { $_.Handle.IsCompleted })
            foreach ($runspace in $completedRunspaces) {
                try {
                    $result = $runspace.PowerShell.EndInvoke($runspace.Handle)
                    if ($result.Success) {
                        Write-Host "Request $($result.RequestId) completed successfully" -ForegroundColor Green
                    } else {
                        Write-Host "Request $($result.RequestId) failed: $($result.Error)" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "Error processing request result: $_" -ForegroundColor Red
                } finally {
                    $runspace.PowerShell.Dispose()
                }
            }
            
            # Remove completed runspaces from collection
            $runspaces = @($runspaces | Where-Object { -not $_.Handle.IsCompleted })
            
            # Small sleep to prevent CPU spiking
            Start-Sleep -Milliseconds 100
            
            # Print progress every 5 seconds
            $elapsed = (Get-Date) - $startTime
            if ($elapsed.TotalSeconds % 5 -lt 0.1) {
                $activeRequests = $runspaces.Count
                $percentComplete = [math]::Min(100, [math]::Round($elapsed.TotalSeconds / $durationSeconds * 100))
                Write-Progress -Activity "Running stress test" -Status "$activeRequests active requests" -PercentComplete $percentComplete
            }
        }
        
        Write-Progress -Activity "Running stress test" -Completed
    } finally {
        # Cleanup any remaining runspaces
        foreach ($runspace in $runspaces) {
            try {
                $runspace.PowerShell.Stop()
                $runspace.PowerShell.Dispose()
            } catch {
                Write-Host "Error disposing runspace: $_" -ForegroundColor Red
            }
        }
        
        if ($pool) {
            $pool.Close()
            $pool.Dispose()
        }
    }
    
    # Get and display monitoring results
    Receive-Job -Job $monitorJob | ForEach-Object {
        $timeElapsed = $_.TimeElapsed
        $formattedTime = "{0,4:N0}s" -f $timeElapsed
        
        $hpas = $_.HPAs
        if ($hpas.items.Count -gt 0) {
            foreach ($hpa in $hpas.items) {
                $deployment = $hpa.spec.scaleTargetRef.name
                $cpu = "N/A"
                $memory = "N/A"
                
                # Extract CPU and memory utilization
                foreach ($metric in $hpa.status.currentMetrics) {
                    if ($metric.type -eq "Resource" -and $metric.resource.name -eq "cpu") {
                        if ($metric.resource.PSObject.Properties["currentAverageUtilization"]) {
                            $cpu = "$($metric.resource.currentAverageUtilization)%"
                        }
                    } elseif ($metric.type -eq "Resource" -and $metric.resource.name -eq "memory") {
                        if ($metric.resource.PSObject.Properties["currentAverageUtilization"]) {
                            $memory = "$($metric.resource.currentAverageUtilization)%"
                        }
                    }
                }
                
                $minPods = $hpa.spec.minReplicas
                $maxPods = $hpa.spec.maxReplicas
                $currentPods = $hpa.status.currentReplicas
            }
        }
    }
    
    Stop-Job -Job $monitorJob
    Remove-Job -Job $monitorJob
}

#############################################################
# Main Script
#############################################################

Write-Host "
#########################################################
# AKS Application Stress Test
#########################################################
" -ForegroundColor Cyan

# Get the application URL
$appUrl = Get-ApplicationURL

# Get test parameters
$testParams = Get-TestParameters

# Start monitoring HPA
$monitorJob = Start-Job -ScriptBlock {
    param($duration)
    
    $iterations = [math]::Ceiling($duration / 5)
    Write-Host "`nStarting HPA monitoring for $duration seconds..." -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "Time     | Deployment | CPU  | Memory | Min | Max | Replicas" -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------" -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $iterations; $i++) {
        $timeElapsed = $i * 5
        $formattedTime = "{0,4:N0}s" -f $timeElapsed
        
        try {
            $hpaInfo = kubectl get hpa -n app -o json | ConvertFrom-Json
            
            if ($hpaInfo.items.Count -gt 0) {
                foreach ($hpa in $hpaInfo.items) {
                    $deployment = $hpa.spec.scaleTargetRef.name
                    $cpu = "N/A"
                    $memory = "N/A"
                    
                    # Extract CPU and memory utilization
                    if ($hpa.status.currentMetrics) {
                        foreach ($metric in $hpa.status.currentMetrics) {
                            if ($metric.type -eq "Resource" -and $metric.resource.name -eq "cpu") {
                                if ($metric.resource.PSObject.Properties["currentAverageUtilization"]) {
                                    $cpu = "$($metric.resource.currentAverageUtilization)%"
                                }
                            } elseif ($metric.type -eq "Resource" -and $metric.resource.name -eq "memory") {
                                if ($metric.resource.PSObject.Properties["currentAverageUtilization"]) {
                                    $memory = "$($metric.resource.currentAverageUtilization)%"
                                }
                            }
                        }
                    }
                    
                    $minPods = $hpa.spec.minReplicas
                    $maxPods = $hpa.spec.maxReplicas
                    $currentPods = $hpa.status.currentReplicas
                    
                    Write-Host ("{0} | {1,-10} | {2,-4} | {3,-6} | {4,-3} | {5,-3} | {6}" -f `
                        $formattedTime, $deployment, $cpu, $memory, $minPods, $maxPods, $currentPods)
                }
            } else {
                Write-Host "$formattedTime | No HPA found in the namespace"
            }
        } catch {
            Write-Host "$formattedTime | Error retrieving HPA information: $_"
        }
        
        if ($i -lt $iterations - 1) {
            Start-Sleep -Seconds 5
        }
    }
    
    Write-Host "============================================================" -ForegroundColor Cyan
} -ArgumentList $testParams.testDuration

# Run concurrent requests
$queryParams = @{}
foreach ($key in $testParams.params.Keys) {
    $queryParams[$key] = $testParams.params[$key]
}

Write-Host "`nRunning stress test with $($testParams.concurrentRequests) concurrent requests for $($testParams.testDuration) seconds..." -ForegroundColor Yellow
Write-Host "Target: $appUrl" -ForegroundColor White
if ($queryParams.Count -gt 0) {
    $queryString = "?"
    foreach ($key in $queryParams.Keys) {
        $queryString += "$key=$($queryParams[$key])&"
    }
    Write-Host "Parameters: $($queryString.TrimEnd('&'))" -ForegroundColor White
}

# Start parallel requests
$startTime = Get-Date
$endTime = $startTime.AddSeconds($testParams.testDuration)
$runspaces = @()

# Create runspace pool
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $testParams.concurrentRequests)
$runspacePool.Open()

$requestCounter = 0
$completedRequests = 0
$failedRequests = 0

try {
    while ((Get-Date) -lt $endTime) {
        # Start new requests up to concurrent limit
        while ($runspaces.Count -lt $testParams.concurrentRequests -and (Get-Date) -lt $endTime) {
            $requestCounter++
            
            # Build URL with query parameters
            $requestUrl = $appUrl
            
            if ($queryParams.Count -gt 0) {
                # Check if URL already has query parameters
                if ($requestUrl -match "\?") {
                    # URL already has query parameters, add with &
                    foreach ($key in $queryParams.Keys) {
                        $requestUrl += "&$key=$($queryParams[$key])"
                    }
                } else {
                    # URL doesn't have query parameters yet
                    $queryString = "?"
                    foreach ($key in $queryParams.Keys) {
                        $queryString += "$key=$($queryParams[$key])&"
                    }
                    $requestUrl += $queryString.TrimEnd('&')
                }
            }
            
            # Create PowerShell instance for request
            $ps = [powershell]::Create().AddScript({
                param($url, $requestId)
                try {
                    $start = Get-Date
                    $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 60
                    $end = Get-Date
                    $duration = ($end - $start).TotalMilliseconds
                    
                    return @{
                        RequestId = $requestId
                        Success = $true
                        Duration = $duration
                        Response = $response
                    }
                } catch {
                    return @{
                        RequestId = $requestId
                        Success = $false
                        Error = $_.Exception.Message
                    }
                }
            }).AddArgument($requestUrl).AddArgument($requestCounter)
            
            # Set runspace and start
            $ps.RunspacePool = $runspacePool
            
            # Add to tracking collection
            $runspaces += [PSCustomObject]@{
                PowerShell = $ps
                Handle = $ps.BeginInvoke()
                RequestId = $requestCounter
            }
        }
        
        # Check for completed requests
        $completed = @($runspaces | Where-Object { $_.Handle.IsCompleted })
        foreach ($runspace in $completed) {
            try {
                $result = $runspace.PowerShell.EndInvoke($runspace.Handle)
                if ($result.Success) {
                    $completedRequests++
                } else {
                    $failedRequests++
                }
            } catch {
                $failedRequests++
                Write-Host "Error processing request $($runspace.RequestId): $_" -ForegroundColor Red
            } finally {
                $runspace.PowerShell.Dispose()
            }
        }
        
        # Remove completed from tracking
        $runspaces = @($runspaces | Where-Object { -not $_.Handle.IsCompleted })
        
        # Show progress
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        $percentComplete = [math]::Min(100, [math]::Round(($elapsed / $testParams.testDuration) * 100))
        $remaining = $testParams.testDuration - $elapsed
        
        if ($elapsed % 2 -lt 0.1) {  # Update roughly every 2 seconds
            Write-Progress -Activity "Running Stress Test" `
                -Status "Requests: $requestCounter | Completed: $completedRequests | Failed: $failedRequests | Active: $($runspaces.Count)" `
                -PercentComplete $percentComplete `
                -SecondsRemaining $remaining
        }
        
        # Short sleep to prevent high CPU
        Start-Sleep -Milliseconds 100
    }
} finally {
    # Clean up remaining runspaces
    foreach ($runspace in $runspaces) {
        try {
            $runspace.PowerShell.Stop()
            $runspace.PowerShell.Dispose()
        } catch {
            # Ignore cleanup errors
        }
    }
    
    # Close pool
    $runspacePool.Close()
    $runspacePool.Dispose()
}

Write-Progress -Activity "Running Stress Test" -Completed

# Wait for monitoring job to complete
Write-Host "`nWaiting for monitoring to complete..." -ForegroundColor Cyan
try {
    Wait-Job -Job $monitorJob -Timeout 10 | Out-Null
    Receive-Job -Job $monitorJob
} catch {
    Write-Host "Error waiting for monitoring job: $_" -ForegroundColor Red
} finally {
    if (Get-Job -Id $monitorJob.Id -ErrorAction SilentlyContinue) {
        Stop-Job -Job $monitorJob
        Remove-Job -Job $monitorJob -Force
    }
}

Write-Host "`n
#########################################################
# Stress Test Complete
#########################################################
" -ForegroundColor Cyan

Write-Host "Total Requests Sent: $requestCounter" -ForegroundColor Yellow
Write-Host "Successful Requests: $completedRequests" -ForegroundColor Green
Write-Host "Failed Requests: $failedRequests" -ForegroundColor $(if ($failedRequests -gt 0) { "Red" } else { "Green" })

# Get final pod count
$finalPods = kubectl get deployment -n app -o jsonpath='{.items[0].status.replicas}'
Write-Host "`nFinal Pod Count: $finalPods" -ForegroundColor Cyan

Write-Host "`nCheck current HPA status:" -ForegroundColor Yellow
Write-Host "kubectl get hpa -n app" -ForegroundColor White

Write-Host "`nMonitor pods:" -ForegroundColor Yellow
Write-Host "kubectl get pods -n app -w" -ForegroundColor White