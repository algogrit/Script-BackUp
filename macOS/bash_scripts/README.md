Bash Scripts
============
Explains some of the script decisions. If you are going through the source, please start with .bash_load. 

## CoderMana NAS backup

`bin/backup-codermana-to-nas` mirrors the Zoho WorkDrive `CoderMana` folder to
the `CoderMana Drive` SMB share. It runs only when the NAS SMB service at
`uttara.local:445` is reachable; other networks are successful no-ops. Run it
manually with `bin/backup-codermana-to-nas --dry-run` before the first backup.
The share mounts locally at `~/Volumes/CoderMana Drive` so the LaunchAgent does
not require administrator privileges.

It excludes legacy `*.gdocx` and `*.gsheetx` link files, `.DS_Store`, and
Synology Drive working metadata. NAS-managed `#recycle` and backup-archive
directories are protected from mirror deletions. Changed or deleted NAS copies
are retained under the hidden
`.codermana-backup-archive/` directory in the share. The SMB credential must
already be stored in Keychain for `uttara.local` (see `aliases/.nas`).
It requires the full rsync executable at `/usr/local/bin/rsync`; macOS's
built-in `openrsync` cannot safely apply the required protection filters.
The LaunchAgent is installed by `restore_scripts.sh` only on the Mac whose
local host name is `Arundhati`.

### First run and macOS permissions

Run the first backup manually in Terminal while connected to the NAS. This
allows macOS to present any required access prompts for the Zoho WorkDrive
folder and the NAS network volume before the background LaunchAgent runs.

```bash
cd ~/Script-BackUp/macOS

# Preview the mirror without changing files.
./bash_scripts/bin/backup-codermana-to-nas --dry-run

# Approve any macOS access prompts, then create the initial versioned backup.
./bash_scripts/bin/backup-codermana-to-nas
```

A successful real run ends with `CoderMana backup completed` and the NAS
archive directory. To check a scheduled run, use:

```bash
tail -n 100 ~/Library/Logs/codermana-nas-backup.log
```

Do not run `launchctl kickstart -k` while a backup is active: the `-k` option
terminates the running job before starting another one. The agent normally
runs every 30 minutes while `uttara.local:445` is reachable.



# Bash Customizations


## Echo colorization
	Attribute codes:
	00=none 01=bold 04=underscore 05=blink 07=reverse 08=concealed

	Text color codes:
	30=black 31=red 32=green 33=yellow 34=blue 35=magenta 36=cyan 37=white

	Background color codes:
	40=black 41=red 42=green 43=yellow 44=blue 45=magenta 46=cyan 47=white

	In MacOSX, using \x1B instead of \e. \033 genrally works for all platforms.
