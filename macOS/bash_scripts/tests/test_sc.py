"""Regression tests: python3 tests/test_sc.py [path/to/sc]. No SSH or real screenshots."""
import contextlib
from datetime import datetime
import io
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

SCRIPT = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / 'bin/sc'
SOURCE = SCRIPT.read_text()


class ScTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / 'home'
        self.project = self.home / 'Developer/CMTech/spark-guru'
        self.project.mkdir(parents=True)
        self.desktop = self.home / 'Desktop'
        self.desktop.mkdir()
        self.config = self.home / '.config/sc'
        self.config.mkdir(parents=True)
        self.original_cwd = Path.cwd()
        self.addCleanup(os.chdir, self.original_cwd)
        self.enter(self.project)
        env = patch.dict(os.environ, {'HOME': str(self.home), 'PWD': str(self.project)}, clear=True)
        env.start()
        self.addCleanup(env.stop)
        self.sc = types.ModuleType('sc_test')
        exec(compile(SOURCE, str(SCRIPT), 'exec'), self.sc.__dict__)
        frozen = patch.object(self.sc, 'datetime')
        clock = frozen.start()
        clock.now.return_value = datetime(2026, 9, 28, 10, 31, 32)
        self.addCleanup(frozen.stop)
        subprocess_patch = patch.object(self.sc.subprocess, 'run')
        self.run = subprocess_patch.start()
        self.run.return_value = types.SimpleNamespace(returncode=0, stdout='/home/remote\n')
        self.addCleanup(subprocess_patch.stop)

    def enter(self, directory):
        directory.mkdir(parents=True, exist_ok=True)
        os.chdir(directory)
        if hasattr(self, 'sc'):
            self.sc.PWD = str(directory)

    def invoke(self, *args):
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            code = self.sc.main(list(args))
        return code, output.getvalue()

    def ok(self, *args):
        code, output = self.invoke(*args)
        self.assertEqual(code, 0, output)
        return output

    def screenshot(self):
        source = self.desktop / 'Screenshot 2026-09-28 at 10.31.32 AM.png'
        source.write_bytes(b'screenshot fixture')
        return source

    def sync_source(self):
        (Path.cwd() / 'screenshots').mkdir(exist_ok=True)

    def project_mapping(self, host='om', directory='/home/om/Developer/CMTech/pyspark-guru'):
        self.ok('sync', 'config', host, '--remote-dir', directory)

    def rsync_destination(self):
        command = self.run.call_args.args[0]
        self.assertEqual(command[0], 'rsync')
        return command[-1]

    def test_default_move_creates_dated_directory(self):
        source = self.screenshot()
        self.ok('mv', 'https-not-working.png')
        target = self.project / 'screenshots/2026-09-28/https-not-working.png'
        self.assertEqual(target.read_bytes(), b'screenshot fixture')
        self.assertFalse(source.exists())

    def test_move_explicit_destinations_do_not_get_prefix(self):
        for dest, target in (
            ('././screenshots/a.png', self.project / 'screenshots/a.png'),
            ('screenshots/a.png', self.project / 'screenshots/a.png'),
            (str(self.root / 'absolute.png'), self.root / 'absolute.png'),
            ('~/tilde.png', self.home / 'tilde.png'),
        ):
            with self.subTest(dest=dest):
                self.screenshot()
                self.ok('mv', dest)
                self.assertEqual(target.read_bytes(), b'screenshot fixture')

    def test_screenshots_directory_keeps_original_name(self):
        for dest in ('screenshots', './screenshots/', 'screenshots/'):
            with self.subTest(dest=dest):
                source = self.screenshot()
                self.ok('mv', dest)
                self.assertTrue((self.project / 'screenshots' / source.name).is_file())
                self.assertFalse((self.project / 'screenshots/2026-09-28').exists())

    def test_relative_subdirectory_and_leading_dot(self):
        self.screenshot()
        self.ok('mv', './bugs/a.png')
        self.assertTrue((self.project / 'screenshots/2026-09-28/bugs/a.png').is_file())

    def test_missing_screenshot_does_not_create_directories(self):
        code, output = self.invoke('mv', 'a.png')
        self.assertEqual(code, 1)
        self.assertIn('No screenshots', output)
        self.assertFalse((self.project / 'screenshots').exists())

    def test_auto_off_persists_and_on_restores_default_move(self):
        self.ok('auto', 'off')
        self.screenshot()
        self.ok('mv', 'a.png')
        self.assertTrue((self.project / 'a.png').is_file())
        self.assertIn('OFF', self.ok('auto', 'status'))
        self.ok('auto', 'on')
        self.screenshot()
        self.ok('mv', 'b.png')
        self.assertTrue((self.project / 'screenshots/2026-09-28/b.png').is_file())

    def test_closest_auto_setting_wins_and_siblings_do_not_match(self):
        self.ok('auto', 'off')
        child = self.project / 'nested'
        self.enter(child)
        self.assertIn('OFF', self.ok('auto'))
        self.assertIn(str(self.project).replace(str(self.home), '~'), self.ok('auto'))
        self.ok('auto', 'on')
        self.enter(child / 'deep')
        self.assertIn('ON', self.ok('auto'))
        self.enter(self.project / 'nested-sibling')
        self.assertIn('OFF', self.ok('auto'))
        self.enter(self.project.with_name('spark-guru-other'))
        self.assertIn('(default)', self.ok('auto'))

    def test_legacy_auto_entries_are_preserved(self):
        legacy = self.home / 'legacy'
        (self.config / 'config').write_text(str(legacy) + '\n')
        self.ok('auto', 'off')
        self.assertIn(str(legacy), (self.config / 'config').read_text())
        self.enter(legacy / 'child')
        output = self.ok('auto')
        self.assertIn('ON', output)
        self.assertIn('directory setting:', output)

    def test_auto_environment_is_authoritative(self):
        self.ok('auto', 'off')
        with patch.dict(os.environ, {'SC_AUTO_PREFIX': '1'}):
            self.assertIn('ON', self.ok('auto'))
            self.assertIn('SC_AUTO_PREFIX=1', self.ok('auto'))
        for value in ('0', 'false', ''):
            with self.subTest(value=value), patch.dict(os.environ, {'SC_AUTO_PREFIX': value}):
                self.assertIn('OFF', self.ok('auto'))
        self.assertIn('OFF', self.ok('auto'))

    def test_auto_dry_run_has_no_config_writes(self):
        self.ok('auto', 'off', '-n')
        self.assertFalse((self.config / 'config').exists())
        self.assertIn('ON', self.ok('auto'))

    def test_root_auto_setting_inherits(self):
        (self.config / 'config').write_text('off\t/\n')
        self.assertIn('OFF', self.ok('auto'))

    def test_project_config_does_not_change_global_fallback(self):
        self.ok('sync', 'config', 'other', '/home/other')
        before = (self.config / 'sync').read_bytes()
        self.project_mapping()
        self.assertEqual((self.config / 'sync').read_bytes(), before)
        mapping = json.loads((self.config / 'sync-projects.json').read_text())
        self.assertEqual(mapping[str(self.project)]['host'], 'om')
        output = self.ok('sync', 'config')
        self.assertIn('Project target: om:/home/om/Developer/CMTech/pyspark-guru/screenshots', output)
        self.assertIn('Home-mirroring fallback: other', output)
        self.run.assert_not_called()

    def test_project_mapping_uses_exact_remote_project(self):
        self.project_mapping()
        self.sync_source()
        self.ok('sync')
        self.assertEqual(self.rsync_destination(), 'om:/home/om/Developer/CMTech/pyspark-guru/')
        command = self.run.call_args.args[0]
        self.assertIn('--rsync-path=mkdir -p /home/om/Developer/CMTech/pyspark-guru && rsync', command)

    def test_project_mapping_inherits_relative_subdirectory(self):
        self.project_mapping()
        self.enter(self.project / 'management/sub')
        self.sync_source()
        self.ok('sync')
        self.assertEqual(self.rsync_destination(), 'om:/home/om/Developer/CMTech/pyspark-guru/management/sub/')
        self.assertIn('/management/sub/screenshots', self.ok('sync', 'config'))

    def test_nearest_project_mapping_wins_and_preserves_parent(self):
        self.project_mapping()
        child = self.project / 'nested'
        self.enter(child)
        self.project_mapping('arundhati', '/Users/gaurav/different')
        self.enter(child / 'deep')
        self.sync_source()
        self.ok('sync')
        self.assertEqual(self.rsync_destination(), 'arundhati:/Users/gaurav/different/deep/')
        self.assertEqual(len(json.loads((self.config / 'sync-projects.json').read_text())), 2)
        self.enter(self.project / 'nested-other')
        self.sync_source()
        self.ok('sync')
        self.assertEqual(self.rsync_destination(), 'om:/home/om/Developer/CMTech/pyspark-guru/nested-other/')

    def test_project_outside_home_is_supported(self):
        self.enter(self.root / 'outside')
        self.project_mapping()
        self.sync_source()
        self.ok('sync')
        self.assertEqual(self.rsync_destination(), 'om:/home/om/Developer/CMTech/pyspark-guru/')

    def test_legacy_home_mirroring(self):
        self.ok('sync', 'config', 'om', '/home/om')
        self.sync_source()
        self.ok('sync')
        self.assertEqual(self.rsync_destination(), 'om:/home/om/Developer/CMTech/spark-guru/')

    def test_mirroring_at_home_and_root_remote_home(self):
        self.ok('sync', 'config', 'om', '/')
        self.enter(self.home)
        self.sync_source()
        self.ok('sync')
        self.assertEqual(self.rsync_destination(), 'om:/')

    def test_different_host_uses_cached_home_instead_of_project(self):
        self.project_mapping()
        self.sync_source()
        (self.config / 'sync-homes').write_text('other=/home/other\n')
        self.ok('sync', '--to', 'other')
        self.assertEqual(self.rsync_destination(), 'other:/home/other/Developer/CMTech/spark-guru/')
        self.assertEqual(self.run.call_count, 1)

    def test_same_host_override_keeps_project_mapping(self):
        self.project_mapping()
        self.sync_source()
        self.ok('sync', '--to', 'om')
        self.assertEqual(self.rsync_destination(), 'om:/home/om/Developer/CMTech/pyspark-guru/')

    def test_explicit_home_overrides_project_mapping(self):
        self.project_mapping()
        self.sync_source()
        self.ok('sync', '--remote-home', '/custom')
        self.assertEqual(self.rsync_destination(), 'om:/custom/Developer/CMTech/spark-guru/')

    def test_explicit_directory_overrides_project_and_environment(self):
        self.project_mapping()
        self.sync_source()
        with patch.dict(os.environ, {'SC_SYNC_REMOTE_HOME': '/env/home'}):
            self.ok('sync', '--to', 'other', '--remote-dir', '/custom/project')
        self.assertEqual(self.rsync_destination(), 'other:/custom/project/')
        self.assertEqual(self.run.call_count, 1)
        self.assertEqual(json.loads((self.config / 'sync-projects.json').read_text())[str(self.project)]['host'], 'om')

    def test_environment_overrides_and_explicit_host_priority(self):
        self.project_mapping()
        self.sync_source()
        for variable in ('SC_SYNC_HOST', 'OM_HOST'):
            with self.subTest(variable=variable), patch.dict(os.environ, {variable: 'env-host', 'SC_SYNC_REMOTE_HOME': '/env/home'}):
                self.ok('sync')
                self.assertEqual(self.rsync_destination(), 'env-host:/env/home/Developer/CMTech/spark-guru/')
                self.ok('sync', '--to', 'flag-host', '--remote-home', '/flag/home')
                self.assertEqual(self.rsync_destination(), 'flag-host:/flag/home/Developer/CMTech/spark-guru/')

    def test_environment_home_overrides_project(self):
        self.project_mapping()
        self.sync_source()
        with patch.dict(os.environ, {'SC_SYNC_REMOTE_HOME': '/env/home'}):
            self.ok('sync')
        self.assertEqual(self.rsync_destination(), 'om:/env/home/Developer/CMTech/spark-guru/')

    def test_project_dry_run_has_no_remote_mkdir_or_local_writes(self):
        self.project_mapping()
        self.sync_source()
        before = {p.name: p.read_bytes() for p in self.config.iterdir()}
        output = self.ok('sync', '-n')
        command = self.run.call_args.args[0]
        self.assertIn('--dry-run', command)
        self.assertIn('--rsync-path=rsync', command)
        self.assertNotIn('mkdir', ' '.join(command))
        self.assertIn('pyspark-guru/screenshots  (dry-run)', output)
        self.assertEqual({p.name: p.read_bytes() for p in self.config.iterdir()}, before)

    def test_home_probe_dry_run_does_not_cache(self):
        self.sync_source()
        self.ok('-n', 'sync', '--to', 'new-host')
        self.assertEqual(self.run.call_count, 2)
        self.assertEqual(self.run.call_args_list[0].args[0][0], 'ssh')
        self.assertEqual(self.rsync_destination(), 'new-host:/home/remote/Developer/CMTech/spark-guru/')
        self.assertFalse((self.config / 'sync-homes').exists())
        self.assertIn('--dry-run', self.run.call_args.args[0])

    def test_normal_home_probe_is_cached(self):
        self.sync_source()
        self.ok('sync', '--to', 'new-host')
        self.assertEqual((self.config / 'sync-homes').read_text(), 'new-host=/home/remote\n')

    def test_config_dry_run_has_no_writes(self):
        self.ok('sync', 'config', 'om', '--remote-dir', '/project', '-n')
        self.ok('sync', 'config', 'om', '/home/om', '-n')
        self.assertEqual(list(self.config.iterdir()), [])
        self.run.assert_not_called()

    def test_conflicting_flags_are_rejected(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            self.sc.main(['sync', '--remote-dir', '/project', '--remote-home', '/home/om'])
        self.assertEqual(error.exception.code, 2)
        self.run.assert_not_called()

    def test_invalid_config_and_relative_paths_do_not_write(self):
        for args in (
            ('sync', 'config', 'om', '--remote-dir', 'relative'),
            ('sync', 'config', 'om', 'relative'),
            ('sync', 'config', '--remote-dir', '/project'),
            ('sync', 'config', 'om', '/home/om', 'extra'),
            ('sync', 'config', 'om', '/home/om', '--remote-dir', '/project'),
            ('sync', '--to', 'om', '--remote-dir', 'relative'),
            ('sync', '--to', 'om', '--remote-home', 'relative'),
        ):
            with self.subTest(args=args):
                code, _ = self.invoke(*args)
                self.assertEqual(code, 1)
        self.assertEqual(list(self.config.iterdir()), [])
        self.run.assert_not_called()

    def test_missing_source_does_not_probe_remote(self):
        code, output = self.invoke('sync', '--to', 'new-host')
        self.assertEqual(code, 1)
        self.assertIn('No ./screenshots', output)
        self.run.assert_not_called()

    def test_home_mirroring_outside_home_fails_before_probe(self):
        self.enter(self.root / 'outside')
        self.sync_source()
        code, output = self.invoke('sync', '--to', 'om')
        self.assertEqual(code, 1)
        self.assertIn('outside $HOME', output)
        self.run.assert_not_called()

    def test_probe_failure_does_not_rsync_or_cache(self):
        self.sync_source()
        self.run.return_value = types.SimpleNamespace(returncode=255, stdout='')
        code, output = self.invoke('sync', '--to', 'bad-host')
        self.assertEqual(code, 1)
        self.assertIn('Could not determine', output)
        self.assertEqual(self.run.call_count, 1)
        self.assertFalse((self.config / 'sync-homes').exists())

    def test_rsync_failure_propagates(self):
        self.project_mapping()
        self.sync_source()
        self.run.return_value.returncode = 23
        self.assertEqual(self.invoke('sync')[0], 23)

    def test_remote_paths_with_spaces_and_quotes_are_shell_quoted(self):
        remote = "/srv/om's projects/spark $(touch unexpected)"
        self.project_mapping(directory=remote)
        self.sync_source()
        self.ok('sync')
        command = self.run.call_args.args[0]
        self.assertEqual(shlex.split(command[-1].split(':', 1)[1]), [remote + '/'])
        option = next(arg for arg in command if arg.startswith('--rsync-path='))
        self.assertEqual(shlex.split(option.split('=', 1)[1]), ['mkdir', '-p', remote, '&&', 'rsync'])

    def test_invalid_project_config_is_not_overwritten(self):
        path = self.config / 'sync-projects.json'
        for content in ('broken json', '[]', '{"/project": {"host": "om", "remote_dir": "relative"}}'):
            with self.subTest(content=content):
                path.write_text(content)
                with self.assertRaises(ValueError):
                    self.project_mapping()
                self.assertEqual(path.read_text(), content)

    def test_config_environment_paths_can_be_relative(self):
        self.sc.CONFIG_FILE = 'local-auto'
        self.sc.SYNC_CONFIG_FILE = 'local-sync'
        self.sc.SYNC_PROJECTS_FILE = 'local-projects'
        self.ok('auto', 'off')
        self.ok('sync', 'config', 'om', '/home/om')
        self.project_mapping()
        self.assertTrue((self.project / 'local-auto').is_file())
        self.assertTrue((self.project / 'local-sync').is_file())
        self.assertTrue((self.project / 'local-projects').is_file())


@unittest.skipUnless(shutil.which('rsync'), 'rsync is needed for local transport tests')
class ScTransportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.local = self.root / 'local'
        self.local.mkdir()
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith('SC_') and key != 'OM_HOST'}
        self.env.update(HOME=str(self.local), PWD=str(self.local))
        # Execute rsync's remote shell command locally, entirely inside the fixture.
        # This verifies actual remote argument escaping without an SSH server.
        transport = self.root / 'transport.py'
        transport.write_text("import os, sys\nos.execv('/bin/sh', ['sh', '-c', ' '.join(sys.argv[2:])])\n")
        self.env['RSYNC_RSH'] = shlex.join([sys.executable, str(transport)])
        self.source = self.local / 'screenshots/2026-09-28/a.png'
        self.source.parent.mkdir(parents=True)
        self.source.write_bytes(b'local transport screenshot fixture')

    def command(self, *args):
        return subprocess.run([sys.executable, str(SCRIPT), *args], cwd=self.local,
                              env=self.env, capture_output=True, text=True, timeout=15)

    def test_sync_special_remote_path_and_dry_run_with_real_rsync(self):
        remote = self.root / "om's projects with spaces/spark $(touch unexpected)"
        result = self.command('sync', 'config', 'local', '--remote-dir', str(remote))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = self.command('sync')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        target = remote / 'screenshots/2026-09-28/a.png'
        self.assertEqual(target.read_bytes(), self.source.read_bytes())
        self.assertFalse((self.local / 'unexpected').exists())
        self.source.write_bytes(b'changed screenshot fixture -- preview only')
        before = target.read_bytes()
        result = self.command('sync', '-n')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(target.read_bytes(), before)

    def test_dry_run_missing_remote_directory_does_not_create_it(self):
        remote = self.root / 'missing/project'
        result = self.command('sync', '-n', '--to', 'local', '--remote-dir', str(remote))
        # rsync may report missing remote parents; the preview must never mkdir.
        self.assertIn(str(remote / 'screenshots'), result.stdout)
        self.assertFalse(remote.parent.exists())
        self.assertFalse((self.local / '.config').exists())



if __name__ == '__main__':
    unittest.main(verbosity=2)
