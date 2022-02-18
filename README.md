# Windows BHYVE image builder for SmartOS 

Build a windows image for Bhyve use on SmartOS

## Requirements

* A Windows ISO (x64 version)
* Virtio drives for windows ISO
* A machine with a up and running SmartOS global zone running Bhyve vm's or no vm's (you can not start a bhyve if a kvm is running)

## Tested versions

* Tested with Windows 10 x64
* [Virtio 0.1.185](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.185-2/) seems to work, newer releases seems to crash on formatting the disk in the windows installer

## Create the image

* place de needed ISO files somewhere on you SmartOS global zone
* first run ./initialize.sh script with required parameters: windows iso and virtio drivers iso
```
./initialize.sh -w <windows iso> -v <virtio iso>
```
* connect with VNC to the vm (vnc://<golbalzone>:<port>) default the script uses vnc port 5900
* the vm waits for booting until vnc connection is established. press a key to boot form the cdrom
* load virtio drivers from the driver disk under /amd64/<winversion>
* continue installation

* when installer reboots you need to start the vm again with the ./restart.sh script
```
./restart.sh
```
* do not press key to boot from cdrom but let the installer finish
* you might need to restart vm again with the restart script if the installer reboots

* when the installer starts asking questions you need to exit this and goto into audit mode by pressing ctrl + shift + F3
* the installer reboots start the vm again with the ./restart.sh script
* now the installer logs you in as administrator do not close the audit popup window unti you finish as it will shutdown again
* install the virtio drivers form the virtio driver cd by running the msi installer on the cd
* close the installation by closing the audit popup

* now create a zvol image and manifest for imgadm filename and image name are required
```
./create_image.sh -f windows_imgage.zvol -n windows-10-pro
```
* a zvol file and corresponding json image manifest is created

* you can now cleanup the temporary vm by running the cleanup script ./cleanup.sh
```
./cleanup.sh
```

* optional script to install the image and create a vmadm json file to create a vm from this image ./install.sh
```
./install.sh -a win-10-pro -j windows.json
```

Remark: If you use optional arguments in the initialize.sh script you should use the same parrameters in the next steps