#!perl
use warnings;
use strict;
use Test::More;
use File::Find::Rule;
use File::Spec::Functions;

BEGIN {
  # This is in a BEGIN block because otherwise perl will issue a warning
  # when we use $Module::CoreList::version below.
  eval q{
    use ExtUtils::Installed;
    use Module::CoreList;
    use Module::Distname;
    use PPI;
    use version;
    1;
  } or plan skip_all => 'required modules not installed';
}

my @modules = File::Find::Rule->file()->name('*.pm')->in('lib');
my (@scripts, $requires, $recommends, $build_requires);
eval q{
  use Module::Build;
  Module::Build->current->script_files;
  @scripts = keys %{ Module::Build->current->script_files || {}};
  $requires = Module::Build->current->requires;
  $recommends = Module::Build->current->recommends;
  $build_requires = Module::Build->current->build_requires;
} or plan skip_all => "Cannot get requirements: $@"; 

push @scripts, grep { !/\.svn\b/ and !/~$/ } File::Find::Rule
    ->file()                                    # find all files
    ->in('bin') if -d 'bin';                    # ... but only if there's a bin/ dir
@scripts = 
  grep { _perl_shebang($_) }            # only check perl scripts.
  keys %{{ map { $_ => 1 } @scripts }}; # only check scripts once.

sub _perl_shebang {
  my $file = shift;
  open FILE, $file or die "Can't read $file: $!";
  return <FILE> =~ /^#!.*\bperl/;
}

my @docs = map { PPI::Document->new( $_ ) || () } (@modules, @scripts);

my (%modules, %packages);
for my $doc (@docs) {

  # Record all packages we use.
  my $includes = $doc->find( 
    sub { $_[1]->isa('PPI::Statement::Include') and $_[1]->module }
  ) || [];
  for (@$includes) {
    next if $_->pragma;
    $modules{ $_->module }++;
  }
  
  # Record all packages we provide.
  my $packages = $doc->find( sub { $_[1]->isa('PPI::Statement::Package') } ); 
  $packages{ $_->namespace }++ for @{ $packages || [] };
}

delete $modules{'Module::Build::Kwalitee::Stub'}; # remove 'magic' module
delete $modules{$_} for keys %packages;  # remove all packages we provide 

plan skip_all => "No requirements" unless scalar keys %modules;
plan tests => scalar keys %modules;

my $perl;
if ($requires->{perl}) {
  my $ver = version->new("$requires->{perl}");
  $perl = $ver->numify;
}

my $inst = ExtUtils::Installed->new;
for my $module (keys %modules) {
  if (is_required( $module )) {
    next;
  }
  SKIP: {
    skip "$module not installed", 1 
      unless eval "use $module; 1";

    my %dists = Module::Distname->dists( $module );
    # Some dists have different dist names than what you can use in 'requires'
    $dists{'perl'} = delete $dists{'Perl'} if exists $dists{'Perl'};
    $dists{'LWP'} = delete $dists{'libwww-perl'} if exists $dists{'libwww-perl'};
      
    my $found;
    for (keys %dists) {
      if (is_required( $_ )) {
        $found++;
        last SKIP;
      }
    }
    
    unless ($found) {
      fail "$module is not listed in dependencies.";
      diag "$module found in dist '$_' version '$dists{$_}'"
	for keys %dists;
    }
  }
}

sub is_required {
  my $module = shift;
  my $ret;
  
  if ( $perl && exists $Module::CoreList::version{$perl}{$module} ) {
    pass "$module is a core module in $perl";
    $ret++;
  }
  elsif ( exists $requires->{$module} ) {
    pass "$module is required";
    $ret++;
  }
  elsif ( exists $recommends->{$module} ) {
    pass "$module is recommended";
    $ret++;
  }

  return $ret;
}
