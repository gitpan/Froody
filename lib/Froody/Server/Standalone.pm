package Froody::Server::Standalone;
use base qw(HTTP::Server::Simple::CGI);

=head1 NAME

Froody::Server::Standalone - standalone server for Froody

=head1 SYNOPSIS

  use Froody::Server::Standalone;
  my $server = Froody::Server::Standalone->new();
  $server->port(4242);
  $server->run;

  # now you'll have a froody server listening on port 4242

=head1 DESCRIPTION

Froody::Server::Standalone is a subvlass of HTTP::Server::Simple::CGI
that has been altered to serve Froody requests

Currently it uses a global dispatcher stored in the global variable
$Froody::Server::Standalone::dispatcher.  If no dispatcher exists when the
first handler comes in one is created automatically and put into this
variable.

This code is very likely to change, but that's the current behavior.

=cut

use Froody;

use strict;
use warnings;

use HTTP::Date;

sub handle_request
{
 my ($self, $cgi) = @_;
 
  use Froody::Request::CGI;
  my $request = Froody::Request::CGI->new();
  
  use Froody::Dispatch;
  our $dispatcher ||= Froody::Dispatch->new();
  $dispatcher->error_style("response");
  $self->_send_bytes($dispatcher->dispatch(
    method => $request->method,
    params => $request->params,
  )->present);
}

sub _send_bytes
{
  my $self = shift;
  my $bytes = shift;
  
  my $time = time2str();
  
  # server headers
  print "HTTP/1.0 200 OK\r\n";

  # standard headers
  print "Content-Type: text/xml\r\n";
  print "Content-Length: ", length($bytes), "\r\n";

  # froody headers (for debugging)
  print "X-Froody-Version: ".$Froody::VERSION."\r\n";
  print "X-Towel: Over drain.\r\n";
  
  # no caching
  print "Cache-Control: no-cache\r\n";
  print "Date: $time\r\n";
  print "Expires: $time\r\n";
  
  # seperator
  print "\r\n";
 
  # content
  print $bytes;
}

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

L<Froody>, L<Froody::Dispatch>, L<Froody::Repository>

=cut



1;
