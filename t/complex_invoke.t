#!/usr/bin/perl

############################################################################
# This file tests that we can write custom invokers
# we define our own little implementation and
# then declare we're going to use it with "invoker_class"
############################################################################

use strict;
use warnings;

use Test::More tests => 6;

use Test::Exception;

use lib 't/lib';

######
# Implementation

package MyInvoker;
use base qw(Froody::Invoker::Implementation);

sub pre_process {
  my ($class, $method, $params) = @_;
  $::pre_process_called++;
  $params->{one} = reverse $params->{one};
  return $params;
}

$INC{"MyInvoker.pm"} = 1;

#######
# actual code

package MyObject;
use base qw(Froody::Implementation);

sub implements { Other => 'other.object.*' }
sub invoker_class { "MyInvoker" }

sub method {
    return { -text => $_[1]->{one} };
}

#######
# tests

package main;

use Froody::Repository;
my $repos = Froody::Repository->new;
MyObject->register_in_repository($repos);
my $method = $repos->get_method('other.object.method');

# look, this stuff is meant to be over here!
is $method->module(), 'Other::Object';
is $method->service(), 'other';
is $method->object(), 'Object';

$::pre_process_called = 0;

my $r;
lives_and {
    my $data = { one => 'foo', two => 'bar, baz' };
    my $response = $method->call($data);
    isa_ok $response, 'Froody::Response';
    is($response->render,
       '<?xml version="1.0" encoding="utf-8"?>
<rsp stat="ok">
  <value>oof</value>
</rsp>
');
} 'invoked';

ok $::pre_process_called, "The pre_process method is called";

