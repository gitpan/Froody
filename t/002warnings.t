#!/usr/bin/perl
#
# Make sure every module contains 'use warnings'

use strict;
use warnings;

use Test::More;
eval "use File::Find::Rule; 1;"
	or plan skip_all => 'File::Find::Rule not installed';

my @classes = File::Find::Rule->file()->name('[A-Z]*.pm')->in('lib');

plan tests => scalar @classes;

foreach my $class ( @classes ) {
  my $fh;
  local $/ = undef;
  open $fh, $class;
  my $file = <$fh>;
  ok($file =~ qr/use\s+warnings/, $class);
}
