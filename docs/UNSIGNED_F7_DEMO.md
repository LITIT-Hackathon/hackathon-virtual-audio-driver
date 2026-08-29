# Certificate-free VAD demo (one Windows session)

This path does **not** add any certificate to the computer and does not change
Secure Boot, BitLocker, or the persistent TESTSIGNING boot setting. It is only
for a hackathon/demo machine and must be repeated after every normal restart.

## Start Windows in the temporary unsigned-driver mode

1. Save work and open **Settings > System > Recovery**.
2. Under **Advanced startup**, select **Restart now**.
3. Choose **Troubleshoot > Advanced options > Startup Settings > Restart**.
4. After the restart menu appears, press **7** or **F7** for **Disable driver
   signature enforcement**.

Windows now permits an unsigned or untrusted kernel driver for this session
only. The setting is automatically restored at the next normal restart.

## Install the LIT VAD package

Open an elevated PowerShell and run:

```powershell
Expand-Archive .\dist\LIT-Virtual-Audio-Cable-G2-x64-Debug.zip .\dist\unsigned-demo
.\scripts\install-test-driver.ps1 -PackageDirectory .\dist\unsigned-demo
```

The installer intentionally never imports a `.cer` file. If installation
reports Code 52, Windows was not started using the F7 option; restart and repeat
the temporary startup mode.

## Limit

Windows requires signatures for normal loading of x64 kernel drivers. Therefore
this is not a production installation mechanism: the driver stops working after
the next normal reboot until F7 mode is selected again.
