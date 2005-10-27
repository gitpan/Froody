package Module::Build::Kwalitee::Util;
use strict;
use warnings;
use base qw(Exporter);
use File::Find::Rule;

our @EXPORT = qw( &module_files &pod_files &test_files &path_to_package );

=head1 NAME

Module::Build::Kwalitee::Util - find modules & programs to test

=head1 SYNOPSIS

  use Module::Build::Kwalitee::Util;
  my @module_files = module_files();
  my @pod_files = pod_files();
  my @test_files = test_files();
  my $package = path_to_package($files);
  
=head1 DESCRIPTION

=over

=item module_files()

Returns a list of all modules found.

=item pod_files()

Returns a list of all pod files found.

=item test_files()

Returns a list of all test files found.

=cut

sub module_files { _files('*.pm') }

sub pod_files { _files('*.pod') }

sub test_files { _files('*.t', 't') }

=item path_to_package( path )

Convert a filesystem path to a package name

=cut

sub path_to_package ($) {
  for (shift) {
    s|.*lib/||;
    s|/|::|g;
    s|\.pm$||;
    return $_;
  }
}

sub _files($;$) {
  my ($glob, $dir) = @_;
  File::Find::Rule->file()->name($glob)->in($dir || 'lib');
}

1;
