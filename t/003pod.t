#!perl
use warnings;
use strict;

use Test::More;



use Test::More;
eval q(
	use File::Find::Rule;
	use Test::Pod;
	use Pod::Coverage::CountParents;
	1;
) or plan skip_all => 'Necessary modules not installed';

my @files = File::Find::Rule->file()->name('[A-Z]*.pm', '*.pod')->in('lib');

plan tests => ( scalar @files * 3 ) + 1;

my $total_coverage;
my $total_files;

for my $file (@files) {
  pod_file_ok( $file );

  SKIP: {
    skip "$file is not a module", 2 if $file =~ /pod$/;

    # read in the file and look for trustmes
    my $fh;
    open $fh, "<", $file
      or die "Can't read file $fh";
    my @trustme;
    while (<$fh>) {
      push @trustme, qr/^\Q$1\E$/ if (/^\s*#\s+(.*?) is documented\s*$/)
    }

    # work out the package that is
    my $package = $file;
    $package =~ s!.*lib/!!;
    $package =~ s!/!::!g;
    $package =~ s!\.pm$!!;

    # load the package
    my $pc = Pod::Coverage::CountParents->new(
      package => $package,
      trustme => [ @trustme, qr/db_(in|de)flate/ ]
    );

    # check if we got coverage or not
    my $coverage = $pc->coverage;
    if (defined $coverage) {
      ok( $coverage, "$file has POD" );
      ok( $coverage > 0.90, "$file has ".($coverage * 100)."% coverage > 90%" );
      if ($ENV{SHOW_NAKED}) { diag(map {"Naked sub: $_\n"} $pc->naked) }

      $total_coverage += $coverage;
      $total_files++;
    }
    else {
      ok( !($pc->why_unrated eq "couldn't find pod"), "$file has POD" );
      SKIP: {
        skip "$file has no subs", 1 if 1;
        # missing subs need no docs
      }
    }
  }
}

#
my $average_coverage = $total_coverage / $total_files;
ok( $average_coverage > 0.98,
  "Average POD coverage ". ( $average_coverage * 100 )."% > 98%" );
