# Hyper-V Manager Dashboard (PowerShell Universal)

This project is a **PowerShell Universal (PSU)** dashboard that lets you manage Hyper-V virtual machines on a local host and view basic hypervisor/VM metrics, including historical CPU and memory usage. PowerShell Universal runs PowerShell-based dashboards, so the UI and logic here are regular PowerShell scripts hosted by PSU.

---

## Prerequisites
The following must be installed so the dashboard can work. Installation of Influxdb can be done directly on the machine or through Docker.
  - Windows 10/11 or Windows Server with Hyper-V role installed
  - [Powershell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5)
  - [Powershell Universal](https://powershelluniversal.com/downloads)
  - [InfluxDB](https://docs.influxdata.com/influxdb3/enterprise/install/#download-and-install-the-latest-build-artifacts)

## Clean Install

1. Place "Repository" folder and database.db in C:\ProgramData\UniversalAutomation\ 

2. Trust the PSU repository (unblock files):

       $repo = 'C:\ProgramData\UniversalAutomation\Repository'
       Get-ChildItem $repo -Recurse -File | Unblock-File

3. Create a **bucket**, **organization**, and **token** in your InfluxDB instance.

4. Create connection secrets for Influx in Powershell Universal (**IMPORTANT:** secrets must be named exactly):
   - `influxBucket`
   - `influxOrg`
   - `influxServer`
   - `influxToken`  
   Add the values for your InfluxDB instance.

5. Import Influx module in Powershell Universal (Platform -> Modules -> Repositories)

6. Create folder structure for Hyper-V:
   - `C:\Hyper-V\iso` → put ISO files here
   - *(Optional)* `C:\Hyper-V\Disks` and `C:\Hyper-V\VM` → you can set Hyper-V to store disks and VM files here so everything is in one place


---

## Features

### Hyper-V Manager

Allows the user to create, edit, delete and manage VMs on the local hypervisor through a handy dashboard.

- **Create:** create new VMs and use ISOs located in `C:\Hyper-V\iso`
- **Edit:** edit the name and memory size of existing VMs
- **Delete:** delete any VM on the local hypervisor
- **Manage:** stop, start or reboot VMs on the local hypervisor

### Hypervisor & VM Information

Gives the user basic data on the hypervisor or a VM and allows the user to see historical CPU and memory usage.

**Metrics:**
- Hostname
- Runtime
- Total memory
- Total disk space
- Historical CPU Usage
- Historical Memory Usage
- Disk usage percentage (free and used)

## Usage

### Powershell Universal

The admin console can be reached on port 5000 of the server running PSU. The dashboard has the endpoint /Hyperv
- **Admin console**: http://localhost:5000/admin
- **Dashboard**: http://localhost:5000/Hyperv/

### Influxdb

Influxdb can be accessed on port 8086: http://localhost:8086
