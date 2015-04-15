package Report::Generate;

use strict;
use warnings;

use Exporter;
use Scalar::Util qw(looks_like_number);

our @ISA    = qw(Exporter);
our @EXPORT = qw(build_template file2table);

my $VERSION='0.01';

1;


sub build_template {
	my $templateName = $_[0];
	my %hash         = %{ $_[1] };

	my $headEnd    = 0;
	my $summaryTop = '<div class="summary">
    <h2>Table of Contents</h2>
        <ul>';
	my $summaryBottom = '        </ul>
</div>';
	my @head;
	my @content;
	my @summary;
	open TEMP, "<$templateName" or die "can't open $templateName!";

	while (<TEMP>) {
		chomp;
		if ( $headEnd == 0 ) {
			push @head, $_;
		}
		else {
			push @content, $_;
			if (/TMPL_LOOP NAME=(MAKETABLE\d+)/) {
				if ( exists $hash{$1} ) {
#					print "${ $hash{$1} }[0]\n";
					foreach my $tableTitle ( @{ ${ $hash{$1} }[0] } ) {
						if ($tableTitle=~/Distance$/) {
							push @content,
						    '      <td align="center"><img src=<!-- TMPL_VAR NAME=\''
						  . $tableTitle
						  . '\' -->></td>';
						} else {
							push @content,
						    '      <td align="center"><!-- TMPL_VAR NAME=\''
						  . $tableTitle
						  . '\' --></td>';
						}

					}
					shift @{ $hash{$1} };
				}
			}
		}
		if (/<\/h1>/) {
			$headEnd = 1;
		}
		if (/<div><h2 id="(\w+)">([\s\w]+)/) {
			push @summary, '<li><a href=#' . $1 . '>' . $2 . '</a></li>';
		}
	}
	open TEMPRESULT, ">$templateName.temp" or die "can't write $!";
	print TEMPRESULT ( join( "\n", @head ) );
	print TEMPRESULT $summaryTop . "\n";
	print TEMPRESULT ( join( "\n", @summary ) );
	print TEMPRESULT $summaryBottom . "\n";
	print TEMPRESULT ( join( "\n", @content ) );
	close(TEMPRESULT);

	my $template = HTML::Template->new(
		filename          => "$templateName.temp",
		loop_context_vars => 1,
		die_on_bad_params => 0,
		filter            => \&cstmrow_filter
	);
	foreach my $key ( keys %hash ) {
		$template->param( $key => $hash{$key} );
	}
#	unlink "$templateName.temp";
	return ($template);
}

sub cstmrow_filter {
	my $text_ref = shift;

	#no first, end with no space, don't match if with first
	$$text_ref =~ s/<CSTM_ROW\s+EVEN=(.+)\s+ODD=(\S+)\s*>
                 /<TMPL_IF NAME=__odd__>
                    <tr class="$2">
                  <TMPL_ELSE>
                    <tr class="$1">
                  <\/TMPL_IF>
                 /gx;

	#with first
	$$text_ref =~ s/<CSTM_ROW\s+EVEN=(.+)\s+ODD=(.+)\s+FIRST=(.+)\s*>
                 /<TMPL_IF NAME=__first__>
                 <tr class="$3">
                  <TMPL_ELSE>
                 <TMPL_IF NAME=__odd__>
                    <tr class="$1">
                  <TMPL_ELSE>
                    <tr class="$2">
                  <\/TMPL_IF>
                  <\/TMPL_IF>
                 /gx;
}

#Please note all " were deleted
sub file2table {
	my $file        = $_[0];
	my $selectedColsRef = $_[1];
	my $recordTitle = $_[2];
	my $maxLineRecored = $_[3];

	my $lineRecored = 0;
	if (!defined $maxLineRecored) {
		$maxLineRecored=100;
	}
	my $rows;
	my @title;
	my $splitSign="\t";
	if ($file=~/.csv$/) {
		$splitSign=",";
	}
	
	open READ, "<$file" or die "can't find $file\n";
	while (<READ>) {
		chomp;
		s/"//g;   #all " were deleted in case of csv
		my @content = ( split /$splitSign/, $_ );
		if ( $lineRecored == 0 ) {
			if (defined($recordTitle) and ($recordTitle ne 0) and ($recordTitle ne 1)) {
				@title=@{$recordTitle};
			}
			elsif ( defined( $selectedColsRef ) and $selectedColsRef ne "" ) {
				@title = @content[ @{ $selectedColsRef } ];
			}
			else {
				@title = @content;
			}
			if (defined($recordTitle) and $recordTitle ne 0) {
				push @{$rows}, \@title;
			}	
		}
		my $temp = {};
		if ( defined( $selectedColsRef ) and $selectedColsRef ne "" ) {
			my @temp=&arry2Number(@content[ @{ $selectedColsRef } ]);
			@$temp{@title} = @temp;
		}
		else {
			my @temp=&arry2Number(@content);
			@$temp{@title} = @temp;
		}
		push @{$rows}, $temp;
		$lineRecored++;
		if ($lineRecored>=$maxLineRecored) {
			close(READ);
			return ($rows);
		}
	}
	close(READ);
	return ($rows);
}


sub arry2Number {
	my @data = @_;
	my @result;
	foreach my $data (@data) {
		if ( looks_like_number($data) ) {
			my $format;
			if ( $data =~ /\./ ) {
				$format = "%.2f";
			}
			else {
				$format = "%d";
			}
			my $temp = sprintf( $format, $data );
			push @result, $temp;
		}
		else {
			push @result, $data;
		}
	}
	return (@result);
}
