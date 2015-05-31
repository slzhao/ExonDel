#!/usr/bin/perl
use strict;
use warnings;
use threads;
use threads::shared;
use File::Basename;
use Getopt::Long;
use File::Copy qw(copy);

use FindBin;
use lib $FindBin::Bin;
use HTML::Template;
use Report::Generate;

my $version = "1.05";

my %config;
my $current : shared;
my @resultOut : shared;

my $usage = "
Program: ExonDel.pl (A tool detecting internal exon deletions through exome sequencing data)
Version: $version

Usage:   perl ExonDel.pl -i bamfileList -o outputDirectory [-g geneList] [-c configFile] [-t threads]

Options:

	-i	input bam filelist     Required. Input file. It should be a file listing all analyzed bam files.
	-o	output directory       Required. Output directory for ExonDel result. If the directory doesn't exist, it would be created.
	-g	selected gene list     Optional. Genes interested. If specified, Only these genes will be analyzed by ExonDel.
	-c	config file            Optional. If not specified, ExonDel.cfg in ExonDel directory will be used.
	-t	threads                Optional. Threads used in analysis. The default value is 4. This parameter only valid for analysis of bam files.
	-ra re-analysis            Optional. If specified, the analysis will be performed again.
	
	-h	help                   Optional. Show this information.
	
For more information, please refer to the readme file in ExonDel directory. Or visit the ExonDel website at https://github.com/slzhao/ExonDel

";

my $commandline = "perl $0 "
  . join( " ", @ARGV )
  ;    #Output you input command in the report to reproduce you result
my (
	$maxThreads, $filelist, $resultDir, $configFile,
	$reAnalysis, $genelist, $showHelp
);
my %genes;

#our @log : shared;
my @log;

GetOptions(
	"t=i" => \$maxThreads,
	"i=s" => \$filelist,
	"g=s" => \$genelist,
	"o=s" => \$resultDir,
	"c=s" => \$configFile,
	"ra"  => \$reAnalysis,
	"h"   => \$showHelp,
);

if ($showHelp) { die "$usage"; }

if ( !defined $configFile ) {
	$configFile = dirname($0) . "/ExonDel.cfg";
}
open CFG, "<$configFile" or die "Can't read $configFile\n$!";
my $perlCfgSign = 0;
while (<CFG>) {
	s/\r|\n//g;
	if (/^#/) {
		next;
	}
	elsif (/^\[perl\]/) {
		$perlCfgSign = 1;
		next;
	}
	elsif (/^\[R\]/) {
		$perlCfgSign = 0;
		next;
	}
	if ($perlCfgSign) {
		my @lines = ( split /[=]/, $_ );
		if ( !defined $lines[1] ) {
			die(
"Invalid config file: $configFile The following line is not correct:\n$_\n$usage"
			);
		}
		else {
			$config{ $lines[0] } = $lines[1];
		}
	}
}

my $detectR = `which $config{"RBin"}`;
if ( $detectR eq '' ) {
	die
"Can't find R. Please install R or modify the RBin in ExonDel.cfg.\n$usage";
}
if ( !defined $filelist or !defined $resultDir ) {
	die("Input file (-i) and Output directory (-o) must be provided\n$usage");
}
elsif ( !( -s $filelist ) ) {
	die("Input file (-i) didn't exist or size equal 0\n$usage");
}

if ( !defined $maxThreads ) { $config{'maxThreads'} = 4; }
else {
	$config{'maxThreads'} = $maxThreads;
}
$config{'resultDir'} = $resultDir;
if ( !defined $reAnalysis ) {
	$config{'reAnalysis'} = 0;
}
else {
	$config{'reAnalysis'} = $reAnalysis;
}
if ( !( -e $resultDir ) ) {
	if ( mkdir $resultDir ) {
	}
	else {
		die "Can't make result dir. $!\n";
	}
}
else {
	if ( $config{'reAnalysis'} ) {
		unlink("$resultDir/genesPassQCwithGC.bed.depth.all");
	}
}

