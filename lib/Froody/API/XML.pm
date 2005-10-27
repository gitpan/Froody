package Froody::API::XML;
use strict;
use warnings;
use XML::LibXML;
use Params::Validate ':types';
use Froody::Method;
use Froody::ErrorType;
use Froody::Response::XML;

use base qw(Froody::API);

use Scalar::Util qw(weaken);

=head1 NAME

Froody::API::XML - Define a Froody API with xml

=head1 SYNOPSIS

  package MyAPI;
  use base qw{Froody::API::XML};
  
  sub xml { 
    return q{
      <spec>
        <methods>
          <method name="foo">....</method>
        </methods>
      </spec>
    };
   }
   
   1;

=head1 DESCRIPTION

This class is a helper base class for Froody::API.  It can parse a standard
format of XML and turn it into a bunch of Froody::Method objects.

=head1 METHODS

=over

=item xml

Subclasses must override this method to provide an XML specification.

=cut

sub xml {
  Froody::Error->throw("perl.use", "Please override the abstract method Froody::API::XML::xml()");
}

=item load( xml )

Calls C<load_spec()> with the return value of the C<xml> method.

=cut

sub load {
  my $class = shift;
  return $class->load_spec($class->xml);
}

=item load_spec($xml_string)

Turns a method spec xml string into an array of
C<Froody::Method> objects.

=cut

sub load_spec {
  my ($class, $xml) = @_;
  unless ($xml)
   { Froody::Error->throw("perl.methodcall.param", "No xml passed to load_spec!") }
  
  my $parser = $class->parser;
  my $doc = eval { $parser->parse_string($xml) };

  if ($@)
    { Froody::Error->throw("froody.xml.invalid", "Invalid xml passed: $@") }

  my @methods = map { $class->load_method($_) }
    $doc->findnodes('/spec/methods/method')
      or Froody::Error->throw('froody.xml.nomethods', "no methods found in spec!");
    
  my @errortypes =map { $class->load_errortype($_) }
    $doc->findnodes('/spec/errortypes/errortype');

  return (@methods, @errortypes);
}

=item load_method($element)

Passed an XML::LibXML::Element that represents a <method>...</method>,
this returns an instance of Froody::Method that represents that method.

=cut

sub load_method {
  my ($class, $method_element) = @_;
  unless (UNIVERSAL::isa($method_element, 'XML::LibXML::Element')) {
    Froody::Error->throw("perl.methodcall.param",
                          "we were expected to be passed a XML::LibXML::Element!");
  }
  
  # work out the name of the element
  my ($name_element) = $method_element->findnodes('./@name')
    or Froody::Error->throw("froody.xml",
       "Can't find the attribute 'name' for the method definition within "
       .$method_element->toString);
  my $full_name = $name_element->nodeValue;

  # work out what the response should be
  my ($structure, $example);
  
  my ($response_element) = $class->_extract_response($method_element, $full_name);
  if ($response_element) {
    # TODO, This encoding is *all* wrong
    my $doc = XML::LibXML::Document->new( "1.0", "utf-8");
    my $rsp = $doc->createElement("rsp");
    $rsp->setAttribute("stat", "ok");
    $rsp->addChild($response_element);
    $doc->setDocumentElement($rsp);
    $example = Froody::Response::XML->new->xml( $doc );
    $structure = $class->_extract_structure($response_element);
  }

  # create a new method
  my $method = 
    Froody::Method->new()
                  ->full_name($full_name)
                  ->arguments($class->_arguments($method_element))
                  ->structure($structure || {})
                  ->errors($class->_errors($method_element))
                  ->needslogin($class->_needslogin($method_element));

  # set the example response's method
  # weaken it so we don't leak memory faster than a certain mac app that I
  # can't mention for libel reasons
  if ($example)
  {
    $example->structure($method);
    weaken($example->structure);
    $method->example_response($example);
  }
  
  my ($desc) = $method_element->findnodes("./description");
  $desc = $desc ? _entity_decode($desc->textContent) : '';
  $desc =~ s/^\s+//;
  $desc =~ s/\s+$//;
  $method->description($desc);

  return $method;
}

# okay, we're parsing this
#  <arguments>
#    <argument name="sex">male or female</argument>
#    <argument name="hair" optional="1">optionally list hair color</argument>
#    <argument name="hair" optional="1">optionally list hair color</argument>
#  </arguments>

