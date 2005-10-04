#!/usr/bin/perl

#################################################################
# tests remote invokation (i.e. Froody::Invoker::Remote)
#################################################################

use strict;
use warnings;

# useful diagnostic modules that's good to have loaded
use Data::Dumper;
use Devel::Peek;

# colourising the output if we want to
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

###################################

# Test modules we might want to use:
# use Test::DatabaseRow;
# use Test::Exception;

# start the tests
use Test::More tests => 1;
use Test::Exception;

use Froody::Method;
use Froody::Invoker::Remote;

# from a local server

throws_ok {
 my $invoker = Froody::Invoker::Remote
                ->new()
                ->url("http://localhost:1/");
                
 my $method = Froody::Method
                ->new()
                ->full_name("does.it.hurt")
                ->invoker($invoker);

 my $rsp = $method->call({});
} qr/Bad response from remote server/, "got the correct error back!";


#We actually handle the rest of the success and failure conditions in t/high-level.t
