Table of Content
================
 * [Introduction](#Introduction)
 * [Download](#download)
 * [Change log](#Change)
  * [Release candidate (RC) version 1.2](#RC12)
  * [Release candidate (RC) version 1.1](#RC11)
  * [Release candidate (RC) version 1.0](#RC10)
 * [Prerequisites](#Prerequisites)
  * [Install required perl packages](#irpp)
  * [Install required software](#irs)
  * [Download required database](#drr)
 * [Usage](#Usage)
 * [Parameters] (#pa)
  * [Input file](#if)
  * [Gene file](#gf)
  * [Config file](#cf)
 * [Example](#Example)
  * [Download example data](#ded)
  * [Example usage](#eu)
 * [Results](#Results)


<a name="Introduction"/>
# Introduction #

Exome sequencing is one of the most cost efficient sequencing approaches for conducting genome research on coding regions. The primary applications of exome sequencing include detection of single nucleotide polymorphisms, somatic mutations, small indels, and copy number variations. There are also some less obvious data mining opportunities through exome sequencing data such as extraction of mitochondria, and virus. Another less explored genomic aberration that can be detected through exome sequencing is internal exon deletions (IEDs).  Exon deletion is the deletion of one or more consecutive exons in a gene.

IEDs have biological importance in cancer and may remove important regulatory mechanisms or protein-protein interactions. Given the large amount of publicly available exome sequencing data accumulated over the last few years, a method that can efficiently detect such deletions would benefit the medical research community greatly and provide a means to rapidly find new internal deletion candidates. Thus, we designed ExonDel, a tool aimed at detecting IEDs through exome sequencing data. 

ExonDel is written with Perl and R and is freely available for public use. It can be downloaded from [ExonDel website on github](https://github.com/slzhao/ExonDel).

<a name="Download"/>
# Download #

You can directly download ExonDel from [github](https://github.com/slzhao/ExonDel) by the following commands (If git has already been installed in your computer).

	#The source codes of ExonDel software will be downloaded to your current directory
	git clone https://github.com/slzhao/ExonDel.git

Or you could also download the zip file of ExonDel from [github](https://github.com/slzhao/ExonDel/archive/master.zip).

	#The zip file of ExonDel software will be downloaded to your current directory
	wget https://github.com/slzhao/ExonDel/archive/master.zip -O exonDel.zip
	#A directory named ExonDel-master will be generated and the source codes will be extracted there
    unzip exonDel.zip

<a name="Change"/>
# Change log #

<a name="RC12">
## Release candidate (RC) version 1.2 on December 15, 2013
Release candidate version 1.2 for test
 * Documents were improved;
 * Some functions were modified;

<a name="RC11">
## Release candidate (RC) version 1.1 on November 27, 2013
Release candidate version 1.1 for test
 * Documents were improved;
 * Some bugs were fixed;
 * Example files were provided;

<a name="RC10">
## Release candidate (RC) version 1.0 on November 11, 2013
Release candidate version 1.0 for test

<a name="Prerequisites"/>
# Prerequisites #
<a name="irpp"/>
## Install Perl and required Perl packages ##

Perl is a highly capable, widely used, feature-rich programming language. It could be downloaded [Perl website](http://www.perl.org/get.html).

If Perl has already been installed on your computer, no other Perl module is needed to run ExonDel in most cases. And you can run the following commands to make sure all the required modules have been installed.

	#go the the directory where your ExonDel software is.
	#And test whether all the required modules have been installed.
	bash test.modules

The successful output would look like this

    ok   File::Basename
    ok   File::Copy
    ok   Getopt::Long
    ok   threads
    ok   threads::shared

Otherwise, for example, if File::Basename package was missing, it may look like this

    fail   File::Basename
    ok   File::Copy
    ok   Getopt::Long
    ok   threads
    ok   threads::shared

Then you need to install the missing packages from [CPAN](http://www.cpan.org/). A program was also provided to make the package installation more convenient.
	
	#if File::Basename was missing
	bash install.modules File::Basename

<a name="irs"/>
## Install required software ##

### R ###

R is a free software environment for statistical computing and graphics. It could be downloaded from [R website](http://www.r-project.org/).

After you install R and add R bin file to your Path, the software can find and use R automatically. Or you can modify the ExonDel.cfg file in the software directory and tell the program where the R is on your computer. Here is the line you need to modify.

	#where the R bin file is
    RBin=R

### samtools ###

SAM Tools provide various utilities for manipulating alignments in the SAM format, including sorting, merging, indexing and generating alignments in a per-position format. It could be downloaded from [SAM Tools website](http://samtools.sourceforge.net/).

After you install SAMtools and add SAMtools bin file to your Path, the software can find and use SAMtools automatically. Or you can modify the ExonDel.cfg file in the software directory and tell the program where the SAMtools is on your computer. Here is the line you need to modify.

	#where the SAMtools bin file is
    samtoolsBin=samtools

<a name="drr"/>
## Download required reference files##
ExonDel needs a .gtf (refseq) file, a .bed file and a .fa file as reference files. The position annotation and GC content for each exon were exported from them. The chromosomes and positions information in these files should be exactly same with the bam files (for example, chromosome 1 can't be represented as chr1 in one file but 1 in another file). The .gtf and .bed files could be downloaded at [UCSC table browser](http://genome.ucsc.edu/cgi-bin/hgTables?command=start). The format of these files were: 

	#bed file:
	#Column1	    Column2         Column3
	Chromosome	StartPosition	EndPosition
	
	#bed file and if you want select some genes:
	#Column1	    Column2         Column3     Column4
	Chromosome	StartPosition	EndPosition     Gene

	#gtf file:
	#Column1   	...	Column3	Column4	        Column5	...
	Chromosome	...	exon	StartPosition	EndPosition	...

The .fa files could be downloaded at [UCSC website](http://hgdownload.cse.ucsc.edu/goldenPath/hg19/bigZips/). As UCSC does not provide the full .fa file, you may needed to download chromFa.tar.gz and combine the files in different chromosome into one .fa file, or download hg19.2bit and convert the 2bit file to .fa file by twoBitToFa.

**After the .gtf (refseq) file, .bed file and .fa file were downloaded, you also need to modify the config file so that ExonDel can find them. See [config file](#cf) for more information.**

<a name="Usage"/>
# Usage #

The usage of ExonDel software could be:

    perl ExonDel.pl -i bamfileList -o outputDirectory [-g geneList] [-c configFile] [-t threads]

	-i	input bam filelist     Required. Input file. It should be a file listing all analyzed bam files and their paths.
	-o	output directory       Required. Output directory for ExonDel result. If the directory doesn't exist, it would be created.
	-g	selected gene list     Optional. Genes interested. If specified, Only these genes will be analyzed by ExonDel.
	-c	config file            Optional. If not specified, ExonDel.cfg in ExonDel directory will be used.
	-t	threads                Optional. Threads used in analysis. The default value is 4. This parameter only valid for analysis of bam files.
	-ra re-analysis            Optional. If specified, the analysis will be performed again.
	-h	help                   Optional. Show help information.

<a name="pa"/>
# Parameters #

<a name="if"/>
## Input file ##
The input file should be a file listing all analyzed bam files. It also supports label for each file listed (The labels are optional). The label should follow the file and separated by a Tab. The labels will be used in the report instead of the file names, so the report will be much easier to understand. An example was listed here:

	#An example of input file. The labels are optional.
	#Column1 (bam files)    Column2(labels)
	sample1File.bam    labelForSample1
	Sample2File.bam    labelForSample2

<a name="gf"/>
## gene list file 
ExonDel will perform analysis for all genes by default. But the user can specify some genes in gene list file, so that ExonDel will restrict in these genes, which will be much faster.

<a name="cf"/>
## config file 
The config file contains all parameters for ExonDel to execute, such as the path to bed file, gtf file, the cutoff for detecting deletions. The default config file ExonDel.cfg located in the ExonDel directory. And there are several comment lines which start with "#" and describe the usage of the following line. 

**The user need to modify the following lines in ExonDel.cfg to ensure ExonDel could find the .gtf, .bed, and .fa files.**

    #reference .bed file
    bedfile=
    #reference .gtf file
    refseq=
    #reference .fa file
    reffa=

if these files were example.bed, example.gtf, hg19.fa and located in /reference/, then the user need to modify these lines into:

    #reference .bed file
    bedfile=/reference/example.bed
    #reference .gtf file
    refseq=/reference/example.gtf
    #reference .fa file
    reffa=/reference/hg19.fa

<a name="Example"/>
# Example #

The example files can be downloaded from [ExonDel website on sourceforge](http://sourceforge.net/projects/exondel/files/).

You need to download and extract it to a directory. Then the example code for running ExonDel with given example data set could be:

<a name="ded"/>
## download example data ##
	#download and extract example data into exampleDir
	mkdir exampleDir	
	cd exampleDir
	wget http://sourceforge.net/projects/exondel/files/example.tar.gz/download
	tar zxvf example.tar.gz
	ls

<a name="ue"/>
## example usage ##

We can use all genes to do exon deletions detection.

	#assume ExonDel.pl in the directory ExonDel-master/, examples in exampleDir
	cd exampleDir
	perl path_to/ExonDel-master/ExonDel.pl -i exampleBams.list -c ExonDel.example.cfg -o ./result1
	
You should standard out message as below:

	#[Fri Dec 20 10:28:00 2013] All genes will be used
	#[Fri Dec 20 10:28:00 2013] Loading BED file
	#[Fri Dec 20 10:28:00 2013] Finish BED file (cover 18683 base pairs)
	#[Fri Dec 20 10:28:00 2013] Loading RefSeq file
	#[Fri Dec 20 10:28:00 2013] Finish RefSeq file
	#[Fri Dec 20 10:28:00 2013] Loading fasta file and caculating GC content
	#[Fri Dec 20 10:28:02 2013] Caculating GC content in 5: 43 exons
	#[Fri Dec 20 10:28:04 2013] Caculating GC content in 6: 24 exons
	#[Fri Dec 20 10:28:05 2013] Caculating GC content in 13: 35 exons
	#[Fri Dec 20 10:28:05 2013] Finish fasta file
	#[Fri Dec 20 10:28:05 2013] Loading genesPassQCwithGC.bed
	#[Fri Dec 20 10:28:05 2013] Processing bam files
	#[Fri Dec 20 10:28:06 2013] Thread 1 stared
	#[Fri Dec 20 10:28:06 2013] Thread 1 processing example1.bam     example1
	#[Fri Dec 20 10:28:06 2013] Thread 1 processing example2.bam     example2
	#[Fri Dec 20 10:28:06 2013] Thread 1 processing example3.bam     example3
	#[Fri Dec 20 10:28:06 2013] Thread 2 stared
	#[Fri Dec 20 10:28:06 2013] Thread 2 processing example4.bam     example4
	#[Fri Dec 20 10:28:06 2013] Thread 3 stared
	#[Fri Dec 20 10:28:06 2013] Thread 4 stared
	#[Fri Dec 20 10:28:06 2013] Thread 1 finished
	#[Fri Dec 20 10:28:07 2013] Thread 2 finished
	#[Fri Dec 20 10:28:07 2013] Thread 3 finished
	#[Fri Dec 20 10:28:07 2013] Thread 4 finished
	#[Fri Dec 20 10:28:07 2013] Finish bam file
	#[Fri Dec 20 10:28:07 2013] Analyzing Exon Deletion
	#[Fri Dec 20 10:28:07 2013] Success!

Also we can just select some genes to do exon deletions detection.

    perl path_to/ExonDel-master/ExonDel.pl -i exampleBams.list -c ExonDel.example.cfg -g genelist.txt -o ./result2
    
You will see the standard out message as below:

	#[Fri Dec 20 10:34:34 2013] Only the genes in genelist.txt will be used
	#[Fri Dec 20 10:34:34 2013] GC adjustment will not be performed, and the constant cutoffs in config file will be used
	#[Fri Dec 20 10:34:34 2013] Loading BED file
	#[Fri Dec 20 10:34:34 2013] Finish BED file (cover 6655 base pairs)
	#[Fri Dec 20 10:34:34 2013] Loading RefSeq file
	#[Fri Dec 20 10:34:34 2013] Finish RefSeq file
	#[Fri Dec 20 10:34:34 2013] Loading fasta file and caculating GC content
	#[Fri Dec 20 10:34:38 2013] Caculating GC content in 6: 24 exons
	#[Fri Dec 20 10:34:39 2013] Caculating GC content in 13: 35 exons
	#[Fri Dec 20 10:34:39 2013] Finish fasta file
	#[Fri Dec 20 10:34:39 2013] Loading genesPassQCwithGC.bed
	#[Fri Dec 20 10:34:39 2013] Processing bam files
	#[Fri Dec 20 10:34:40 2013] Thread 1 stared
	#[Fri Dec 20 10:34:40 2013] Thread 1 processing example1.bam     example1
	#[Fri Dec 20 10:34:40 2013] Thread 1 processing example2.bam     example2
	#[Fri Dec 20 10:34:40 2013] Thread 1 processing example3.bam     example3
	#[Fri Dec 20 10:34:40 2013] Thread 2 stared
	#[Fri Dec 20 10:34:40 2013] Thread 2 processing example4.bam     example4
	#[Fri Dec 20 10:34:40 2013] Thread 3 stared
	#[Fri Dec 20 10:34:40 2013] Thread 4 stared
	#[Fri Dec 20 10:34:40 2013] Thread 1 finished
	#[Fri Dec 20 10:34:40 2013] Thread 2 finished
	#[Fri Dec 20 10:34:40 2013] Thread 3 finished
	#[Fri Dec 20 10:34:40 2013] Thread 4 finished
	#[Fri Dec 20 10:34:40 2013] Finish bam file
	#[Fri Dec 20 10:34:40 2013] Analyzing Exon Deletion
	#[Fri Dec 20 10:34:41 2013] Success!

<a name="Results"/>
# Results #
genesPassQCwithGC.bed.depth.all included the GC content and median depth for each exon. ExonDel  detectes exon deletions based on these information.

exonDelsBy1.csv to exonDelsBy9.csv included the deletions found by a moving-window with 1 to 9 exons.

exonDelsCutoffs.csv included the cutoffs for every bam file.

figures directory included some figures as examples for exon deletions found by different moving-windows.