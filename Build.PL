#!/usr/bin/perl
use strict;
use warnings;
use lib 'mbk';
use Module::Build::Kwalitee;
Module::Build::Kwalitee->new(
  module_name => 'Froody',
  license     => 'perl',
  requires    => {
    'perl' => 5.008,
    'Class::Accessor::Chained' => 0,
    'Class::Accessor' => 0,
    'HTTP::Server::Simple' => 0,
    'Error' => '0.15',
    'File::Spec' => 0,
    'Params::Validate' => 0,
    'XML::LibXML' => 0,
    'UNIVERSAL::require' => 0,
    'YAML' => 0,
    'LWP::Simple' => 0,
    'LWP::UserAgent' => 0,
    'HTTP::Request::Common' => 0,
    'List::MoreUtils' => 0,
  },
  recommends => {
    'Apache' => 0,
    'Apache::Request' => 0,
    'Apache::Cookie' => 0,
    'Apache::Constants' => 0,
  },
  build_requires => {
    'Test::More' => 0,
    'Test::Exception' => 0,
    'Test::Differences' => 0,
    'Test::XML' => 0,
    'File::Find::Rule' => 0,
  },
  script_files => [qw(
    bin/froody
  )],
  create_readme => 1,
  create_makefile_pl => 'passthrough',
  recursive_test_files => 1,
)->create_build_script();
