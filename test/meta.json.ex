{
  "workflowName": "jgi_meta_assem_wf",
  "workflowProcessingEvents": [{
    "description": "Finished",
    "cromwellVersion": "44",
    "cromwellId": "cromid-fb9ecc1",
    "timestamp": "2020-07-13T02:57:26.657Z"
  }, {
    "cromwellId": "cromid-fb9ecc1",
    "description": "PickedUp",
    "timestamp": "2020-07-13T02:47:17.369Z",
    "cromwellVersion": "44"
  }],
  "actualWorkflowLanguageVersion": "draft-2",
  "submittedFiles": {
    "workflow": "workflow jgi_meta_assem_wf {\n    File input_file  \n    Int threads\n\n    call rqcfilt {\n      input: infile=input_file,\n             threads=threads\n    }\n\n    call bfc {\n      input: infile=rqcfilt.filtered,\n             threads=threads\n    }\n\n    call split {\n      input: infile=bfc.out\n    }\n\n    call spades {\n      input: read1=split.read1,\n             read2=split.read2\n    }\n\n    call fungalrelease {\n      input: infile=spades.scaffolds\n    }\n\n    call stats {\n      input: infile=fungalrelease.assy\n    }\n\n    call bbmap {\n      input: fastq=rqcfilt.filtered,\n             ref=fungalrelease.assy\n    }\n}\n\n# Error correct and filter junk from reads\ntask rqcfilt {\n    File infile\n    Int threads\n\n    command {\n\tpwd\n        rqcfilter.sh -Xmx50G threads=${threads} in=${infile} \\\n           out=filtered.fastq.gz \\\n           path=. rqcfilterdata=/refdata/RQCFilterData trimfragadapter=t qtrim=r trimq=10 maxns=0 maq=12 minlen=51 mlf=0.33 \\\n           phix=t removehuman=t removedog=t removecat=t removemouse=t khist=t removemicrobes=f sketch=f kapa=t clumpify=t\n    }\n\n    output {\n        File filtered = \"filtered.fastq.gz\"\n    }\n    runtime {\n        docker: 'jfroula/jgi_meta_assem:1.0.2'\n    }\n}\n\ntask bfc {\n    File infile \n    Int threads\n    \n    command\n    {\n        echo -e \"\\n### running bfc infile: ${infile} ###\\n\"\n        bfc -1 -k 25 -b 32 -t ${threads} ${infile} 1> bfc.fastq 2> bfc.error \n\n        seqtk trimfq bfc.fastq 1> bfc.seqtk.fastq 2> seqtk.error\n        \n        pigz -c bfc.seqtk.fastq -p 4 -2 1> filtered.bfc.fq.gz 2> pigz.error \n    }\n    output {\n        File out = \"filtered.bfc.fq.gz\"\n    }\n    runtime {\n        docker: 'jfroula/jgi_meta_assem:1.0.2'\n    }\n}\n\n# split paired end reads for spades (and generate some read stats)\ntask split {\n    File infile \n    \n    command\n    {\n        readlength.sh in=${infile} 1>| readlen.txt;\n\n        reformat.sh overwrite=true in=${infile} out=read1.fasta out2=read2.fasta\n    }\n    output {\n        File readlen = \"readlen.txt\"\n        File read1 = \"read1.fasta\"\n        File read2 = \"read2.fasta\"\n    }\n    runtime {\n        docker: 'jfroula/jgi_meta_assem:1.0.2'\n    }\n}\n\n# run MetaSpades\ntask spades {\n    File read1\n    File read2\n    \n    command\n    {\n        spades.py -m 2000 -o spades3 --only-assembler -k 33,55,77,99,127 --meta -t 32 -1 ${read1} -2 ${read2}\n    }\n    output {\n        File scaffolds = \"spades3/scaffolds.fasta\"\n    }\n    runtime {\n        cpu: 32\n        time: \"24:00:00\"\n        mem: \"115G\"\n        cluster: \"cori\"\n        poolname:  \"annotation\"\n        docker: 'jfroula/jgi_meta_assem:1.0.2'\n    }\n}\n\n# fungalrelease step will improve conteguity of assembly\ntask fungalrelease {\n    File infile\n    \n    command\n    {\n        fungalrelease.sh -Xmx10g in=${infile} out=assembly.scaffolds.fasta outc=assembly.contigs.fasta agp=assembly.agp legend=assembly.scaffolds.legend mincontig=200 minscaf=200 sortscaffolds=t sortcontigs=t overwrite=t\n    }\n    output {\n        File assy = \"assembly.scaffolds.fasta\"\n    }\n    runtime {\n        docker: 'jfroula/jgi_meta_assem:1.0.2'\n    }\n}\n\n# generate some assembly stats for the report\ntask stats {\n    File infile\n    \n    command\n    {\n        stats.sh format=6 in=${infile} 1> bbstats.tsv 2> bbstats.tsv.e \n\n        stats.sh in=${infile} 1> bbstats.txt 2> bbstats.txt.e\n    }\n    output {\n        File statstsv = \"bbstats.tsv\"\n        File statstxt = \"bbstats.txt\"\n    }\n    runtime {\n        docker: 'jfroula/jgi_meta_assem:1.0.2'\n    }\n}\n\n# Map the filtered (but not bfc corrected) reads back to scaffold\ntask bbmap {\n    File fastq\n    File ref\n    \n    command\n    {\n        bbmap.sh nodisk=true interleaved=true ambiguous=random in=${fastq} ref=${ref} out=paired.mapped.bam covstats=paired.mapped.cov \n\n        samtools sort -@ 3 paired.mapped.bam -o paired.mapped_sorted.bam\n\n        samtools index paired.mapped_sorted.bam\n    }\n    output {\n        File bam = \"paired.mapped.bam\"\n        File covstats = \"paired.mapped.cov\"\n    }\n    runtime {\n        docker: 'jfroula/jgi_meta_assem:1.0.2'\n    }\n}\n\n\n",
    "root": "",
    "options": "{\n\n}",
    "inputs": "{\"jgi_meta_assem_wf.input_file\": \"548243e0-5272-45a3-8124-0064cd64bb7d.inter.fastq\", \"jgi_meta_assem_wf.threads\": \"4\"}\n",
    "workflowUrl": "../../../jgi_meta_spades.wdl",
    "labels": "{}"
  },
  "calls": {
    "jgi_meta_assem_wf.bbmap": [{
      "executionStatus": "Done",
      "stdout": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bbmap/execution/stdout",
      "backendStatus": "Done",
      "compressedDockerSize": 625530858,
      "commandLine": "bbmap.sh nodisk=true interleaved=true ambiguous=random in=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bbmap/inputs/2043362170/filtered.fastq.gz ref=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bbmap/inputs/148534751/assembly.scaffolds.fasta out=paired.mapped.bam covstats=paired.mapped.cov \n\nsamtools sort -@ 3 paired.mapped.bam -o paired.mapped_sorted.bam\n\nsamtools index paired.mapped_sorted.bam",
      "shardIndex": -1,
      "outputs": {
        "covstats": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bbmap/execution/paired.mapped.cov",
        "bam": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bbmap/execution/paired.mapped.bam"
      },
      "runtimeAttributes": {
        "maxRetries": "0",
        "continueOnReturnCode": "0",
        "docker": "jfroula/jgi_meta_assem:1.0.2",
        "failOnStderr": "false"
      },
      "callCaching": {
        "allowResultReuse": false,
        "effectiveCallCachingMode": "CallCachingOff"
      },
      "inputs": {
        "fastq": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/execution/filtered.fastq.gz",
        "ref": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-fungalrelease/execution/assembly.scaffolds.fasta"
      },
      "returnCode": 0,
      "jobId": "26398",
      "backend": "Docker",
      "end": "2020-07-13T02:57:25.034Z",
      "dockerImageUsed": "jfroula/jgi_meta_assem@sha256:c49e756bce635f85ab643827070528f650b6bfffcca99264342b0c9f2b3fe8b9",
      "stderr": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bbmap/execution/stderr",
      "callRoot": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bbmap",
      "attempt": 1,
      "executionEvents": [{
        "startTime": "2020-07-13T02:57:25.034Z",
        "description": "UpdatingJobStore",
        "endTime": "2020-07-13T02:57:25.034Z"
      }, {
        "description": "WaitingForValueStore",
        "endTime": "2020-07-13T02:57:13.905Z",
        "startTime": "2020-07-13T02:57:13.904Z"
      }, {
        "endTime": "2020-07-13T02:57:13.914Z",
        "startTime": "2020-07-13T02:57:13.905Z",
        "description": "PreparingJob"
      }, {
        "startTime": "2020-07-13T02:57:13.328Z",
        "endTime": "2020-07-13T02:57:13.329Z",
        "description": "Pending"
      }, {
        "startTime": "2020-07-13T02:57:13.914Z",
        "description": "RunningJob",
        "endTime": "2020-07-13T02:57:25.034Z"
      }, {
        "description": "RequestingExecutionToken",
        "startTime": "2020-07-13T02:57:13.329Z",
        "endTime": "2020-07-13T02:57:13.904Z"
      }],
      "start": "2020-07-13T02:57:13.328Z"
    }],
    "jgi_meta_assem_wf.split": [{
      "executionStatus": "Done",
      "stdout": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-split/execution/stdout",
      "backendStatus": "Done",
      "compressedDockerSize": 625530858,
      "commandLine": "readlength.sh in=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-split/inputs/-1334454390/filtered.bfc.fq.gz 1>| readlen.txt;\n\nreformat.sh overwrite=true in=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-split/inputs/-1334454390/filtered.bfc.fq.gz out=read1.fasta out2=read2.fasta",
      "shardIndex": -1,
      "outputs": {
        "readlen": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-split/execution/readlen.txt",
        "read1": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-split/execution/read1.fasta",
        "read2": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-split/execution/read2.fasta"
      },
      "runtimeAttributes": {
        "maxRetries": "0",
        "continueOnReturnCode": "0",
        "docker": "jfroula/jgi_meta_assem:1.0.2",
        "failOnStderr": "false"
      },
      "callCaching": {
        "allowResultReuse": false,
        "effectiveCallCachingMode": "CallCachingOff"
      },
      "inputs": {
        "infile": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bfc/execution/filtered.bfc.fq.gz"
      },
      "returnCode": 0,
      "jobId": "20383",
      "backend": "Docker",
      "end": "2020-07-13T02:56:38.354Z",
      "dockerImageUsed": "jfroula/jgi_meta_assem@sha256:c49e756bce635f85ab643827070528f650b6bfffcca99264342b0c9f2b3fe8b9",
      "stderr": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-split/execution/stderr",
      "callRoot": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-split",
      "attempt": 1,
      "executionEvents": [{
        "startTime": "2020-07-13T02:56:33.699Z",
        "description": "RequestingExecutionToken",
        "endTime": "2020-07-13T02:56:33.903Z"
      }, {
        "startTime": "2020-07-13T02:56:33.903Z",
        "description": "WaitingForValueStore",
        "endTime": "2020-07-13T02:56:33.904Z"
      }, {
        "endTime": "2020-07-13T02:56:38.353Z",
        "description": "UpdatingJobStore",
        "startTime": "2020-07-13T02:56:38.353Z"
      }, {
        "description": "Pending",
        "startTime": "2020-07-13T02:56:33.698Z",
        "endTime": "2020-07-13T02:56:33.699Z"
      }, {
        "startTime": "2020-07-13T02:56:33.904Z",
        "endTime": "2020-07-13T02:56:33.912Z",
        "description": "PreparingJob"
      }, {
        "endTime": "2020-07-13T02:56:38.353Z",
        "startTime": "2020-07-13T02:56:33.912Z",
        "description": "RunningJob"
      }],
      "start": "2020-07-13T02:56:33.698Z"
    }],
    "jgi_meta_assem_wf.fungalrelease": [{
      "executionStatus": "Done",
      "stdout": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-fungalrelease/execution/stdout",
      "backendStatus": "Done",
      "compressedDockerSize": 625530858,
      "commandLine": "fungalrelease.sh -Xmx10g in=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-fungalrelease/inputs/-1152505077/scaffolds.fasta out=assembly.scaffolds.fasta outc=assembly.contigs.fasta agp=assembly.agp legend=assembly.scaffolds.legend mincontig=200 minscaf=200 sortscaffolds=t sortcontigs=t overwrite=t",
      "shardIndex": -1,
      "outputs": {
        "assy": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-fungalrelease/execution/assembly.scaffolds.fasta"
      },
      "runtimeAttributes": {
        "continueOnReturnCode": "0",
        "maxRetries": "0",
        "failOnStderr": "false",
        "docker": "jfroula/jgi_meta_assem:1.0.2"
      },
      "callCaching": {
        "allowResultReuse": false,
        "effectiveCallCachingMode": "CallCachingOff"
      },
      "inputs": {
        "infile": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-spades/execution/spades3/scaffolds.fasta"
      },
      "returnCode": 0,
      "jobId": "26168",
      "backend": "Docker",
      "end": "2020-07-13T02:57:11.791Z",
      "dockerImageUsed": "jfroula/jgi_meta_assem@sha256:c49e756bce635f85ab643827070528f650b6bfffcca99264342b0c9f2b3fe8b9",
      "stderr": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-fungalrelease/execution/stderr",
      "callRoot": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-fungalrelease",
      "attempt": 1,
      "executionEvents": [{
        "startTime": "2020-07-13T02:57:11.790Z",
        "description": "UpdatingJobStore",
        "endTime": "2020-07-13T02:57:11.791Z"
      }, {
        "endTime": "2020-07-13T02:57:09.903Z",
        "startTime": "2020-07-13T02:57:09.246Z",
        "description": "RequestingExecutionToken"
      }, {
        "endTime": "2020-07-13T02:57:11.790Z",
        "startTime": "2020-07-13T02:57:09.909Z",
        "description": "RunningJob"
      }, {
        "startTime": "2020-07-13T02:57:09.904Z",
        "description": "PreparingJob",
        "endTime": "2020-07-13T02:57:09.909Z"
      }, {
        "startTime": "2020-07-13T02:57:09.903Z",
        "description": "WaitingForValueStore",
        "endTime": "2020-07-13T02:57:09.904Z"
      }, {
        "description": "Pending",
        "startTime": "2020-07-13T02:57:09.245Z",
        "endTime": "2020-07-13T02:57:09.246Z"
      }],
      "start": "2020-07-13T02:57:09.245Z"
    }],
    "jgi_meta_assem_wf.bfc": [{
      "executionStatus": "Done",
      "stdout": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bfc/execution/stdout",
      "backendStatus": "Done",
      "compressedDockerSize": 625530858,
      "commandLine": "echo -e \"\\n### running bfc infile: /cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bfc/inputs/2043362170/filtered.fastq.gz ###\\n\"\nbfc -1 -k 25 -b 32 -t 4 /cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bfc/inputs/2043362170/filtered.fastq.gz 1> bfc.fastq 2> bfc.error \n\nseqtk trimfq bfc.fastq 1> bfc.seqtk.fastq 2> seqtk.error\n\npigz -c bfc.seqtk.fastq -p 4 -2 1> filtered.bfc.fq.gz 2> pigz.error",
      "shardIndex": -1,
      "outputs": {
        "out": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bfc/execution/filtered.bfc.fq.gz"
      },
      "runtimeAttributes": {
        "continueOnReturnCode": "0",
        "maxRetries": "0",
        "docker": "jfroula/jgi_meta_assem:1.0.2",
        "failOnStderr": "false"
      },
      "callCaching": {
        "allowResultReuse": false,
        "effectiveCallCachingMode": "CallCachingOff"
      },
      "inputs": {
        "threads": 4,
        "infile": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/execution/filtered.fastq.gz"
      },
      "returnCode": 0,
      "jobId": "19976",
      "backend": "Docker",
      "end": "2020-07-13T02:56:31.730Z",
      "dockerImageUsed": "jfroula/jgi_meta_assem@sha256:c49e756bce635f85ab643827070528f650b6bfffcca99264342b0c9f2b3fe8b9",
      "stderr": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bfc/execution/stderr",
      "callRoot": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bfc",
      "attempt": 1,
      "executionEvents": [{
        "description": "RequestingExecutionToken",
        "endTime": "2020-07-13T02:51:20.904Z",
        "startTime": "2020-07-13T02:51:20.358Z"
      }, {
        "startTime": "2020-07-13T02:51:20.917Z",
        "description": "RunningJob",
        "endTime": "2020-07-13T02:56:31.729Z"
      }, {
        "description": "WaitingForValueStore",
        "endTime": "2020-07-13T02:51:20.905Z",
        "startTime": "2020-07-13T02:51:20.904Z"
      }, {
        "startTime": "2020-07-13T02:56:31.729Z",
        "description": "UpdatingJobStore",
        "endTime": "2020-07-13T02:56:31.729Z"
      }, {
        "startTime": "2020-07-13T02:51:20.356Z",
        "description": "Pending",
        "endTime": "2020-07-13T02:51:20.358Z"
      }, {
        "startTime": "2020-07-13T02:51:20.905Z",
        "description": "PreparingJob",
        "endTime": "2020-07-13T02:51:20.917Z"
      }],
      "start": "2020-07-13T02:51:20.356Z"
    }],
    "jgi_meta_assem_wf.stats": [{
      "executionStatus": "Done",
      "stdout": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-stats/execution/stdout",
      "backendStatus": "Done",
      "compressedDockerSize": 625530858,
      "commandLine": "stats.sh format=6 in=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-stats/inputs/148534751/assembly.scaffolds.fasta 1> bbstats.tsv 2> bbstats.tsv.e \n\nstats.sh in=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-stats/inputs/148534751/assembly.scaffolds.fasta 1> bbstats.txt 2> bbstats.txt.e",
      "shardIndex": -1,
      "outputs": {
        "statstsv": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-stats/execution/bbstats.tsv",
        "statstxt": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-stats/execution/bbstats.txt"
      },
      "runtimeAttributes": {
        "docker": "jfroula/jgi_meta_assem:1.0.2",
        "failOnStderr": "false",
        "maxRetries": "0",
        "continueOnReturnCode": "0"
      },
      "callCaching": {
        "allowResultReuse": false,
        "effectiveCallCachingMode": "CallCachingOff"
      },
      "inputs": {
        "infile": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-fungalrelease/execution/assembly.scaffolds.fasta"
      },
      "returnCode": 0,
      "jobId": "26394",
      "backend": "Docker",
      "end": "2020-07-13T02:57:16.795Z",
      "dockerImageUsed": "jfroula/jgi_meta_assem@sha256:c49e756bce635f85ab643827070528f650b6bfffcca99264342b0c9f2b3fe8b9",
      "stderr": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-stats/execution/stderr",
      "callRoot": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-stats",
      "attempt": 1,
      "executionEvents": [{
        "startTime": "2020-07-13T02:57:13.327Z",
        "endTime": "2020-07-13T02:57:13.328Z",
        "description": "Pending"
      }, {
        "startTime": "2020-07-13T02:57:13.905Z",
        "endTime": "2020-07-13T02:57:13.913Z",
        "description": "PreparingJob"
      }, {
        "description": "RunningJob",
        "startTime": "2020-07-13T02:57:13.913Z",
        "endTime": "2020-07-13T02:57:16.794Z"
      }, {
        "description": "WaitingForValueStore",
        "endTime": "2020-07-13T02:57:13.905Z",
        "startTime": "2020-07-13T02:57:13.904Z"
      }, {
        "startTime": "2020-07-13T02:57:13.328Z",
        "description": "RequestingExecutionToken",
        "endTime": "2020-07-13T02:57:13.904Z"
      }, {
        "startTime": "2020-07-13T02:57:16.794Z",
        "description": "UpdatingJobStore",
        "endTime": "2020-07-13T02:57:16.794Z"
      }],
      "start": "2020-07-13T02:57:13.327Z"
    }],
    "jgi_meta_assem_wf.spades": [{
      "executionStatus": "Done",
      "stdout": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-spades/execution/stdout",
      "backendStatus": "Done",
      "compressedDockerSize": 625530858,
      "commandLine": "spades.py -m 2000 -o spades3 --only-assembler -k 33,55,77,99,127 --meta -t 32 -1 /cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-spades/inputs/-2136479803/read1.fasta -2 /cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-spades/inputs/-2136479803/read2.fasta",
      "shardIndex": -1,
      "outputs": {
        "scaffolds": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-spades/execution/spades3/scaffolds.fasta"
      },
      "runtimeAttributes": {
        "continueOnReturnCode": "0",
        "maxRetries": "0",
        "docker": "jfroula/jgi_meta_assem:1.0.2",
        "failOnStderr": "false"
      },
      "callCaching": {
        "allowResultReuse": false,
        "effectiveCallCachingMode": "CallCachingOff"
      },
      "inputs": {
        "read2": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-split/execution/read2.fasta",
        "read1": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-split/execution/read1.fasta"
      },
      "returnCode": 0,
      "jobId": "20647",
      "backend": "Docker",
      "end": "2020-07-13T02:57:08.005Z",
      "dockerImageUsed": "jfroula/jgi_meta_assem@sha256:c49e756bce635f85ab643827070528f650b6bfffcca99264342b0c9f2b3fe8b9",
      "stderr": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-spades/execution/stderr",
      "callRoot": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-spades",
      "attempt": 1,
      "executionEvents": [{
        "description": "WaitingForValueStore",
        "startTime": "2020-07-13T02:56:39.903Z",
        "endTime": "2020-07-13T02:56:39.905Z"
      }, {
        "startTime": "2020-07-13T02:56:39.815Z",
        "description": "Pending",
        "endTime": "2020-07-13T02:56:39.816Z"
      }, {
        "description": "UpdatingJobStore",
        "endTime": "2020-07-13T02:57:08.005Z",
        "startTime": "2020-07-13T02:57:08.004Z"
      }, {
        "startTime": "2020-07-13T02:56:39.914Z",
        "description": "RunningJob",
        "endTime": "2020-07-13T02:57:08.004Z"
      }, {
        "startTime": "2020-07-13T02:56:39.905Z",
        "description": "PreparingJob",
        "endTime": "2020-07-13T02:56:39.914Z"
      }, {
        "startTime": "2020-07-13T02:56:39.816Z",
        "description": "RequestingExecutionToken",
        "endTime": "2020-07-13T02:56:39.903Z"
      }],
      "start": "2020-07-13T02:56:39.815Z"
    }],
    "jgi_meta_assem_wf.rqcfilt": [{
      "executionStatus": "Done",
      "stdout": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/execution/stdout",
      "backendStatus": "Done",
      "compressedDockerSize": 625530858,
      "commandLine": "pwd\n       rqcfilter.sh -Xmx50G threads=4 in=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/inputs/621809747/548243e0-5272-45a3-8124-0064cd64bb7d.inter.fastq \\\n          out=filtered.fastq.gz \\\n          path=. rqcfilterdata=/refdata/RQCFilterData trimfragadapter=t qtrim=r trimq=10 maxns=0 maq=12 minlen=51 mlf=0.33 \\\n          phix=t removehuman=t removedog=t removecat=t removemouse=t khist=t removemicrobes=f sketch=f kapa=t clumpify=t",
      "shardIndex": -1,
      "outputs": {
        "filtered": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/execution/filtered.fastq.gz"
      },
      "runtimeAttributes": {
        "continueOnReturnCode": "0",
        "maxRetries": "0",
        "docker": "jfroula/jgi_meta_assem:1.0.2",
        "failOnStderr": "false"
      },
      "callCaching": {
        "allowResultReuse": false,
        "effectiveCallCachingMode": "CallCachingOff"
      },
      "inputs": {
        "threads": 4,
        "infile": "548243e0-5272-45a3-8124-0064cd64bb7d.inter.fastq"
      },
      "returnCode": 0,
      "jobId": "19217",
      "backend": "Docker",
      "end": "2020-07-13T02:51:19.199Z",
      "dockerImageUsed": "jfroula/jgi_meta_assem@sha256:c49e756bce635f85ab643827070528f650b6bfffcca99264342b0c9f2b3fe8b9",
      "stderr": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/execution/stderr",
      "callRoot": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt",
      "attempt": 1,
      "executionEvents": [{
        "startTime": "2020-07-13T02:47:21.311Z",
        "description": "RequestingExecutionToken",
        "endTime": "2020-07-13T02:47:21.923Z"
      }, {
        "startTime": "2020-07-13T02:47:21.286Z",
        "description": "Pending",
        "endTime": "2020-07-13T02:47:21.311Z"
      }, {
        "startTime": "2020-07-13T02:47:24.147Z",
        "description": "RunningJob",
        "endTime": "2020-07-13T02:51:19.197Z"
      }, {
        "startTime": "2020-07-13T02:47:21.934Z",
        "description": "PreparingJob",
        "endTime": "2020-07-13T02:47:24.147Z"
      }, {
        "startTime": "2020-07-13T02:51:19.197Z",
        "description": "UpdatingJobStore",
        "endTime": "2020-07-13T02:51:19.201Z"
      }, {
        "description": "WaitingForValueStore",
        "startTime": "2020-07-13T02:47:21.923Z",
        "endTime": "2020-07-13T02:47:21.934Z"
      }],
      "start": "2020-07-13T02:47:21.255Z"
    }]
  },
  "outputs": {
    "jgi_meta_assem_wf.rqcfilt.filtered": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/execution/filtered.fastq.gz",
    "jgi_meta_assem_wf.split.read1": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-split/execution/read1.fasta",
    "jgi_meta_assem_wf.stats.statstsv": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-stats/execution/bbstats.tsv",
    "jgi_meta_assem_wf.fungalrelease.assy": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-fungalrelease/execution/assembly.scaffolds.fasta",
    "jgi_meta_assem_wf.split.readlen": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-split/execution/readlen.txt",
    "jgi_meta_assem_wf.bfc.out": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bfc/execution/filtered.bfc.fq.gz",
    "jgi_meta_assem_wf.split.read2": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-split/execution/read2.fasta",
    "jgi_meta_assem_wf.spades.scaffolds": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-spades/execution/spades3/scaffolds.fasta",
    "jgi_meta_assem_wf.bbmap.bam": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bbmap/execution/paired.mapped.bam",
    "jgi_meta_assem_wf.stats.statstxt": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-stats/execution/bbstats.txt",
    "jgi_meta_assem_wf.bbmap.covstats": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-bbmap/execution/paired.mapped.cov"
  },
  "workflowRoot": "/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204",
  "actualWorkflowLanguage": "WDL",
  "id": "6f823463-12d8-4608-a458-a1b006b35204",
  "inputs": {
    "jgi_meta_assem_wf.input_file": "548243e0-5272-45a3-8124-0064cd64bb7d.inter.fastq",
    "jgi_meta_assem_wf.threads": 4
  },
  "labels": {
    "cromwell-workflow-id": "cromwell-6f823463-12d8-4608-a458-a1b006b35204"
  },
  "submission": "2020-07-13T02:47:17.298Z",
  "status": "Succeeded",
  "end": "2020-07-13T02:57:26.655Z",
  "start": "2020-07-13T02:47:17.436Z"
}
