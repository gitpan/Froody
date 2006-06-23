#!perl

############################################################################
# high-level API test - start a server, use the api to upload a file or two,
# then make sure that those files exist and are what we expect.
############################################################################

use Test::More tests => 27;

use warnings;
use strict;
use Test::Exception;
use Test::Differences;
use lib 't/lib';
use DTest;

use Froody::Server::Test;
use Froody::SimpleClient;

ok( my $real_client = Froody::Server::Test->client( "DTest::Test" ), 'got interface to client');
is $real_client->repository->get_methods, 11, "Right number of methods.";

ok( my $simple_client = Froody::SimpleClient->new( keys %{ $real_client->endpoints } ), "got simpleclient" );

my $first = 1;

for my $client ( $real_client, $simple_client ) {
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
  { local $TODO = 'fix this' unless $first;
  eq_or_diff $@->data || {}, { fire => "++good", napster => '++ungood' }, "We threw a data structure.";
  }
  
  # Die with a non-froody error in the error_handler should return a 500 from the server.
  throws_ok {
    $client->call('foo.test.badhandler');
  } qr/froody.invoke.remote/;
  isa_ok $@, 'Froody::Error';

  # nasty. The server has been killed by the test suite. 
  if ($first == 1) {
    Froody::Server::Test->stop;
    Froody::Server::Test->client( "DTest::Test" );
    $first = 0;
  }
}
