#!/usr/bin/env pwsh
# Stress Test Script for HTTP Applications
# This script sends multiple concurrent requests to test application performance

param(
    [string]$Url,
    [int]$Duration = 60,
    [int]$Concurrent = 20,
    [int]$Chunks = 10
)

#############################################################
# Parameters and Configuration
#############################################################

# Get the complete application URL from parameters or user input
function Get-ApplicationURL {
    if ($Url) {
        if ($Url -notmatch "^https?://") {
            return "http://$Url"
        }
        return $Url
    }
    $userURL = Read-Host "Enter the complete application URL including endpoint (e.g., http://your-app/stress)"
    if ($userURL -notmatch "^https?://") {
        $userURL = "http://$userURL"
    }
    return $userURL
}

# Get test parameters from script parameters or user input
function Get-TestParameters {
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "     Stress Test Configuration" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    # Get test duration from parameter or user input
    $testDuration = $Duration
    if ($testDuration -le 0) {
        $userDuration = Read-Host "Enter test duration in seconds [default: 60]"
        if ([string]::IsNullOrWhiteSpace($userDuration) -or -not ($userDuration -match "^\d+$")) {
            $testDuration = 60
        } else {
            $testDuration = [int]$userDuration
        }
    }

    # Get concurrent requests from parameter or user input
    $concurrentRequests = $Concurrent
    if ($concurrentRequests -le 0) {
        $userConcurrent = Read-Host "Enter number of concurrent requests [default: 20]"
        if ([string]::IsNullOrWhiteSpace($userConcurrent) -or -not ($userConcurrent -match "^\d+$")) {
            $concurrentRequests = 20
        } else {
            $concurrentRequests = [int]$userConcurrent
        }
    }

    # Get chunks for stress test parameters
    $params = @{}
    if ($appUrl -like "*/stress-light") {
        $chunks = $Chunks
        if ($chunks -le 0) {
            $userChunks = Read-Host "Enter number of chunks [default: 10]"
            if ([string]::IsNullOrWhiteSpace($userChunks) -or -not ($userChunks -match "^\d+$")) {
                $chunks = 10
            } else {
                $chunks = [int]$userChunks
            }
        }
        $params["chunks"] = $chunks
    }
    elseif ($appUrl -like "*/stress") {
        $duration = 5000  # Default duration for stress endpoint
        $params["duration"] = $duration
    }

    return @{
        "params" = $params
        "concurrentRequests" = [int]$concurrentRequests
        "testDuration" = [int]$testDuration
    }
}



# Run parallel requests to the application
function Invoke-ParallelRequests {
    param (
        [string]$baseUrl,
        [hashtable]$queryParams,
        [int]$concurrentRequests,
        [int]$durationSeconds
    )
    
    $url = $baseUrl
    
    # Build query string
    if ($queryParams.Count -gt 0) {
        $query = "?"
        foreach ($key in $queryParams.Keys) {
            $query += "$key=$($queryParams[$key])&"
        }
        $url += $query.TrimEnd("&")
    }
    
    Write-Host "`nStarting stress test with following configuration:" -ForegroundColor Yellow
    Write-Host "URL: $url" -ForegroundColor White
    Write-Host "Concurrent Requests: $concurrentRequests" -ForegroundColor White
    Write-Host "Test Duration: $durationSeconds seconds" -ForegroundColor White
    if ($queryParams.Count -gt 0) {
        Write-Host "Parameters: $($queryParams | ConvertTo-Json)" -ForegroundColor White
    }
    
    # Initialize counters for metrics
    $script:totalRequests = 0
    $script:successfulRequests = 0
    $script:failedRequests = 0
    
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
                    $script:totalRequests++
                    if ($result.Success) {
                        $script:successfulRequests++
                        Write-Host "." -ForegroundColor Green -NoNewline
                    } else {
                        $script:failedRequests++
                        Write-Host "x" -ForegroundColor Red -NoNewline
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
    
    # Display final metrics
    Write-Host "`n`nTest Results:" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "Total Requests:     $script:totalRequests"
    Write-Host "Successful:         $script:successfulRequests"
    Write-Host "Failed:            $script:failedRequests"
    Write-Host "Success Rate:       $([math]::Round(($script:successfulRequests / $script:totalRequests) * 100, 2))%"
    Write-Host "============================================" -ForegroundColor Cyan
}

#############################################################
# Main Script
#############################################################

Write-Host "
#########################################################
# HTTP Application Stress Test
#########################################################
" -ForegroundColor Cyan

# Get the application URL
$appUrl = Get-ApplicationURL

# Get test parameters
$testParams = Get-TestParameters

# Run concurrent requests
$queryParams = @{}
foreach ($key in $testParams.params.Keys) {
    $queryParams[$key] = $testParams.params[$key]
}

# Execute the stress test
Invoke-ParallelRequests -baseUrl $appUrl -queryParams $queryParams -concurrentRequests $testParams.concurrentRequests -durationSeconds $testParams.testDuration