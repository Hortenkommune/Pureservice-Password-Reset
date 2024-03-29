﻿Param(
    [string]$ticketNumber
)


function Create-RandomPassword {
    $Liste1 = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Hortenkommune/Pureservice-Password-Reset/master/Pronomen.txt" -UseBasicParsing).ToString()
    $Liste1 = $Liste1 -split '[\r\n]'
    $Liste2 = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Hortenkommune/Pureservice-Password-Reset/master/Verb.txt" -UseBasicParsing).ToString()
    $Liste2 = $Liste2 -split '[\r\n]'
    $Liste3 = (Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Hortenkommune/Pureservice-Password-Reset/master/Byer.txt" -UseBasicParsing).ToString()
    $Liste3 = $Liste3 -split '[\r\n]'
    $Word1 = $Liste1 | Sort-Object { Get-Random } -Unique | Select-Object -first 1
    $Word2 = $Liste2 | Sort-Object { Get-random } -Unique | Select-Object -first 1
    $Word3 = $Liste3 | Sort-Object { Get-random } -Unique | Select-Object -first 1
    $Word4 = "i"
    $Date = Get-Date -Format "ddMM"
 
    $pwd = $Word1 + " " + $Word2.tolower() + " " + $Word4.tolower() + " " + $Word3 + " " + $Date 
  
    $pwd

}

##Config stuff
$config = Get-Content C:\Pureservice\config.json | convertfrom-json

$Version = "1.72.4"
$versionCheck = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Hortenkommune/Pureservice-Password-Reset/master/version.json" -UseBasicParsing
Write-Host "Sjekker versjonsnummer... Du kjører versjon $Version..."

#added cleanup
If(Test-Path C:\Pureservice\Reset-PasswordViaPureservice.ps1){
    Remove-Item -Path "C:\Pureservice\Reset-PasswordViaPureservice.ps1"
}

if ($Version -eq $versionCheck.version) {
    Write-Host "Du er allerede på nyeste versjon... Fortsetter"
}
else {
    Write-Host "Ny versjon er $Versioncheck... Oppdaterer scriptet"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Hortenkommune/Pureservice-Password-Reset/master/Reset-PasswordViaPureservice.ps1" -OutFile "C:\Pureservice\Reset-PasswordViaPureservice.ps1" -UseBasicParsing
    Start-Sleep 1
    if ($ticketnumber) {
        Start-Process "powershell.exe" -ArgumentList "-File `"C:\Pureservice\Reset-PasswordViaPureservice.ps1`" -WaitFor $PID -ticketNumber $ticketnumber"
    }
    else {
        Start-Process "powershell.exe" -ArgumentList "-File `"C:\Pureservice\Reset-PasswordViaPureservice.ps1`" -WaitFor $PID"
    }
    break
}

$Credentials = Get-Credential -Message "Bruker med tilatelse til å resette passord..."

if ($ticketnumber) {
    
    $baseUri = $Config.baseUri 
    $apiKey = $config.apiKey
    $content = $Config.content

    # Declare Pureservice variables -Do not change
    $headers = @{'Accept' = 'application/vnd.api+json'; 'X-Authorization-Key' = $apiKey }
  

    # Get User from Active Directory
    $UserName = Read-Host "Vennligst spesifiser brukernavn"
    $userObj = Get-ADUser -Filter { SamAccountName -eq $UserName } -Properties mail, LockedOut -Credential $Credentials
    $userName = $userObj.SamAccountName
    Unlock-ADAccount -Identity $userObj -Credential $Credentials

    # Get ticket info
    $ticketUri = "$baseUri/api/ticket?filter=requestNumber=$ticketNumber"
    $ticketQuery = Invoke-RestMethod -uri $ticketUri -ContentType $content -Headers $headers
    $ticketId = $ticketQuery.tickets.Id

    #Get agent to assign ticket
    $AdSearch = Get-ADUser -Filter "SamAccountName -eq '$env:USERNAME'" -pr cn, displayName -Credential $Credentials
    $GetAgents = invoke-restmethod -uri "$BaseUri/api/user/?filter=$($config.pureserviceFilter)" -headers $headers | Select-Object -ExpandProperty users | Select-Object fullName, id
    $Agent = $GetAgents | Where-Object { $_.fullName -contains $AdSearch.displayName } | Select-Object id

    $pw = Create-RandomPassword

    # Send the command to change password in Active Directory
    Set-ADAccountPassword -Identity $username -NewPassword (ConvertTo-SecureString -AsPlainText "$pw" -Force) -Reset -Credential $Credentials
  
    # Close ticket and notify user
    $CloseBody = [PSCustomObject]@{
        tickets = @(
            @{
                id              = $ticketID
                subject         = $ticketQuery.tickets.subject
                description     = $ticketQuery.tickets.description
                solution        = "Passordet for bruker med brukernavn $username er satt til '$pw' og endres ved første pålogging.

                Visste du at man kan resette sitt eget passord dersom man har lagret mobilnummeret sitt i HR-systemet? Da skriver man en SMS: HRTPASS og sender til $($config.resetNumber). Da vil man få nytt passord på SMS.
                Pass derfor på å ha riktig informasjon i HR-systemet. Man kan sjekke sine egne opplysninger på $($config.linktoHR) (denne finner man også på skrivebordet og på selvbetjening på intranett - HR Web)
                Vi setter pris på om dere sender brukernavn i passordhenvendelser, det gjør jobben til oss på IT litt lettere."
            
                assignedTeamId  = 1 
                assignedAgentId = $Agent.id
                resolvedbyId    = $ticketQuery.tickets.assignedAgentId
                category1Id     = 1083
                links           = @{
                    user        = @{ id = $ticketquery.tickets.links.user.id }
                    ticketType  = @{ id = $ticketquery.tickets.links.ticketType.id }
                    priority    = @{ id = $ticketquery.tickets.links.priority.id }
                    status      = @{ id = 7 }
                    source      = @{ id = $ticketquery.tickets.links.source.id }
                    modifiedBy  = @{ id = $ticketquery.tickets.links.modifiedBy.id }
                    requestType = @{ id = $ticketquery.tickets.links.requestType.id }
                } 
            }
        )
    } | convertto-json -depth 4



    Invoke-RestMethod -uri "$Baseuri/api/ticket/$ticketID" -Headers $headers  -Body ([System.Text.Encoding]::UTF8.GetBytes($CloseBody))  -Method Put -ContentType $content
    
}
else {
    $UserName = Read-Host "Vennligst spesifiser brukernavn"
    $userObj = Get-ADUser -Filter { SamAccountName -eq $UserName } -Properties mail, LockedOut -Credential $Credentials
    $userName = $userObj.SamAccountName
    Unlock-ADAccount -Identity $userObj -Credential $Credentials

    $pw = Create-RandomPassword
    Set-ADAccountPassword -Identity $userobj -NewPassword (ConvertTo-SecureString -AsPlainText "$pw" -Force) -Reset -Credential $Credentials 
    Set-ADUser -Identity $userobj -ChangePasswordAtLogon $true -Credential $Credentials
    if ($userobj.enabled -eq $false) {
        Unlock-ADAccount -Identity $userObj -Credential $Credentials
    }

    Write-Host "Passord satt til: $pw"

    pause
}

