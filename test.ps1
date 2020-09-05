

function Start-LogRotate
{ 
  param(  [string]$LogFilePath, 
          [int64]$LogFileMaximumSize = 10kb, 
          [int] $LogFileCountToKeep = 3
       ) 
  if(test-path $LogFilePath) 
  {
    $LogFile = Get-ChildItem $LogFilePath

    if( ($LogFile).length -ige $LogFileMaximumSize )
    {
      $Files = (Get-ChildItem $LogFile.Directory | ?{$_.name -like "$($LogFile.BaseName)*$($LogFile.Extension)"} | Sort-Object -Property lastwritetime )
      $i = $Files.count
      foreach( $File in $Files )
      {
        if($i -le $LogFileCountToKeep)
        {
          $Success = Invoke-Retry {
            $New = Move-Item ($File.FullName) -PassThru -Destination ($LogFile.Directory.ToString() + '\' + $LogFile.BaseName + '.' + $i + $LogFile.Extension) -Force -ea Stop
            compact /c /i /f /q $New.FullName
          }
          if($Success){ Write-Debug "log file rotated" }else{ Write-Warning "log rotation failed" }
        }
        else
        {
          $Success = Invoke-Retry {
            Remove-Item $File.FullName -Force -ea Stop
          }
          if($Success){ Write-Debug "$($File.FullName) removed" }else{ Write-Warning "'$($File.FullName)' removal failed" }
        }
      $i--
      }

      $Success = Invoke-Retry {
        $streamWriter = [System.IO.StreamWriter]::new($LogFilePath,$true)
        $streamWriter.WriteLine("log file rotation finished")
        $streamWriter.Close(); $streamWriter.Dispose()
      }
      if($Success){ Write-Debug "new logfile created" }else{ Write-Warning "new logfile creation failed" }


    }
  }
}

# do-util embedded try/catch loop
function Invoke-Retry
{
  param(  [int]$Retries = 10, 
          [int]$Delay = 3, 
          [Parameter(Mandatory=$true,Position=0)][ScriptBlock]$ScriptBlock
       ) 
  
  $RetryCounter = 0;  $RetrySuccess = $false
  do{$RetryCounter++;try{
    Invoke-Command -Scriptblock $ScriptBlock -NoNewScope
    $RetrySuccess = $true
  }Catch{
    Write-Warning "[$($ScriptBlock.ToString())] failed (try $($RetryCounter)/$($Retries))"
    Write-Warning $_
    Start-Sleep -Seconds $Delay # wait 3 seconds between each retry
  }}until($RetryCounter -ge $Retries -or $RetrySuccess)
  
  if(!$RetrySuccess){ # Command failed on all retries
    Write-Warning "Invoke-Retry failed."
    return $false
  }else{
    Write-Debug "Invoke-Retry successful."
    return $true
  }
}


$ScriptBlock = {
  param($param) 
  for($i=0;$i -lt 100;$i++)
  {
    # do-util embedded try/catch loop
    $DoRetryCounter = 0;   $DoRetryRetries = 10;   $DoRetrySuccess = $false
    do{$DoRetryCounter++;try{
      # try content / add -ea Stop
        $streamWriter = [System.IO.StreamWriter]::new("C:\Users\Gilbert\Desktop\test.log",$true)
        $streamWriter.WriteLine("Block $param loop $i")
        $streamWriter.Close(); $streamWriter.Dispose()
        $DoRetrySuccess = $true
    }Catch{
      Write-Host "[Command] failed (try $($DoRetryCounter)/$($DoRetryRetries))"
      Write-Host $_
      Start-Sleep -Seconds 3 # wait 3 seconds between each retry
    }}until($DoRetryCounter -ge $DoRetryRetries -or $DoRetrySuccess)
    
    if(!$DoRetrySuccess){ # Command failed on all retries
      Write-Host "[Command] failed, aborting."
    }else{
      Write-Host "[Command] successful."
    }
    
  }
}

Start-LogRotate -LogFilePath "C:\Users\Gilbert\Desktop\test.log"

for($i=0;$i -lt 10;$i++)
{
  for($j=0;$j -lt 100;$j++)
  {
    # do-util embedded try/catch loop
    $DoRetryCounter = 0;   $DoRetryRetries = 10;   $DoRetrySuccess = $false
    do{$DoRetryCounter++;try{
      # try content / add -ea Stop
        $streamWriter = [System.IO.StreamWriter]::new("C:\Users\Gilbert\Desktop\test.log",$true)
        $streamWriter.WriteLine("Block $i loop $j")
        $streamWriter.Close(); $streamWriter.Dispose()
        $DoRetrySuccess = $true
    }Catch{
      Write-Host "[Command] failed (try $($DoRetryCounter)/$($DoRetryRetries))"
      Write-Host $_
      Start-Sleep -Seconds 3 # wait 3 seconds between each retry
    }}until($DoRetryCounter -ge $DoRetryRetries -or $DoRetrySuccess)
    
    if(!$DoRetrySuccess){ # Command failed on all retries
      Write-Host "[Command] failed, aborting."
    }else{
      Write-Host "[Command] successful."
    }
    
  }
}

