package Froody::Walker::XMLToTerse;
use strict;
use warnings;
use base 'Froody::Walker';

=head1 NAME

Froody::Walker::XMLToTerse - convert XMLToTerse

=head1 SYNOPSIS

=head1 DESCRIPTION

Turn xml into data in the form of Implementation class returns.

=cut

# xml -> data walker

sub new {
    my ($class, $node) = @_;
    bless { node => $node }, $class;
}

sub name {
    my $self = shift;
    $self->{name};
}

sub get_child_walkers {
    my $self = shift;
    map {
        bless { name => $_->nodeName, node => $_ }, ref $self
    } grep { !$_->isa('XML::LibXML::Text') } $self->{node}->childNodes;
}

sub calculate_value {
    my $self = shift;
    
    my $text = $self->{node}->findvalue("./text()");
    unless ($text && $text =~ m/\S/) {
      $text .= $_->toString for $self->{node}->childNodes();
    }
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    
    if (exists $self->{tmp}) {
      $self->{tmp}{'-text'} = $text;
    }
    else {
        $self->{tmp} = $text;
    }
}

sub opaque_ds {
    my $self = shift;
    return $self->{tmp};
}

sub calculate_attribute {
    my ($self, $name) = @_;
    $self->{tmp}{$name} = $self->{node}->findvalue('./@'.$name);
}

sub associate_opaque_ds {
    my ($self, $name, $childvalue, $multi) = @_;
    if ($multi) {
        push @{$self->{tmp}{$name}}, $childvalue;
    }
    else {
        $self->{tmp}{$name} = $childvalue;
    }
}

sub is_leaf {
    my $self = shift;
    return if $self->{node}->hasAttributes;
    my @children = $self->{node}->childNodes;
    return $#children == 0 && $children[0]->isa('XML::LibXML::Text');
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
