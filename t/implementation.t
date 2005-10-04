#!/usr/bin/perl

#####################################################################
# Basic checks to see if the implementation stuff works
#
# This test declares an API and then declares an implementation
# that implements it.  We then test we can dispatch into that
# implementation and it all works okay.
######################################################################

use strict;
use warnings;

use Test::More tests => 4;

package Thingy::API;
use base qw(Froody::API);
use Froody::API::XML;
sub load { return Froody::API::XML->load_spec(<<'ENDOFSPEC') }
<spec>
 <methods>

  <method name="roger.wilko.bravo">
   <arguments /><response /><description>Silly method</description>
  </method>

  <method name="wibble.frobniz.disneyChar">
   <arguments>
    <argument name="type" type="text" optional="0">From what film?</argument>
   </arguments>
   <response>
    <char>Disney Char</char>
   </response>
  </method>

 </methods>
</spec>
ENDOFSPEC

$INC{"Thingy/API.pm"} = 1; # we're declared inline!!

package ThingyClass;
use base qw(Froody::Implementation);

sub implements { "Thingy::API" => "wibble.frobniz.*" }

sub disneyChar
{
  my $class = shift;
  my $args = shift;
  
  return $args->{type} eq "Toy Story" ? "Woody" : "Nemo";
}

package main;

use Froody::Dispatch;
my $dispatch = Froody::Dispatch->new();
my $repos = $dispatch->default_repository();
ThingyClass->register_in_repository($repos);

is($repos->get_methods, 5, "only one method loaded, and the two reflection methods.");
my $method = $repos->get_method("wibble.frobniz.disneyChar");
is($method->name, "disneyChar", "method loaded okay");
isa_ok($method->invoker, "Froody::Invoker::Implementation", "method loaded okay");

my $rsp = $method->call({ type => "Toy Story" });
like($rsp->render, qr{<char>Woody</char>}, "char back");
