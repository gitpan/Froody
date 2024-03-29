=head1 NAME

Froody::Request::CGI

=head1 DESCRIPTION

A Froody request object that slurps its data from a CGI request.

=over 4

=cut

package Froody::Request::CGI;
use warnings;
use strict;
use Froody::Error;
use Froody::Upload;
use base qw( Froody::Request );

use CGI;

sub new {
  my $class = shift;
  my $cgi = shift || CGI->new;

  my $self = $class->SUPER::new(@_);

  my @vars = $cgi->Vars();
  my %vars = map { ref($_) || s/\xef\xbb\xbf//; $_ } @vars; # remove BOM from strings

  my $method = delete $vars{method} || "";
  $method = Encode::decode('utf-8', $method, 1 );
  $self->method($method);

  my $type = Encode::decode('utf-8', delete $vars{'_type'} || delete $vars{'_froody_type'}, 1 );
  $self->type($type);
  
  for (keys %vars) {

    # XXX: multiple uploads???
    if (my $upload = $cgi->upload($_)) {
      my $filename = $cgi->tmpFileName($upload);
      my $client_filename = "".$cgi->param($_);
      my $type = ( $cgi->uploadInfo($upload) || {} )->{'Content-Type'};
      $vars{$_} = Froody::Upload
          ->new->fh($upload)
               ->filename($filename)
               ->client_filename($client_filename)
               ->mime_type($type);

    } else {
      # split multi-values params into a listref
      my @vals = split("\0",$vars{$_});
      $vars{$_} = \@vals if (@vals > 1);
      
      # decopde params from unicode
      my $value = Encode::decode("utf-8", delete $vars{$_}, 1 );
      my $pname = Encode::decode("utf-8", $_, 1 );
      $vars{ $pname } = $value;
    }
  }

  if ($type and $type eq 'json') {
    $self->callback( delete $vars{"_json_callback"} );
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
