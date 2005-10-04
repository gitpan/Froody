package Froody::Walker::TerseToXML;
use base 'Froody::Walker::TerseToPerlDS';
use strict;
use warnings;

use Encode qw(encode);

=head1 NAME

Froody::Walker::TerseToXML - convert Terse to XML

=head1 SYNOPSIS

=head1 DESCRIPTION

Turn what Implementation class returns into the structure
L<Froody::Response> expects.

=cut

# quick hacky version.  This builds everything up just as TopPerlDS
# does, but rather than returning the hash with opaque_ds I return
# an XML node.  Is it not nifty?

# TODO: replace this with something a little more constructive
# get it? CONSTRUCTIVE.  Oh never mind.

sub opaque_ds {

    my $self = shift;
    my $doc = $self->{param}[0];
    my $enc = $doc->getEncoding();
    
    # create an element with the XML::LibXML::Document thingy
    my $xml = $doc->createElement(
      encode($enc, $self->{name}, 1)
    );

    foreach (keys %{$self->{tmp}{attributes}}) {
        $xml->setAttribute( 
          $_, 
          encode($enc, $self->{tmp}{attributes}{ $_ }, 1)
        );
    }

    # attach children
    $xml->addChild( $_ ) foreach @{ $self->{tmp}{children} };

    $xml->appendText(
      encode($enc, $self->{tmp}{value}, 1)
    ) if defined $self->{tmp}{value};
      
    return $xml;
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

L<Froody>, L<Froody::Walker>

=cut

1;
