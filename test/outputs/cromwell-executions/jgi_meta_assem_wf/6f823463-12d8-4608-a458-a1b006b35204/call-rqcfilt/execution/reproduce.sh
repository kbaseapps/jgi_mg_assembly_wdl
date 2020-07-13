#!/bin/bash
#BBTools version 38.57
#The steps below recapitulate the output of RQCFilter2 when run like this:
#rqcfilter2.sh jni=t threads=4 in=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/inputs/621809747/548243e0-5272-45a3-8124-0064cd64bb7d.inter.fastq out=filtered.fastq.gz path=. rqcfilterdata=/refdata/RQCFilterData trimfragadapter=t qtrim=r trimq=10 maxns=0 maq=12 minlen=51 mlf=0.33 phix=t removehuman=t removedog=t removecat=t removemouse=t khist=t removemicrobes=f sketch=f kapa=t clumpify=t
#Data dependencies are available at http://portal.nersc.gov/dna/microbial/assembly/bushnell/RQCFilterData.tar


bbmerge.sh overwrite=true in1=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/inputs/621809747/548243e0-5272-45a3-8124-0064cd64bb7d.inter.fastq outa=./adaptersDetected.fa reads=1m

clumpify.sh pigz=t unpigz=t zl=4 reorder in1=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/inputs/621809747/548243e0-5272-45a3-8124-0064cd64bb7d.inter.fastq out1=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/tmp.4ec90d83/TEMP_CLUMP_22d1d55c6a4b2a3caf7082c611ec7f_filtered.fastq.gz passes=1

bbduk.sh ktrim=r ordered minlen=51 minlenfraction=0.33 mink=11 tbo tpe rcomp=f overwrite=true k=23 hdist=1 hdist2=1 ftm=5 pratio=G,C plen=20 phist=./phist.txt qhist=./qhist.txt bhist=./bhist.txt gchist=./gchist.txt pigz=t unpigz=t zl=4 ow=true in1=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/tmp.4ec90d83/TEMP_CLUMP_22d1d55c6a4b2a3caf7082c611ec7f_filtered.fastq.gz out1=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/tmp.4ec90d83/TEMP_TRIM_22d1d55c6a4b2a3caf7082c611ec7f_filtered.fastq.gz rqc=hashmap outduk=./ktrim_kmerStats1.txt stats=./ktrim_scaffoldStats1.txt loglog loglogout ref=/refdata/RQCFilterData/adapters2.fa.gz

rm /cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/tmp.4ec90d83/TEMP_CLUMP_22d1d55c6a4b2a3caf7082c611ec7f_filtered.fastq.gz

seal.sh ordered overwrite=true k=31 hdist=0 pigz=t unpigz=t zl=6 in1=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/tmp.4ec90d83/TEMP_TRIM_22d1d55c6a4b2a3caf7082c611ec7f_filtered.fastq.gz outu1=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/tmp.4ec90d83/TEMP_SPIKEIN_22d1d55c6a4b2a3caf7082c611ec7f_filtered.fastq.gz outm=./spikein.fq.gz stats=./scaffoldStatsSpikein.txt loglog loglogout ref=/refdata/RQCFilterData/kapatags.L40.fa.gz

rm /cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/tmp.4ec90d83/TEMP_TRIM_22d1d55c6a4b2a3caf7082c611ec7f_filtered.fastq.gz

bbduk.sh maq=12.0,0 trimq=10.0 qtrim=r ordered overwrite=true maxns=0 minlen=51 minlenfraction=0.33 k=31 hdist=1 pigz=t unpigz=t zl=6 cf=t barcodefilter=crash ow=true in1=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/tmp.4ec90d83/TEMP_SPIKEIN_22d1d55c6a4b2a3caf7082c611ec7f_filtered.fastq.gz out1=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/tmp.4ec90d83/TEMP_FILTER1_22d1d55c6a4b2a3caf7082c611ec7f_filtered.fastq.gz outm=./synth1.fq.gz rqc=hashmap outduk=./kmerStats1.txt stats=./scaffoldStats1.txt loglog loglogout ref=/refdata/RQCFilterData/Illumina.artifacts.fa.gz,/refdata/RQCFilterData/nextera_LMP_linker.fa.gz,/refdata/RQCFilterData/phix174_ill.ref.fa.gz,/refdata/RQCFilterData/lambda.fa.gz,/refdata/RQCFilterData/pJET1.2.fa.gz

rm /cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/tmp.4ec90d83/TEMP_SPIKEIN_22d1d55c6a4b2a3caf7082c611ec7f_filtered.fastq.gz

bbduk.sh ordered overwrite=true k=20 hdist=1 pigz=t unpigz=t zl=6 ow=true in1=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/tmp.4ec90d83/TEMP_FILTER1_22d1d55c6a4b2a3caf7082c611ec7f_filtered.fastq.gz out1=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/tmp.4ec90d83/TEMP_FILTER2_22d1d55c6a4b2a3caf7082c611ec7f_filtered.fastq.gz outm=./synth2.fq.gz outduk=./kmerStats2.txt stats=./scaffoldStats2.txt loglog loglogout ref=/refdata/RQCFilterData/short.fa.gz,/refdata/RQCFilterData/short.fa.gz

rm /cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/tmp.4ec90d83/TEMP_FILTER1_22d1d55c6a4b2a3caf7082c611ec7f_filtered.fastq.gz

bbsplit.sh ordered=false k=14 idtag=t usemodulo printunmappedcount ow=true qtrim=rl trimq=10 untrim kfilter=25 maxsites=1 tipsearch=0 minratio=.9 maxindel=3 minhits=2 bw=12 bwr=0.16 fast=true maxsites2=10 build=1 ef=0.03 outm=./human.fq.gz path=/refdata/RQCFilterData/mousecatdoghuman/ refstats=./refStats.txt pigz=t unpigz=t zl=9 forcereadonly in1=/cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/tmp.4ec90d83/TEMP_FILTER2_22d1d55c6a4b2a3caf7082c611ec7f_filtered.fastq.gz outu1=./filtered.fastq.gz

rm /cromwell-executions/jgi_meta_assem_wf/6f823463-12d8-4608-a458-a1b006b35204/call-rqcfilt/tmp.4ec90d83/TEMP_FILTER2_22d1d55c6a4b2a3caf7082c611ec7f_filtered.fastq.gz

bbmerge.sh loose overwrite=true in1=./filtered.fastq.gz ihist=./ihist_merge.txt outc=./cardinality.txt pigz=t unpigz=t zl=9 adapters=/refdata/RQCFilterData/adapters2.fa.gz mininsert=25 ecct extend2=100 rem k=62 prefilter prealloc loglog

kmercountexact.sh overwrite=true in1=./filtered.fastq.gz khist=./khist.txt peaks=./peaks.txt unpigz=t gchist
