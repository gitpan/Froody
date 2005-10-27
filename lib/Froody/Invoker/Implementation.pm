package Froody::Invoker::Implementation;
use base qw(Froody::Invoker);

use strict;
use warnings;

use File::Spec;
use Froody::Response::Terse;

use Froody::Error;
use Froody::Logger;
my $logger = Froody::Logger->get_logger('froody.invoker.implementation');

use constant response_class => 'Froody::Response::Terse';

__PACKAGE__->mk_accessors(qw( delegate_class ));

use Scalar::Util qw(blessed);

sub invoke {
  my ($self, $method, $params) = @_;
 
  # load the module if we need to
  my $module = $self->module($method);
  
  # get the perl code we're actually going to call
  my $func = $module->can($method->name) or
      $logger->logdie("no such method: ".$method->name." in $module");

  # create the context object, and return the instance that you
  # can call the other methods on.  By default, this simply returns
  # the current object (i.e. $invocation is the same as $self)
  my $invocation = $self->create_context($method->full_name, $params);
  my $response;

  # run the gauntlet
  eval {
    # munge the arguments
    $invocation->pre_process($method, $params);
    
    # call the perl code
    my $data = $func->($invocation, $params);
    
    # munge the results
    $response = $invocation->post_process($method, $data);
    
    # store extra stuff in the response (e.g. cookies)
    $invocation->store_context($response);
  };
  if ($@) {
      $invocation->error_handler($method->full_name, $@);
      unless ( ref $@ && $@->isa("Froody::Error") ) {
        Froody::Error->throw("perl.methodcall", 
          "While calling ".$method->full_name.", an error was not caught: $@");
      }
  }

  die $@ if $@;

  return $response;
}

############
# these are all helper methods for this particular implmentation
# that are either called directly or indirectly from invoke

sub error_handler {}

sub create_context {
  my ($self, $params) = @_;
  return $self;
}

sub store_context {
  return
}

sub module {
  my ($self, $method) = @_;

  # do a quick module conversion
  my $module = $self->delegate_class;

  # require that module and return it.
  $self->require_module($module, $method->name);

  return $module;
}

use Params::Validate qw(:all);

sub pre_process {
  my ($self, $method, $params) = @_;
  my $spec = $method->arguments;
  for my $arg (grep {$spec->{$_}{multiple}} keys %$spec) {
      if (defined $params->{$arg}) {
          if (!ref($params->{$arg})) { # csv
              $params->{$arg} = [ split(/\s*,\s*/, $params->{$arg}) ];
          }
          elsif (ref($params->{$arg}) ne 'ARRAY') {
              $params->{$arg} = [$params->{$arg}];
          }
      }
  }
  $self->verify_params( $spec, $params );
}

sub verify_params {
  my ($self, $spec, $params) = @_;

  # is there a special 'remainder' type?
  my ($remainder) = grep { $spec->{$_}{usertype} eq 'remaining' } keys %$spec;

  # filter out those not in spec, adding to the 'remainder' param, if
  # present.
  for (grep { !exists $spec->{$_} } keys %$params) {
    if ($remainder) {
      $params->{$remainder}{$_} = delete $params->{$_};
    } else {
      delete $params->{$_};
    }
  }

  local $SIG{__DIE__} = sub {
    my $error = shift;
    my $param;
    if (($param) = $error =~ m/parameter '(.+)' missing/) {
      Froody::Error->throw("perl.methodcall.param", "Missing argument: $param");
    }
    elsif (($param) = $error =~ m/'(.+)' parameter .*allowed/) {
      Froody::Error->throw("perl.methodcall.param", "Bad argument type: $param");
    }
    $logger->warn("weird params error $error");
    Froody::Error->throw("perl.methodcall.param", "Bad params");
  };

  validate_with ( params => $params, spec => $spec );
}

sub post_process {
  my ($self, $method, $data) = @_;

  $logger->logconfess("called with old style post_process")
      unless UNIVERSAL::isa($method,'Froody::Method');

  # have a response already?  Don't bother doing anything
  return $data if blessed($data) && $data->isa("Froody::Response");

  # build a response
  my $response = $self->response_class->new;
  $response->content($data);
  $response->structure($method);
  return $response;
}

1;

__DATA__

=head1 NAME

Froody::Implementation - define what should be run for a Froody::Method

=head1 SYNOPSIS

  # run the code from the froody method
  my $implementation_obj = $froody_method->implementation();
  my $response = $implementation_obj->invoke($froody_method, \%params);
  $response->render;
  
=head1 DESCRIPTION

You probably don't care about this class unless you want to change the way that
your Perl code is called for a given method (e.g. you want to dynamically
create methods or do something clever with sessions.)

Froody::Implementation and its subclasses are responsible for implementing the
Perl code that is run when a Froody::Method is called.  Essentially a
Froody::Method only really knows what it's called and that the instance of
another class - its implementation - knows how to run the code.

In reality, all a Froody::Implementation really has to do is implement an
C<invoke> method, that when passed a Froody::Method and a hashref containing
named parameters can 'execute' that method and return a Froody::Response:

  my $response = $implementation_obj->invoke($froody_method, $hash_params);

This module provides a default implementation that calculates a Perl method
name by transforming the Froody::Method name.  Before it runs that method it
pokes around with the arguments passed in based on the Froody::Method's
arguments.  When that Perl method returns, it transforms the hashref that code
returned into a proper Froody::Response based on the response defined for the
Froody::Method that is being processed.  Essentially, it wraps the Perl code
that you have to write in such a way you don't even have to think about what's
going on from Froody's point of view.

=head1 METHODS

=over

=item $self->delegate_class

A get/set accessor that gets/sets what class the Perl code that actually
implements the code here is created.

=item $self->module($method)

Given a L<Froody::Method> object, require and return the module
that the method will be dispatched to.

=item $self->create_context($params)

Returns the context of the current invocation.  By default this return the
class, so it's not instantiating.  Override this to provide session
management in C<store_context>.

=item $self->store_context($response)

Serialize the current context into C<$response>.  By default this does
nothing, you can override this and add a cookie to the response object.

=item $self->verify_params($spec, $params)

Run Params::Validate with the the given spec.  By default this is
called in C<pre_process>, and will filter out params that is not in the
spec.

=item $context->pre_process($method, $params)

Called by C<invoke> before the actual method call.  C<verify_params> is
called by default.  C<$params> is a hashref and can be modified to be
passed in for C<invoke>.  Currently the split of comma-separated
values (type=multiple) arguments is also handled here.

=item $context->post_process($method, $data)

Builds a L<Froody::Response::Terse> object according to the method's response
specification and the data returned from the method.

=item $context->error_handler($method_name, $error)

=back

=head1 SEE ALSO

L<Froody::Repository>, L<Froody::API> and for other implementations
L<Froody::Implmentation::OneClass> and L<Froody::Implementation::Remote>

=head1 AUTHORS

Copyright Fotango 2005.  All rights reserved.

Please see the main L<Froody> documentation for details of who has worked
on this project.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
