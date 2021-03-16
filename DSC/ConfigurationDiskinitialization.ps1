Configuration Diskinitialization
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Script Initialize_Disk {
        SetScript  =
        {
            # Start logging the actions 
            Start-Transcript -Path C:\Temp\Diskinitlog.txt -Append -Force

            # Get list of Disks that are not initialized
            $disks = Get-Disk | Where-Object partitionstyle -eq 'raw' | Sort-Object number

            #DriveLabel,DriveLetter,Lun
            $driveparams = @('SQLDATA,E,2','SQLLOG,L,3')
 
            "Formatting disks.."
            foreach ($disk in $disks) {
                foreach ( $driveparam in $driveparams ) {
                    $driveLabel = $driveparam.split(",")[0]
                    $driveLetter = $driveparam.split(",")[1]
                    $driveLun = $driveparam.split(",")[2]
                    if ( $disk.Number -eq $driveLun ) {
                        $disk |
                        Initialize-Disk -PartitionStyle GPT -PassThru |
                        New-Partition -UseMaximumSize -DriveLetter $driveLetter |
                        Format-Volume -FileSystem NTFS -NewFileSystemLabel "$label.$count" -Confirm:$false -AllocationUnitSize 65536 -Force
                        "driveLabel: $(($driveLabel)) driveLetter: $(($driveLetter)) driveLUN: $(($driveLun))"
                }
            }
            Stop-Transcript
        }

        TestScript =
        {
            try {
                Write-Verbose "Testing if any Raw disks are left"
                # $Validate = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg' -ErrorAction SilentlyContinue
                $Validate = Get-Disk | Where-Object partitionstyle -eq 'raw'
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $ErrorMessage
            }
 
            If (!($Validate -eq $null)) {
                Write-Verbose "Disks are not initialized"     
                return $False 
            }
            Else {
                Write-Verbose "Disks are initialized"
                Return $True
                
            }
        }

        GetScript  = { @{ Result = Get-Disk | Where-Object partitionstyle -eq 'raw' } }
                
    }
}
