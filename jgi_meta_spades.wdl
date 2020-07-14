workflow jgi_meta_assem_wf {
    File input_file  
    Int threads

    call rqcfilt {
      input: infile=input_file,
             threads=threads
    }

    call bfc {
      input: infile=rqcfilt.filtered,
             threads=threads
    }

    call split {
      input: infile=bfc.out
    }

    call spades {
      input: read1=split.read1,
             read2=split.read2
    }

    call fungalrelease {
      input: infile=spades.scaffolds
    }

    call stats {
      input: infile=fungalrelease.assy
    }

    call bbmap {
      input: fastq=rqcfilt.filtered,
             ref=fungalrelease.assy
    }
}

# Error correct and filter junk from reads
task rqcfilt {
    File infile
    Int threads

    command {
        rqcfilter.sh -Xmx50G threads=${threads} in=${infile} \
           out=filtered.fastq.gz \
           rqcfilterdata=/refdata/RQCFilterData \
           path=. trimfragadapter=t qtrim=r trimq=10 maxns=0 maq=12 minlen=51 mlf=0.33 \
           phix=t removehuman=t removedog=t removecat=t removemouse=t khist=t removemicrobes=f sketch=f kapa=t clumpify=t
    }

    output {
        File filtered = "filtered.fastq.gz"
    }
    runtime {
        docker: 'jfroula/jgi_meta_assem:1.0.2'
    }
}

task bfc {
    File infile 
    Int threads
    
    command
    {
        echo -e "\n### running bfc infile: ${infile} ###\n"
        bfc -1 -k 25 -b 32 -t ${threads} ${infile} 1> bfc.fastq 2> bfc.error 

        seqtk trimfq bfc.fastq 1> bfc.seqtk.fastq 2> seqtk.error
        
        pigz -c bfc.seqtk.fastq -p 4 -2 1> filtered.bfc.fq.gz 2> pigz.error 
    }
    output {
        File out = "filtered.bfc.fq.gz"
    }
    runtime {
        docker: 'jfroula/jgi_meta_assem:1.0.2'
    }
}

# split paired end reads for spades (and generate some read stats)
task split {
    File infile 
    
    command
    {
        readlength.sh in=${infile} 1>| readlen.txt;

        reformat.sh overwrite=true in=${infile} out=read1.fasta out2=read2.fasta
    }
    output {
        File readlen = "readlen.txt"
        File read1 = "read1.fasta"
        File read2 = "read2.fasta"
    }
    runtime {
        docker: 'jfroula/jgi_meta_assem:1.0.2'
    }
}

# run MetaSpades
task spades {
    File read1
    File read2
    
    command
    {
        spades.py -m 2000 -o spades3 --only-assembler -k 33,55,77,99,127 --meta -t 32 -1 ${read1} -2 ${read2}
    }
    output {
        File scaffolds = "spades3/scaffolds.fasta"
    }
    runtime {
        cpu: 32
        time: "24:00:00"
        mem: "115G"
        cluster: "cori"
        poolname:  "annotation"
        docker: 'jfroula/jgi_meta_assem:1.0.2'
    }
}

# fungalrelease step will improve conteguity of assembly
task fungalrelease {
    File infile
    
    command
    {
        fungalrelease.sh -Xmx10g in=${infile} out=assembly.scaffolds.fasta outc=assembly.contigs.fasta agp=assembly.agp legend=assembly.scaffolds.legend mincontig=200 minscaf=200 sortscaffolds=t sortcontigs=t overwrite=t
    }
    output {
        File assy = "assembly.scaffolds.fasta"
    }
    runtime {
        docker: 'jfroula/jgi_meta_assem:1.0.2'
    }
}

# generate some assembly stats for the report
task stats {
    File infile
    
    command
    {
        stats.sh format=6 in=${infile} 1> bbstats.tsv 2> bbstats.tsv.e 

        stats.sh in=${infile} 1> bbstats.txt 2> bbstats.txt.e
    }
    output {
        File statstsv = "bbstats.tsv"
        File statstxt = "bbstats.txt"
    }
    runtime {
        docker: 'jfroula/jgi_meta_assem:1.0.2'
    }
}

# Map the filtered (but not bfc corrected) reads back to scaffold
task bbmap {
    File fastq
    File ref
    
    command
    {
        bbmap.sh nodisk=true interleaved=true ambiguous=random in=${fastq} ref=${ref} out=paired.mapped.bam covstats=paired.mapped.cov 

        samtools sort -@ 3 paired.mapped.bam -o paired.mapped_sorted.bam

        samtools index paired.mapped_sorted.bam
    }
    output {
        File bam = "paired.mapped.bam"
        File covstats = "paired.mapped.cov"
    }
    runtime {
        docker: 'jfroula/jgi_meta_assem:1.0.2'
    }
}


