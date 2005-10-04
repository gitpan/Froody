=head1 NAME

Froody::Dispatch - Easily call Froody Methods

=head1 SYNOPSIS

  use Froody::Dispatch;
  my $dispatcher = Froody::Dispatch->new();
  my $response = $dispatcher->dispatch(
     method => "foo.bar.baz",
     params => { fred => "wilma" },
  );

or, as a client:

  $client = Froody::Dispatch->new;

  # uses reflection to load methods from the server
  $client->endpoint( "uri" ); 

  # look mah, no arguments!
  $rsp = $client->call('service.wibble');

  # ok, take some arguments then.
  $rsp = $client->call('service.devide', divisor => 1, dividend => 2);

  # alternatively, args can be passed as a hashref:
  $args = { devisor => 1, devidend => 2 }; 
  $rsp = $client->call('service.devide', $args);


=head1 DESCRIPTION

This class handles dispatching Froody Methods.  It's used both from within the
servers where you don't want to have to worry about the little details and as a
client.

=cut

package Froody::Dispatch;
use base qw( Froody::Base );

use warnings;
use strict;

use Params::Validate qw(:all);
use Scalar::Util qw( blessed );
use UNIVERSAL::require;

use Froody::Response::Terse;
use Froody::Repository;
use Froody::Response::Error;

use Froody::Logger;

my $logger = get_logger("froody.dispatch");

=head1 METHODS

=head2 Class Methods

=over 4

=item new

Create a new instance of the dispatcher

=cut

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  $self->error_style("throw");
  $self;
}

=item default_repository

The first time this method is called it creates a default repository by
trawling through all loaded modues and checking which are subclasses of
Froody::Implementation.

If you're running this in a mod_perl handler you might want to consider
calling this method at compile time to preload all the classes.

=cut

sub default_repository
{
  my $class = shift;
  
  # create a default repository
  our $default_repository;
  unless ($default_repository)
  {
     $default_repository = Froody::Repository->new();
  
     # for every module already loaded that is a Froody::Implementation
     # register it's methods in this repository
     foreach (keys %INC)
     {
        # convert to module names
        s/\.pm$//;
        s{/}{::}g;
        
        next if $_ eq "Froody::Implementation";  # base class
        next if $_ eq "Froody::Reflection";      # don't register twice
        
       if (UNIVERSAL::isa($_, "Froody::Implementation"))
        { $_->register_in_repository($default_repository) }
     }
  }

  # return the default repos
  return $default_repository;
}

=item add_endpoint( "url" )

Registers all methods from a remote repository within this one.

TODO:  add regex filtering of methods.

=cut

sub add_endpoint {
  my ($self,$url) = @_;

  # override the local invokers *just* *for* *now*
  my $invoker = Froody::Invoker::Remote->new()->url($url);
  my $repo = $self->repository;


  my $get_methods = $repo->get_method("froody.reflection.getMethods")->new->invoker($invoker);
  my $get_method_info = $repo->get_method("froody.reflection.getMethodInfo")->new->invoker($invoker);
  
  my $response = $get_methods->call({})->as_terse;
  foreach my $method_name (@{ $response->content->{method} })
  {
     my $method_response = $get_method_info->call({ method_name => $method_name });
     local $@;
     eval {
       my $method = Froody::API::XML->load_method(
         $method_response->as_xml->xml->findnodes("//method")
       );
       $method->invoker($invoker);
       $repo->register_method($method);
     };
     warn "method '$method_name' not loaded: $@" if $@;
  }
  
  my $get_errortypes = $repo->get_method("froody.reflection.getErrorTypes")->new->invoker($invoker);
  my $get_errortype_info = $repo->get_method("froody.reflection.getErrorTypeInfo")->new->invoker($invoker);
  $response = $get_errortypes->call({})->as_terse;
  foreach my $code (@{ $response->content ? $response->content->{errortype} : [] })
  {
     my $errortype_response = $get_errortype_info->call({ code => $code });
     local $@;
     eval {
       my $errortype = Froody::API::XML->load_errortype(
         $errortype_response->as_xml->xml->findnodes("//errortype")
       );
       $repo->register_errortype($errortype);
     };
     warn "errortype '$code' not loaded: $@" if $@;
  }
}

sub _get_method {
  my ($repo, $name, $invoker) = @_;

  my $method = $repo->get_method($name);
  my $old_invoker = $method->invoker;
  $method->invoker($invoker);

  return $method, $old_invoker;
}


=back

=head2 Instance Methods

=over

=item dispatch( %args )

Causes a dispatch to a froody method to happen.  At a minimum you need to
pass in a method name:

  my $response = Froody::Dispatch->new->dispatch( method => "foo.bar.bob" );

You can also pass in parameters:

  my $response = Froody::Dispatch->new->dispatch( 
    method => "foo.bar.bob",
    param  => { wibble => "wobble" },
  );

