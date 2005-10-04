package Froody::Implementation;

use strict;
use warnings;

our $VERSION = "0.01";

use Scalar::Util qw(blessed);
use List::MoreUtils qw(any);

use Froody::Error;

use Froody::Logger;
my $logger = Froody::Logger->get_logger("Froody::Implementation");

use UNIVERSAL::require;
# NOTE: this is not a subclass of Froody::Base!
# people should be able to use their own superclass for new et al

sub register_in_repository
{
  my $class       = shift;
  my $repository  = shift;

  # what of this API do we implement?
  my ($api_class, @method_matches) = $class->implements;
  return unless $api_class; # Allow for superclasses doing crazy things.
  @method_matches = map { Froody::Method->match_to_regex( $_ ) } @method_matches;

  # load the api
  $api_class->require
    or Froody::Error->throw("perl.use", "unknown or broken API class: $api_class");

  # create an invoker instance
  my $invoker_class = $class->invoker_class;
  $invoker_class->require
    or Froody::Error->throw("perl.use", "unknown or broken Invoker class: $invoker_class");
  my $inv = $invoker_class->new()
                          ->delegate_class($class);

  # process each thing based on it's type
  foreach my $thingy ($api_class->load())
  {
    # froody method?  Set the invoker and register it
    if (blessed($thingy) && $thingy->isa("Froody::Method"))
    {
      my $full_name = $thingy->full_name;
      next unless any { $full_name =~ $_ } @method_matches;
      $repository->register_method($thingy);
      $thingy->invoker($inv);
      next;
    }
    
    # froody errortype?  register the error type
    if (blessed($thingy) && $thingy->isa("Froody::ErrorType"))
    {
      $repository->register_errortype($thingy);
      next;
    }

    # hmm, unknown
    $logger->info("unknown thingy back from ->load: $thingy");
 }

 return
}

sub implements {
   Froody::Error->throw("perl.methodcall.unimplemented",
                        "You must define an 'implements' method in '$_[0]'")
}

# this is defined here because someday someone might subclass
# Froody::Invoker::Implementation and it would be nice to not force
# them to rewrite Froody::Implementation
sub invoker_class { "Froody::Invoker::Implementation" }

1;

__END__

# Module::Build::Kwalitee wants us to declare =item or =head with our method
# names to show we've documented them, but it doesn't work well with the
# tutorial style of the current pod.  Let's just declare they're documented
# with the magic strings in the following comments:
#
# register_in_repository is documented

=head1 NAME

Froody::Implementation - define Perl methods to implement Froody::Method 

=head1 SYNOPSIS

  package MyCompany::PerlMethods::Time;
  use base qw(Froody::Implementation);

  # say what api you're implementing, and what subset of those methods
  # should be handled by perl methods in this class
  sub implements { "MyCompany::API" => "mycompany.timequery.*" }

  use DateTime;
 
  # this is mycompany.timequery.gettime
  sub gettime
  {
     my $self = shift;
     my $args = shift;

     $now = DateTime->now;
     $now->set_time_zone($args->{time_zone}) if $args->{time_zone};
     return $now->datetime;
  }
  
  ...

=head1 DESCRIPTION

This class is a simple base class that allows you to quickly and simply
provide code for Froody to run when it needs to execute a method.

=head2 How to write your methods

It's fairly straightforward to write methods for Froody, and is best demonstrated
with an example.  Imagine we've got a Froody::Method that's been defined
like so:

  package PerlService::API;
  use base qw(Froody::API::XML);
  1;
  
  sub xml { <<'XML';
  <spec>
   <methods>
    <method name="perlservice.corelist.released">
      <arguments>
        <argument name="module" type="text" optional="0" />
      </arguments>
      <response>
        <module name="">
          <in version=""></in>
        </module>
      </response>
    </method>
   </methods>
  </spec>
  XML

We are now ready to start writing a class implementing this API:

  package MyCompany::PerlMethods;
  use base qw(Froody::Implementation);
  
  sub implements { "MyCompany::API" => "mycompany.timequery.datetime" }

The methods will be called with two parameters, a
L<Froody::Invoker::Implementation> object and a hashref containing the method
arguments.  The arguments will have already been pre-processed to verify that
they are all there and of the right type, for example. Look at
L<Froody::Invoker::Implementation> if you want to change the behaviour of this
pre-processing (you can use this to implement authentication common for all
methods, for example).

=head2 Abstract methods

=over

=item implements()

Should return a hash of 

  Namespace => 'method.names.*'

mappings specifying in what modules the given methods are
implemented.

=back

=head2 Instance methods

=over

=item invoker_class()

Returns the class of the invoker. Override this if you need to do
fancy checking in the invoker (for sessions or similar).

=back


=head1 BUGS

You can't use this to run code for a Froody::Method whose full name
ends with ".implements", ".invoker_class" or ".register_in_repository" as
those methods are special.  Sorry.

Please report any bugs you find via the CPAN RT system.
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Froody>

=head1 AUTHOR

Copyright Fotango 2005.  All rights reserved.

Please see the main L<Froody> documentation for details of who has worked
on this project.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<Froody>, L<Froody::Invoker::Implementation>

=cut

1;