if ( defined $resultDir ) {
	open LOG, ">$resultDir/" . $config{'logFileName'}
	  or die "can't open log file. $!\n";

	#copy cfg file to result dir
	if ( !-s ("$resultDir/ExonDel.cfg") or $reAnalysis ) {
		copy $configFile, "$resultDir/ExonDel.cfg";
	}
}

$| = 1;

#############################
# 0. load genes interested
#############################
if ( defined $genelist and ( -s $genelist ) ) {
	open GENELIST, "<$genelist" or die "Can't open $genelist\n";
	while (<GENELIST>) {
		chomp;
		$genes{$_} = "";

		#		pInfo( "$_", \@log );
	}
	pInfo( "Only the genes in $genelist will be used", \@log );
	pInfo(
"GC adjustment will not be performed, and the constant cutoffs in config file will be used",
		\@log
	);
}
else {
	pInfo( "All genes will be used", \@log );
}

#############################
# 1. load capture kit ped and put into hash
#############################
my %bedDatabase;
if (    -s ("$resultDir/genesPassQCwithGC.bed")
	and -s ("$resultDir/genesPassQC.bed")
	and -s ("$resultDir/covered_percentage")
	and !$reAnalysis )
{
	pInfo( "$resultDir/genesPassQCwithGC.bed exists, skip load BED file",
		\@log );
}
else {
	pInfo( "Loading BED file", \@log );
	my $bedSize = &loadbed( $config{'bedfile'}, \%bedDatabase, 1 );
	pInfo( "Finish BED file (cover $bedSize base pairs)", \@log );
}

########################
# 2. load RefSeq Gene file
########################
my %resultHash;
if (    -s ("$resultDir/genesPassQCwithGC.bed")
	and -s ("$resultDir/genesPassQC.bed")
	and -s ("$resultDir/covered_percentage")
	and !$reAnalysis )
{
	pInfo( "$resultDir/genesPassQCwithGC.bed exists, skip load RefSeq Gene",
		\@log );
}
else {
	pInfo( "Loading RefSeq file", \@log );
	&generateNewRefseq( \%config, \%bedDatabase, \%resultHash );
	pInfo( "Finish RefSeq file", \@log );
}

########################
# 3. process fasta to caculate GC
########################
if ( -s ("$resultDir/genesPassQCwithGC.bed") and !$reAnalysis ) {
	pInfo(
"$resultDir/genesPassQCwithGC.bed exists, skip processing fasta and caculating GC content",
		\@log
	);
}
else {
	pInfo( "Loading fasta file and caculating GC content", \@log );
	&processFasta( \%config, \%resultHash );
	pInfo( "Finish fasta file", \@log );
}

########################
# 4. load bam files to caculate median depth for each exon
########################
if ( -s ("$resultDir/genesPassQCwithGC.bed.depth") and !$reAnalysis ) {
	pInfo(
"$resultDir/genesPassQCwithGC.bed.depth exists, skip caculating depth for each exon",
		\@log
	);
}
else {
	##load genesPassQCwithGC.bed file to get content for exon depth
	pInfo( "Loading genesPassQCwithGC.bed", \@log );
	my @newBed;
	open( NEWBED, "<$resultDir/genesPassQCwithGC.bed" ) or die $!;
	while (<NEWBED>) {
		chomp $_;
		push @newBed, $_;

	}
	close(NEWBED);

##processing bam list
	pInfo( "Processing bam files", \@log );
	&processFileList( \%config, $filelist, \@newBed );
	pInfo( "Finish bam file", \@log );

##write depth result
	open DEPTH, ">$resultDir/genesPassQCwithGC.bed.depth"
	  or die "Can't write!\n";
	foreach my $result (@resultOut) {
		print DEPTH "$result\n";
	}
	close DEPTH;
}

