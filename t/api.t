#!/usr/bin/perl -w

#########################################################################
# This tests loads an xml based API (Testobject::API) and makes sure that 
# the right things are set up in the repository
#########################################################################

use strict;
use lib 't/lib';

use Data::Dumper;

# colourising the output if we want to
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

use Test::More tests => 31;
use Test::Exception;

# this is where we keep our modules
use Froody::Repository;

use Scalar::Util qw(blessed);

# load our test API
use_ok ('Testproject::API');

{
  my @stuff = Testproject::API->load();

  # Check we got our methods back
  my @methods = grep { blessed($_) && $_->isa("Froody::Method") } @stuff;
  is(@methods, 8, "got eight methods back from the api");
  my $methods = { map { $_->full_name => 1 } @methods };
  is_deeply($methods, { map { $_ => 1 } qw(
      testproject.object.method
      testproject.object.text
      testproject.object.sum
      testproject.object.texttest
      testproject.object.extra
      testproject.object.range
      testproject.object.range2
      testproject.object.params
  )},"got the right method names")
    or diag(Dumper $methods);
    
  # Check we got our error types back
  my @et = grep { blessed($_) && $_->isa("Froody::ErrorType") } @stuff;
  is(@et, 2, "got two et back from the api");
  my $et = { map { $_->name => 1 } @et };
  is_deeply($et, { map { $_ => 1 } qw(
     foo.fish
     foo.fish.fred
  )},"got the right et names")

}

# ignore the previous methods, and just load up Testproject::Service
# that will register them for us
use_ok("Testproject::Object");
my $repos = Froody::Repository->new();
Testproject::Object->register_in_repository($repos);

# okay, so I removed the ability for the framework to be called on just
# method names, now you need to invoke with a proper Froody::Method.  This
# makes sense from the way the API is now used (since nothing but the
# method object should really be calling invoke,) but makes testing a bit more
# painful.
my $text     = $repos->get_method('testproject.object.text');
my $sum      = $repos->get_method('testproject.object.sum');
my $texttest = $repos->get_method('testproject.object.texttest');
my $extra    = $repos->get_method('testproject.object.extra');
my $range    = $repos->get_method('testproject.object.range');
my $range2   = $repos->get_method('testproject.object.range2');
my $params   = $repos->get_method('testproject.object.params');
foreach ($text, $sum, $texttest, $extra, $range, $range2, $params)
 { isa_ok($_, 'Froody::Method') }

dies_ok {
    Froody::API->load
} 'need to override ::load';

lives_ok {
    $text->call({});
} "we can invoke thingy.text without errors";

use Froody::Response::PerlDS;

{
  my $result = $sum->call({ values => '10,20,30'})->as_perlds->content;
  is_deeply ( $result, {name => 'sum', value => 60}, 'multi argument handling')
    or diag(Dumper $result);
}

throws_ok { $sum->call({ values => undef }) } qr{Bad argument type}, "bad arg";
throws_ok { $sum->call({ })                 } qr{Missing argument}, "missing";

is_deeply($range->call({ base => 90, offset => 10 })->as_perlds->content,
    {name => 'range',
      children => [{name => 'value', value => 80},
       {name => 'value', value => 100}]
     },"range");

is_deeply($range2->call({ base => 90, offset => 10 })->as_perlds->content,
    {name => 'range',
      children => [{name => 'value', attributes => {num => 80}},
       {name => 'value', attributes => {num => 100}}]
     },"range2");

# XXX: test the logger warnings!
is_deeply($extra->call({})->as_perlds->content,
    { name => 'range' }, "wibble");

is_deeply($params->call( { bob => 'baz', fred => "wobble" } )
  ->as_perlds->content, { name => "count", value => 2 }, "remaining params passed ok");

#### test the errortypes #####

my $default = $repos->get_errortype('');
my $fish = $repos->get_errortype('foo.fish');
my $fred = $repos->get_errortype('foo.fish.fred');
foreach ($fish, $fred, $default)
 { isa_ok($_, 'Froody::ErrorType') }

is($fish->name, 'foo.fish', "fish name");
is($fred->name, 'foo.fish.fred', "fred name");
is($default->name, '', "default name");

is_deeply($fish->structure, {
            'err' => {
                     'elts' => [
                                 'foo'
                               ],
                     'attr' => [
                                 'code',
                                 'msg'
                               ]
                   }
}, "fish struct");

is_deeply($fred->structure, {
          'err/bars/bar' => {
                            'elts' => [],
                            'text' => 1,
                            'multi' => 1,
                            'attr' => []
                          },
          'err/bars' => {
                        'elts' => [
                                    'bar'
                                  ],
                        'attr' => []
                      },
          'err' => {
                     'elts' => [
                                 'bars',
                                 'foo'
                               ],
                     'attr' => [
                                 'code',
                                 'msg'
                               ]
                   }
}, "fred struct");

is_deeply($default->structure, {
            'err' => {
                     'elts' => [
                               ],
                     'attr' => [
                                 'code',
                                 'msg'
                               ]
                   }
}, "default struct");
