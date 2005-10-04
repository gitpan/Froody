package Froody::Response::Terse;
use base qw(Froody::Response::Content);
use warnings;
use strict;

use XML::LibXML;
use Encode;
use Params::Validate qw(SCALAR ARRAYREF HASHREF);

use Storable qw(dclone);

use Froody::Logger;
my $logger = get_logger("froody.response.terse");

use Froody::Response::Error;

=head1 NAME

Froody::Response::Terse - create a response from a Terse data structure

=head1 SYNOPSIS

  my $rsp = Froody::Response::Terse->new();
  $rsp->structure($froody_method);
  $rsp->content({
   group => "imperialframeworks"
   person => [
    { nick => "Trelane",  number => "243", name => "Mark Fowler"    }
    { nick => "jerakeen", number => "235", name => "Tom Insam"      }
   ],
   -text => "Some of Frameworks went to Imperial Collage"
  }
  print $rsp->render();
  
  # prints out (more or less)
  <?xml version="1.0" encoding="utf-8" ?>
  <people group="imperialframeworks">
    <person nick="Trelane" number="234"><name>Mark Fowler</name></person>
    <person nick="jerakeen" number="235"><name>Tom Insam</name></person>
    Some of Frameworks went to Imperial Collage
  </people>

=head1 DESCRIPTION

The Terse response class allows you to construct Responses from a very small
data structure that is the most logical form for the data to take.  It is able
to convert the data to XML by virtue of the specification stored in the
Froody::Method alone.

The data structure is exactly the same that's returned from a method
implementation that's defined in a Froody::Implementation subclass (If you
don't know what that is, I'd go read that module's documentation now if I were
you.)

=cut

=head2 Attributes

In addition to the attributes inherited from Froody::Response, this class has
the following get/set methods:

=over 4

=item status

The status of the response, should be 'ok' or 'fail' only.

=item content

The contents of the data structure.  Setting this accessor causes a deep
clone of the data structure to happen, meaning that you can add similar
content to multiple Response objects by setting on one object, altering, then
setting another object.

  my $data = { keywords => [qw( fotango office daytime )] };
  $picture_of_office->content($data);
  push @{ $data->{keywords} } = "Trelane";
  $picture_of_me_in_office->content($data);
  
Note however, this is not true for the returned value from content.  Altering
that data structure really does alter the data in the response (this is
considered a feature)

  # add my name as a keyword as well
  push @{ $picture_of_me_in_office->content->{keywords} }, "Mark";

=back

=cut

# yep, this is all we need to do, everything else is defined in the
# superclass
sub _to_xml
{
   my $self = shift;
   my $content = shift;

   # okay, we have an error.  This means we should have a data
   # structure that looks like this:
   # { code => 123, message => "" }
   # and we need to construct XML from it
#    if ($self->status && $self->status eq "fail")
#    {
#        my $xml = XML::LibXML::Document->new("1.0", "utf-8");
#        my $rsp = $xml->createElement("rsp");
#        $rsp->setAttribute("stat" => "fail");
#        my $element = $xml->createElement("err");
#        $element->setAttribute(
#          "code"    => Encode::encode("utf-8", $self->content->{code}, "1")
#        );
#        $element->setAttribute(
#          "message" => Encode::encode("utf-8", $self->content->{message}, "1")
#        );
#        
#        $xml->setDocumentElement($rsp);
#        return $xml;
#    }
   
   # okay, we've got a sucessful response.  Create the XML
   my $xml = XML::LibXML::Document->new("1.0", "utf-8");
   my $rsp = $xml->createElement("rsp");
   $rsp->setAttribute("stat" => $self->status );
   my $child = $self->_transform('TerseToXML',$self->content, $xml);
   $rsp->addChild( $child ) if $child;
   $xml->setDocumentElement($rsp);
   return $xml;
}

sub _transform {
    my $self = shift;
    my $walker_class = shift;  # the walker class defines what we're transforming to what
    my @args = @_;

    my $method = $self->structure
      or Froody::Error->throw("froody.convert.nomethod", "Response has no associated Froody Method!");

    # FIXME: Shouldn't a lack of structure indicate that we should be using the default
    # structure???
    my $spec = $method->structure
      or Froody::Error->throw("froody.convert.nostructure",
        "Associated method '".$method->full_name."' doesn't have a specification structure!");
    
    # create a new instance of the walker that processes our data
    $walker_class = "Froody::Walker::".$walker_class;
    $walker_class->require or Froody::Error->throw("perl.use","couldn't load class $walker_class");
    my $walker = $walker_class->new(@args);

    # and walk with it
    return $walker->walk($spec, $method->full_name);
}

=head2 Converting other Responses to Froody::Response::Terse objects

Once you've loaded this class you can automatically convert other
Froody::Response class instances to Froody::Response::Terse objects with
the C<as_terse> method.

  use Froody::Response::PerlDS;
  use Froody::Response::Terse;
  my $terse = Froody::Response::PerlDS
      ->new()
      ->structure($froody_method)
      ->content({ name => "foo", text => "bar" })
      ->as_terse;
  print ref($terse);  # prints "Froody::Response::Terse"

=cut

# as_terse is documented
sub as_terse { $_[0] }
sub Froody::Response::as_terse
{
  my $self = shift;
  
  # Er...I have no idea how to do this.  quick, let's turn
  # whatever we are into xml first!
  my $xml = $self->as_xml;
  
  # create a new terse
  my $terse = Froody::Response::Terse->new();
  $terse->structure($xml->structure);

  # walk the xml and set it as the content
  my ($node) = $xml->xml->findnodes("/rsp/*");
  $terse->content($terse->_transform("XMLToTerse", $node));  
  return $terse;
}

sub as_error
{
  my $self = shift;
  
  my $error = Froody::Error->new(
    $self->content->{code},
    $self->content->{message},
  );
  
  return Froody::Response::Error->new()
                                ->structure($self->structure)
                                ->set_error($error);
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

L<Froody>, L<Froody::Response>

=cut

1;
