#!perl

############################################################################
# high-level API test - start a server, use the api to upload a file or two,
# then make sure that those files exist and are what we expect.
############################################################################

use Test::More tests => 12;

use warnings;
use strict;
use Test::Exception;
use lib 't/lib';
use DTest;

use Froody::Dispatch;

# This is our port skew, which is an attempt to not tromp over other users who might
# be testing their own froody clients at the same time.
my $port = ( $> % 400 ) * 150 + 2050;


# start the web server
my $child;
unless ($child = fork()) {

  # loading Froody::Server::Standalone does some things
  # to our enviroment (for example, it piddles with the SIG handlers
  # so we only want to do that in the child.)

  eval q[
    use lib 't/lib';
    use DTest::Test; #Implementation
    use Froody::Server::Standalone;
    1;
  ]; 
  die $@ if $@;
  
  my $server = Froody::Server::Standalone->new();
  $server->port($port);
  $server->run;
}

sleep 1;


my $client = Froody::Dispatch->new();
$client->add_endpoint("http://localhost:$port");
ok( $client , 'got interface to client');
is $client->repository->get_methods, 9, "Right number of methods.";

my $answer;
lives_ok {
  $answer = $client->call( 'foo.test.add');
} 'can make call';
ok( $answer, 'got a response');

lives_and {
  $answer = $client->call( 'foo.test.add', {} );
  is $answer, "\x{e9}", "We get the right answer back.";
} 'can make call';

lives_and {
  $answer = $client->call( 'foo.test.empty' );
  is $answer, undef, "We get empty response back.";
} 'can make call';

throws_ok {
  $answer = $client->call('foo.foo.bar');
} qr/not found/;

isa_ok($@, "Froody::Error", "right error") or diag $@;
throws_ok {
  $client->call('foo.test.haltandcatchfire');
} qr/I'm on fire/;

isa_ok $@, 'Froody::Error';
is_deeply $@->data || {}, { fire => "++good", napster => '++ungood' }, "We threw a data structure.";
is $@->code, 'test.error';

END {
  # what the gosh-darn signals numbered on this box then?
  use Config;
  defined $Config{sig_name} || die "No sigs?";
  my ($i, %signo);
  foreach my $name (split(' ', $Config{sig_name})) {
     $signo{$name} = $i;
     $i++;
  }
  
  # die with more and more nastyness
  for my $signal (qw(TERM KILL)) {
    kill $signo{$signal}, $child;
    exit unless kill 0, $child;
    sleep 1;
  }
}
