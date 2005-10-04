=head1 NAME

Froody::Request::CGI

=head1 DESCRIPTION

A Froody request object that slurps its data from a CGI request.

=over 4

=cut

package Froody::Request::CGI;
use warnings;
use strict;
use CGI;
use Froody::Error;
use Froody::Upload;
use base qw( Froody::Request );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);

  my %vars = CGI::Vars();
  my $method = delete $vars{method} || "";
  $self->method($method);
  
  for (keys %vars) {

    # split multi-values params into a listref
    my @vals = split("\0",$vars{$_});
    $vars{$_} = \@vals if (@vals > 1);

    # XXX: multiple uploads???
    if (my $upload = CGI::upload($_)) {
      my $filename = CGI::param($_);
      my $type = CGI::uploadInfo($filename)>{'Content-Type'};
      $vars{$_} = Froody::Upload
          ->new->fh($upload)
               ->filename(CGI::tmpFileName($_))
               ->client_filename($filename)
               ->mime_type($type);
    }
  }

  # read cookies into the request as well.
  for (CGI::cookie()) {
    next unless $_ eq 'cookie_session';
    $vars{$_} = CGI::cookie($_);
  }

  $self->params(\%vars);
  
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

L<Froody>, L<Froody::Request>

=cut

1;