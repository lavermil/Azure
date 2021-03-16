Configuration Diskinitialization
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Script Initialize_Disk {
        SetScript  =
        {
            # Start logging the actions 
            Start-Transcript -Path C:\Temp\Diskinitlog.txt -Append -Force

            # Move DVD drive letter since it is there by default and should only be needed at provisioning, but be safe and keep it reserved.
            # https://github.com/MicrosoftDocs/azure-docs/issues/27776
            # Move CD-ROM drive to Q for now:
            "Moving CD-ROM drive to Q:.."
            Get-WmiObject -Class Win32_volume -Filter 'DriveType=5' | Select-Object -First 1 | Set-WmiInstance -Arguments @{DriveLetter='Q:'}

            # Get list of Disks that are not initialized
            $disks = Get-Disk | Where-Object partitionstyle -eq 'raw' | Sort-Object number

            # DriveLabel,DriveLetter,Lun
            # Todo: Allow this to be passed as argument
            $driveparams = @('SQLDATA,E,2','SQLLOG,L,3')
 
            "Formatting disks.."
            foreach ($disk in $disks) {
                foreach ( $driveparam in $driveparams ) {
                    $driveLabel = $driveparam.split(",")[0]
                    $driveLetter = $driveparam.split(",")[1]
                    $driveLun = $driveparam.split(",")[2]
                    $drivePathLetter = (-join($driveLetter,":\",$driveLabel))
                    if ( $disk.Number -eq $driveLun ) {
                    "Working on: driveLabel: $(($driveLabel)) driveLetter: $(($driveLetter)) driveLUN: $(($driveLun))"
                        $disk |
                        Initialize-Disk -PartitionStyle GPT -PassThru |
                        New-Partition -UseMaximumSize -DriveLetter $driveLetter |
                        Format-Volume -FileSystem NTFS -NewFileSystemLabel "$driveLabel" -Confirm:$false -AllocationUnitSize 65536 -Force
                        if ( $? ) {
                            md -Path $drivePathLetter
                            $retstatus = $?
                            $verifypathdir = Test-Path $drivePathLetter
                            if ( $retstatus -and $verifypathdir ) {
                                "  Created: driveLabel: $(($driveLabel)) driveLetter: $(($driveLetter)) driveLUN: $(($driveLun))"
                            }
                        }
                    }
                }
            }
            # Create the D:SQLDATA if it isn't created
            $drivePathLetter = "D:\SQLDATA"
            $verifypathdir = Test-Path $drivePathLetter
            if ( $verifypathdir -eq $false ) {
                md -Path $drivePathLetter
                $retstatus = $?
                $verifypathdir = Test-Path $drivePathLetter
                if ( $retstatus -and $verifypathdir ) {
                    "  Created: driveLabel: $(($driveLabel)) driveLetter: $(($driveLetter)) driveLUN: $(($driveLun))"
                }
            } else {
                "  Already Exists: driveLabel: $(($driveLabel)) driveLetter: $(($driveLetter)) driveLUN: $(($driveLun))"
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
