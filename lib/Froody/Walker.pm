package Froody::Walker;
use strict;
use warnings;

use Froody::Logger;

my $logger = get_logger("froody.walker");

=head1 NAME

Froody::Walker;

=head1 SYNOPSIS

  my $spec        = $froody_method->structure;
  my $method_name = $froody_method->name;
  
  # create a new walker that knows about the spec
  my $walker = Froody::Walker::TerseToXML->new($source);
  
  # walk $source turning it into xml
  my $xml = $walker->walk($spec, $method_name);

=head1 DESCRIPTION

Walker classes are constructed with a data source.  We can then ask them
to convert, using a specification, that data source into another format.

A walker object has its data source (the 'original data structure'), as well as
its state (an 'opaque data structure' which we're constructing).

The following methods are used to combine the states, according to the response
structure, to a final wanted object.

You need to subclass C<Froody::Walker> to implement a walker which will define
how the data source is walked and presented.

=head2 METHODS

=over

=item $class->new(@arg)

=item $self->walk($spec, $method_name)

Method that's designed to be called on the root node.  Walks the data structure
we're configured with from the top and returns the new data structure.
$method_name is used for debugging info.

=item $self->walk_node($spec, $xpath_key, $method_name)

Walks the data structure this object holds with the specification, starting at
the part of the spec indicated by $xpath_key.  The $method_name is used for
debugging info.

=item $self->name

=item $self->get_child_walkers

Returns a child walker node for each child element of the data structure
that we hold.

=item calculate_value

Set the opaque data structure value from the original data structure value.
i.e. copy the text across from one node to the other.

=item calculate_attribute($name)

Set the walker node attribute in the opaque datastructure called $name from
the original data structure

=item associate_opaque_ds($name => $opaque_ds, $multi)

Set the value of child C<$name> to $childvalue. C<$multi> is true if the child
is declared to have multiple values.

=item is_leaf

Returns true if the node is leaf.

=item opaque_ds

Returns the opaque datastructure that this walker has constructed to
represent the new data source.

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

L<Froody>, L<Froody::Response::Terse>

=cut

sub walk {
    my ($self, $global_spec, $method) = @_;
    
    # look for the toplevel in the spec.  If we've got more than one, panic!
    my @toplevel = grep m[^[^/]+$], keys %{ $global_spec };
    my $toplevel = shift(@toplevel)
      or return;
    if (@toplevel)
     { Froody::Error->throw("froody.xml", "invalid Response spec (multiple toplevel nodes!)") }

    $self->{name} = $toplevel;
    
    return $self->walk_node($global_spec, $toplevel, $method);
}

# this is the function that knows how to follow the specification
sub walk_node {
    my ($self, $global_spec, $xpath_key, $method) = @_;
 
    # get the part of the spec for where we are now looking at
    my $spec = $global_spec->{ $xpath_key } || { text => 1 };

    # THE BASE CASE (are we nearly there yet?)
    #if ($self->is_leaf) {
    #  $self->calculate_value;
    #  return $self->opaque_ds;
    #}

    # the attributes are easy.  We just pass them each on.
    # TODO: Work out if we need to encode these
    $self->calculate_attribute($_) for @{ $spec->{attr} };
 
    # build this data structure, grouping elements that have the same name
    # and creating new walkers for each of the nodes that were in the data
    # structure we were transforming from
    # $child_walkers = {
    #   nodename     => [ $walker1, $walker2, $walker3 ],  # all walkers named 'nodename'
    #   othernodname => [ $walker4, $walker5, $walker6 ],  # all walkers named 'othernodename'
    # };
    my $child_walkers = {};
    foreach ($self->get_child_walkers) {
      push @{ $child_walkers->{ $_->name } }, $_;
    }
    
    # go through the specification processing each of the elements
    foreach my $element_name (@{ $spec->{elts} }) {
    
      # work out the full xpath_key for this element
      my $newname = "$xpath_key/$element_name";

      ###
      # check for missing bits
      
      # are we expecting more than one of them?
      my $new_ismulti = $global_spec->{ $newname }            # there
                        && $global_spec->{ $newname }{multi}; # has multi flag
      
      # does that exist? Warn if it doesn't
      if (!exists $child_walkers->{ $element_name } && !$new_ismulti) {
        $logger->info("$method: the response is missing element '$element_name'");
        next;
      }
      
      # did we get too many elements back?
      if (!$new_ismulti && @{ $child_walkers->{ $element_name } } > 1 ) {
        Froody::Error->throw("froody.xml", "got multiple entry but spec say it's single")
      }
      
      ###
      # walk child nodes

      # recurse for all the elements of that name
      for my $child (@{ $child_walkers->{ $element_name } }) {

        # walk that element, and get what that creates back
        my $opaque_ds = $child->walk_node($global_spec, $newname, $method);
        
        # add that a child element of the current destination node
        $self->associate_opaque_ds($child->name => $opaque_ds, $new_ismulti);
      }

      # we've successfully processed it.  Remove it from the list of things
      delete $child_walkers->{ $element_name };
    }

    # okay, if we've still got child walkers after we've iterated over the
    # elements we're expecting from the spec and processed the ones that
    # matched then we've got ones that wern't in the spec.  Kick up a fuss
    if (%$child_walkers) {
      $logger->info("$method: unexpected child '$_' found within '$xpath_key'") 
        for keys %$child_walkers;
    }

    $self->calculate_value if $spec->{text};
    return $self->opaque_ds;
}

1;
