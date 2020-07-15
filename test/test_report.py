import unittest
import os
import json
from configparser import ConfigParser
from unittest.mock import patch, MagicMock
from jgi_mg_assembly_wdl.utils.report import ReportUtil


class mock_reportutil:
    def __init__(self):
        return
    
    def create_exenteded_report(self):
        return {}

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

    def test_report(self):
        report = ReportUtil('http://localhost:8000', self.scratch)
        saved_objects = {
            "ref": '1/2/3',
            "description": 'example'
        }
        tgt = os.path.join(self.scratch, 'cromwell-executions')
        if not os.path.exists(tgt):
            src = os.path.join(self.tdir,'outputs', 'cromwell-executions')
            os.symlink(src, tgt)
        report.report_client = MagicMock()
        report.dfu = MagicMock()
        result = report.make_report(self.meta, 'test', saved_objects)
        print(result)
