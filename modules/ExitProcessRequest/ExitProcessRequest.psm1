function Start-ExitProcessRequest {
    param(
        [Parameter(Mandatory=$true)]
        [string]$processName,

        [Parameter(Mandatory=$false)]
        [int]$timeLimit = 120,

        [Parameter(Mandatory=$false)]
        [switch]$allowCancel,

        [Parameter(Mandatory=$false)]
        [string]$logoPath,

        [Parameter(Mandatory=$false)]
        [string]$logoUrl,

        [Parameter(Mandatory=$false)]
        [string]$displayName = $processName
    )

    Add-Type -AssemblyName System.Windows.Forms

    #Before we do anything, lets see if we even need to bother the user
    if($null -eq (Get-Process "$processName" -ErrorAction SilentlyContinue).HandleCount) {
        Write-Host "No processes found for $displayName. Exiting."
        return
    }


    if ($logoPath -and $logoUrl) {
        Write-Warning "Both logoPath and logoUrl were specified. Using logoPath."
        $logoUrl = $null
    } elseif ($logoPath -eq "" -and $logoUrl -eq "") {
        Write-Warning "Neither logoPath nor logoUrl were specified. Using default logo."
        $logoPath = "$PSScriptRoot\default.png"
    }

    #Create a new Form
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSHOME\powershell.exe")
    $form.ControlBox = $false
    $form.TopMost = $true
    $form.Text = "Application Exit Request"
    $form.Size = New-Object System.Drawing.Size(400,300)
    $form.StartPosition = "CenterScreen"
    $form.Add_FormClosing({ if ($_.CloseReason -eq "UserClosing" -and $null -eq $form.Tag) { $form.Tag = "Closed" } })

    # Decide if we need to adjust the picture or use the default
    if($logoUrl -ne "") {
        try {
            Invoke-WebRequest $logoUrl -OutFile "$env:TEMP\ExitProcessRequestIcon.png"

            # Load the original image
            $originalImage = [System.Drawing.Image]::FromFile("$env:TEMP\ExitProcessRequestIcon.png")
        }
        catch {
            $originalImage = [System.Drawing.Image]::FromFile("$PSScriptRoot\default.png")
        }

        # Create a new bitmap of the desired size
        $resizedImage = New-Object System.Drawing.Bitmap(100, 100)

        # Get a graphics object from the new bitmap
        $graphics = [System.Drawing.Graphics]::FromImage($resizedImage)

        # Draw the original image onto the new bitmap, effectively resizing it
        $graphics.DrawImage($originalImage, 0, 0, 100, 100)

        # Dispose the original image and graphics object as they are no longer needed
        $originalImage.Dispose()
        $graphics.Dispose()

        # Now use $resizedImage where you used to use $originalImage
        $pictureBox = New-Object System.Windows.Forms.PictureBox
        $pictureBox.Size = New-Object System.Drawing.Size(100,100)
        $pictureBox.Location = New-Object System.Drawing.Point(25,5)
        $pictureBox.Image = $resizedImage
        $form.Controls.Add($pictureBox)
    } else {

        # Load the original image
        $originalImage = [System.Drawing.Image]::FromFile("$logoPath")

        # Create a new bitmap of the desired size
        $resizedImage = New-Object System.Drawing.Bitmap(100, 100)

        # Get a graphics object from the new bitmap
        $graphics = [System.Drawing.Graphics]::FromImage($resizedImage)

        # Draw the original image onto the new bitmap, effectively resizing it
        $graphics.DrawImage($originalImage, 0, 0, 100, 100)

        # Dispose the original image and graphics object as they are no longer needed
        $originalImage.Dispose()
        $graphics.Dispose()

        # Now use $resizedImage where you used to use $originalImage
        $pictureBox = New-Object System.Windows.Forms.PictureBox
        $pictureBox.Size = New-Object System.Drawing.Size(100,100)
        $pictureBox.Location = New-Object System.Drawing.Point(25,5)
        $pictureBox.Image = $resizedImage
        $form.Controls.Add($pictureBox)
    }    
    

    #Add a Label for the instructions
    $label = New-Object System.Windows.Forms.Label
    $label.Size = New-Object System.Drawing.Size(235,100)
    $label.Location = New-Object System.Drawing.Point(130,5)
    $label.Text = "Please save and close $displayName if it is being used. It is about to be forcibly closed."
    $label.Font = New-Object System.Drawing.Font("Verdana", 10)
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($label)

    #Add a Label for the countdown
    $counterLabel = New-Object System.Windows.Forms.Label
    $counterLabel.Size = New-Object System.Drawing.Size(360,80)
    $counterLabel.Location = New-Object System.Drawing.Point(20,110)
    $counterLabel.Font = New-Object System.Drawing.Font("Verdana", 20)
    $counterLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($counterLabel)

    #Add a Button for "Continue"
    $continueButton = New-Object System.Windows.Forms.Button
    $continueButton.Location = New-Object System.Drawing.Point(5,195)
    $continueButton.Size = New-Object System.Drawing.Size(120,60)
    $continueButton.Text = "Continue"
    $continueButton.Font = New-Object System.Drawing.Font("Verdana", 14)
    $continueButton.Add_Click({ $form.Tag = "Continue"; $form.Close() })
    $form.Controls.Add($continueButton)

    #Add a Button for "Cancel"
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(245,195)
    $cancelButton.Size = New-Object System.Drawing.Size(120,60)
    $cancelButton.Text = "Cancel"
    $cancelButton.Font = New-Object System.Drawing.Font("Verdana", 14)
    $cancelButton.Enabled = $allowCancel.IsPresent
    $cancelButton.Add_Click({ $form.Tag = "Cancelled"; $form.Close() })
    $form.Controls.Add($cancelButton)

    #Start the timer
    $startTime = Get-Date
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000 # 1 second
    $timer.Add_Tick({
        $elapsed = [math]::Round((New-TimeSpan -Start $startTime).TotalSeconds)
        $remaining = $timeLimit - $elapsed
        $counterLabel.Text = "$remaining seconds remaining"
        if ($remaining -le 0) {
            $form.Tag = "Time's up"
            $form.Close()
        }
    })


    #Before we do anything, lets see if we even need to bother the user
    if($null -eq (Get-Process "$processName" -ErrorAction SilentlyContinue).HandleCount) {
        Write-Host "No processes found for $processName. Exiting."
        return
    }


    if ([Environment]::UserInteractive) {
        # This is an interactive session, so we display the form and start the timer

        $timer.Start()

        #Show the Form
        $form.ShowDialog() | Out-Null

        switch ($x) {
            condition {  }
            Default {}
        }

        switch ($form.Tag) {
            "Cancelled" { 
                Write-Error "User cancelled the operation"
            }

            "Continue" {
                    If((Get-Process "$processName" -ErrorAction SilentlyContinue).HandleCount -gt 0) {
                        Get-Process "$processName" | Stop-Process -Force
                        Write-Output "User clicked continue."
                    }
                    else {
                        Write-Output "User clicked continue."
                        Write-Output "No process with the name $processName was found."
                    }
            }
            
            "Closed" {
                Write-Error "User closed the window" 
            }
            
            "Time's up" { 
                Write-Output "Time for $displayName to be closed."

                If((Get-Process "$processName" -ErrorAction SilentlyContinue).HandleCount -gt 0) {
                    Get-Process "$processName" | Stop-Process -Force
                }
                else {
                    Write-Output "No process with the name $processName was found."
                }
            }
        }


        #Clean up
        $timer.Dispose()
        $form.Dispose()
    } else {
        # This is a non-interactive session, so we skip the form and timer and just stop the process

        Stop-Process -Name $processName -Force
        Write-Output "Non-interactive session, $processName was forcibly closed"        
    }
}

Export-ModuleMember -Function Start-ExitProcessRequest