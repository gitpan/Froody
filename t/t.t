#!/usr/bin/perl

#######################################################################
# This test checks that all tests have blocks like this that
# explain what they do
#######################################################################

use strict;
use warnings;

use FindBin;
use File::Spec::Functions;

my @files;

BEGIN {
  my $path = catfile($FindBin::Bin,"*.t");
  @files = grep {!/00/ } glob($path);
}

use Test::More tests => scalar(@files);

FISH:
foreach my $filename (@files)
{
  open my $fh, "<", $filename
    or die "Can't open '$filename' for reading!\n";

  while (<$fh>)
    { last if /\s*##########################/; }
  
  # did we either not find the start of the comment block or
  # find that the comment block starts too far down the file?  FAIL!
  if ($. > 8 or eof $fh) {
    fail($filename);
    next;
  }
  
  while (<$fh>)
  { 
    # found closing ########## - we got the comment - PASS!
    if (/\s*###########################/)
    {
      pass($filename);
      next FISH;
    }
    
    # comment ended without a ############ - FAIL!
    if (!/^\s*#/)
    {
      fail($filename);
      next FISH;
    }
  }
  
  # reached end of file without ending comment - FAIL!
  fail($filename);
}