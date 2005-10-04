package Froody::Walker::TerseToPerlDS;
use base 'Froody::Walker';

use strict;
use warnings;

=head1 NAME

Froody::Walker::TerseToPerlDS - convert Terse to PerlDS

=head1 SYNOPSIS

=head1 DESCRIPTION

Turn what Implementation class returns into the structure
L<Froody::Response> expects.

=cut

sub new {
    my ($class, $data, @param) = @_;
    return bless { data => $data, param => \@param }, $class;
}

sub name {
    my $self = shift;
    $self->{name};
}

# WARNING: *FUNCTIONAL* *PROGRAMMING* LINE NOISE AHEAD
# CLKAO original wrote this, and I can't understand it -- MarkFowler
sub get_child_walkers {
    my $self = shift;
    
    return if $self->is_leaf;
    
    return map {
        my $name = $_;
        
        # if there's one, just return that, otherwise do them all
        ref ($self->{data}{ $name }) eq 'ARRAY'
          ? map  { 
                bless { name  => $name,
                        data  => $_,
                        param => $self->{param} }, ref $self
              } @{$self->{data}{$name}}
          : bless { name => $name,
                    data => $self->{data}{$name},
                    param => $self->{param} }, ref $self;
    }
    
      # all nodes that aren't attrbitutes or text nodes are proper children nodes
      grep { !$self->_has_attr($_) && $_ ne "-text"}
    
      # the node names
      keys %{ $self->{data} };
}

sub _has_attr {
    my ($self, $name) = @_;
    return unless exists $self->{tmp}{attributes};
    return exists $self->{tmp}{attributes}{$_};
}

sub calculate_value {
    my $self = shift;
    if (ref($self->{data})) {
      $self->{tmp}{value} = $self->{data}{'-text'}; 
    }
    else 
     { $self->{tmp}{value} = $self->{data} }
}

sub opaque_ds {
    my $self = shift;

    print STDERR "op called with class ".ref($self)."\n";

    $self->{tmp}{name} = $self->{name};
    return $self->{tmp};
}

sub calculate_attribute {
    my ($self, $name) = @_;
    $self->{tmp}{attributes}{$name} = $self->{data}->{$name};
}

sub associate_opaque_ds {
    my ($self, $name, $child, $multi) = @_;
    push @{$self->{tmp}{children}}, $child;
}

sub is_leaf {
    my $self = shift;
    !ref ($self->{data});
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
