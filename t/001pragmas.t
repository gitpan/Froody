#!/usr/bin/perl
#
# Make sure every module contains 'use strict' and 'use warnings'

use strict;
use warnings;

use Test::More;
use Module::Build::Kwalitee::Util;

my @files = module_files();

plan tests => 2 * scalar @files;

foreach my $file ( @files ) {
  my $fh;
  local $/;
  open $fh, $file;
  my $file = <$fh>;
  ok($file =~ qr/use\s+strict\b/, "$file using strict");
  ok($file =~ qr/use\s+warnings\b/, "$file using warnings");
}