sub _arguments {
  my ($class, $method_element) = @_;

  # get all of the argument elements
  my @argument_elements = $method_element->findnodes('./arguments/argument');

  # convert them into a big old hash
  my %arguments;
  foreach my $argument_element (@argument_elements)
  {
    # pull our the attributes
    my ($name_attr)     = $argument_element->findnodes('./@name');
    my ($optional_attr) = $argument_element->findnodes('./@optional');
    my ($type_attr)     = $argument_element->findnodes('./@type');

    # convert the elements to their values, with default values if needed
    my $type     = $type_attr ? $type_attr->nodeValue : 'text';
    my $name     = $name_attr->nodeValue;
    my $optional = $optional_attr ? $optional_attr->nodeValue : 0;

    # extract the contents of <argument>...</argument> as the description
    my $description = $argument_element->textContent;
    
    # examine the type and work out what that means
    my $multiple = ($type eq 'csv' || $type eq 'multipart');
    $arguments{$name}{multiple} = 1 if $multiple;
    $arguments{$name}{optional} = $optional;
    $arguments{$name}{doc}      = $description;
    # TODO: There should be some sort of type handling registration system, rather than
    # hardcoding the user types.
    $arguments{$name}{usertype} = $type;
    $arguments{$name}{type}     = $multiple ? ARRAYREF : SCALAR;
    if ($type eq 'multipart') {
      $arguments{$name}{callbacks} =
      { 'attribute "'.$name.'" requires an array of Froody::Upload objects' =>
        sub { !grep { !UNIVERSAL::isa($_, 'Froody::Upload') } @{$_[0]} } };
    }
    if ($type eq 'remaining') {
      $arguments{$name}{optional} = 1;
      $arguments{$name}{type} = HASHREF;
    }
  }

  return \%arguments;
}

# get the response element from the XML
sub _extract_response {
  my ($class, $dom, $full_name) = @_;
  my ($structure) = $dom->findnodes("./response");
  return unless $structure;  # we don't *have* to have a structure

  return $class->_extract_children($structure, $full_name);
}

sub _extract_children {
  my ($class, $structure, $full_name) = @_;

  my @child_nodes = $structure->childNodes;
  unless (grep { $_->isa('XML::LibXML::Element') } @child_nodes) {
    my $structure_xml = $structure->textContent;
    # TODO: After extracting the structure, we should
    # entity decode all of them and remove this crack

    # we don't need no steenkin' HTML::Entities ;)
    for ($structure_xml) {
      $_ = _entity_decode($_);

      # Eeevil - entity encode quotes inside quoted attribute
      # values
      s/"([^=><]+)"/ '"' . _entity_encode($1) . '"'/ge;
    }
    $structure_xml = '<rsp>'.$structure_xml.'</rsp>';

    my $structure_doc = $class->parser->parse_string($structure_xml);
    @child_nodes = $structure_doc->documentElement->childNodes();
  }
  @child_nodes = grep { $_->isa('XML::LibXML::Element') } @child_nodes;
  Froody::Error->throw("froody.xml", "Too many top level elements in the structure for $full_name")
    unless @child_nodes <= 1;

  return @child_nodes;
}

sub _extract_structure {
  my ($class, $dom) = @_;

  return unless $dom;
  return _xml_to_structure_hash($dom);
}

sub _text_only {
  my $entry = shift;
  return if exists $entry->{attr};
  return if exists $entry->{elts};
  return if exists $entry->{multi};
  return 1 if $entry->{text};
}

sub _xml_to_structure_hash {
  my $node = shift;

  # Each element is explained in the top level results hash.
  my $result;

  my $trans; #This allows us to call ourselves recursively.
  $trans = sub {
    my $node = shift;
    my $parent = shift;

    my $name = $node->nodeName;

    my $path = $parent ? "$parent/$name" : $name;

    # If seen, don't reprocess the children and mark it as multi.
    # This assumes that the content of the multiple entries are the same.
    $result->{$path}{multi} = 1, return
       if exists $result->{$path};
    $result->{$path}{attr}{$_} = 1 for ( map { $_->nodeName } $node->attributes);
    my @children = $node->childNodes;
    $result->{$path}{text} = 1 if grep { $_->isa('XML::LibXML::Text') 
                                        && $_->textContent =~ /\S/ } @children;
    @children = grep { $_->isa('XML::LibXML::Element') } @children;
    $result->{$path}{elts}{$_} = 1 for (map { $_->nodeName }  @children );
    foreach (@children) {
      $trans->($_, $path);
    }
    foreach (@children) {
      my $childkey = join('/', $path, $_->nodeName);
      if (my $ret = $result->{$childkey}) {
      delete $result->{$childkey}
        if _text_only($result->{$childkey});
      }
    }
  };

  $trans->($node, '');

  foreach my $key (keys %$result) {
    foreach (qw{attr elts}) {
      $result->{$key}{$_} = [ sort keys %{$result->{$key}{$_}} ]
    }
  }

  return $result;
      # TODO: Handling types is a Service level detail.
}


sub _entity_encode {
  my $str = shift;
  for ($str) {
    s/&/&amp;/g;
    s/</&lt;/g;
    s/>/&gt;/g;
    s/'/&apos;/g;
    s/"/&quot;/g;
  }
  return $str;
}

sub _entity_decode {
  my $str = shift;
  for ($str) {
    s/&lt;/</g;
    s/&gt;/>/g;
    s/&apos;/\'/g;
    s/&quot;/\"/g;
  }
  return $str;
}



