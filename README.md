# Bigstep New PC Setup

Set up a new work computer with **one command**. The command downloads this
repository and installs all the standard Bigstep software automatically.

| Operating system | Status         | Go to                         |
|------------------|----------------|-------------------------------|
| Windows 10 / 11  | ✅ Ready        | [Windows](#windows)           |
| macOS            | 🚧 Coming soon  | [macOS](#macos-coming-soon)   |
| Linux (Ubuntu)   | 🚧 Coming soon  | [Linux](#linux-coming-soon)   |

---

## Windows

### What gets installed

| Software               | Installed by default |
|------------------------|:--------------------:|
| Google Chrome          | ✅ |
| Mozilla Firefox        | ✅ |
| Opera                  | ✅ |
| AnyDesk                | ✅ |
| Adobe Acrobat Reader   | ✅ |
| Microsoft 365 (Office) | ✅ |
| WinMemoryCleaner       | ✅ |
| ScanCircle4D, Tux Paint, 7-Zip, VLC, Zoom, Slack, VS Code, Notepad++ | ❌ (optional – see [Adding or removing software](#adding-or-removing-software)) |

### Before you start

- The PC must be connected to the **internet**.
- You must be able to approve an **Administrator** prompt on the PC.
- Setup takes about **10–30 minutes**, depending on internet speed. Keep the PC
  switched on and plugged in. Most of that time is **Microsoft 365** (a 2–3 GB
  download). It installs in the background while the other apps install, and the
  script waits for it at the end. The summary shows how many minutes each app took.

### Method 1 – One command (recommended)

1. Click the **Start** button and type **`PowerShell`**.
2. Click **Windows PowerShell** to open it. (Running it as Administrator is not
   needed; the script will ask for Administrator rights by itself.)
3. Copy the command below, paste it into the PowerShell window
   (right-click pastes), and press **Enter**:

   ```powershell
   irm https://raw.githubusercontent.com/akashsharma-creator/bigstep-setup/main/windows/setup.ps1 | iex
   ```

4. A **"Do you want to allow this app to make changes?"** window appears. Click **Yes**.
5. A new blue PowerShell window opens and installs the software one by one.
   **Don't close it.** Some installers (for example Microsoft 365) may open
   their own window. Let them finish.
6. At the end you'll see a **SUMMARY** table showing each app as `OK` or `FAILED`.
   Press **Enter** to close the window.
7. **Restart the PC.**

### Method 2 – From a pendrive (no internet / slow internet)

1. On a PC that has internet, download this repo: on the GitHub page click
   **Code → Download ZIP**, then extract it.
2. Copy the extracted **`windows`** folder to a pendrive.
3. On the new PC, open the `windows` folder on the pendrive and **double-click `install.bat`**.
4. Click **Yes** on the Administrator prompt, then follow steps 5–7 above.

> Without internet, only apps that have a file in `windows/installers/` will install.

### After installation

- **Microsoft 365:** open Word or Outlook and **sign in with your company account** to activate it.
- **AnyDesk:** open it and note the AnyDesk address of this PC for IT support.
- **Log file:** a full log of each run is saved in `C:\BigstepSetup\`.

### Troubleshooting

| Problem | Fix |
|---|---|
| An app shows **FAILED** in the summary | Run the same command again. Apps that are already installed are skipped, so only the missing ones are retried. |
| `irm` / "could not be resolved" / download error | Check the internet connection, or use [Method 2](#method-2--from-a-pendrive-no-internet--slow-internet). |
| "running scripts is disabled on this system" | Use the one-line command from Method 1 exactly as written, or double-click `install.bat`. Both get around this setting. |
| Nothing happens after clicking **Yes** | Look for the second PowerShell window on the taskbar. |
| Still stuck | Send the latest log file from `C:\BigstepSetup\` to IT. |

### Adding or removing software

All Windows apps are listed in [`windows/apps.json`](windows/apps.json). Each app looks like this:

```json
{ "name": "VLC", "enabled": false, "wingetId": "VideoLAN.VLC" }
```

| Field       | What it means |
|-------------|---------------|
| `name`      | Name shown during installation. |
| `enabled`   | `true` = install it, `false` = skip it. |
| `wingetId`  | ID used by **winget** (Windows' built-in installer) to download the latest version. To find an ID, run `winget search <app name>` on any Windows PC. |
| `installer` | *(optional)* An installer file in `windows/installers/`, used if winget isn't available or fails. |
| `args`      | *(optional)* Silent-install options for that installer file. |
| `background`| *(optional)* `true` = start this installer and carry on with the other apps without waiting. Use it for large, slow installers (Microsoft 365 uses it). |
| `portable`  | *(optional)* `true` = the app has no installer. The file is copied to Program Files and a Start Menu shortcut is added. |

**To add a new app:**
1. Find its winget ID: `winget search "app name"`.
2. Add a line to `windows/apps.json` with `"enabled": true`.
3. *(Optional)* Put its installer in `windows/installers/` and set `installer` / `args`.
   GitHub does **not** accept files larger than **100 MB**.
4. Commit and push. Every new PC gets the change straight away.

---

## macOS (coming soon)

This will work the same way: one command in **Terminal**, using `macos/setup.sh`
and `macos/apps` (installed through Homebrew).

```bash
# Not available yet
curl -fsSL https://raw.githubusercontent.com/akashsharma-creator/bigstep-setup/main/macos/setup.sh | bash
```

## Linux (coming soon)

This will work the same way: one command in **Terminal**, using `linux/setup.sh`
(installed through apt / snap).

```bash
# Not available yet
curl -fsSL https://raw.githubusercontent.com/akashsharma-creator/bigstep-setup/main/linux/setup.sh | sudo bash
```

---

## Repository layout

```
bigstep-setup/
├── README.md          ← this guide
├── windows/
│   ├── setup.ps1      ← main Windows setup script
│   ├── install.bat    ← double-click launcher (pendrive use)
│   ├── apps.json      ← list of Windows apps to install
│   └── installers/    ← offline / fallback installer files
├── macos/             ← (coming soon)
└── linux/             ← (coming soon)
```

## Rules for this repository

- This repository is **public**. **Never** add passwords, licence keys, Wi-Fi
  keys or personal files.
- Keep each file under **100 MB**. Store large ISO files on the pendrive instead.
- Only add installers downloaded from the software's **official website**.