########################
# 5. run R codes to find deleted exons
########################
pInfo( "Analyzing Exon Deletion", \@log );
my $RBin    = $config{"RBin"};
my $Rsource = dirname($0) . "/rFunctions.R";
if ( defined $genelist ) {
	$genelist = "T";
}
else {
	$genelist = "F";
}
my $rResult = system(
"cat $Rsource | $RBin --vanilla --slave --args $resultDir $configFile $genelist 1>$resultDir/ExonDel.rLog 2>$resultDir/ExonDel.rLog"
);
if ( $rResult != 0 ) {
	pInfo( "Something wrong in running R. Please check the ExonDel.rLog file!",
		\@log );
}

########################
# 6. Gererate report
########################

#report
my $reportHash;
${$reportHash}{'COMMAND'}   = $commandline;
${$reportHash}{'CREATTIME'} = localtime;

my $table1 = &file2table( "$resultDir/exonDelsCutoffs.csv", '', 1 );
${$reportHash}{'MAKETABLE1'} = $table1;

my @filesContent;
opendir( DIR, "$resultDir" ) or die $!;
my $count = 0;
while ( my $file = readdir(DIR) ) {
	if ( $file =~ /exonDelsBy\d+.csv$/ ) {
		my $table1 =
		  &file2table( "$resultDir/$file", [ 0, 1, 2, 5, 7, 8, 9 ], 1, 4 );
		${$reportHash}{'MAKETABLE2'} = $table1;

		my @temp = @{$table1};
		shift @temp;
		$filesContent[$count]{'MAKETABLE2'} = \@temp;
		$filesContent[$count]{'FILENAME'}   = $file;

		$count++;
	}
}
${$reportHash}{'FILECONTENTLOOP'} = \@filesContent;

my $template =
  &build_template( dirname($0) . "/report_tmpl.tmpl", $reportHash );

open REPORT, ">$resultDir/ExonDelReport.html" or die "can't open $!\n";
print REPORT $template->output;

########################
# Ends
########################
pInfo( "Success!", \@log );
foreach my $log (@log) {
	print LOG $log;
}
close(LOG);

########################
# Subs
########################
sub processFasta {
	my ( $config, $resultHashRef ) = @_;
	my $fastaFile  = $config->{'reffa'};
	my $resultDir  = $config->{'resultDir'};
	my $reAnalysis = $config->{'reAnalysis'};

	open FASTA, "<$fastaFile" or die $!;
	open RESULT, ">$resultDir/genesPassQCwithGC.bed" or die $!;

	my $chr      = "";
	my $sequence = "";
	while (<FASTA>) {
		chomp;
		if (/^>/) {

			#do some thing here
			if ( $chr ne "" ) {
				$chr =~ s/chr//;
				&caculateGC( $chr, $sequence, $resultHashRef );
			}

			#end do something

			$chr      = $';
			$sequence = "";
		}
		else {
			$sequence .= $_;
		}
	}

	#do some thing again for last sequence here
	$chr =~ s/chr//;
	&caculateGC( $chr, $sequence, $resultHashRef );

	#end do something
	close(RESULT);
}

sub caculateGC {
	my ( $chr, $sequence, $resultHashRef ) = @_;

	if ( !exists $resultHashRef->{$chr} ) {
		return ();
	}
	my $exonCounts = scalar @{ $resultHashRef->{$chr} };
	pInfo( "Caculating GC content in $chr: $exonCounts exons", \@log );
	for ( my $x = 0 ; $x < $exonCounts ; $x++ ) {
		my ( $sub_start, $sub_end ) =
		  ( split( /\t/, $resultHashRef->{$chr}[$x] ) )[ ( 1, 2 ) ];
		$sub_start = $sub_start + 1;    #do we need to do this?
		my $sub_length   = $sub_end - $sub_start + 1;
		my $sub_sequence = substr( $sequence, $sub_start, $sub_length );
		my $number       = () = $sub_sequence =~ /[GC]/gi;
		my $ratio        = sprintf( "%.2f", $number / $sub_length );
		print RESULT "$resultHashRef->{$chr}[$x]\t$ratio\n";
	}
}

