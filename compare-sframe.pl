#!/usr/bin/perl
# Compare two directories with otherwise identical binaries
# where 'new' has .sframe sections.
use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use Class::CSV;

my %results       = ();

my $BASELINE_PATH = "baseline/";
my $NEW_PATH      = "new/";
my $VERBOSE       = 0;
my $CSV           = "";

GetOptions (
		'baseline=s' => \$BASELINE_PATH,
		'new=s'      => \$NEW_PATH,
		'verbose'    => \$VERBOSE,
		'csv=s'      => \$CSV,
) || die "Failed to parse arguments: $!";

$VERBOSE or $CSV || die "Need to specify at least one-of: verbose or csv. Exiting.";

sub gather_binary_list {
	# Scrape the VDB for packages with NEEDED (-> ELF we want to inspect)
	# Return an array of absolute paths to such binaries
	my @binaries = ();
	while (my $needed_path = glob("$BASELINE_PATH/var/db/pkg/*/*/NEEDED")) {
		open (my $needed_file, "<", $needed_path) || die "Couldn't open $needed_path: $!";
		while (my $line = readline $needed_file) {
			push (@binaries, (split(' ', $line))[0]);
		}
		close ($needed_file) || die "Couldn't close $needed_path: $!";
	}
	return @binaries;
}

sub analyse_binary {
	my $file = shift;

	print "Processing $file\n" if $VERBOSE;

	# If the
	if ( ! -f "baseline/$file" || ! -f "new/$file") {
		# This should only happen for binutils which got rebuilt
		# on the wrong side of midnight in one chroot.
		print "Skipping $file because missing on one side\n" if $VERBOSE;
		return;
	}

	open my $pipe, '-|', 'size', '-A', "baseline/$file", "new/$file" or die "Failed to run size: $!";

	# baseline or new
	my $type;
	while (my $line = readline $pipe) {
		# Header line indicating a new file we're size(1)-ing
		if ($line =~ /^(baseline|new)/) {
			$type = $1;
			next;
		}

		# .section 
		if ($line =~ /^\./) {
			my @fields  = split(' ', $line);
			my $section = $fields[0];
			my $size    = $fields[1];

			$results{$file}{$type}{'section'}{$section} = $size;
		} elsif ($line =~ /Total/) {
			my @fields = split(' ', $line);
			my $total  = $fields[1];
			$results{$file}{$type}{'total'} = $total;
		}
	}
	close $pipe || die "size already gone: $!";
	
	my $eh_size    = $results{$file}{'new'}{'section'}{'.eh_frame'}     // 0;
	$eh_size      += $results{$file}{'new'}{'section'}{'.eh_frame_hdr'} // 0;
	my $sf_size    = $results{$file}{'new'}{'section'}{'.sframe'}       // 0;
	if ($eh_size == 0 || $sf_size == 0) {
		print "\tNo .sframe, punting\n" if $VERBOSE;
		delete $results{$file};
		return;
	}

	my $sfeh_delta = $sf_size - $eh_size;
	my $sfeh_rat   = sprintf "%0.5f", ($eh_size / $sf_size);
	my $sfeh_pct   = $sfeh_rat * 100;

	my $t_delta    = $results{$file}{'new'}{'total'} - $results{$file}{'baseline'}{'total'};
	my $t_pct      = sprintf "%0.0f", (($t_delta / $results{$file}{'baseline'}{'total'}) * 100);

	# Stash the ratio between SFrames and EH Frame as we want to
	# use it in our CSV.
	$results{$file}{'sum'}{'sframe_ehframe_ratio'} = $sfeh_rat;

	if ($VERBOSE) {
		printf "Processed %s\n", $file;
		printf "\tOld total: %s\n", $results{$file}{'baseline'}{'total'};
		printf "\tNew total: %s\n", $results{$file}{'new'}{'total'};
		printf "\tTotal delta: %s (%s%%)\n", $t_delta, $t_pct;
		printf "\tSFrame: %s\n", $results{$file}{'new'}{'section'}{'.sframe'};
		printf "\tEH Frame: %s\n", $eh_size;
		printf "\tSFrame size / EH Frame size: %s (%s%%) (< 1 means SFrames were larger)\n", $sfeh_rat, $sfeh_pct;
	}
}

sub write_results_csv {
	my $csv = Class::CSV->new(
  		fields         => [qw/binary total_size sframe_size ehframe_size sframe_ehframe_ratio/]
	);

	foreach my $binary (keys %results) {
		$csv->add_line({
			binary               => $binary,
			total_size           => $results{$binary}{'new'}{'total'},
			sframe_size          => $results{$binary}{'new'}{'section'}{'.sframe'},
			ehframe_size         => $results{$binary}{'new'}{'section'}{'.eh_frame'} +
									$results{$binary}{'new'}{'section'}{'.eh_frame_hdr'},
			sframe_ehframe_ratio => $results{$binary}{'sum'}{'sframe_ehframe_ratio'},
		});
	}

	open (my $fh, ">", $CSV) || die "Failed to open $CSV: $!";
	$csv->print($fh);
	print $fh $csv->string();
	close ($fh) || die "Failed to close $CSV: $!";
}

my @binaries = gather_binary_list ();
#analyse_binary ("bin/bash");
for (@binaries) {
	analyse_binary ($_);
}

write_results_csv () if $CSV;

#print Dumper(%results);
