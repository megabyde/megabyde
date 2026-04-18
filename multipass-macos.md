# Using Multipass on macOS

This note covers the host-side setup, launching a `primary` VM, and connecting to it from a terminal
or VS Code.

## Prepare the host

1. Install [Multipass](https://multipass.run) with [Homebrew](https://brew.sh):

   ```console
   $ brew install --cask multipass
   ...
   🍺  multipass was successfully installed!
   ```

1. Verify that the CLI and daemon are available:

   ```console
   $ multipass version
   multipass   1.13.1+mac
   multipassd  1.13.1+mac
   ```

1. Make sure you have an SSH public key at `~/.ssh/id_rsa.pub`.
   - If you do not, generate one with `ssh-keygen -t rsa`.
   - If you leave the passphrase empty, just press ENTER at the prompt.
   - If you created a new key, restart Terminal so the new shell session picks it up cleanly.

1. Install and configure [XQuartz](https://www.xquartz.org) if you need X11 forwarding.
   - Download and install the DMG from the project website.
   - Log out and back in, or reboot, after installation.
   - In XQuartz preferences, enable `Allow connections from network clients`.
   - Start XQuartz, then run `xhost +` on the host.

## Launch the VM

1. Create a guest named `primary`. Multipass gives `primary` special treatment for host filesystem
   integration:

   ```console
   $ multipass launch --name primary --cpus 4 --mem 4G --disk 10G --cloud-init - <<EOF
   ssh_authorized_keys:
     - $(cat ~/.ssh/id_rsa.pub)
   package_upgrade: true
   packages:
     - build-essential
   EOF
   ```

1. Verify that the instance is running:

   ```console
   $ multipass list
   Name                    State             IPv4             Image
   primary                 Running           192.168.64.5     Ubuntu 24.04 LTS
   ```

   The exact Ubuntu LTS version depends on the current default image, but the default user is
   `ubuntu`.

1. Resolve the VM IP address and keep it for later:

   ```console
   $ IP_ADDRESS=$(multipass info primary --format csv | awk -F, '/^primary/ { print $3 }')
   $ printf '%s\n' "${IP_ADDRESS:?failed to determine the Multipass VM IP address}"
   192.168.64.5
   ```

1. Connect either through the built-in shell:

   ```console
   multipass shell primary
   ```

   or through SSH with X forwarding:

   ```console
   ssh -X ubuntu@${IP_ADDRESS:?}
   ```

## Connect VS Code

1. Open VS Code and click the green button in the lower-left corner.
1. Select `Remote-SSH: Connect to Host...`.
1. Enter `ubuntu@${IP_ADDRESS:?}`.
1. Work in the new VS Code window that opens for the remote session.
1. After the server install completes, the status bar should show `SSH: 192.168.64.5` or your VM's
   actual IP address.