sub generateNewRefseq {
	my ( $config, $bedDatabaseRef, $resultHashRef ) = @_;

	my $refseq                  = $config->{'refseq'};
	my $resultDir               = $config->{'resultDir'};
	my $exon_bp_cover_threshold = $config->{'exon_bp_cover_threshold'};
	my $overall_exon_count_threshold =
	  $config->{'overall_exon_count_threshold'};

	open( REFSEQ, "<$refseq" ) or die "cannot find $refseq\n";
	open( COVER,  ">$resultDir/covered_percentage" ) or die $!;
	open( NEWBED, ">$resultDir/genesPassQC.bed" )    or die $!;
	my $header = <REFSEQ>;
	chomp $header;
	if ($header!~/^#bin	name	chrom	strand	txStart	txEnd	cdsStart	cdsEnd	exonCount	exonStarts	exonEnds/) {
		pInfo( "###WARNING###The format in GTF file may not be supported. Please check the descriptions for GTF in README file!",
			\@log );
	}
	print COVER $header . "\t" . "coveredBP\t" . "coveredExon\n";

	while (<REFSEQ>) {
		chomp $_;
		s/^chr//;
		my @tokens = split( /\t/, $_ );
		my $chr = $tokens[2];
		$chr =~ s/chr//;
		if ( !exists $bedDatabaseRef->{$chr} ) {
			next;
		}
		my $gene = $tokens[12];
		if ( %genes and !( exists $genes{$gene} ) ) {
			next;
		}
		my $TID       = $tokens[1];
		my $exonCount = $tokens[8];
		my $exonStart = $tokens[9];
		my $exonEnd   = $tokens[10];

		my $inbed        = 0;
		my @start        = split( ",", $exonStart );
		my @end          = split( ",", $exonEnd );
		my $gene_length  = 0;
		my $exon_covered = 0;

		for ( my $i = 0 ; $i < $exonCount ; $i++ ) {
			my $exon_inbed = 0;
			foreach my $pos ( $start[$i] .. $end[$i] ) {
				my $temp = vec( $bedDatabaseRef->{$chr}, $pos, 1 );
				$inbed      = $inbed + $temp;
				$exon_inbed = $exon_inbed + $temp;
			}
			my $exon_length = $end[$i] - $start[$i] + 1;
			$gene_length = $gene_length + $exon_length;
			my $exon_coverage = $exon_inbed / $exon_length;
			if ( $exon_coverage > $exon_bp_cover_threshold ) {
				$exon_covered++;
			}
		}
		my $covered_percentage_bp   = $inbed / $gene_length;
		my $covered_percentage_exon = $exon_covered / $exonCount;
		if ( $covered_percentage_exon >= $overall_exon_count_threshold ) {
			for ( my $i = 0 ; $i < $exonCount ; $i++ ) {
				print NEWBED "$chr\t$start[$i]\t$end[$i]\t$gene\t$TID\n";
				push(
					@{ $resultHashRef->{$chr} },
					"$chr\t$start[$i]\t$end[$i]\t$gene\t$TID"
				);
			}
		}
		print COVER "$_\t$covered_percentage_bp\t$covered_percentage_exon\n"
		  ;    #Done:chr vs chr needs to be taken care of
	}
	close(COVER);
	close(NEWBED);
}

sub pInfo {
	my ( $info, $refLog ) = @_;
	print "[", scalar(localtime), "] $info\n";
	push @{$refLog}, "[" . scalar(localtime) . "] $info\n";
}

sub loadbed {
	my ( $in, $ref, $header ) = @_;
	my $count = 0;
	open( IIN, $in ) or die $!;
	if ($header) {
		my $temp = <IIN>;
	}
	while (<IIN>) {
		s/\r|\n//g;
		my @line = split "\t";
		if ( %genes and defined $line[3] ) {
			my $selectThisGene = 0;
			foreach my $gene ( split( "\\|", $line[3] ) ) {
				if ( exists $genes{$gene} ) {
					$selectThisGene = 1;
					last;
				}
			}
			if ( $selectThisGene == 0 ) { next; }
		}
		my ( $chr, $start, $end ) = @line;
		$chr =~ s/chr//;
		if ( exists $ref->{$chr} ) {
		}
		else {
			$ref->{$chr} = "";
		}
		foreach ( my $i = $start + 1 ; $i <= $end ; $i++ ) {
			vec( $ref->{$chr}, $i, 1 ) = 1;    #1 in bed
			$count++;
		}
	}
	close IIN;
	return ($count);
}

