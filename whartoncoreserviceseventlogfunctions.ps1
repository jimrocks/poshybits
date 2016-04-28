function new-wcseventlog {
<#
    .SYNOPSIS
    Creates a new log source for wharton core services logging.
    .Description
    This function needs to be run from an elevated prompt.
    This will make a new source in the Application log for tracking wharton core services events. 
    Optionally alternate logs may be specified.
    This should only need to be invoked once per host.
    .Parameter source
    The event log source to be written to. Defaults to whartonCoreServices
    .Parameter logname
    The event log to be written to. Defaults to application.
    .Example
    Create a new event log.
    new-wcseventlog
#>
    [cmdletbinding()]
    param(
        $source = "whartonCoreServices",
        $logname = "Application"
    )
    if((get-eventlog -logname Application -source $source -ErrorAction SilentlyContinue) -eq $null) {
        try { 
            New-Eventlog -Logname Application -source $source
        }
        catch {
            "Failed to create source {0} in log {1}" -f $source, $logname | Write-Error -ErrorAction Stop
        }
    }
    else { "Source {0} already exists in log {1}" -f $source, $logname  | write-warning }
}

function get-wcseventlog {
<#
    .SYNOPSIS
    Get the contents of the whartonCoreServices source/providername
    .Description
    This function can call the winevent provider on the local or remote machines to get the contents of the whartoncoreservices log with optional additional filters.
    .Parameter entrytype
    The log level of the event log.
    .Parameter providername
    The source (aliased) in the log. Defaults to "whartonCoreServices".
    .Parameter logname
    The log to which whartonCoreServices events are written. Defaults to application.
    .Parameter computerName
    Optionally specify a remote computer to query.
    .Example
    Gets the contents of the whartonCoreServices log provider in the application log. 
    get-wcseventlog   
#>
    [cmdletbinding()]
    param(
        [ValidateSet("Error","Warning","Information")]$entrytype, 
        [alias("id")]$eventID,
        [alias("source")]$providerName = "whartonCoreServices",
        $logname = "Application",
        $computerName
    )

    $levels = @("LogAlways","Critical","Error","Warning","Information","Verbose") 
    $level = [array]::IndexOf($levels,$entrytype)
    $filter = @{
        'ProviderName'=$providerName
        'logname'=$logname
    }
    if($entrytype) { $filter.add('Level',$level) }
    if($eventID) { $filter.add('id',$eventID) }
    $splat = @{'filterhashtable'=$filter}
    if($computerName) { $splat.add('computerName',$computerName)}
    Get-winevent @splat

}

function write-wcseventlog {
<#
    .SYNOPSIS
    Write to the whartonCoreservice event source in the application log
    .Description
    This function provides the lazyperson with a wrapper for writing to a standardized event location.
    .Parameter entrytype
    The log level of the event log. 
    .Parameter source
    The source in the log. Defaults to "whartonCoreServices".
    .Parameter logname
    The log to which whartonCoreServices events are written. Defaults to application.
    .Parameter message
    The message being logged.
    .Paramter stream
    An optional switch that will cause errors to be pushed along to the error stream and info to be pushed to the verbose stream.
    .Example 
    Write to the highest eventID available to confirm that the log source has been initialized
    write-wcseventlog -entrytype Information -eventID 65535 -message 'Initial log to confirm logs'   
    .Example
    Write an error and send the error to the error stream as well.
    write-wcseventlog -entrytype error -eventID 65534 -message 'BORKED!' -stream
#>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateSet("Error","Warning","Information","SuccessAudit","FailureAudit")]$entrytype,
        [Parameter(Mandatory=$true)][validateScript({$_-le65535})]$eventID,
        [Parameter(Mandatory=$true)]$message,
        $source = "whartonCoreServices",
        $logname = "Application",
        [switch]$stream  
    )

    #Write the log file
    Write-Eventlog -logname $logname -source $source -eventID $eventID -entrytype $entrytype -message $message -rawdata 10,20

    if($stream) {
        switch ($entrytype) {
            "Error" { $message | Write-Error -ErrorId $eventID }
            "Warning" {}
            "Information" { $message | Write-Verbose }
            "SuccessAudit" {}
            "FailureAudit" {}
        }

    }

}