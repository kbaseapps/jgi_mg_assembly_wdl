{
  "workflowName": "metagenome_filtering_assembly_and_alignment",
  "workflowProcessingEvents": [{
    "description": "Finished",
    "cromwellVersion": "44",
    "cromwellId": "cromid-09ef52e",
    "timestamp": "2020-08-21T21:49:45.101Z"
  }, {
    "cromwellId": "cromid-09ef52e",
    "description": "PickedUp",
    "timestamp": "2020-08-21T21:45:32.543Z",
    "cromwellVersion": "44"
  }],
  "actualWorkflowLanguageVersion": "draft-2",
  "submittedFiles": {
    "workflow": "import \"rqcfilter2.wdl\" as rqcfilter2\nimport \"metagenome_assy.wdl\" as metagenome_assy\nimport \"mapping.wdl\" as mapping\n\nworkflow metagenome_filtering_assembly_and_alignment {\n    Array[File] input_files\n\n\tcall rqcfilter2.rqcfilter2 as filter {\n\t\tinput: input_files=input_files\n\t}\n    call metagenome_assy.metagenome_assy as assy {\n        input: input_files=filter.final_filtered\n    }\n    call mapping.mapping {\n       input: input_files=filter.final_filtered, input_reference=assy.final_contigs\n    }\n}\n\n",
    "root": "/homes/oakland/canon/",
    "options": "{\n\n}",
    "inputs": "{\n  \"metagenome_filtering_assembly_and_alignment.input_files\": [\n    \"/homes/oakland/canon/dev/jgi_meta_wdl/548243e0-5272-45a3-8124-0064cd64bb7d.inter.fastq.gz\"\n  ]\n}\n",
    "workflowUrl": "metagenome_filtering_assembly_and_alignment.wdl",
    "labels": "{}",
    "imports": {
      "metagenome_assy.wdl": "workflow metagenome_assy {\n    Array[File] input_files\n    Boolean nersc = false\n\n    String bbtools_container=\"bryce911/bbtools:38.86\"\n    String spades_container=\"bryce911/spades:3.14.1\"\n\n    call bbcms {\n    \t input: reads_files=input_files, is_nersc=nersc, container=bbtools_container\n    }\n    call assy {\n    \t input: infile1=bbcms.out1, infile2=bbcms.out2, is_nersc=nersc, container=spades_container    \n    }\n    call create_agp {\n         input: scaffolds_in=assy.out, is_nersc=nersc, container=bbtools_container\n    }\n    output {\n        File final_contigs = create_agp.outcontigs\n        File final_scaffolds = create_agp.outscaffolds\n        File final_spades_log = assy.outlog\n\t    File final_readlen = bbcms.outreadlen\n\t    File final_counts = bbcms.outcounts\n    }\n}\n\ntask bbcms{\n    Array[File] reads_files\n\n    String container\n    Boolean is_nersc\n    String run_prefix = if(is_nersc) then \"shifter --image=\" + container + \" -- \" else \"\"    \n    String single = if (length(reads_files) == 1 ) then \"1\" else \"0\"\n\n    String bbcms_input = \"bbcms.input.fastq.gz\"\n    String filename_counts=\"counts.metadata.json\"\n  \n    String filename_outfile1=\"input.corr.left.fastq.gz\"\n    String filename_outfile2=\"input.corr.right.fastq.gz\"\n    \n     String filename_readlen=\"readlen.txt\"\n     String filename_outlog=\"stdout.log\"\n     String filename_errlog=\"stderr.log\"\n     String filename_kmerfile=\"unique31mer.txt\"\n\n     String java=\"-Xmx20g\"\n     String dollar=\"$\"\n#     runtime { backend : \"Local\"} \n\n     command {\n        if [ ${single} == 0 ]\n\tthen\n\t    cat ${sep = \" \" reads_files } > ${bbcms_input}\n\telse\n\t    ln ${reads_files[0]} ./${bbcms_input}\n\tfi\n\ttouch ${filename_readlen}\n\t${run_prefix} readlength.sh -Xmx1g in=${bbcms_input} out=${filename_readlen} overwrite \n        ${run_prefix} bbcms.sh ${java} metadatafile=${filename_counts} mincount=2 highcountfraction=0.6 \\\n\t    in=${bbcms_input} out1=${filename_outfile1} out2=${filename_outfile2} \\\n\t    1> ${filename_outlog} 2> ${filename_errlog}\n\n     }\n     output {\n            File out1 = filename_outfile1\n            File out2 = filename_outfile2\n            File outreadlen = filename_readlen\n            File stdout = filename_outlog\n            File stderr = filename_errlog\n            File outcounts = filename_counts\n\n     }\n     runtime {\n         docker: 'bryce911/bbtools:38.86'\n     }\n\n}\n\ntask assy{\n    File infile1\n    File infile2    \n\n    String container\n    Boolean is_nersc\n    String run_prefix = if(is_nersc) then \"shifter --image=\" + container + \" -- \" else \"\"    \n\n    String outprefix=\"spades3\"\n    String filename_outfile=\"${outprefix}/scaffolds.fasta\"\n    String filename_spadeslog =\"${outprefix}/spades.log\"\n    String dollar=\"$\"\n#    runtime { backend : \"Local\"}\n\n    command{\n       ${run_prefix} spades.py -m 2000 --tmp-dir ${dollar}PWD -o ${outprefix} --only-assembler -k 33,55,77,99,127 --meta -t ${dollar}(nproc) -1 ${infile1} -2 ${infile2}\n    }\n    output {\n           File out = filename_outfile\n           File outlog = filename_spadeslog\n    }\n     runtime {\n         docker: 'bryce911/spades:3.14.1'\n     }\n}\n\ntask create_agp {\n    File scaffolds_in\n    String container\n    String prefix=\"assembly\"\n\n    Boolean is_nersc\n    String run_prefix = if(is_nersc) then \"shifter --image=\" + container + \" -- \" else \"\"    \n    \n    String filename_contigs=\"${prefix}.contigs.fasta\"\n    String filename_scaffolds=\"${prefix}.scaffolds.fasta\"\n    String filename_agp=\"${prefix}.agp\"\n    String filename_legend=\"${prefix}.scaffolds.legend\"\n#     runtime { backend : \"Local\"} \n    command{\n        ${run_prefix} fungalrelease.sh -Xmx105g in=${scaffolds_in} out=${filename_scaffolds} \\\n        outc=${filename_contigs} agp=${filename_agp} legend=${filename_legend} \\\n        mincontig=200 minscaf=200 sortscaffolds=t sortcontigs=t overwrite=t\n    }\n    output{\n        File outcontigs = filename_contigs\n        File outscaffolds = filename_scaffolds\n        File outagp = filename_agp\n        File outlegend = filename_legend\n    }\n     runtime {\n         docker: 'bryce911/bbtools:38.86'\n     }\n}\n",
      "rqcfilter2.wdl": "workflow rqcfilter2 {\n    Array[File] input_files\n\n    call rqcfilter {\n    \t input: reads_files=input_files\n    }\n    output {\n        Array[File] final_filtered = rqcfilter.outrqcfilter\n    }\n}\n\ntask rqcfilter{\n    Array[File] reads_files\n\n    String single = if (length(reads_files) == 1 ) then \"1\" else \"0\"\n\n    String rqcfilter_input = \"rqcfilter.input.fastq.gz\"\n    String rqcfilter_output = \"rqcfilter.output.fastq.gz\"    \n\n     String filename_readlen=\"readlen.txt\"\n     String filename_outlog=\"stdout.log\"\n     String filename_errlog=\"stderr.log\"\n\n     String java=\"-Xmx20g\"\n     String dollar=\"$\"\n\n    command {\n        if [ ${single} == 0 ]\n\tthen\n\t    cat ${sep = \" \" reads_files } > ${rqcfilter_input}\n\telse\n\t    ln ${reads_files[0]} ./${rqcfilter_input}\n\tfi\n\ttouch ${filename_readlen}\n\treadlength.sh -Xmx1g in=${rqcfilter_input} out=${filename_readlen} overwrite \n        rqcfilter2.sh jni=t in=${rqcfilter_input} \\\n            path=filter rna=f trimfragadapter=t qtrim=r trimq=0 maxns=3 maq=3 minlen=51 \\\n            mlf=0.33 phix=t removehuman=t removedog=t removecat=t removemouse=t khist=t \\\n            removemicrobes=t sketch kapa=t clumpify=t tmpdir= barcodefilter=f trimpolyg=5 usejni=f \\\n\t    rqcfilterdata=/refdata/RQCFilterData \\\n            out=../${rqcfilter_output} 1> ${filename_outlog} 2> ${filename_errlog}\n     }\n     output {\n     \t\tArray[File] outrqcfilter = glob(rqcfilter_output)\n            File outreadlen = filename_readlen\n            File stdout = filename_outlog\n            File stderr = filename_errlog\n\n     }\n     runtime {\n         docker: 'bryce911/bbtools:38.44'\n     }\n\n}\n",
      "mapping.wdl": "workflow mapping {\n    Array[File] input_files\n    File input_reference\n\n    if (length(input_files) == 1 ){\n       call mappingtask as single_run {\n           input: reads=input_files[0], reference=input_reference\n       }\n    }\n    if (length(input_files) > 1 ){\n       scatter (input_file in input_files) {\n           call mappingtask as multi_run {\n               input: reads=input_file, reference=input_reference\n           }\n       }\n    }\n    call finalize_bams{\n        input: insing=single_run.outbamfile, inmult=multi_run.outbamfile\n    }\n    output {\n        File final_outbam = finalize_bams.outbam\n        File final_outsam = finalize_bams.outsam\n        File final_outbamidx = finalize_bams.outbamidx\n        File final_outcov = finalize_bams.outcov\n        File final_outflagstat = finalize_bams.outflagstat\n    }\n\n}\n\ntask finalize_bams {\n    File? insing\n    Array[File]? inmult\n\n    String single = if(defined(insing)) then \"1\" else \"0\"\n    String java=\"-Xmx50g\"\n    String filename_outsam=\"pairedMapped.sam.gz\"\n    String filename_sorted=\"pairedMapped_sorted.bam\"\n    String filename_sorted_idx=\"pairedMapped_sorted.bam.bai\"\n    String filename_cov=\"pairedMapped_sorted.bam.cov\"\n    String filename_flagstat=\"pairedMapped_sorted.bam.flagstat\"    \n    String dollar=\"$\"\n\n    command{\n        if [ ${single} == \"1\" ]\n        then\n                ln ${insing} ${filename_sorted}      \n        else\n                samtools merge ${filename_sorted} ${sep=\" \" inmult}\n        fi\n        samtools index ${filename_sorted}\n        reformat.sh threads=${dollar}(nproc) ${java} in=${filename_sorted} out=${filename_outsam} overwrite=true\n        pileup.sh in=${filename_sorted} out=${filename_cov}\n        samtools flagstat ${filename_sorted} 1>| ${filename_flagstat} 2>| ${filename_flagstat}.e          \n    }\n    output{\n        File outsam = filename_outsam\n        File outbam = filename_sorted\n        File outbamidx = filename_sorted_idx\n        File outcov = filename_cov\n        File outflagstat = filename_flagstat    \n    }\n     runtime {\n         docker: 'bryce911/bbtools:38.44'\n     }\n}\n\ntask mappingtask {\n    File reads\n    File reference\n\n    String filename_unsorted=\"pairedMapped.bam\"\n    String filename_sorted=\"pairedMapped_sorted.bam\"\n    String dollar=\"$\"\n    \n    command{\n        bbmap.sh threads=${dollar}(nproc)  nodisk=true \\\n        interleaved=true ambiguous=random rgid=filename \\\n        in=${reads} ref=${reference} out=${filename_unsorted}\n        samtools sort -m200M -@ ${dollar}(nproc) ${filename_unsorted} -o ${filename_sorted}\n  }\n  output{\n      File outbamfile = filename_sorted\n   }\n     runtime {\n         docker: 'bryce911/bbtools:38.44'\n     }\n}\n\n"
    }
  },
  "calls": {
    "metagenome_filtering_assembly_and_alignment.mapping": [{
      "executionStatus": "Done",
      "subWorkflowMetadata": {
        "workflowName": "mapping",
        "rootWorkflowId": "9617fcc1-b903-449c-9245-c0438074d3ea",
        "calls": {
          "mapping.finalize_bams": [{
            "executionStatus": "Done",
            "stdout": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/stdout",
            "backendStatus": "Done",
            "compressedDockerSize": 499108549,
            "commandLine": "if [ 1 == \"1\" ]\nthen\n        ln /cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/inputs/-1802964840/pairedMapped_sorted.bam pairedMapped_sorted.bam      \nelse\n        samtools merge pairedMapped_sorted.bam \nfi\nsamtools index pairedMapped_sorted.bam\nreformat.sh threads=$(nproc) -Xmx50g in=pairedMapped_sorted.bam out=pairedMapped.sam.gz overwrite=true\npileup.sh in=pairedMapped_sorted.bam out=pairedMapped_sorted.bam.cov\nsamtools flagstat pairedMapped_sorted.bam 1>| pairedMapped_sorted.bam.flagstat 2>| pairedMapped_sorted.bam.flagstat.e",
            "shardIndex": -1,
            "outputs": {
              "outbamidx": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped_sorted.bam.bai",
              "outcov": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped_sorted.bam.cov",
              "outbam": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped_sorted.bam",
              "outflagstat": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped_sorted.bam.flagstat",
              "outsam": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped.sam.gz"
            },
            "runtimeAttributes": {
              "maxRetries": "0",
              "continueOnReturnCode": "0",
              "docker": "bryce911/bbtools:38.44",
              "failOnStderr": "false"
            },
            "callCaching": {
              "allowResultReuse": false,
              "effectiveCallCachingMode": "CallCachingOff"
            },
            "inputs": {
              "filename_flagstat": "pairedMapped_sorted.bam.flagstat",
              "dollar": "$",
              "inmult": null,
              "java": "-Xmx50g",
              "insing": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-single_run/execution/pairedMapped_sorted.bam",
              "single": "1",
              "filename_sorted_idx": "pairedMapped_sorted.bam.bai",
              "filename_sorted": "pairedMapped_sorted.bam",
              "filename_outsam": "pairedMapped.sam.gz",
              "filename_cov": "pairedMapped_sorted.bam.cov"
            },
            "returnCode": 0,
            "jobId": "29417",
            "backend": "Docker",
            "end": "2020-08-21T21:49:42.020Z",
            "dockerImageUsed": "bryce911/bbtools@sha256:4f8a3afeb42502d40b89d0444be90f8d6cfc71eb3d457bfe32ce7edd20a0d680",
            "stderr": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/stderr",
            "callRoot": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams",
            "attempt": 1,
            "executionEvents": [{
              "startTime": "2020-08-21T21:49:37.088Z",
              "endTime": "2020-08-21T21:49:42.020Z",
              "description": "RunningJob"
            }, {
              "endTime": "2020-08-21T21:49:37.088Z",
              "description": "PreparingJob",
              "startTime": "2020-08-21T21:49:37.077Z"
            }, {
              "description": "WaitingForValueStore",
              "startTime": "2020-08-21T21:49:37.076Z",
              "endTime": "2020-08-21T21:49:37.077Z"
            }, {
              "description": "RequestingExecutionToken",
              "endTime": "2020-08-21T21:49:37.076Z",
              "startTime": "2020-08-21T21:49:36.927Z"
            }, {
              "startTime": "2020-08-21T21:49:36.927Z",
              "description": "Pending",
              "endTime": "2020-08-21T21:49:36.927Z"
            }, {
              "startTime": "2020-08-21T21:49:42.020Z",
              "endTime": "2020-08-21T21:49:42.020Z",
              "description": "UpdatingJobStore"
            }],
            "start": "2020-08-21T21:49:36.926Z"
          }],
          "mapping.single_run": [{
            "executionStatus": "Done",
            "stdout": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-single_run/execution/stdout",
            "backendStatus": "Done",
            "compressedDockerSize": 499108549,
            "commandLine": "bbmap.sh threads=$(nproc)  nodisk=true \\\ninterleaved=true ambiguous=random rgid=filename \\\nin=/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-single_run/inputs/-1885903553/rqcfilter.output.fastq.gz ref=/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-single_run/inputs/1239197184/assembly.contigs.fasta out=pairedMapped.bam\nsamtools sort -m200M -@ $(nproc) pairedMapped.bam -o pairedMapped_sorted.bam",
            "shardIndex": -1,
            "outputs": {
              "outbamfile": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-single_run/execution/pairedMapped_sorted.bam"
            },
            "runtimeAttributes": {
              "continueOnReturnCode": "0",
              "maxRetries": "0",
              "docker": "bryce911/bbtools:38.44",
              "failOnStderr": "false"
            },
            "callCaching": {
              "allowResultReuse": false,
              "effectiveCallCachingMode": "CallCachingOff"
            },
            "inputs": {
              "reference": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp/execution/assembly.contigs.fasta",
              "dollar": "$",
              "filename_unsorted": "pairedMapped.bam",
              "reads": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/execution/glob-6f0506bead1626d205fb3811ca67163b/rqcfilter.output.fastq.gz",
              "filename_sorted": "pairedMapped_sorted.bam"
            },
            "returnCode": 0,
            "jobId": "29001",
            "backend": "Docker",
            "end": "2020-08-21T21:49:34.432Z",
            "dockerImageUsed": "bryce911/bbtools@sha256:4f8a3afeb42502d40b89d0444be90f8d6cfc71eb3d457bfe32ce7edd20a0d680",
            "stderr": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-single_run/execution/stderr",
            "callRoot": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-single_run",
            "attempt": 1,
            "executionEvents": [{
              "description": "WaitingForValueStore",
              "endTime": "2020-08-21T21:49:25.078Z",
              "startTime": "2020-08-21T21:49:25.076Z"
            }, {
              "startTime": "2020-08-21T21:49:25.086Z",
              "endTime": "2020-08-21T21:49:34.432Z",
              "description": "RunningJob"
            }, {
              "description": "UpdatingJobStore",
              "endTime": "2020-08-21T21:49:34.432Z",
              "startTime": "2020-08-21T21:49:34.432Z"
            }, {
              "description": "Pending",
              "startTime": "2020-08-21T21:49:24.748Z",
              "endTime": "2020-08-21T21:49:24.749Z"
            }, {
              "startTime": "2020-08-21T21:49:24.749Z",
              "endTime": "2020-08-21T21:49:25.076Z",
              "description": "RequestingExecutionToken"
            }, {
              "startTime": "2020-08-21T21:49:25.078Z",
              "endTime": "2020-08-21T21:49:25.086Z",
              "description": "PreparingJob"
            }],
            "start": "2020-08-21T21:49:24.747Z"
          }]
        },
        "outputs": {
          "mapping.final_outbamidx": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped_sorted.bam.bai",
          "mapping.final_outcov": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped_sorted.bam.cov",
          "mapping.final_outbam": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped_sorted.bam",
          "mapping.final_outsam": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped.sam.gz",
          "mapping.final_outflagstat": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped_sorted.bam.flagstat"
        },
        "workflowRoot": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea",
        "id": "898b4836-9021-49ca-acb2-f615ab4b0daa",
        "inputs": {
          "input_reference": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp/execution/assembly.contigs.fasta",
          "input_files": ["/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/execution/glob-6f0506bead1626d205fb3811ca67163b/rqcfilter.output.fastq.gz"]
        },
        "status": "Succeeded",
        "parentWorkflowId": "9617fcc1-b903-449c-9245-c0438074d3ea",
        "end": "2020-08-21T21:49:43.057Z",
        "start": "2020-08-21T21:49:20.639Z"
      },
      "shardIndex": -1,
      "outputs": {
        "final_outbam": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped_sorted.bam",
        "final_outbamidx": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped_sorted.bam.bai",
        "final_outsam": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped.sam.gz",
        "final_outcov": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped_sorted.bam.cov",
        "final_outflagstat": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped_sorted.bam.flagstat"
      },
      "inputs": {
        "input_files": ["/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/execution/glob-6f0506bead1626d205fb3811ca67163b/rqcfilter.output.fastq.gz"],
        "input_reference": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp/execution/assembly.contigs.fasta"
      },
      "end": "2020-08-21T21:49:43.058Z",
      "attempt": 1,
      "executionEvents": [{
        "description": "SubWorkflowRunningState",
        "startTime": "2020-08-21T21:49:20.644Z",
        "endTime": "2020-08-21T21:49:43.057Z"
      }, {
        "startTime": "2020-08-21T21:49:20.637Z",
        "description": "SubWorkflowPendingState",
        "endTime": "2020-08-21T21:49:20.637Z"
      }, {
        "startTime": "2020-08-21T21:49:20.637Z",
        "description": "WaitingForValueStore",
        "endTime": "2020-08-21T21:49:20.639Z"
      }, {
        "endTime": "2020-08-21T21:49:20.644Z",
        "description": "SubWorkflowPreparingState",
        "startTime": "2020-08-21T21:49:20.639Z"
      }],
      "start": "2020-08-21T21:49:20.637Z"
    }],
    "metagenome_filtering_assembly_and_alignment.assy": [{
      "executionStatus": "Done",
      "subWorkflowMetadata": {
        "workflowName": "assy",
        "rootWorkflowId": "9617fcc1-b903-449c-9245-c0438074d3ea",
        "calls": {
          "metagenome_assy.create_agp": [{
            "executionStatus": "Done",
            "stdout": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp/execution/stdout",
            "backendStatus": "Done",
            "compressedDockerSize": 418546310,
            "commandLine": " fungalrelease.sh -Xmx105g in=/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp/inputs/1200777607/scaffolds.fasta out=assembly.scaffolds.fasta \\\noutc=assembly.contigs.fasta agp=assembly.agp legend=assembly.scaffolds.legend \\\nmincontig=200 minscaf=200 sortscaffolds=t sortcontigs=t overwrite=t",
            "shardIndex": -1,
            "outputs": {
              "outagp": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp/execution/assembly.agp",
              "outlegend": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp/execution/assembly.scaffolds.legend",
              "outscaffolds": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp/execution/assembly.scaffolds.fasta",
              "outcontigs": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp/execution/assembly.contigs.fasta"
            },
            "runtimeAttributes": {
              "docker": "bryce911/bbtools:38.86",
              "failOnStderr": "false",
              "maxRetries": "0",
              "continueOnReturnCode": "0"
            },
            "callCaching": {
              "allowResultReuse": false,
              "effectiveCallCachingMode": "CallCachingOff"
            },
            "inputs": {
              "filename_legend": "assembly.scaffolds.legend",
              "filename_scaffolds": "assembly.scaffolds.fasta",
              "scaffolds_in": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-assy/execution/spades3/scaffolds.fasta",
              "prefix": "assembly",
              "is_nersc": false,
              "container": "bryce911/bbtools:38.86",
              "run_prefix": "",
              "filename_agp": "assembly.agp",
              "filename_contigs": "assembly.contigs.fasta"
            },
            "returnCode": 0,
            "jobId": "28541",
            "backend": "Docker",
            "end": "2020-08-21T21:49:17.023Z",
            "dockerImageUsed": "bryce911/bbtools@sha256:9ded1865aa47877cdc3ced078b3bff20edee8826a6c084f324702bfa20fa3994",
            "stderr": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp/execution/stderr",
            "callRoot": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp",
            "attempt": 1,
            "executionEvents": [{
              "startTime": "2020-08-21T21:49:13.075Z",
              "endTime": "2020-08-21T21:49:13.076Z",
              "description": "WaitingForValueStore"
            }, {
              "startTime": "2020-08-21T21:49:12.538Z",
              "description": "Pending",
              "endTime": "2020-08-21T21:49:12.539Z"
            }, {
              "startTime": "2020-08-21T21:49:17.023Z",
              "description": "UpdatingJobStore",
              "endTime": "2020-08-21T21:49:17.023Z"
            }, {
              "description": "RunningJob",
              "endTime": "2020-08-21T21:49:17.023Z",
              "startTime": "2020-08-21T21:49:13.085Z"
            }, {
              "startTime": "2020-08-21T21:49:13.076Z",
              "endTime": "2020-08-21T21:49:13.085Z",
              "description": "PreparingJob"
            }, {
              "startTime": "2020-08-21T21:49:12.539Z",
              "description": "RequestingExecutionToken",
              "endTime": "2020-08-21T21:49:13.075Z"
            }],
            "start": "2020-08-21T21:49:12.537Z"
          }],
          "metagenome_assy.assy": [{
            "executionStatus": "Done",
            "stdout": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-assy/execution/stdout",
            "backendStatus": "Done",
            "compressedDockerSize": 151688136,
            "commandLine": "spades.py -m 2000 --tmp-dir $PWD -o spades3 --only-assembler -k 33,55,77,99,127 --meta -t $(nproc) -1 /cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-assy/inputs/1590640610/input.corr.left.fastq.gz -2 /cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-assy/inputs/1590640610/input.corr.right.fastq.gz",
            "shardIndex": -1,
            "outputs": {
              "outlog": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-assy/execution/spades3/spades.log",
              "out": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-assy/execution/spades3/scaffolds.fasta"
            },
            "runtimeAttributes": {
              "maxRetries": "0",
              "continueOnReturnCode": "0",
              "docker": "bryce911/spades:3.14.1",
              "failOnStderr": "false"
            },
            "callCaching": {
              "allowResultReuse": false,
              "effectiveCallCachingMode": "CallCachingOff"
            },
            "inputs": {
              "infile2": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/execution/input.corr.right.fastq.gz",
              "dollar": "$",
              "is_nersc": false,
              "container": "bryce911/spades:3.14.1",
              "filename_spadeslog": "spades3/spades.log",
              "run_prefix": "",
              "outprefix": "spades3",
              "infile1": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/execution/input.corr.left.fastq.gz",
              "filename_outfile": "spades3/scaffolds.fasta"
            },
            "returnCode": 0,
            "jobId": "21950",
            "backend": "Docker",
            "end": "2020-08-21T21:49:11.383Z",
            "dockerImageUsed": "bryce911/spades@sha256:9f86a65f161715c0da8f03308be28803c10475bd162f414419db8b9c106982cf",
            "stderr": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-assy/execution/stderr",
            "callRoot": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-assy",
            "attempt": 1,
            "executionEvents": [{
              "description": "RequestingExecutionToken",
              "startTime": "2020-08-21T21:48:22.588Z",
              "endTime": "2020-08-21T21:48:23.076Z"
            }, {
              "description": "UpdatingJobStore",
              "endTime": "2020-08-21T21:49:11.383Z",
              "startTime": "2020-08-21T21:49:11.383Z"
            }, {
              "description": "WaitingForValueStore",
              "startTime": "2020-08-21T21:48:23.076Z",
              "endTime": "2020-08-21T21:48:23.077Z"
            }, {
              "startTime": "2020-08-21T21:48:23.568Z",
              "description": "RunningJob",
              "endTime": "2020-08-21T21:49:11.383Z"
            }, {
              "description": "PreparingJob",
              "startTime": "2020-08-21T21:48:23.077Z",
              "endTime": "2020-08-21T21:48:23.568Z"
            }, {
              "startTime": "2020-08-21T21:48:22.587Z",
              "description": "Pending",
              "endTime": "2020-08-21T21:48:22.588Z"
            }],
            "start": "2020-08-21T21:48:22.587Z"
          }],
          "metagenome_assy.bbcms": [{
            "executionStatus": "Done",
            "stdout": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/execution/stdout",
            "backendStatus": "Done",
            "compressedDockerSize": 418546310,
            "commandLine": "       if [ 1 == 0 ]\nthen\n    cat /cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/inputs/-1885903553/rqcfilter.output.fastq.gz > bbcms.input.fastq.gz\nelse\n    ln /cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/inputs/-1885903553/rqcfilter.output.fastq.gz ./bbcms.input.fastq.gz\nfi\ntouch readlen.txt\n readlength.sh -Xmx1g in=bbcms.input.fastq.gz out=readlen.txt overwrite \n        bbcms.sh -Xmx20g metadatafile=counts.metadata.json mincount=2 highcountfraction=0.6 \\\n    in=bbcms.input.fastq.gz out1=input.corr.left.fastq.gz out2=input.corr.right.fastq.gz \\\n    1> stdout.log 2> stderr.log",
            "shardIndex": -1,
            "outputs": {
              "outcounts": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/execution/counts.metadata.json",
              "out2": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/execution/input.corr.right.fastq.gz",
              "stdout": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/execution/stdout.log",
              "outreadlen": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/execution/readlen.txt",
              "stderr": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/execution/stderr.log",
              "out1": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/execution/input.corr.left.fastq.gz"
            },
            "runtimeAttributes": {
              "maxRetries": "0",
              "continueOnReturnCode": "0",
              "failOnStderr": "false",
              "docker": "bryce911/bbtools:38.86"
            },
            "callCaching": {
              "allowResultReuse": false,
              "effectiveCallCachingMode": "CallCachingOff"
            },
            "inputs": {
              "bbcms_input": "bbcms.input.fastq.gz",
              "dollar": "$",
              "is_nersc": false,
              "container": "bryce911/bbtools:38.86",
              "filename_errlog": "stderr.log",
              "filename_outfile2": "input.corr.right.fastq.gz",
              "java": "-Xmx20g",
              "filename_kmerfile": "unique31mer.txt",
              "run_prefix": "",
              "single": "1",
              "filename_counts": "counts.metadata.json",
              "filename_outfile1": "input.corr.left.fastq.gz",
              "filename_readlen": "readlen.txt",
              "filename_outlog": "stdout.log",
              "reads_files": ["/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/execution/glob-6f0506bead1626d205fb3811ca67163b/rqcfilter.output.fastq.gz"]
            },
            "returnCode": 0,
            "jobId": "21556",
            "backend": "Docker",
            "end": "2020-08-21T21:48:21.481Z",
            "dockerImageUsed": "bryce911/bbtools@sha256:9ded1865aa47877cdc3ced078b3bff20edee8826a6c084f324702bfa20fa3994",
            "stderr": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/execution/stderr",
            "callRoot": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms",
            "attempt": 1,
            "executionEvents": [{
              "startTime": "2020-08-21T21:48:00.055Z",
              "endTime": "2020-08-21T21:48:21.481Z",
              "description": "RunningJob"
            }, {
              "startTime": "2020-08-21T21:47:58.129Z",
              "description": "RequestingExecutionToken",
              "endTime": "2020-08-21T21:47:59.076Z"
            }, {
              "endTime": "2020-08-21T21:48:00.055Z",
              "description": "PreparingJob",
              "startTime": "2020-08-21T21:47:59.077Z"
            }, {
              "endTime": "2020-08-21T21:47:58.129Z",
              "startTime": "2020-08-21T21:47:58.128Z",
              "description": "Pending"
            }, {
              "startTime": "2020-08-21T21:47:59.076Z",
              "description": "WaitingForValueStore",
              "endTime": "2020-08-21T21:47:59.077Z"
            }, {
              "description": "UpdatingJobStore",
              "startTime": "2020-08-21T21:48:21.481Z",
              "endTime": "2020-08-21T21:48:21.481Z"
            }],
            "start": "2020-08-21T21:47:58.128Z"
          }]
        },
        "outputs": {
          "metagenome_assy.final_scaffolds": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp/execution/assembly.scaffolds.fasta",
          "metagenome_assy.final_readlen": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/execution/readlen.txt",
          "metagenome_assy.final_contigs": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp/execution/assembly.contigs.fasta",
          "metagenome_assy.final_spades_log": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-assy/execution/spades3/spades.log",
          "metagenome_assy.final_counts": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/execution/counts.metadata.json"
        },
        "workflowRoot": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea",
        "id": "cf48e1e0-ac76-4737-8246-1d8b627419ef",
        "inputs": {
          "spades_container": "bryce911/spades:3.14.1",
          "nersc": false,
          "bbtools_container": "bryce911/bbtools:38.86",
          "input_files": ["/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/execution/glob-6f0506bead1626d205fb3811ca67163b/rqcfilter.output.fastq.gz"]
        },
        "status": "Succeeded",
        "parentWorkflowId": "9617fcc1-b903-449c-9245-c0438074d3ea",
        "end": "2020-08-21T21:49:18.657Z",
        "start": "2020-08-21T21:47:56.029Z"
      },
      "shardIndex": -1,
      "outputs": {
        "final_readlen": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/execution/readlen.txt",
        "final_counts": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/execution/counts.metadata.json",
        "final_scaffolds": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp/execution/assembly.scaffolds.fasta",
        "final_spades_log": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-assy/execution/spades3/spades.log",
        "final_contigs": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp/execution/assembly.contigs.fasta"
      },
      "inputs": {
        "input_files": ["/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/execution/glob-6f0506bead1626d205fb3811ca67163b/rqcfilter.output.fastq.gz"],
        "bbtools_container": "bryce911/bbtools:38.86",
        "spades_container": "bryce911/spades:3.14.1",
        "nersc": false
      },
      "end": "2020-08-21T21:49:18.658Z",
      "attempt": 1,
      "executionEvents": [{
        "startTime": "2020-08-21T21:47:56.034Z",
        "description": "SubWorkflowRunningState",
        "endTime": "2020-08-21T21:49:18.658Z"
      }, {
        "endTime": "2020-08-21T21:47:56.028Z",
        "description": "SubWorkflowPendingState",
        "startTime": "2020-08-21T21:47:56.026Z"
      }, {
        "description": "SubWorkflowPreparingState",
        "endTime": "2020-08-21T21:47:56.034Z",
        "startTime": "2020-08-21T21:47:56.029Z"
      }, {
        "startTime": "2020-08-21T21:47:56.028Z",
        "endTime": "2020-08-21T21:47:56.029Z",
        "description": "WaitingForValueStore"
      }],
      "start": "2020-08-21T21:47:56.026Z"
    }],
    "metagenome_filtering_assembly_and_alignment.filter": [{
      "executionStatus": "Done",
      "subWorkflowMetadata": {
        "workflowName": "filter",
        "rootWorkflowId": "9617fcc1-b903-449c-9245-c0438074d3ea",
        "calls": {
          "rqcfilter2.rqcfilter": [{
            "executionStatus": "Done",
            "stdout": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/execution/stdout",
            "backendStatus": "Done",
            "compressedDockerSize": 499108549,
            "commandLine": "       if [ 1 == 0 ]\nthen\n    cat /cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/inputs/-417757945/548243e0-5272-45a3-8124-0064cd64bb7d.inter.fastq.gz > rqcfilter.input.fastq.gz\nelse\n    ln /cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/inputs/-417757945/548243e0-5272-45a3-8124-0064cd64bb7d.inter.fastq.gz ./rqcfilter.input.fastq.gz\nfi\ntouch readlen.txt\nreadlength.sh -Xmx1g in=rqcfilter.input.fastq.gz out=readlen.txt overwrite \n       rqcfilter2.sh jni=t in=rqcfilter.input.fastq.gz \\\n           path=filter rna=f trimfragadapter=t qtrim=r trimq=0 maxns=3 maq=3 minlen=51 \\\n           mlf=0.33 phix=t removehuman=t removedog=t removecat=t removemouse=t khist=t \\\n           removemicrobes=t sketch kapa=t clumpify=t tmpdir= barcodefilter=f trimpolyg=5 usejni=f \\\n    rqcfilterdata=/refdata/RQCFilterData \\\n           out=../rqcfilter.output.fastq.gz 1> stdout.log 2> stderr.log",
            "shardIndex": -1,
            "outputs": {
              "outreadlen": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/execution/readlen.txt",
              "outrqcfilter": ["/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/execution/glob-6f0506bead1626d205fb3811ca67163b/rqcfilter.output.fastq.gz"],
              "stdout": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/execution/stdout.log",
              "stderr": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/execution/stderr.log"
            },
            "runtimeAttributes": {
              "docker": "bryce911/bbtools:38.44",
              "failOnStderr": "false",
              "maxRetries": "0",
              "continueOnReturnCode": "0"
            },
            "callCaching": {
              "allowResultReuse": false,
              "effectiveCallCachingMode": "CallCachingOff"
            },
            "inputs": {
              "dollar": "$",
              "filename_errlog": "stderr.log",
              "java": "-Xmx20g",
              "rqcfilter_output": "rqcfilter.output.fastq.gz",
              "single": "1",
              "rqcfilter_input": "rqcfilter.input.fastq.gz",
              "filename_readlen": "readlen.txt",
              "filename_outlog": "stdout.log",
              "reads_files": ["/homes/oakland/canon/dev/jgi_meta_wdl/548243e0-5272-45a3-8124-0064cd64bb7d.inter.fastq.gz"]
            },
            "returnCode": 0,
            "jobId": "20108",
            "backend": "Docker",
            "end": "2020-08-21T21:47:52.520Z",
            "dockerImageUsed": "bryce911/bbtools@sha256:4f8a3afeb42502d40b89d0444be90f8d6cfc71eb3d457bfe32ce7edd20a0d680",
            "stderr": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/execution/stderr",
            "callRoot": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter",
            "attempt": 1,
            "executionEvents": [{
              "startTime": "2020-08-21T21:47:52.518Z",
              "description": "UpdatingJobStore",
              "endTime": "2020-08-21T21:47:52.520Z"
            }, {
              "startTime": "2020-08-21T21:45:39.097Z",
              "description": "WaitingForValueStore",
              "endTime": "2020-08-21T21:45:39.107Z"
            }, {
              "startTime": "2020-08-21T21:45:39.107Z",
              "description": "PreparingJob",
              "endTime": "2020-08-21T21:45:40.824Z"
            }, {
              "startTime": "2020-08-21T21:45:38.598Z",
              "endTime": "2020-08-21T21:45:39.097Z",
              "description": "RequestingExecutionToken"
            }, {
              "startTime": "2020-08-21T21:45:40.824Z",
              "description": "RunningJob",
              "endTime": "2020-08-21T21:47:52.518Z"
            }, {
              "startTime": "2020-08-21T21:45:38.577Z",
              "description": "Pending",
              "endTime": "2020-08-21T21:45:38.598Z"
            }],
            "start": "2020-08-21T21:45:38.545Z"
          }]
        },
        "outputs": {
          "rqcfilter2.final_filtered": ["/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/execution/glob-6f0506bead1626d205fb3811ca67163b/rqcfilter.output.fastq.gz"]
        },
        "workflowRoot": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea",
        "id": "b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60",
        "inputs": {
          "input_files": ["/homes/oakland/canon/dev/jgi_meta_wdl/548243e0-5272-45a3-8124-0064cd64bb7d.inter.fastq.gz"]
        },
        "status": "Succeeded",
        "parentWorkflowId": "9617fcc1-b903-449c-9245-c0438074d3ea",
        "end": "2020-08-21T21:47:54.133Z",
        "start": "2020-08-21T21:45:36.395Z"
      },
      "shardIndex": -1,
      "outputs": {
        "final_filtered": ["/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/execution/glob-6f0506bead1626d205fb3811ca67163b/rqcfilter.output.fastq.gz"]
      },
      "inputs": {
        "input_files": ["/homes/oakland/canon/dev/jgi_meta_wdl/548243e0-5272-45a3-8124-0064cd64bb7d.inter.fastq.gz"]
      },
      "end": "2020-08-21T21:47:54.135Z",
      "attempt": 1,
      "executionEvents": [{
        "startTime": "2020-08-21T21:45:36.423Z",
        "description": "SubWorkflowRunningState",
        "endTime": "2020-08-21T21:47:54.134Z"
      }, {
        "startTime": "2020-08-21T21:45:36.396Z",
        "endTime": "2020-08-21T21:45:36.423Z",
        "description": "SubWorkflowPreparingState"
      }, {
        "startTime": "2020-08-21T21:45:36.373Z",
        "description": "SubWorkflowPendingState",
        "endTime": "2020-08-21T21:45:36.388Z"
      }, {
        "startTime": "2020-08-21T21:45:36.388Z",
        "endTime": "2020-08-21T21:45:36.396Z",
        "description": "WaitingForValueStore"
      }],
      "start": "2020-08-21T21:45:36.369Z"
    }]
  },
  "outputs": {
    "metagenome_filtering_assembly_and_alignment.assy.final_scaffolds": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp/execution/assembly.scaffolds.fasta",
    "metagenome_filtering_assembly_and_alignment.mapping.final_outbamidx": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped_sorted.bam.bai",
    "metagenome_filtering_assembly_and_alignment.assy.final_spades_log": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-assy/execution/spades3/spades.log",
    "metagenome_filtering_assembly_and_alignment.mapping.final_outflagstat": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped_sorted.bam.flagstat",
    "metagenome_filtering_assembly_and_alignment.mapping.final_outbam": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped_sorted.bam",
    "metagenome_filtering_assembly_and_alignment.assy.final_counts": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/execution/counts.metadata.json",
    "metagenome_filtering_assembly_and_alignment.assy.final_contigs": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-create_agp/execution/assembly.contigs.fasta",
    "metagenome_filtering_assembly_and_alignment.mapping.final_outsam": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped.sam.gz",
    "metagenome_filtering_assembly_and_alignment.filter.final_filtered": ["/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-filter/rqcfilter2.rqcfilter2/b6a3d4bd-ce8a-492b-9b45-7c984a7fbc60/call-rqcfilter/execution/glob-6f0506bead1626d205fb3811ca67163b/rqcfilter.output.fastq.gz"],
    "metagenome_filtering_assembly_and_alignment.mapping.final_outcov": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-mapping/mapping.mapping/898b4836-9021-49ca-acb2-f615ab4b0daa/call-finalize_bams/execution/pairedMapped_sorted.bam.cov",
    "metagenome_filtering_assembly_and_alignment.assy.final_readlen": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea/call-assy/metagenome_assy.metagenome_assy/cf48e1e0-ac76-4737-8246-1d8b627419ef/call-bbcms/execution/readlen.txt"
  },
  "workflowRoot": "/mnt/nfs3/data1/homes/canon/dev/jgi_meta_wdl/cromwell-executions/metagenome_filtering_assembly_and_alignment/9617fcc1-b903-449c-9245-c0438074d3ea",
  "actualWorkflowLanguage": "WDL",
  "id": "9617fcc1-b903-449c-9245-c0438074d3ea",
  "inputs": {
    "metagenome_filtering_assembly_and_alignment.assy.bbtools_container": "bryce911/bbtools:38.86",
    "metagenome_filtering_assembly_and_alignment.assy.spades_container": "bryce911/spades:3.14.1",
    "metagenome_filtering_assembly_and_alignment.assy.nersc": false,
    "metagenome_filtering_assembly_and_alignment.input_files": ["/homes/oakland/canon/dev/jgi_meta_wdl/548243e0-5272-45a3-8124-0064cd64bb7d.inter.fastq.gz"]
  },
  "labels": {
    "cromwell-workflow-id": "cromwell-9617fcc1-b903-449c-9245-c0438074d3ea"
  },
  "submission": "2020-08-21T21:45:32.486Z",
  "status": "Succeeded",
  "end": "2020-08-21T21:49:45.099Z",
  "start": "2020-08-21T21:45:32.614Z"
}