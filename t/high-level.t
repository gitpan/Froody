#!perl

############################################################################
# high-level API test - start a server, use the api to upload a file or two,
# then make sure that those files exist and are what we expect.
############################################################################

use Test::More tests => 14;

use warnings;
use strict;
use Test::Exception;
use Test::Differences;
use lib 't/lib';
use DTest;

use Froody::Server::Test;

ok( my $client = Froody::Server::Test->client( "DTest::Test" ), 'got interface to client');
is $client->repository->get_methods, 11, "Right number of methods.";

my $answer;
lives_ok {
  $answer = $client->call( 'foo.test.add', values => [1,2,3]);
} 'can make call';
ok( $answer, 'got a response');

lives_and {
  $answer = $client->call( 'foo.test.add', {} );
  is $answer, "\x{e9}", "We get the right answer back.";
} 'can make call';

lives_and {
  $answer = $client->call( 'foo.test.empty' );
  is_deeply $answer, {}, "We get empty response back.";
} 'can make call';

throws_ok {
  $answer = $client->call('foo.foo.bar');
} qr/not found/;

isa_ok($@, "Froody::Error", "right error") or diag $@;
throws_ok {
  $client->call('foo.test.haltandcatchfire');
} qr/I'm on fire/;

isa_ok $@, 'Froody::Error';
is $@->code, 'test.error';
eq_or_diff $@->data || {}, { fire => "++good", napster => '++ungood' }, "We threw a data structure.";

$TODO = "Find brain.  Shoot self in foot with brain.";
throws_ok {
  $client->call('foo.test.badhandler');
} qr/XXX/; #What should happen???  Should this even throw, or should I be getting back a froody response
isa_ok $@, 'Froody::Error';
