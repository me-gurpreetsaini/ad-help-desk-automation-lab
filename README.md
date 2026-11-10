# Active Directory Help Desk and Automation Lab

A Windows Server 2022 domain with a Windows 11 client, built from scratch in VMware. I automated bulk user creation with PowerShell and set up DHCP, DNS, NAT, shared folders, and Group Policy, then used the environment to practice real help desk ticket work.

## Scenario

I play the IT person at a 150-person company. I build the domain, create the staff accounts, give everyone internet access through the server, and then handle the kind of account and access tickets a help desk sees every week.

## Tools

VMware Workstation Pro, Windows Server 2022 (evaluation), Windows 11 Enterprise (evaluation), PowerShell, Active Directory Users and Computers, DHCP, DNS, Routing and Remote Access (NAT), Group Policy Management.

## Lab design

| | DC01 | CLIENT01 |
|---|---|---|
| OS | Windows Server 2022 Standard (Desktop Experience) | Windows 11 Enterprise |
| Resources | 2 vCPU, 4 GB RAM, 60 GB disk | 2 vCPU, 4 GB RAM, 60 GB disk |
| Network | Internal NIC on VMnet2 (192.168.50.10), External NIC on NAT | One NIC on VMnet2, address from DHCP |
| Roles | AD DS, DNS, DHCP, RRAS (NAT) | Domain member |

Domain: `corp.local`. Internal network: `192.168.50.0/24`. VMware's built-in DHCP is turned off on VMnet2 so that DC01 is the only DHCP server, as in a real office.

![VMnet2 settings](SCREENSHOTS/01-vmnet2-virtual-network-editor.png)

*VMnet2 is host-only with VMware's DHCP disabled, so DC01 controls addressing.*

![DC01 hardware](SCREENSHOTS/02-dc01-vm-hardware-and-adapters.png)

*DC01 has two adapters: one on the private network, one on NAT for internet access.*

![CLIENT01 hardware](SCREENSHOTS/03-client01-vm-hardware.png)

*CLIENT01 sits only on the private network, so its internet access has to go through DC01.*

## What I built

### 1. Domain controller, DHCP, and NAT
I installed AD DS, DNS, and DHCP on DC01 and promoted it to a domain controller for a new forest, `corp.local`. I added a DNS forwarder so the lab can resolve internet names, created the DHCP scope `LabScope` (192.168.50.100 to 150), and set up NAT in RRAS so clients reach the internet through DC01.

### 2. Company structure and bulk user creation
I created an OU structure (Corp, with Users split into Sales, IT, HR, Finance, and Operations, plus Computers, Groups, and Disabled) and six security groups. I created three users by hand to learn the fields, then wrote a PowerShell script that reads a CSV and creates 150 users in their department OUs and adds each to the matching security group.

![Generated CSV](SCREENSHOTS/04-users-csv-generated.png)

*The CSV holds one row per employee: first name, last name, logon name, and department.*

![Script timing](SCREENSHOTS/05-bulk-user-script-measure-command.png)

*The script wrapped in `Measure-Command`: 150 accounts created in about 20.7 seconds.*

![Populated OUs](SCREENSHOTS/08-aduc-populated-ous.png)

*The department OUs filled with users after the script ran.*

### 3. Joining the client and testing the network
CLIENT01 received its address from DC01's DHCP server, resolved `corp.local` through DC01's DNS, reached the internet through NAT, and joined the domain. I moved its computer account from the default Computers container into the Corp > Computers OU so Group Policy can target it, then signed in as a domain user.

![CLIENT01 IP configuration](SCREENSHOTS/09-client01-ipconfig-all.png)

*CLIENT01's lease from DC01: address in the scope, gateway and DNS pointing at DC01.*

![DNS and internet tests](SCREENSHOTS/10-client01-dns-and-internet-tests.png)

*`nslookup corp.local` resolves to DC01 and the ping to 8.8.8.8 succeeds through NAT.*

![DHCP lease](SCREENSHOTS/11-dc01-dhcp-lease-client01.png)

*The lease for CLIENT01 as seen on the DHCP server.*

