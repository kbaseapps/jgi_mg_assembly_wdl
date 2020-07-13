# -*- coding: utf-8 -*-
import os
import time
import unittest
import json
import shutil
from configparser import ConfigParser

from jgi_mg_assembly_wdl.jgi_mg_assembly_wdlImpl import jgi_mg_assembly_wdl
from jgi_mg_assembly_wdl.jgi_mg_assembly_wdlServer import MethodContext
from installed_clients.authclient import KBaseAuth as _KBaseAuth

from installed_clients.WorkspaceClient import Workspace

from unittest.mock import patch, MagicMock

class mock_special:
    def __init__(self):
        return

    def wdl(self, params):
        return

class jgi_mg_assembly_wdlTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        token = os.environ.get('KB_AUTH_TOKEN', None)
        config_file = os.environ.get('KB_DEPLOYMENT_CONFIG', None)
        cls.cfg = {}
        config = ConfigParser()
        config.read(config_file)
        cls.tdir = os.path.dirname(os.path.realpath(__file__))
        with open(os.path.join(cls.tdir, 'meta.json.ex')) as f:
            cls.meta = json.loads(f.read())
        for nameval in config.items('jgi_mg_assembly_wdl'):
            cls.cfg[nameval[0]] = nameval[1]
        # Getting username from Auth profile for token
        authServiceUrl = cls.cfg['auth-service-url']
        auth_client = _KBaseAuth(authServiceUrl)
        user_id = auth_client.get_user(token)
        # WARNING: don't call any logging methods on the context object,
        # it'll result in a NoneType error
        cls.ctx = MethodContext(None)
        cls.ctx.update({'token': token,
                        'user_id': user_id,
                        'provenance': [
                            {'service': 'jgi_mg_assembly_wdl',
                             'method': 'please_never_use_it_in_production',
                             'method_params': []
                             }],
                        'authenticated': 1})
        cls.wsURL = cls.cfg['workspace-url']
        cls.wsClient = Workspace(cls.wsURL)
        cls.serviceImpl = jgi_mg_assembly_wdl(cls.cfg)
        cls.scratch = cls.cfg['scratch']
        cls.callback_url = os.environ['SDK_CALLBACK_URL']
        suffix = int(time.time() * 1000)
        cls.wsName = "test_ContigFilter_" + str(suffix)
        ret = cls.wsClient.create_workspace({'workspace': cls.wsName})  # noqa

    @classmethod
    def tearDownClass(cls):
        if hasattr(cls, 'wsName'):
            cls.wsClient.delete_workspace({'workspace': cls.wsName})
            print('Test workspace was deleted')

    # NOTE: According to Python unittest naming rules test method names should start from 'test'. # noqa
    
    def test_assemble(self):
        # Prepare test objects in workspace if needed using
        # self.getWsClient().save_objects({'workspace': self.getWsName(),
        #                                  'objects': []})
        #
        # Run your method by
        # ret = self.getImpl().your_method(self.getContext(), parameters...)
        #
        # Check returned data with
        # self.assertEqual(ret[...], ...) or other unittest methods
        params = {
            "cleaned_reads_name": None,
            "filtered_reads_name": "mock2pct",
            "output_assembly_name": "mock2pct_ass",
            "reads_upa": "52374/4/1",
            "skip_rqcfilter": 0,
            "workspace_name": "scanon:narrative_1594487998614"
        }
        
        meta = self.meta
        with open('meta.json', 'w') as f:
            f.write(json.dumps(meta))
        tgt = os.path.join(self.scratch, 'cromwell-executions')
        if not os.path.exists(tgt):
            src = os.path.join(self.tdir,'outputs', 'cromwell-executions')
            shutil.copytree(src, tgt)
        
        self.serviceImpl.ac.special = mock_special()
        ret = self.serviceImpl.run_jgi_mg_assembly_wdl(self.ctx, params)
        #{'workspace_name': self.wsName,
        #                       'reads': 'Hello World!'})
