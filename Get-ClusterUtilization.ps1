function Get-ClusterUtilization {
<#
    .NOTES
    Created by WillyMoselhy
    This content is provided AS IS without any warranties. Use at your own risk.
    This content is not in anyway affilicated with Microsoft.
    .SYNOPSIS
    Gets the Total Memory, Free Memory, CPU utilization on all cluster nodes.
    .DESCRIPTION
    This function connects to all cluster nodes using WMI to collect info about memory and CPU load.
    You can either run it on any cluster node or remotely using the ClusterName parameter
    Fucntion supports Verbose.

    The function requrired FailoverClustering module to be installed.
    .EXAMPLE
    Get-ClusterUtilization | FT
    
    Use on any cluster node to get memory and CPU utilization in table format
    .EXAMPLE
    Get-ClusterUtilization -ClusterName "ClusterName" | Out-GridView

    Use to remotely get utilization info in a grid view
    .EXAMPLE
    Get-ClusterUtilization -Verbose

    Shows additinal info on function progress
    .PARAMETER ClusterName
    The name of a cluster to connect to. 

    .LINK
    https://plusontech.com/?p=57&preview=true
     
#>
    
    #Requires -Modules "FailoverClusters"

    [CmdletBinding()]
    Param( 
        [Parameter(Mandatory = $false)]
        [string] $ClusterName
    )

    $ErrorActionPreference = "Stop"

    try {
    #region: Query cluster nodes
        Write-Verbose "Querying cluster"
        if($ClusterName){
            Write-Verbose "Cluster name supplied, connecting to $ClusterName"
            $ClusterNodes = (Get-ClusterNode -Cluster $ClusterName -Verbose:$false).name #Get list of cluster nodes        
        }
        else{
            Write-Verbose "Cluster name not supplied, connecting to localhost"
            $ClusterNodes = (Get-ClusterNode -WarningAction SilentlyContinue -Verbose:$false).name
        }
        Write-Verbose "Found $($ClusterNodes.count) nodes"
    #endregion: Query cluster nodes

    #region: Get cluster utilization
        Write-Verbose "Checking utlization"
        $ClusterUtilization = foreach ($Node in $ClusterNodes) { #Loop through nodes one by one
            Write-Verbose "Connecting to node $Node"
            if(Test-NetConnection -ComputerName $Node -InformationLevel Quiet -WarningAction SilentlyContinue){ #Confirm the node is online
                Write-Verbose "Node is online"
                Write-Verbose "Quering WMI for memory and CPU utilization"
                $TotalMemory = $FreeMemory = $CPULoad = $null
                try{
                    $TotalMemory = "{0:N2} GB" -f ((Get-CimInstance -Class win32_OperatingSystem -ComputerName $Node -Verbose:$false).TotalVisibleMemorySize / 1MB)
                    $FreeMemory  = "{0:N2} GB" -f ((Get-CimInstance -Class win32_OperatingSystem -ComputerName $Node -Verbose:$false).FreePhysicalMemory / 1MB)
                    $CPULoad     = "{0:N0}%"   -f (Get-CimInstance win32_processor -Verbose:$false| Measure-Object -Property LoadPercentage -Average).Average
                }
                catch{
                    Write-Warning "Error while quering WMI on $Node"
                    Write-Error "$($Error[0])" -ErrorAction Continue
                }
                [PSCustomObject] @{
                    ComputerName = $Node
                    State        = "Online"
                    TotalMemory  = $TotalMemory
                    FreeMemory   = $FreeMemory
                    CPULoad      = $CPULoad
                }
                Write-Verbose "Query complete"
            }
            else {
                Write-Warning "Node $Node is not pinging"
                [PSCustomObject] @{
                    ComputerName = $Node
                    State        = "Offline"
                    TotalMemory  = $null
                    FreeMemory   = $null
                    CPULoad      = $null
                }
            }
        }
    #endregion: Get cluster utilization

    #return results
        return $ClusterUtilization
    }
    Catch [Microsoft.FailoverClusters.PowerShell.ClusterCmdletException] {
        if ($Error[0].Exception.Message -eq "The cluster service is not running.  Make sure that the service is running on all nodes in the cluster."){
            Throw "Cluster service is not running. Please run from an online cluster node or provide cluster name."
        }
        Throw $Error[0]
    }
}
