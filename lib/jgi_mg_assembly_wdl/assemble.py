from installed_clients.KBaseReportClient import KBaseReport
from installed_clients.specialClient import special
from .utils.file import FileUtil as FU
from .utils.report import ReportUtil as report
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
        self.report = report(self.callback_url, scratch)

    def validate_params(self, params):
        pass

    def run_wdl(self, rf):
        wdl_files = [
                'metagenome_filtering_assembly_and_alignment.wdl',
                'rqcfilter2.wdl',
                'metagenome_assy.wdl',
                'mapping.wdl'
                ]

        for f in wdl_files:
            src = os.path.join('../', f)
            dst = os.path.join(self.scratch, f)
            shutil.copy(src, dst)
        # Make the input file relative
        in_file = rf.replace(self.scratch, './')
        ins = {
            "metagenome_filtering_assembly_and_alignment.input_files": [in_file]
        }
        ifile = 'input.json'
        input_file = os.path.join(self.scratch, ifile)
        with open(input_file, 'w') as f:
            f.write(json.dumps(ins))

        p = {
            'workflow': wdl_files[0],
            'inputs': ifile
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
            self._fix_path(pipeline_result["metagenome_filtering_assembly_and_alignment.assy.final_contigs"]), 
            workspace_name, assembly_name
        )
        upload_result = {
            "assembly_upa": uploaded_assy_upa
        }
        # upload filtered reads if we didn't skip RQCFilter (otherwise it's just a copy)
        if filtered_reads_name and not skip_rqcfilter:
            # unzip the cleaned reads because ReadsUtils won't do it for us.
            decompressed_reads = os.path.join(self.scratch, "filtered_reads.fastq")
            inf = self._fix_path(pipeline_result["metagenome_filtering_assembly_and_alignment.filter.final_filtered"][0])
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

    def _build_and_upload_report(self, pipeline_output, output_objects, workspace_name):
        """
        Builds and uploads a report. This contains both an HTML report for display as well
        as a list of report files with various outputs from the pipeline.

        pipeline_output - dict, expects the following keys, from each of the different steps
        * reads_info_prefiltered
        * reads_info_filtered
        * reads_info_corrected
        * rqcfilter
        * bfc
        * seqtk
        * spades
        * agp
        * stats
        * bbmap

        output_objects - dict, expects to see
        * assembly_upa - the UPA for the new assembly object

        workspace_name - string, the name of the workspace to upload the report to
        """
        return report_util.make_report(pipeline_output, workspace_name, stored_objects)

    def assemble(self, params):
        self.validate_params(params)

        workspace_name = params['workspace_name']

        # Stage Data
        files = self.file_util.fetch_reads_files([params["reads_upa"]])
        reads_files = list(files.values())

        # Run WDL
        self.run_wdl(reads_files[0])

        # Check if things ran
        mfile = os.path.join(self.scratch, 'meta.json')
        if not os.path.exists(mfile):
            raise OSError("Failed to run workflow")

        with open(mfile) as f:
            pipeline_output = json.loads(f.read())

        # Generate Output Objects
        upload_kwargs = {
            "cleaned_reads_name": params.get("cleaned_reads_name"),
            "filtered_reads_name": params.get("filtered_reads_name"),
            "skip_rqcfilter": params.get("skip_rqcfilter"),
            "input_reads": params.get("reads_upa")
        }

        output_objects = self._upload_pipeline_result(
            pipeline_output['outputs'],
            params["workspace_name"],
            params["output_assembly_name"],
            **upload_kwargs
        )

        stored_objects = list()
        stored_objects.append({
            "ref": output_objects["assembly_upa"],
            "description": "Assembled with the JGI metagenome pipeline."
        })
        if "cleaned_reads_upa" in output_objects:
            stored_objects.append({
                "ref": output_objects["cleaned_reads_upa"],
                "description": "Reads processed by the JGI metagenome pipeline before assembly."
            })
        if "filtered_reads_upa" in output_objects:
            stored_objects.append({
                "ref": output_objects["filtered_reads_upa"],
                "description": "Reads filtered by RQCFilter, and used to align against the assembled contigs."
            })

        print("upload complete")
        print(stored_objects)


        # Do report
        result = self.report.make_report(pipeline_output, workspace_name, stored_objects)
        # report_info = self.report.create({'report': {'objects_created':[],
        #                                         'text_message': "Results from assembly"},
        #                                         'workspace_name': params['workspace_name']})
        # return {
        #     'report_name': report_info['name'],
        #     'report_ref': report_info['ref'],
        # }
        print(result)
        return result