Which repository this class uses and how errors are reported depends on
the methods defined below.

=cut

sub dispatch {
  my $self = shift;
  my $repo = $self->repository;

  my $method;
  my $response = eval {
  
    # make sure we're being dispatched with the right args
    my %args = $self->validate_object(@_, {
      method      => { type => SCALAR },
      params      => { type => HASHREF, optional => 1 },
    });

    Froody::Error->throw("froody.invoke.nomethod", "Missing argument: method")
      unless length($args{method});

    # load the Froody::Method, and call it with the parameters
    $method = $repo->get_method($args{method});
    my $response = $method->call($args{params} || {});

    # throw an exception if what we got back wasn't an acceptable
    # Froody::Response object
    $self->_validate_response($response);
    
    return $response;
  };
  
  my $style = $self->error_style;
  
  # either a problem during initial dispatch, or when we got the
  # response back we couldn't convert it to another type and check
  # that it was a successful pass
  if ($@)
  {     
     # simply rethrow the error if we're passing through or if we're
     # throwing and it's already a Froody::Error
     my $is_froody_error = blessed($@) && $@->isa("Froody::Error");
     if ($style eq "passthrough") {
      die $@;
     } 
     elsif ($style eq 'throw') 
     {
       die $@ if $is_froody_error; 
       Froody::Error->throw($@);
     } 
     # must be creating a response
     my $err = Froody::Response::Error->new();
     $err->set_error($@);
     
     my $structure = $is_froody_error 
        ? $repo->get_closest_errortype($@->code)
        : Froody::ErrorType->new; 

     $err->structure($structure);
    
     $response = $err;
  }
  $self->cleanup;
  
  my $is_an_error;
  if (!$response->can('status')) {
    $response->structure($method);

    my $xml = $response->as_xml->xml;
    
    my ($status) = $xml->findnodes('//rsp/@stat');
    if ($status->nodeValue ne 'ok') {
      $is_an_error = 1;
      my ($code) = $xml->findnodes('//err/@code');
      # we need to fix our structure
      $response->structure($repo->get_closest_errortype($code ? $code->nodeValue : '' ));
    }
  } elsif ($response->status ne 'ok') {
    $is_an_error = 1;
  }

  if ($style eq "throw" && $is_an_error)
  {
    $response->as_error->throw;
  }
  
  return $response;
}

# throws an error if the reponse isn't valid
sub _validate_response
{
  my $class    = shift;
  my $response = shift;

  # nothing?  Throw an error
  if ( ! $response ) {
    Froody::Error->throw("froody.invoke.badresponse", "No response");
  }

  # if we didn't get the right sort of response, throw an error.
  unless ( ref($response) && blessed($response)
            && $response->isa("Froody::Response")) {
    Froody::Error->throw("froody.invoke.badresponse", "Bad response $response");
  }
}

=item cleanup

Subclasses should override this method if there are any cleanup tasks that should be
run after 

=cut

sub cleanup {
}

=item call( 'method', [ args ] )

Call a method (optionally with arguments) and return a
L<Froody::Response::Terse> response, as described in
L<Froody::DataFormats>.  This is a thin wrapper for the
->dispatch() method. 

=cut

sub call {
  my $self = shift;
  my $method = shift;
  my $args = ref $_[0] eq "HASH" ? shift : { @_ };

  my $rsp = $self->dispatch( method => $method, params => $args );

  return $rsp->as_terse->{content};
}


=item repository

Get/set the repository that we're calling methods on.  If this is set
to undef (as it is by default) then we will use the default repository
(see above.)

=cut

sub repository
{
  my $self = shift;

  unless (blessed($self))
   { Froody::Error->throw("perl.methodcall.class", "repository cannot be called as a class method") }
  
  unless (@_)
  {
     return $self->{repository} if defined $self->{repository};
     return $self->default_repository;
  }
  
  unless (!defined($_[0]) || blessed($_[0]) && $_[0]->isa("Froody::Repository"))
   { Froody::Error->throw("perl.methodcall.param", "repository must be passed undef or a Froody::Repository instance") }
  
  $self->{repository} = shift;
  return $self;
}

=item error_style

Get/set chained accessor that sets the style of errors that this should use. By
default this is C<response>, which causes all errors to be converted into valid
responses.  Other options are C<throw> which turns all errors into
Froody::Error objects which are then immediatly thrown and C<passthrough> which
doesn't actually do anything (errors that are thrown continue to be thrown,
error responses are returned.)

=cut

sub error_style
{
   my $self = shift;
   return $self->{error_style} || "response" unless @_;
   
   unless ($_[0] && ($_[0] eq "response" || $_[0] eq "throw" || $_[0] eq "passthrough"))
    { Froody::Error->throw("perl.methodcall.param", "Invalid error style") }
    
   $self->{error_style} = shift;
   return $self;
}

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

L<Froody>, L<Froody::Method>

=cut

1;
