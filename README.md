# Alicloud PX Disk DaemonSet

This repository contains our hack for dealing with Portworks volumes backed by Alicloud disks.  It runs as a kubernetes DaemonSet on all Alibaba Kubernetes Service worker nodes and ensures that those nodes claim an available alicloud disk if one is avilable. 

## Assumptions/Requirements

* Each cluster is named and tagged with partner-environment (ex: bca-prod, bca-dev).  
* Disks avialable to be claimed by worker nodes are tagged to match cluter (ex: bca-prod-px-disk-1, bca-prod-px-disk-2, etc.)
* The number of worker nodes should be equal to or greater than the number of available disks.
