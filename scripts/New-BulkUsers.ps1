   Import-Module ActiveDirectory

   $domain   = 'corp.local'
   $baseDN   = 'OU=Users,OU=Corp,DC=corp,DC=local'
   $password = ConvertTo-SecureString 'Welcome#2026' -AsPlainText -Force
   $users    = Import-Csv C:\Scripts\users.csv

   foreach ($u in $users) {
       $ou = "OU=$($u.Dept),$baseDN"
       New-ADUser -Name "$($u.First) $($u.Last)" `
                  -GivenName $u.First `
                  -Surname $u.Last `
                  -SamAccountName $u.Sam `
                  -UserPrincipalName "$($u.Sam)@$domain" `
                  -Department $u.Dept `
                  -Path $ou `
                  -AccountPassword $password `
                  -ChangePasswordAtLogon $true `
                  -Enabled $true

       Add-ADGroupMember -Identity "SG-$($u.Dept)" -Members $u.Sam
   }