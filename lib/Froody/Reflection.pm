package Froody::Reflection;
use base qw(Froody::Implementation);

use strict;
use warnings;
use Params::Validate qw( :all );

sub implements { "Froody::API::Reflection" => 'froody.reflection.*' }

use Froody::Logger;
our $logger = get_logger("froody.reflection");

=head1 NAME

Froody::Reflection

=head1 DESCRIPTION

=head2 Functions

=over


=item getMethodInfo

Returns information for a given froody API method.

=cut

sub getMethodInfo
{
  my $self = shift;
  my $args = shift;
  my $calling_method = shift;

  my $repository = $self->repository;

  my $method = $repository->get_method($args->{method_name});

  my $response = {
    name => $method->full_name,
  };

  for (qw(needslogin description)) {
    my $val = $method->$_;
    $response->{$_} = $val if $val;
  }

  my $arg_info;
  {
    my $arguments = $method->arguments;
    for my $k (keys %$arguments) {
      my $v = $arguments->{$k};
      my $argdata = {
        name => $k,
        -text => $v->{doc},
        optional => $v->{optional},
        type => $v->{usertype}
      };
      push @$arg_info, $argdata;
    }
  }
  $response->{arguments} = { argument => $arg_info } if $arg_info && @$arg_info;

  my $method_errors = $method->errors;
  my $errors = [ map { 
    +{ 
        code => $_, 
        message => $method_errors->{$_}{message}, 
        -text => $method_errors->{$_}{description} 
    } } keys %$method_errors ];

  $response->{errors} = { error => $errors } if @$errors;
  $response->{response} = {} if $method->example_response;

  my $rsp = Froody::Response::Terse->new();
  $rsp->content($response);
  $rsp->structure( $calling_method );
  $rsp = $rsp->as_xml;
 
  # find the empty <response>...</response> and shove in our
  # child nodes.  This *must* be encoded in what we are (which is utf-8)
  if ($method->example_response) {
    my ($example_element) = $rsp->xml->findnodes("//response");
    $example_element->addChild( _response_to_xml($method) );
  }

  return $rsp; 
}

use Froody::Response::XML;
use Froody::Response::PerlDS;

sub _response_to_xml {
  my $structure = shift;

  # convert whatever we have to XML
  my $example = $structure->example_response->as_xml;

  # Nasty hack incase things aren't in the right encoding
  unless ($example->xml->encoding eq "utf-8")
   { $example = $example->as_perlds->as_xml };
 
  # grab the thingy inside the rsp and return it
  my ($response) = $example->xml->findnodes("/rsp/*");
  return $response->cloneNode(1);
}


=item getMethods

Returns a list of methods.

=cut

sub getMethods
{
  my $self = shift;
  my $args = shift;

  my $repository =  $self->repository;

  return {
    method => [ sort map { $_->full_name } $repository->get_methods ],
  };
}

=item getErrorTypes

Returns a list of error types.

=cut

sub getErrorTypes
{
  my $self = shift;

  my $repository = $self->repository;

  return {
    errortype => [ sort 
                   map { $_->full_name } 
                   grep { $_->full_name } 
                   $repository->get_errortypes ],
  };
}

=item getErrorTypeInfo

Returns the error type information

=cut

sub getErrorTypeInfo
{
  my $self = shift;
  my $args = shift;
  my $calling_method = shift;

  my $repository = $self->repository;
  my $et = $repository->get_errortype($args->{code});

  return $et->example_response; 
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

L<Froody>

=cut

1;
