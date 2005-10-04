=head1 NAME

Froody::Base - base class for Froody classes

=head1 DESCRIPTION

A base class for all Froody classes, provides useful methods.

=head1 METHODS

=over 4

=cut

package Froody::Base;

use warnings;
use strict;

use Params::Validate ();
use Froody::Error;

use Froody::Logger;
my $logger = get_logger("froody.base");

use base qw( Class::Accessor::Chained );

use UNIVERSAL::require;

use Carp qw(croak);

=item new()

A constructor.  Doesn't take any parameters.  Throws an exception if some
are passed.

=cut


sub new
{
  my $class = shift;
  
  my $fields = shift || {};
  
  my $self = $class->SUPER::new({(ref($class) ? %$class : ()), 
                                 %$fields
                                });
  $self->init;
  return $self;
}

=item init

Called from new.  Designed to be overridden.  Remember to call your
parent init!

=cut

sub init { return }

=item validate_class(@_, { ... })

A utility wrapper around Params::Validate that also makes sure that it's
being called as a class method, eg.

  sub class_method {
    my $class = shift;
    my %args = $class->validate_class(@_, { ... } )
    ...

see L<Params::Validate> for details on the function.

=cut

sub validate_class {
  my $class = shift;
  Froody::Error->throw("perl.methodcall.class", 
    "A class method was called in an instance context") if ref($class);
  $class->_validate(@_);
}

=item validate_object(@_, { ... })

A utility wrapper around Params::Validate that also makes sure that it's
being called as an object method, eg.

  sub object_method {
    my $self = shift;
    my %args = $self->validate_class(@_, { ... } )
    ...

see L<Params::Validate> for details on the function.

=cut

sub validate_object {
  my $self = shift;
  Froody::Error->throw("perl.methodcall.instance",
    "A instance method was called in object context ") unless ref($self);
  $self->_validate(@_);
}

=item validate_either(@_, { ... })

A utility wrapper around Params::Validate that does nothing else, for
methods that can be class or object methods.

  sub class_method {
    my $class = shift;
    my %args = $class->validate_either(@_, { ... } )
    ...

see L<Params::Validate> for details on the function.

=cut

sub validate_either {
  my $self = shift;
  $self->_validate(@_);
}

sub _validate {
  my $class = shift;
  my $spec = pop || {};
  local $Carp::CarpLevel = 4; # hide internals.
  my %h = eval { Params::Validate::validate(@_, $spec) };
  # TODO - it would be really nice to actually throw meta-information
  # about what is missing, what doesn't validate, etc..
  if ($@) {
    Froody::Error->throw("perl.methodcall.param", $@);
  }
  return %h;
}

=item require_module($module_name, $needed_method_name)

Loads the named module off of disk, or throws a nice error if
it can't for some reason.  Checks to see if the module supports
the needed method name too.

=cut

sub require_module {
  my $self        = shift;
  my $module_name = shift;
  my $method_name = shift;

  # are we already loaded?  Sweet.
  {
    no strict 'refs';
    return if %{"$module_name\::"};
  }
  # use the UNIVERSAL::require module to require the module
  # this returns false if the require fails, but this can be _both_ because
  # there were errors, _and_ if the file we expected doesn't exist, but
  # handlers _might_ be defined in differently named files.
  $module_name->require;

  if ( $UNIVERSAL::require::ERROR ) {
    $logger->error("Error compiling module $module_name: $UNIVERSAL::require::ERROR");
    Froody::Error->throw("perl.use", "module $module_name not found");
  }

  # now check to see if there is a package of the right name loaded.
  {
    no strict 'refs';
    unless (%{"$module_name\::"}) {
      # no stash defined, thus there's no package with the right name loaded.
      Froody::Error->throw("perl.use", "module $module_name does not exist");
    }
  }

  # if there was a syntax error, it looks like the stash _is_ defined, but
  # the module won't be able to do a method call.
  unless ( $module_name->can($method_name) ) {
    $logger->error("Error compiling module $module_name: $UNIVERSAL::require::ERROR");
    Froody::Error->throw("perl.use", "module $module_name cannot '$method_name'");
  }
}

1;

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
