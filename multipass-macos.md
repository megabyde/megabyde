# Using Multipass under MacOS

## Setup Dependencies on your Host Machine

1. Install [Multipass](https://multipass.run) using [Homebrew](https://brew.sh):
   ```console
   $ brew install --cask multipass
   ```

1. Verify the installation was successful:
   ```console
   $ multipass version
   multipass   1.10.1+mac
   multipassd  1.10.1+mac
   ```
   
1. If you don't have `~/.ssh/id_rsa.pub`, you can generate one with `ssh-keygen -t rsa`
   - If you do not wish to set a password, just hit ENTER when asked for a passphrase
   - If you generated a key, close and reopen Terminal to start a new shell session
1. Set up and configure [XQuartz](https://www.xquartz.org), an X11 display server for MacOS
	 - Download and install a DMG directly from website
	 - Logout/login or reboot the computer afterwards
	 - Allow X11 forwarding to your host by running `xhost +`
	 - Once you have XQuartz running, go to its "Preferences" and check the "Allow connections from network clients" box

## Setup your Multipass VM

1. Create a Linux guest named `primary`; your `primary` instance gets special treatment with integration to your native filesystem:
   ```console
   $ multipass launch --name primary --cpus 4 --mem 4G --disk 10G --cloud-init - <<EOF
   ssh_authorized_keys:
     - $(cat ~/.ssh/id_rsa.pub)
   package_upgrade: true
   packages:
     - build-essential
   EOF
   ```

1. You now have a Ubuntu 20.04 (Focal) VM named `primary` with a default user named `ubuntu`:
   ```console
   $ multipass list
   Name                    State             IPv4             Image
   primary                 Running           192.168.64.5     Ubuntu 20.04 LTS
   ```
	
1. We can then use this VM using `multipass shell` or through SSH with X forwarding as follows:
   ```console
   $ ssh -X ubuntu@$(multipass info primary --format csv | awk -F, '/^primary/ { print $3 }')
   ```

## Connect VSCode to your Multipass VM

1. Open VSCode and click on the green button in the bottom left corner; this should open a menu listing several "Remote-SSH" options
1. Click "Remote-SSH: Connect to Host...", enter `ubuntu@<ip_address>`, replacing with the address of your Multipass VM
1. This will open a new VSCode window; feel free to close the old window
1. After a brief installation of the VSCode backend onto your VM, the bottom left corner's green button should now read: `SSH: <ip_address>`
