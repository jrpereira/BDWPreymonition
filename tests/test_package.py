import configparser
from pathlib import Path
import sys
import tempfile
import unittest
from zipfile import ZipFile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import package_manifest

ROOT=Path(__file__).resolve().parents[1]
class PackageTests(unittest.TestCase):
    def test_manifest_defaults_version_and_package(self):
        menu=configparser.ConfigParser(interpolation=None)
        menu.read(ROOT/'mod_settings.ini')
        defaults=configparser.ConfigParser()
        defaults.read(ROOT/'distribution/config.ini')
        self.assertEqual(menu['Mod']['Version'],package_manifest.version(ROOT))
        for name in ['Enabled','Debug']:
            setting=menu['Setting.'+name]
            self.assertEqual(setting['Default'],defaults[setting['ConfigSection']][setting['ConfigKey']])
        with tempfile.TemporaryDirectory() as tmp:
            archive=package_manifest.build(ROOT,Path(tmp))
            with ZipFile(archive) as bundle:
                paths=set(bundle.namelist())
                self.assertIn('Premonition/Scripts/main.lua',paths)
                for name in ['animation.lua','events.lua','feature.lua','ue_adapter.lua']:
                    self.assertIn('Premonition/Scripts/'+name, paths)
                self.assertIn('Premonition/Scripts/premonition.lua', paths)
                self.assertNotIn('Premonition/templates/premonition.lua', paths)
                self.assertIn('Premonition/config.example.ini',paths)
                self.assertNotIn('Premonition/config.ini',paths)
                self.assertFalse(any('/tests/' in p or '/.git/' in p for p in paths))
                self.assertFalse(any('tools' in [part.casefold() for part in Path(p).parts[:-1]] for p in paths))

if __name__=='__main__': unittest.main()
