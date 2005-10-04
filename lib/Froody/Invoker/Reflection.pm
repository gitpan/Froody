package Froody::Invoker::Reflection;
use base qw(Froody::Invoker::Implementation);

use Froody::Reflection;

use strict;
use warnings;

use Scalar::Util qw(blessed weaken);

use Froody::Response::Terse;

use Froody::Logger;
my $logger = Froody::Logger->get_logger('froody.invoker.implementation');

use constant response_class => 'Froody::Response::Terse';

sub invoke {
  my ($self, $method, $params) = @_;
 
  # get the perl code we're actually going to call
  my $func = Froody::Reflection->can($method->name) or
      $logger->logdie("no such method: ".$method->name." in Froody::Reflection");

  my $response;

  # run the gauntlet
  eval {
    # munge the arguments
    $self->pre_process($method, $params);
    
    # call the perl code
    my $data = $func->($self, $params, $method);
    
    # munge the results
    $response = $self->post_process($method, $data);
  };

  if ($@ && !ref($@)) {
      $self->error_handler($method->full_name, $@);
  }
  die $@ if $@;

  return $response;
}

############
# these are all helper methods for this particular implmentation
# that are either called directly or indirectly from invoke

sub pre_process {
  my ($self, $method, $params) = @_;
  $self->verify_params( $method->arguments, $params );
}

sub repository {
  my $self = shift;
  return $self->{repository} unless @_;
  unless (blessed($_[0]) && $_[0]->isa("Froody::Repository")) {
    Froody::Error->throw("perl.methodcall.param",
             "repository must be passed an instance of Froody::Repository");
  }
  $self->{repository} = shift;
  weaken $self->{repository};
  return $self;
}

1;

__DATA__

=head1 NAME

Froody::Invoker::Reflection - specialized handler for Reflection that includes the method repository

=head1 SYNOPSIS

  # run the code from the froody method
  my $repo = Froody::Repository->new();
  my $invoker = Froody:Invoker::Reflection->new()->repository($repo);
  my $response = $invoker->invoke($froody_method, \%params);
  $response->render;
  
=head1 DESCRIPTION

You probably don't care about this class unless you want to play with the
Froody method repository with your method call.

=head2 Methods

=over

=item pre_process( $method, $params )

Verify parameters. Called from invoke.

=item repository( $repository )

Accessor for repository

=back

=head1 BUGS

None known.

Please report any bugs you find via the CPAN RT system.
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Froody>

=head1 AUTHOR

Copyright Fotango 2005.  All rights reserved.

Please see the main L<Froody> documentation for details of who has worked
on this project.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<Froody>, L<Froody::Repository>, L<Froody::API> and for other implementations
L<Froody::Implmentation::OneClass> and L<Froody::Implementation::Remote>

=cut