sub processFileList {
	my ( $config, $filelistFile, $newBedRef ) = @_;
	my $maxThreads = $config->{'maxThreads'};

	my @fileList;                              #get file list
	open( FILELIST, $filelistFile ) or die $!;
	while ( my $f = <FILELIST> ) {
		$f =~ s/\r|\n//g;
		my $fileName = ( split( "\t", $f ) )[0];
		if ( !( -e $fileName ) ) {
			pInfo( "$fileName doesn't exist", \@log );
			next;
		}
		push @fileList, $f;
	}
	close(FILELIST);

	my @threads;    #open threads and get results
	$current = 0;
	foreach my $x ( 1 .. $maxThreads ) {
		push @threads,
		  threads->new( \&bamProcess, $x, \@fileList, $config, $newBedRef );
	}
	foreach my $thread (@threads) {
		my $threadNum = $thread->join;
		pInfo( "Thread $threadNum finished", \@log );
	}
}

sub bamProcess {
	my ( $threadNum, $fileListRef, $config, $newBedRef ) = @_;
	pInfo( "Thread $threadNum stared", \@log );
	while (1) {
		my $file;
		my $current_temp;
		{
			lock $current;
			$current_temp = $current;
			++$current;
		}
		return $threadNum unless $current_temp < @{$fileListRef};
		$file = ${$fileListRef}[$current_temp];
		pInfo( "Thread $threadNum processing $file", \@log );
		my $result = &getDepthBam( $file, $config, $newBedRef );

		#return result here
		{
			lock @resultOut;
			$resultOut[$current_temp] = join "\t", ( @{$result} );
		}
	}
}

sub getDepthBam {
	my ( $file, $config, $newBedRef ) = @_;
	my $baseQ       = $config->{'baseQ'};
	my $mapQ        = $config->{'mapQ'};
	my $samtoolsBin = $config->{'samtoolsBin'};
	my $resultDir   = $config->{'resultDir'};

	my @fileLable = ( split /\t/, $file );
	my $fileName  = $fileLable[0];
	my $label     = $fileName;
	if ( defined $fileLable[1] ) {
		$label = $fileLable[1];
	}
	my @sampleDepth = ();
	push @sampleDepth, $label;

	open( DEPTH,
"$samtoolsBin depth -q $baseQ -Q $mapQ -b $resultDir/genesPassQCwithGC.bed $fileName |"
	) or die $!;
	my %bamPosDepth = ();
	while (<DEPTH>) {
		chomp;
		my ( $chr, $pos, $dp ) = split( "\t", $_ );
		$chr =~ s/chr//;
		my $id = $chr . "_" . $pos;
		$bamPosDepth{$id} = $dp;
	}
	close(DEPTH);

	foreach my $bedLine ( @{$newBedRef} ) {
		my ( $chr, $start, $end ) = ( split( "\t", $bedLine ) )[ ( 0, 1, 2 ) ];
		my @all_depth = ();
		foreach my $pos ( $start .. $end ) {
			my $id = $chr . "_" . $pos;
			if ( exists( $bamPosDepth{$id} ) ) {
				push @all_depth, $bamPosDepth{$id};
			}
		}
		my $median_depth = &median(@all_depth);
		push @sampleDepth, $median_depth;
	}
	return ( \@sampleDepth );
}

sub median {
	my @data = sort { $a <=> $b; } @_;
	my $length_data = @data;
	if ( $length_data == 0 ) {
		return (0);
	}
	my $mid_value;
	if ( $length_data % 2 ) {
		my $mid_no = ( $length_data + 1 ) / 2 - 1;
		$mid_value = $data[$mid_no];
	}
	else {
		my $mid_no = $length_data / 2 - 1;
		$mid_value = ( $data[$mid_no] + $data[ $mid_no + 1 ] ) / 2;
	}
	return ($mid_value);
}
