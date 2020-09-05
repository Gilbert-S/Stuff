$VerbosePreference = "Continue"


function Start-LogRotate
{
  param(  [string]$LogFilePath,
          [int64] $LogFileMaximumSize = 10kb,
          [int]   $LogFilesToKeep = 3
       )

  Write-Verbose "function Start-LogRotate called. Parameters: LogFilePath[$($LogFilePath)] - LogFilesToKeep[$($LogFilesToKeep)] - LogFileMaximumSize[$($LogFileMaximumSize)]"


  if(Test-Path $LogFilePath) # validate existence and accessibility of the log file
  {
    Write-Verbose "log file found"


    $LogFile = Get-ChildItem $LogFilePath

    if( ($LogFile).length -ige $LogFileMaximumSize ) # check if the logfile has exceeded the maximum size
    {
      Write-Verbose "log file is larger then parameter LogFileMaximumSize ($(($LogFile).length))"


      # get all log files with the same base name
      $Files = (Get-ChildItem $LogFile.Directory | ?{$_.name -like "$($LogFile.BaseName)*$($LogFile.Extension)"} | Sort-Object -Property lastwritetime )
      $i = $Files.count
      Write-Verbose "$i log files to rotate"

      foreach( $File in $Files ) # itterate through all log files
      {
        Write-Verbose "processing log file $i"
        if($i -le $LogFilesToKeep) # log file doesnt exceed the maximum number of log files to keep
        {
          Write-Verbose "attempting to rotate log file $($File.FullName)"
          $Success = Invoke-Retry {
            # rename logfile
            $New = Move-Item ($File.FullName) -PassThru -Destination ($LogFile.Directory.ToString() + '\' + $LogFile.BaseName + '.' + $i + $LogFile.Extension) -Force -ea Stop
            # activate NTFS file compression for old log
            compact /c /i /f /q $New.FullName
          }
          if($Success){ Write-Verbose "log file rotated to $i" }else{ Write-Warning "log rotation failed" }
        }
        else # log file DOES exceed the maximum number of log files to keep
        {
          Write-Verbose "attempting to delete logfile $($File.FullName)"
          $Success = Invoke-Retry {
            # delete overmuch log files
            Remove-Item $File.FullName -Force -ea Stop
          }
          if($Success){ Write-Verbose "log file $($File.FullName) removed" }else{ Write-Warning "$($File.FullName) removal failed" }
        }
      $i--
      }

      Write-Verbose "finished rotating all old logs"
      Write-DTSLog "log file rotation finished"
    }
    else
    {
      Write-Verbose "log file is smaller then parameter LogFileMaximumSize ($(($LogFile).length))"
      # nothing to do
    }
  }
  else{
    Write-Warning "log file $($LogFilePath) not found"
  }
} # END: function Start-LogRotate




# do-until embedded try/catch loop
# executes a user defined code snippet ($ScriptBlock)
# and retries it 10 ($Retries) times.
# waiting 3 ($Delay) seconds between each retry.
# returning $false if non and $true if any attempt succeeded
function Invoke-Retry
{
  param(  [int]$Retries = 10,
          [int]$Delay = 3,
          [Parameter(Mandatory=$true,Position=0)][ScriptBlock]$ScriptBlock
       )

  Write-Verbose "function Invoke-Retry called. Parameters: Retries[$($Retries)] - Delay[$($Delay)] - ScriptBlock[$($ScriptBlock)]"


  # temporary change the ErrorActionPreference to Stop to remove the need to define it inside every scriptblock
  $OriginalErrorActionPreference = $ErrorActionPreference # storing the previous state
  $ErrorActionPreference = "Stop"


  $RetryCounter = 0;  $RetrySuccess = $false
  do{$RetryCounter++;try{
    Invoke-Command -Scriptblock $ScriptBlock -NoNewScope    # executing the user defined Script snippet
    $RetrySuccess = $true                                   # save success state if no error occured
  }Catch{
    Write-Warning "[$($ScriptBlock.ToString())] failed (try $($RetryCounter)/$($Retries))"
    Write-Warning $_
    Start-Sleep -Seconds $Delay # wait 3 seconds between each retry
  }}until($RetryCounter -ge $Retries -or $RetrySuccess)


  # restoring previous ErrorActionPreference state
  $ErrorActionPreference = $OriginalErrorActionPreference


  if(!$RetrySuccess){ # Command failed on all retries
    Write-Warning "Invoke-Retry failed."
    return $false
  }else{ # command succeeded
    Write-Verbose "Invoke-Retry successful."
    return $true
  }
} # END: function Invoke-Retry







#write log message to a file
 function Write-DTSLog
 {
   Param([Parameter(Mandatory,Position=0,ValueFromPipeline=$true)][String]$LogMessage,
         [Parameter()][int][Alias("ProcessID")]$JobID=0,
         [Parameter()][Switch]$Info,
         [Parameter()][Switch]$Warning,
         [Parameter()][Switch][Alias("Error")]$_Error_,
         [Parameter()][Switch]$Echo
       )

   #convert log level parameter
   $LL = switch($true){
     $Info    {1}
     $Warning {2}
     $_Error_ {3}
     Default  {1}
   }

   $LogLevel = switch($true){
     $Info    {'Info'}
     $Warning {'Warning'}
     $_Error_ {'Error'}
     Default  {'Info'}
   }


   Write-Verbose "DTS module - Write-DTSLog called."
   Write-Verbose "DTS module (Write-DTSLog) - paramter LogMessage: '$($LogMessage)'."
   Write-Verbose "DTS module (Write-DTSLog) - paramter JobID: '$($JobID)'."
   Write-Verbose "DTS module (Write-DTSLog) - paramter LogLevel: '$($LogLevel)'."
   Write-Verbose "DTS module (Write-DTSLog) - paramter Echo: '$($Echo)'."


   Push-Location C:

   $ScriptName = ($MyInvocation.ScriptName | Split-Path -Leaf -ErrorAction SilentlyContinue)
   $LineNumber = $MyInvocation.ScriptLineNumber
   if($ScriptName -eq 'DTSModule.psm1'){
     $CallStacks = (Get-PSCallStack | Select-Object -Property *)
     $ScriptName = 'DTSModule'
     $LineNumber = $CallStacks[1].FunctionName
   }

   $LogLineContent = @()

                                        $LogLineContent += $LogMessage
                                        $LogLineContent += "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
                                        $LogLineContent += (Get-Date -Format MM-dd-yyyy)
   if($PSPrivateMetadata.JobId.Guid) {  $LogLineContent += "Runbook|$([io.path]::GetFileNameWithoutExtension($Script:DTSLogFilePath)):$($MyInvocation.ScriptLineNumber)"    }
   else{                                $LogLineContent += "$($ScriptName):$($LineNumber)" }
                                        $LogLineContent += $LL
                                        $LogLineContent += $JobID
                                        $LogLineContent += (Get-PSCallStack)[1].FunctionName


   $LogLineTemplate  = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="{5}" file="{6}">'
   $LogLine          = $LogLineTemplate -f $LogLineContent

   Write-Verbose "DTS module (Write-DTSLog) - writing log line: '$($LogLine)'."


   # ScriptBlock for start-job / attempts do write log 10 time swith 1 second delays
   # no extended error handling or any outputs
   $ScriptBlock = {
     param($LogFilePath,$LogLine)
       # do-util embedded try/catch loop
       $DoRetryCounter = 0;   $DoRetryRetries = 10;   $DoRetrySuccess = $false
       do{$DoRetryCounter++;try{
           $streamWriter = [System.IO.StreamWriter]::new($LogFilePath,$true)
           $streamWriter.WriteLine($LogLine)
           $streamWriter.Close(); $streamWriter.Dispose()
           $DoRetrySuccess = $true
       }Catch{
         Start-Sleep -Seconds 1 # wait 3 seconds between each retry
       }}until($DoRetryCounter -ge $DoRetryRetries -or $DoRetrySuccess)
   }

   #writes log message, scriptname and line number of script, log level to file. component field is left blank
   #Add-Content -Value $LogLine -Path $Script:DTSLogFilePath -Encoding UTF8 -ErrorAction SilentlyContinue
   $Null = Start-Job $ScriptBlock -ArgumentList @($Script:DTSLogFilePath,$LogLine)

   If($Echo){ switch($LL){
       1 {Write-Output  $LogMessage}
       2 {Write-Warning $LogMessage}
       3 {Write-Error   $LogMessage}
   }}

   Pop-Location

 } # END: function Write-DTSLog













$Script:DTSLogFilePath = "C:\Users\Gilbert\Desktop\test.log"
Start-LogRotate -LogFilePath "C:\Users\Gilbert\Desktop\test.log"

for($i=0;$i -lt 10;$i++)
{
  Write-DTSLog -JobID 112 "Test $i"
}

$NULL = Get-Job | Wait-Job -Timeout 60


#
# $url = "https://www.googleapis.com/fitness/v1/resourcePath?parameters"
# $output = "C:\users\Gilbert\Desktop\downloadtest.txt"
#
# try
# {
# $wc = New-Object System.Net.WebClient
# $wc.Proxy = [System.Net.GlobalProxySelection]::GetEmptyWebProxy()
# $wc.UseDefaultCredentials = $true
# $wc.DownloadFile($url, $output)
#
# }
# catch [System.Net.WebException]
# {
#     write-warning "we got a webexception"
#     write-warning "HTTP Status Code $($_.Exception.Response.StatusCode.value__) ($($_.Exception.Response.StatusDescription))"
#     [System.IO.StreamReader]$StreamReader = New-Object System.IO.StreamReader -argumentList ($_.Exception.Response.GetResponseStream());
#     [string] $Response = $StreamReader.ReadToEnd();
#     $Response
#     $HTML = New-Object -Com "HTMLFile"
#     $encoded = [System.Text.Encoding]::Unicode.GetBytes($Response)
#     $HTML.write($encoded)
# }
# catch
# {
#     write-warning "an error occured"
#     $_
# }
