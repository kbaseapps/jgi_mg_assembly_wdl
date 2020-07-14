from installed_clients.KBaseReportClient import KBaseReport
from installed_clients.specialClient import special
from .utils.file import FileUtil as FU
import shutil
import json
import os
import subprocess

PIGZ = "pigz"

class jgi_mg_assembly:
    def __init__(self, callbaack_url, scratch):
        self.callback_url = callbaack_url
        self.scratch  = scratch
        self.file_util = FU(callbaack_url)
        self.special = special(self.callback_url)
        self.report = KBaseReport(self.callback_url)
        self.wdl_file = '/kb/module/jgi_meta_spades.wdl'

    def validate_params(self, params):
        pass

    def run_wdl(self, rf):
        wdl_file = 'jgi_meta_spades.wdl'
        dst = os.path.join(self.scratch, wdl_file)
        shutil.copy(self.wdl_file, dst)
        ins = {'name': 'KBase'}
        ins = {
            "jgi_meta_assem_wf.input_file": rf,
            "jgi_meta_assem_wf.threads": "4"
        }
        input_file = os.path.join(self.scratch, 'input.json')
        with open(input_file, 'w') as f:
            f.write(json.dumps(ins))

        p = {
            'workflow': wdl_file,
            'inputs': input_file
        }

        res = self.special.wdl(p)
        print('wdl: '+str(res))


    def _fix_path(self, orig):
        ind = orig.find('cromwell-executions')
        return os.path.join(self.scratch, orig[ind:])


    def _upload_pipeline_result(self, pipeline_result, workspace_name, assembly_name,
                                filtered_reads_name=None,
                                cleaned_reads_name=None,
                                skip_rqcfilter=False,
                                input_reads=None):
        """
        This is very tricky and uploads (optionally!) a few things under different cases.
        1. Uploads assembly
            - this always happens after a successful run.
        2. Cleaned reads - passed RQCFilter / BFC / SeqTK
            - optional, if cleaned_reads_name isn't None
        3. Filtered reads - passed RQCFilter
            - optional, if filtered_reads_name isn't None AND skip_rqcfilter is False
        returns a dict of UPAs with the following keys:
        - assembly_upa - the assembly (always)
        - filtered_reads_upa - the RQCFiltered reads (optionally)
        - cleaned_reads_upa - the RQCFiltered -> BFC -> SeqTK cleaned reads (optional)
        """

        # upload the assembly
        uploaded_assy_upa = self.file_util.upload_assembly(
            self._fix_path(pipeline_result["jgi_meta_assem_wf.fungalrelease.assy"]), 
            workspace_name, assembly_name
        )
        upload_result = {
            "assembly_upa": uploaded_assy_upa
        }
        # upload filtered reads if we didn't skip RQCFilter (otherwise it's just a copy)
        if filtered_reads_name and not skip_rqcfilter:
            # unzip the cleaned reads because ReadsUtils won't do it for us.
            decompressed_reads = os.path.join(self.scratch, "filtered_reads.fastq")
            inf = self._fix_path(pipeline_result["jgi_meta_assem_wf.rqcfilt.filtered"])
            pigz_command = "{} -d -c {} > {}".format(PIGZ, inf, decompressed_reads)
            p = subprocess.Popen(pigz_command, cwd=self.scratch, shell=True)
            exit_code = p.wait()
            if exit_code != 0:
                raise RuntimeError("Unable to decompress filtered reads for validation! Can't upload them, either!")
            filtered_reads_upa = self.file_util.upload_reads(
                decompressed_reads, workspace_name, filtered_reads_name, input_reads
            )
            upload_result["filtered_reads_upa"] = filtered_reads_upa
        # upload the cleaned reads
        if cleaned_reads_name:
            # unzip the cleaned reads because ReadsUtils won't do it for us.
            decompressed_reads = os.path.join(self.output_dir, "cleaned_reads.fastq")
            pigz_command = "{} -d -c {} > {}".format(PIGZ, pipeline_result["seqtk"]["cleaned_reads"], decompressed_reads)
            p = subprocess.Popen(pigz_command, cwd=self.scratch_dir, shell=True)
            exit_code = p.wait()
            if exit_code != 0:
                raise RuntimeError("Unable to decompress cleaned reads for validation! Can't upload them, either!")
            cleaned_reads_upa = self.file_util.upload_reads(
                decompressed_reads, workspace_name, cleaned_reads_name, input_reads
            )
            upload_result["cleaned_reads_upa"] = cleaned_reads_upa
        return upload_result


    def assemble(self, params):
        self.validate_params(params)

        # Stage Data
        files = self.file_util.fetch_reads_files([params["reads_upa"]])
        reads_files = list(files.values())

        # Run WDL
        self.run_wdl(reads_files[0])

        # Check if things ran
        if not os.path.exists('meta.json'):
            raise OSError("Failed to run workflow")

        with open('meta.json') as f:
            pipeline_output = json.loads(f.read())['outputs']

        # Generate Output Objects
        upload_kwargs = {
            "cleaned_reads_name": params.get("cleaned_reads_name"),
            "filtered_reads_name": params.get("filtered_reads_name"),
            "skip_rqcfilter": params.get("skip_rqcfilter"),
            "input_reads": params.get("reads_upa")
        }

        stored_objects = self._upload_pipeline_result(
            pipeline_output,
            params["workspace_name"],
            params["output_assembly_name"],
            **upload_kwargs
        )
        print("upload complete")
        print(stored_objects)


        # Do report
        report_info = self.report.create({'report': {'objects_created':[],
                                                'text_message': "Results from assembly"},
                                                'workspace_name': params['workspace_name']})
        return {
            'report_name': report_info['name'],
            'report_ref': report_info['ref'],
        }