![Computer account](SCREENSHOTS/12-client01-joined-computer-account.png)

*CLIENT01's computer account in the Corp > Computers OU after joining the domain.*

![Domain login](SCREENSHOTS/13-client01-domain-login-jsmith.png)

*A domain user created on DC01 signing in on CLIENT01.*

### 4. Shared folder and group-based access
I created a Sales share with Everyone: Full Control at the share level and NTFS Modify for `SG-Sales` only, with the default Users entries removed. Access is controlled by group membership, never by individual user.

![NTFS permissions](SCREENSHOTS/14-sales-folder-ntfs-permissions.png)

*Only SG-Sales (Modify), Administrators, SYSTEM, and CREATOR OWNER have access.*

![Jane has access](SCREENSHOTS/15-jsmith-sales-share-access.png)

*Jane (Sales) opens the share and creates a file.*

![Mark is denied](SCREENSHOTS/16-mlee-sales-share-denied.png)

*Mark (IT) gets "Access denied" on the same share.*

### 5. Group Policy
I created three GPOs: a password and lockout policy linked at the domain level, a mapped Sales drive linked to the Sales OU, and a password-protected screen saver timeout linked to the Users OU. I verified them on CLIENT01 with `gpupdate /force` and `gpresult`.

![Password and lockout settings](SCREENSHOTS/17-gpo-password-lockout-settings.png)

*Minimum length 10, maximum age 90 days, lockout after 5 failed attempts.*

![Mapped drive](SCREENSHOTS/18-jsmith-mapped-sales-drive.png)

*Jane gets the S: drive because her account is in the Sales OU.*

![Jane's applied GPOs](SCREENSHOTS/19-jsmith-gpresult-applied-gpos.png)

*`gpresult` showing the user policies that applied to Jane.*

![Computer policies](SCREENSHOTS/19b-client01-gpresult-computer-scope.png)

*`gpresult` computer scope showing the domain-level policies applied to CLIENT01.*

![Mark's applied GPOs](SCREENSHOTS/20-mlee-gpresult-no-sales-gpo.png)

*Mark gets the screen saver policy but not the Sales drive, because he is in the IT OU.*

## Results

- 150 users created, placed in department OUs, and added to security groups in about 20.7 seconds with one script
- Sales share accessible to a Sales user and denied to an IT user through group membership alone
- Three GPOs applied and verified with `gpresult`, with different results for users in different OUs

## Troubleshooting I did

**Windows Server setup stopped with "Windows cannot find the Microsoft Software License Terms."**
Cause: VMware's Easy Install was feeding Setup an answer file that didn't work with the evaluation ISO. Fix: removed the virtual floppy and ran Setup manually.

**`SG-Sales` showed 33 members instead of the expected 31.**
Cause: two manually created users (Mark and Priya) had been created in the Sales OU instead of IT and HR. I found them by comparing the group against the source CSV. Fix: moved them to the correct OUs, corrected their group membership, and re-checked the counts (31 each).

![Unexpected members](SCREENSHOTS/07a-sg-sales-unexpected-members.png)

*Comparing group members against the CSV exposed the extra accounts.*

![Counts after fix](SCREENSHOTS/07b-group-counts-after-fix.png)

*Group counts back to the expected 31 after the fix.*

**CLIENT01 had an IP address but no default gateway, so it couldn't reach the internet.**
Cause: the DHCP scope had no router option (003), and there were leftover WINS options (044 and 046) pointing at an unreachable address. Fix: added option 003 pointing at DC01, removed the WINS options, and renewed the lease.

**`nslookup corp.local` returned a second, unreachable address.**
Cause: DC01's NAT adapter was registering its own address in DNS. Fix: turned off DNS registration on the External adapter and removed the stray records.

## Notes

- The passwords in the script (`Welcome#2026`) are fake lab values. In a real environment I would never store a password in a script.
- All software is free evaluation editions, used in an isolated lab.

## Still to come

Phase G help desk tickets: password reset with forced change, account unlock, new hire onboarding, leaver offboarding, "Access denied" fix, and Delegation of Control for a help desk group.
