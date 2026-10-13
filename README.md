# unlock-region-change

Change your Escape from Tarkov matchmaking region **while the game is running**, without restarting it.

The BSG Launcher hides its **Change region** button as soon as the game starts, so switching servers (e.g. NA Central → EU North) normally means closing Tarkov, changing the region and launching again. This patch keeps that button available while you play. Your next raid uses the new region.

> [!WARNING]
> **Use at your own risk.** This is an unofficial modification of the BSG Launcher. It is not made, endorsed or supported by Battlestate Games. Read the [Disclaimer](#disclaimer) and [Is it bannable?](#is-it-bannable) before using it.

## Usage

1. [Download this repository](../../archive/refs/heads/main.zip) and extract it anywhere.
2. Double-click **`RegionSwitch-Patch.cmd`**.
3. Fully exit the launcher (right-click the tray icon → Exit) and start it again.

With Tarkov running, the **Change region** button stays in the launcher. Pick your datacenters, click **Apply**, and queue for a raid. You need to be in the main menu, not in a raid or in the matchmaking queue.

**To undo:** double-click **`RegionSwitch-Undo.cmd`**, then restart the launcher.

**After a launcher update:** updates replace the launcher's files and remove the patch. Run `RegionSwitch-Patch.cmd` again.

### Options

`RegionSwitch.ps1` can also be run from PowerShell:

```powershell
.\RegionSwitch.ps1                 # apply the patch
.\RegionSwitch.ps1 -Undo           # remove the patch
.\RegionSwitch.ps1 -Status         # check whether the patch is applied
.\RegionSwitch.ps1 -LauncherDir "D:\Games\BsgLauncher"   # launcher not in the default folder
```

The default launcher folder is `C:\Battlestate Games\BsgLauncher`.

## How it works

### How region selection works in Tarkov

1. The launcher's **Change region** window gets the list of datacenters from BSG (`/launcher/dataCenter/list`) and pings each one from your PC.
2. When you click **Apply**, the launcher sends your choice to BSG (`/launcher/setDataCenters`). It is saved **on BSG's servers, on your account**, not on your PC.
3. When you queue for a raid, BSG's matchmaker reads your saved choice and puts you on a game server in one of those datacenters.

The game client itself never chooses a region. It only reports pings and connects to whichever server the matchmaker gives it.

### What BSG changed

The launcher's interface is a web page that ships with the launcher (`Content\js\app\games\stateHandler.js`). When the game is running, that page hides the whole top button row, Change region included:

```js
case "inGame":
    ...
    game_main.find('.top_buttons').css({visibility: "hidden"})
```

Nothing else stops a mid-game region change. The launcher's own code behind the button doesn't check whether the game is running. BSG's server accepts the change at any time, and the very next raid uses it.

### What the patch changes

It adds **two lines** to that one file. Each line ends with a `// REGION-SWITCH-PATCH` marker comment:

```js
// at the start of every screen redraw: undo the override, so every other state looks exactly as before
game_main.find('.top_buttons .config-matching').css({visibility: ""}) // REGION-SWITCH-PATCH

// in the "inGame" case, right after the row is hidden: show only the Change region button again
game_main.find('.top_buttons .config-matching').css({visibility: "visible"}) // REGION-SWITCH-PATCH
```

The rest of the top button row stays hidden while you play, as normal.

Safety features of the script:

- **Backup:** it saves the original file as `stateHandler.js.region-switch.bak` before changing anything.
- **Undo:** it removes every line carrying the marker, so undo works even if the backup is lost. After undo, the file is byte-for-byte identical to the original.
- **Fails safely:** if a launcher update changes the code so the expected lines can't be found, it stops and changes nothing.
- **Safe to re-run:** running it on an already-patched launcher does nothing.

## Is it bannable?

**Nobody can promise that it isn't**, and that includes the author (see the [Disclaimer](#disclaimer)). Here is why the risk is believed to be low:

- **The game is not touched.** No game files, game memory or network traffic are modified, and nothing is injected into the game. BattlEye protects the game, and this patch never comes near it.
- **The only change is to the launcher's display.** The patch edits one UI script so that a button which already exists stays visible. No launcher program code (`.exe`/`.dll`) is modified.
- **BSG's servers see a normal request.** Clicking Apply makes the launcher send the same `setDataCenters` request through its own code, with its own login, that it sends when the game is closed. Nothing is forged or replayed, and no login tokens are read or handled by this patch.
- **It is an official feature, just at a different time.** Changing your region is a normal launcher feature, and changing it while the game was running used to be possible in the stock launcher. The patch only removes when you are allowed to click the button.
- **The server accepts it.** In testing, BSG's server accepted a region change made mid-session and the next raid was placed in the new region. Nothing was rejected or flagged.
- **It doesn't let you join regions you couldn't already pick.** The launcher still pings each datacenter before applying and refuses any that are above BSG's ping limit (210 ms for NA/EU/RU/South America, 250 ms elsewhere).

What could still go wrong:

- **BSG hid the button on purpose.** Their servers can see that your region changed while you had an active game session. They could decide to log, reject or penalise this in the future.
- **It may break BSG's rules.** Modifying the launcher may go against Battlestate Games' EULA / Terms of Use, even though the change is cosmetic.
- **Future launcher versions may detect it.** The launcher doesn't currently check its own files, but a later version could. Undo the patch if that ever happens.

If you are not comfortable with these risks, don't use the patch. You can always change region the normal way, by closing the game first.

## Requirements

- Windows with PowerShell 5.1 or later (included with Windows 10/11)
- BSG Launcher installed (Steam players whose game starts through the BSG Launcher included)

## Disclaimer

THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND. **YOU USE IT ENTIRELY AT YOUR OWN RISK.**

- The author is **not responsible** for any account bans, suspensions, restrictions, wipes, loss of items or progress, launcher or game malfunctions, or any other consequences of using this software, whether direct or indirect.
- This project is **not affiliated with, endorsed by, or connected to Battlestate Games Limited** in any way. "Escape from Tarkov", "BSG Launcher" and related names are trademarks of their respective owners.
- This software does not contain any code or files from Battlestate Games. It only edits a file that is already on your computer, and it can fully undo that edit.
- It is your responsibility to make sure your use of this software complies with Battlestate Games' EULA and Terms of Use, and with the laws that apply to you.
- The explanation of the risks above is a good-faith description based on how the launcher worked at the time of writing. It is not a guarantee, and it may stop being accurate if Battlestate Games changes the launcher, the game or their policies.

See [LICENSE](LICENSE) for the full terms.
