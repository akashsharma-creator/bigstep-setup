# Bigstep New PC Setup

Set up a new work computer with **one command**. The command downloads this
repository and installs the standard Bigstep software, **always the latest
version**. Apps that are already installed get upgraded.

## 👉 One link for every computer

**https://akashsharma-creator.github.io/bigstep-setup/**

Open this link on the new computer. It detects whether it's Windows, a Mac or Ubuntu
and shows the right command, with a **Copy** button and step-by-step instructions.

| Operating system | Status         | Go to                         |
|------------------|----------------|-------------------------------|
| Windows 10 / 11  | ✅ Ready        | [Windows](#windows)           |
| macOS            | ✅ Ready        | [macOS](#macos)               |
| Linux (Ubuntu)   | ✅ Ready        | [Linux](#linux-ubuntu)        |

---

## Windows

### What gets installed

You can change this list each time in the selection window (see step 5 below).

| Software               | Ticked by default |
|------------------------|:--------------------:|
| Google Chrome          | ✅ |
| Mozilla Firefox        | ✅ |
| Opera                  | ✅ |
| AnyDesk                | ✅ |
| Adobe Acrobat Reader   | ✅ |
| Microsoft 365 (Office) | ✅ |
| WinMemoryCleaner       | ✅ |
| ScanCircle4D, 7-Zip, VLC, Zoom, Slack, VS Code, Notepad++ | ❌ (optional – see [Adding or removing software](#adding-or-removing-software)) |

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
5. A **"Bigstep PC Setup – choose software"** window opens, listing every app:
   - The standard apps are **already ticked**.
   - **Untick** anything this PC doesn't need, and **tick** any extras (VLC, Zoom, Slack…).
   - **Select all** / **Select none** tick or untick everything at once.
   - Click **Install** to continue, or **Cancel** to exit without installing anything.

   > If the window can't open, a numbered list appears in PowerShell instead.
   > Type a number (or several, e.g. `2 5 9`) and press Enter to tick/untick,
   > `A` = all, `N` = none, then press **Enter** on an empty line to install.

   A new blue PowerShell window then installs the software you picked, one by one.
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
| An app shows **FAILED** in the summary | Run the same command again. Apps that are already installed are just checked for updates, so it's safe to re-run. |
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
| `enabled`   | `true` = ticked by default in the selection window, `false` = shown but unticked. |
| `wingetId`  | ID used by **winget** (Windows' built-in installer) to download the latest version. If the app is already installed, winget upgrades it to the latest version. To find an ID, run `winget search <app name>` on any Windows PC. |
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

## macOS

The script **detects the Mac's chip, Intel or Apple M-series (M1/M2/M3/M4…)**,
and downloads the **latest version for that chip** straight from each vendor's
official website:

| App | Intel Mac | M-series Mac |
|---|---|---|
| Zoom, Slack, VS Code | Intel version | M-series (Apple Silicon) version |
| Microsoft 365, Chrome, Firefox, AnyDesk | Universal version (runs natively on both) | Universal version |
| Opera, Acrobat Reader, VLC, 7-Zip | via **Homebrew** (picks the right chip) | via **Homebrew** |

- If a direct download fails, the script automatically tries Homebrew instead.
- Homebrew (the standard Mac package manager) is installed only if one of the
  selected apps needs it.
- On M-series Macs, **Rosetta 2** is also installed. It lets older Intel-only apps
  run, and the script accepts Apple's Rosetta licence automatically.
- Apps that are already installed are replaced with, or upgraded to, the latest version.
- The installer files are **not stored on GitHub**: GitHub's 100 MB file limit is
  too small, and Office alone is about 3 GB. The script on GitHub downloads them
  from the vendors when it runs.

### What gets installed

| Software               | Ticked by default |
|------------------------|:--------------------:|
| Microsoft 365 (Office) | ✅ |
| Google Chrome          | ✅ |
| Mozilla Firefox        | ✅ |
| Opera                  | ✅ |
| AnyDesk                | ✅ |
| Adobe Acrobat Reader   | ✅ |
| 7-Zip, VLC, Zoom, Slack, VS Code | ❌ (optional) |

WinMemoryCleaner, ScanCircle4D and Notepad++ are Windows-only, so they aren't on this list.

### Before you start

- The Mac must be connected to the **internet**.
- You must know the **Mac login password**, and the user must be an **Administrator** on the Mac.
- Allow **20–45 minutes**. On a new Mac, Homebrew and Apple's developer tools are installed first.

### Steps

1. Press **⌘ Cmd + Space**, type **Terminal**, and press **Enter**.
2. Paste this command and press **Enter**:

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/akashsharma-creator/bigstep-setup/main/macos/setup.sh)"
   ```

3. A **Bigstep Mac Setup** window lists every app, with the standard ones already
   selected. **⌘ Cmd-click** to add or remove apps, then click **Install**.
   (If the window can't open, a numbered text list appears in Terminal instead,
   which works the same way as on Windows.)
4. When asked, type the **Mac login password** and press **Enter**. Nothing
   appears while you type, which is normal.
5. Wait for the **SUMMARY**, then restart the Mac.
6. Open Word or Outlook and **sign in with your company account** to activate Microsoft 365.

A log of each run is saved in `~/BigstepSetup/`.

### Adding or removing Mac software

Edit [`macos/apps.txt`](macos/apps.txt). Each line has 6 columns separated by `|`:

```
Name | ticked (1/0) | cask/formula | Homebrew name | Intel download link | M-series download link
Zoom | 0            | cask         | zoom          | https://zoom.us/client/latest/Zoom.pkg | https://zoom.us/client/latest/Zoom.pkg?archType=arm64
VLC  | 0            | cask         | vlc           | -                   | -
```

- **Download links:** use the vendor's official "always latest" link. It can
  be a `.dmg`, `.pkg` or `.zip`, and the script works out which. Write `same` in
  the M-series column if one universal link works on both chips, or `-` for
  no link, in which case Homebrew is used.
- **Homebrew name:** find it with `brew search "app name"` or on https://formulae.brew.sh.
  Desktop apps are usually a `cask`, and command-line tools a `formula`.

## Linux (Ubuntu)

Works on **Ubuntu 22.04 / 24.04** and other Ubuntu-based systems (Linux Mint,
Debian). The script **detects the PC's chip, Intel/AMD (`amd64`) or ARM
(`arm64`)**, and installs the **latest version for that chip**.

### What gets installed

| Software | Ticked by default | Intel/AMD PC | ARM PC | Comes from |
|---|:---:|:---:|:---:|---|
| Google Chrome | ✅ | ✅ | ✅ | Google's official `.deb` |
| Mozilla Firefox | ✅ | ✅ | ✅ | Snap Store |
| Opera | ✅ | ✅ | ❌ | Snap Store |
| AnyDesk | ✅ | ✅ | ✅ | AnyDesk's official `.deb` (newest version) |
| LibreOffice | ✅ | ✅ | ✅ | Ubuntu (apt) |
| 7-Zip | ❌ | ✅ | ✅ | Ubuntu (apt) |
| VLC | ❌ | ✅ | ✅ | Snap (Intel/AMD), apt (ARM) |
| Zoom | ❌ | ✅ | ❌ | Zoom's official `.deb` |
| Slack | ❌ | ✅ | ❌ | Snap Store |
| VS Code | ❌ | ✅ | ✅ | Microsoft's official `.deb` |

- **Not available on Linux:** Microsoft 365 (use https://office.com in the
  browser; LibreOffice opens Word/Excel/PowerPoint files), Adobe Acrobat Reader
  (Ubuntu's built-in Document Viewer opens PDFs), WinMemoryCleaner, ScanCircle4D
  and Notepad++.
- Apps that aren't made for this PC's chip are shown as *"not available for
  arm64"* and marked **SKIPPED** in the summary.
- Chrome, VS Code and AnyDesk keep updating through Ubuntu's normal **Software
  Updater**, and Snap apps update themselves.

### Steps

1. Press **Ctrl + Alt + T** to open **Terminal**.
2. Paste this command (**Ctrl + Shift + V**) and press **Enter**:

   ```bash
   bash -c "$(wget -qO- https://raw.githubusercontent.com/akashsharma-creator/bigstep-setup/main/linux/setup.sh)"
   ```

3. A **Bigstep PC Setup** window lists every app, with the standard ones already
   ticked. Tick or untick apps, then click **Install**.
   - Without a desktop, for example over SSH, a checklist appears inside the Terminal
     instead: arrow keys move, **Space** ticks, **Enter** installs.
4. Type your **password** when asked and press **Enter**. Nothing appears while
   you type, which is normal.
5. Wait for the **SUMMARY**, then restart the PC.

A log of each run is saved in `~/BigstepSetup/`.

### Adding or removing Linux software

Edit [`linux/apps.txt`](linux/apps.txt). Each line has 4 columns:

```
Name | ticked (1/0) | Intel/AMD source | ARM source
Zoom | 0            | deb:https://zoom.us/client/latest/zoom_amd64.deb | -
VLC  | 0            | snap:vlc         | apt:vlc
```

A source is `deb:<official latest .deb link>`, `snap:<name>`, `apt:<package>`, or
`debrepo:<vendor apt repo>#<package>`. In the ARM column, `same` means the same
source as the Intel/AMD column, and `-` means not available for ARM.

---

## Repository layout

```
bigstep-setup/
├── README.md          ← this guide
├── docs/
│   └── index.html     ← the "one link" page (detects Windows / Mac)
├── windows/
│   ├── setup.ps1      ← main Windows setup script
│   ├── install.bat    ← double-click launcher (pendrive use)
│   ├── apps.json      ← list of Windows apps to install
│   └── installers/    ← offline / fallback installer files
├── macos/
│   ├── setup.sh       ← main Mac setup script (Homebrew)
│   └── apps.txt       ← list of Mac apps to install
└── linux/
    ├── setup.sh       ← main Ubuntu setup script
    └── apps.txt       ← list of Ubuntu apps to install
```

## Rules for this repository

- This repository is **public**. **Never** add passwords, licence keys, Wi-Fi
  keys or personal files.
- Keep each file under **100 MB**. Store large ISO files on the pendrive instead.
- Only add installers downloaded from the software's **official website**.
