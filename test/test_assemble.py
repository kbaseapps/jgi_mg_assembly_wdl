import unittest
import os
import json
from configparser import ConfigParser
from unittest.mock import patch, MagicMock
from jgi_mg_assembly_wdl.assemble import jgi_mg_assembly


def fetch_reads(reads):
    with open('input.json', "w") as f:
        f.write("{}")
    return {'1/2/3': 'example.fq'}

class jgi_mg_assembly_wdlTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.tdir = os.path.dirname(os.path.realpath(__file__))
        with open(os.path.join(cls.tdir, 'meta.json.ex')) as f:
            cls.meta = json.loads(f.read())
        # token = os.environ.get('KB_AUTH_TOKEN', None)
        config_file = os.environ.get('KB_DEPLOYMENT_CONFIG', None)
        cls.cfg = {}
        config = ConfigParser()
        config.read(config_file)
        for nameval in config.items('jgi_mg_assembly_wdl'):
            cls.cfg[nameval[0]] = nameval[1]
        if os.getcwd() != '/kb/module/test':
            os.chdir('test_local//')
        cls.scratch = os.getcwd()
        #cls.callback_url = os.environ['SDK_CALLBACK_URL']

    @classmethod
    def tearDownClass(cls):
        pass

    
# from installed_clients.KBaseReportClient import KBaseReport
# from installed_clients.specialClient import special
# from .utils.file import FileUtil as FU

    def test_assemble(self):
        assem = jgi_mg_assembly('http://localhost:8000', self.scratch)
        if not os.path.exists('/kb/module/jgi_meta_spades.wdl'):
            assem.wdl_file = '../jgi_meta_spades.wdl'
        params = {
            'reads_upa': '1/2/3',
            "cleaned_reads_name": None,
            "filtered_reads_name": "filtered_reads",
            "output_assembly_name": "assemnbly",
            "skip_rqcfilter": 0,
            'workspace_name': 'bogus'

        }
        meta = self.meta
        with open('meta.json', 'w') as f:
            f.write(json.dumps(meta))
        tgt = os.path.join(self.scratch, 'cromwell-executions')
        if not os.path.exists(tgt):
            src = os.path.join(self.tdir,'outputs', 'cromwell-executions')
            os.symlink(src, tgt)
        assem.file_util.fetch_reads_files = MagicMock(side_effect=fetch_reads)
        assem.special.wdl = MagicMock()
        assem.file_util.upload_assembly = MagicMock(return_value = '1/3/1')
        assem.file_util.upload_reads = MagicMock(return_value = '1/4/1')
        assem.report = MagicMock()
        assem.assemble(params)
