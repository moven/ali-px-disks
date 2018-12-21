# Alicloud PX Disk DaemonSet

This repository contains our hack for dealing with Portworks volumes backed by Alicloud disks.  It runs as a kubernetes DaemonSet on all Alibaba Kubernetes Service worker nodes and ensures that those nodes claim an available alicloud disk if one is avilable. 

