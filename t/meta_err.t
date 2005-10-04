#!/usr/bin/perl

####################################################################
# This test checks that we haven't got any nasty looking errors
# in the files (die, old style Froody::Error, and that all errors
# that we throw are defined in Froody::Error::Standard.pod)
####################################################################

use strict;
use warnings;

use File::Spec::Functions;
use FindBin;

my @files;

BEGIN {
  use File::Find::Rule;
  @files = File::Find::Rule->file()->name('[A-Z]*.pm') # , '*.pod')
                                   ->in(catdir($FindBin::Bin, updir,'lib'));
}

use Test::More tests => ((@files-1) * 3);

# load all the error names documented in Froody::Error::Standard
open my $fh, "<", catfile($FindBin::Bin, updir,'lib',"Froody","Error","Standard.pod")
  or die "Can't open Froody::Error::Standard.pod: $!";
my %errs;
while (<$fh>) { /^=item ([a-z.]+)/ && ($errs{ $1 } = 1) }

# check each of the files
foreach my $filename (@files)
{
  local $/;
  open $fh, "<", $filename
    or die "Eeeek! Can't open '$filename': $!";
  my $file = <$fh>;
  close $fh;

  # we don't look at ourselves
  next if $file =~ /package Froody::Error;/;
    
  # no oldstyle errors
  ok($file !~ /Froody::Error::/, "no oldstyle errors in $filename");
  
  # any old school Froody Errors in there that we don't know about?
  my $thingy = "";
  while ($file =~ /Froody::Error->throw\(\s*['"]([^'"]+)/sg)
   { $thingy .= "$1 " unless $errs{ $1 } }
  ok(!$thingy, "$filename contains known errors")
    or diag("unknown errors: $thingy");

  # any die in a class that's not okay to have it?
  ok($file !~ /\bdie\s*["']/, "no dies in $filename");
}
