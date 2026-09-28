Bash Scripts
============
Explains some of the script decisions. If you are going through the source, please start with .bash_load. 



# Bash Customizations


## Echo colorization
	Attribute codes:
	00=none 01=bold 04=underscore 05=blink 07=reverse 08=concealed

	Text color codes:
	30=black 31=red 32=green 33=yellow 34=blue 35=magenta 36=cyan 37=white

	Background color codes:
	40=black 41=red 42=green 43=yellow 44=blue 45=magenta 46=cyan 47=white

	In MacOSX, using \x1B instead of \e. \033 genrally works for all platforms.


## Screenshot utility (`sc`)

`sc mv name.png` moves the newest Desktop screenshot to
`screenshots/<today>/name.png`, creating directories as needed. This is enabled
by default everywhere. Absolute paths, `~` paths, and paths already beginning
with `screenshots/` (including `./screenshots/`) keep their explicit destination.
A destination without `.png` is a directory and keeps the original filename.

Use `sc auto off` or `sc auto on` to save a setting for the current directory and
its descendants. The nearest configured ancestor wins. `sc auto status` shows
the effective setting and its source. `SC_AUTO_PREFIX=1` forces organization on;
any other explicitly set value forces it off. Existing enabled-directory
configuration entries remain valid.

To sync to a project whose name or location differs on the remote machine:

```bash
sc sync config om --remote-dir /home/om/Developer/CMTech/pyspark-guru
sc sync -n
sc sync
```

This maps the current directory to that exact remote project and sends
`./screenshots` into its `screenshots/` directory. The mapping is local to this
project, and descendants append their path relative to the mapped local root.
A closer project mapping overrides an ancestor mapping.

The existing global home-mirroring syntax is still available:

```bash
sc sync config om /home/om
```

Here `/home/om` means the remote home directory: `sc` appends the current local
path relative to `$HOME`. Use `--remote-dir` for an exact project destination.
`sc sync config` shows the project mapping and home-mirroring fallback.

One-time overrides:

```bash
sc sync --to other-host --remote-dir /srv/project
sc sync --to other-host --remote-home /home/other
```

`--remote-dir` and `--remote-home` cannot be combined. Explicit flags take
precedence. `SC_SYNC_HOST` (or `OM_HOST`) overrides the configured host, and
`SC_SYNC_REMOTE_HOME` overrides project mapping with home mirroring. Otherwise
the nearest project mapping takes precedence over the global fallback. Changing
to a different host never reuses the saved project's remote directory; the
fallback uses that host's configured, cached, or SSH-detected home.

`sc sync -n` invokes rsync's dry run, prints the resolved destination, and neither
creates remote directories nor writes the home cache. It still connects to the
remote host; rsync may report an error if remote parent directories do not yet
exist. Configuration commands also support `-n` to preview without writing.

Configuration is stored under `~/.config/sc/`: `config` for auto settings,
`sync` for global home mirroring, `sync-homes` for detected homes, and
`sync-projects.json` for project mappings. Their paths can be overridden with
`SC_CONFIG_FILE`, `SC_SYNC_CONFIG_FILE`, `SC_SYNC_HOMES_FILE`, and
`SC_SYNC_PROJECTS_FILE`, respectively.

Run the regression suite from this directory with:

```bash
python3 tests/test_sc.py
```

Tests use temporary screenshots and configuration; transport tests run rsync
locally without SSH or touching real screenshot files.