sub _errors {
  my ($class, $method_element) = @_;

  # extract out the error methods
  my @error_elements = $method_element->findnodes('./errors/error');

  # build them into a hash
  my %errors;
  foreach my $error_element (@error_elements) { 
  
    # extract the attributes
    my ($code_attr)    = $error_element->findnodes('./@code');
    my ($message_attr) = $error_element->findnodes('./@message');

    # convert them into a a hash that has the error number as the
    # key, and contains a hashref with a message and description in it
    my $description = $error_element->textContent;
    $description =~ s/^\s+//;
    $description =~ s/\s+$//;
    $errors{ $code_attr->nodeValue } = {
      message     => $message_attr ? $message_attr->nodeValue : '', 
      description => $description
    };
  }

  return \%errors;
}

# returns true if the method element passed needs a login, i.e. has
# an attribute <method needslogin="1">.  Returns false in all other cases
sub _needslogin {
  my ($class, $method_element) = @_;
  my ($needslogin_attr) = $method_element->findnodes('./@needslogin');
  return 0 unless $needslogin_attr;

  return $needslogin_attr->nodeValue eq '1' ? 1 : 0;
}

=item load_errortype

Passed an XML::LibXML::Element that represents an <errortype>...</errortype>,
this returns an instance of Froody::ErrorType that represents that error type.

=cut

sub load_errortype  {
  my ($class, $et_element) = @_;
  unless (UNIVERSAL::isa($et_element, 'XML::LibXML::Element')) {
    Froody::Error->throw("perl.methodcall.param",
                          "we were expected to be passed a XML::LibXML::Element!");
  }
  
  # work out the name of the element
  my ($name) = $et_element->findvalue('./@code')
    or Froody::Error->throw("froody.xml",
       "Can't find the attribute 'code' for the error definition within "
       .$et_element->toString);

  my $et = Froody::ErrorType->new;
  $et->name($name);

  my $spec = $class->_extract_structure($et_element);
  
  foreach (keys %$spec) {
    my $val = delete $spec->{$_};
    s{^errortype}{err};  # 'errortype's are really 'err's
    $spec->{$_} = $val;
  }

  my $example;
  if ($spec) {
    # TODO, This encoding is *all* wrong
    my $doc = XML::LibXML::Document->new( "1.0", "utf-8");
    my $rsp = $doc->createElement("rsp");
    $rsp->setAttribute("stat", "ok");
    $rsp->addChild($et_element);
    $doc->setDocumentElement($rsp);
    $example = Froody::Response::XML->new->xml( $doc );
  }

  # enforce msg (code is already in here!)
  push @{ $spec->{err}{attr} }, "msg";
  
  # set the structure
  $et->structure($spec);
  $et->example_response($example);

  return $et
}

=item parser

This method returns the parser we're using.  It's an instance of XML::LibXML.

=cut

{
  my $parser = XML::LibXML->new;
  sub parser { $parser }
}

=back

=head1 SPEC OVERVIEW

The specs handed to C<register_spec()> should be on this form:

  <spec>
    <methods>
      <method ...> </method>
      ...
    </methods>
    <errortypes>
       <errortype code="error.subtype">...</errortype>
       ...
    </errortypes>
  </spec>


=head2 <method>

Each method take this form:

  <method name="foo.bar.quux" needslogin="1">
    <description>Very short description of method's basic behaviour</description>
    <keywords>...</keywords>
    <arguments>...</arguments>
    <response>...</response>
    <errors>...</errors>
  </method>

=over

=item <keywords>

A space-separated list of keywords of the concepts touched upon
by this method. As an example, clockthat.events.addTags would
have "events tags" as its keywords. This way we can easily list
all methods that deals with tags, no matter where in the
namespace they live.

=item <arguments>

Each argument has two mandatory attributes: "name" and
"optional". The name is the name of the argument, and optional is
"1" if the argument is optional, or "0" otherwise.

  <argument name="api_key" optional="0">A non-optional argument</argument>
  <argument name="quux_id" optional="1">An optional argument</argument>

You can specify that your argument should accept a comma-separated list of values:

  <argument name="array_val" type="csv" optional="1">Don't
    worry about description for argument type deduction now.</argument>

=item <response>

A well-formed XML fragment (excluding the <rsp> tag) describing
by example how this method will respond. This section can be
empty if the method does not return. When a list of elements are
expected, your example response B<must contain at least two>
elements of the same name.

  <photoset page="1" per_page="10" pages="9" total="83">
    <name>beyond repair</name>
    <photo photo_id="1123" />
    <photo photo_id="2345" />
  </photos>

Currently we accept both a well-formed XML fragment and an
entity-encoded string that can be decoded to an XML fragment.

=item <errors>

A list of errors of this form:

  <error code="1" message="Short message">Longer error message</error>

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
