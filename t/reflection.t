#!/usr/bin/perl

#####################################################################
# checks the reflection methods are loaded by the repository
#####################################################################

use strict;
use warnings;

use Test::More tests => 9;
use Test::Exception;

use Froody::Repository;

use lib 't/lib';

use_ok ('Other');
use Froody::Dispatch;

my $client = Froody::Dispatch->new;
my $repo = $client->repository;

$repo->register_method($_) for Other->load();

is scalar $repo->get_methods(), 5, 'One method plus the reflection methods';
is scalar $repo->get_methods(qr'^reflection'), 0, 'partial query';
is scalar $repo->get_methods(qr'^other'), 1, 'partial query';
is scalar @{
    $client->call('froody.reflection.getMethods')->{method}
  }, 5, '1 method plus reflection ones';

my $method = $repo->get_method('other.object.method');

is $method->module, 'Other::Object', 'namespace transform worked';

isa_ok $repo->get_method('other.object.method'), 'Froody::Method';

throws_ok {
  $repo->get_method('Ack.Bar');
} qr/Method 'Ack.Bar' not found/;

isa_ok $method, 'Froody::Method';

