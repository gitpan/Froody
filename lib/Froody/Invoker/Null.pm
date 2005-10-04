package Froody::Invoker::Null;
use strict;
use warnings;

use base qw(Froody::Invoker);

use Froody::Response;
use Froody::Response::PerlDS;

our $VERSION = 0.01;

sub invoke
{
   my $self   = shift;
   my $method = shift;
   my $params = shift;
  
   return Froody::Response::PerlDS->new()
}
  
=head1 NAME

Froody::Invoker::Null - invoker that returns empty responses

=head1 SYNOPSIS

  use Froody::Invoker::Null;

  my $null = Froody::Invoker::Null->new();
  my $method = Froody::Method->new()
                             ->full_name("fred.bar.baz")
                             ->invoker($null);

=head1 DESCRIPTION

An Invoker that always returns an empty Froody::Response.

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

L<Froody>, L<Froody::Invoker>

=cut

1;
