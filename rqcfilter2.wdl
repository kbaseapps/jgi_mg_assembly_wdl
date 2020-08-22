workflow rqcfilter2 {
    Array[File] input_files

    call rqcfilter {
    	 input: reads_files=input_files
    }
    output {
        Array[File] final_filtered = rqcfilter.outrqcfilter
    }
}

task rqcfilter{
    Array[File] reads_files

    String single = if (length(reads_files) == 1 ) then "1" else "0"

    String rqcfilter_input = "rqcfilter.input.fastq.gz"
    String rqcfilter_output = "rqcfilter.output.fastq.gz"    

     String filename_readlen="readlen.txt"
     String filename_outlog="stdout.log"
     String filename_errlog="stderr.log"

     String java="-Xmx20g"
     String dollar="$"

    command {
        if [ ${single} == 0 ]
	then
	    cat ${sep = " " reads_files } > ${rqcfilter_input}
	else
	    ln ${reads_files[0]} ./${rqcfilter_input}
	fi
	touch ${filename_readlen}
	readlength.sh -Xmx1g in=${rqcfilter_input} out=${filename_readlen} overwrite 
        rqcfilter2.sh jni=t in=${rqcfilter_input} \
            path=filter rna=f trimfragadapter=t qtrim=r trimq=0 maxns=3 maq=3 minlen=51 \
            mlf=0.33 phix=t removehuman=t removedog=t removecat=t removemouse=t khist=t \
            removemicrobes=t sketch kapa=t clumpify=t tmpdir= barcodefilter=f trimpolyg=5 usejni=f \
	    rqcfilterdata=/refdata/RQCFilterData \
            out=../${rqcfilter_output} 1> ${filename_outlog} 2> ${filename_errlog}
     }
     output {
     		Array[File] outrqcfilter = glob(rqcfilter_output)
            File outreadlen = filename_readlen
            File stdout = filename_outlog
            File stderr = filename_errlog

     }
     runtime {
         docker: 'bryce911/bbtools:38.44'
     }

}
