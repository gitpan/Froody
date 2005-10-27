package Testproject::Object;
use base qw(Froody::Implementation);
sub implements { "Testproject::API" => "testproject.object.*" }

use strict;
use warnings;
use List::Util 'reduce';

sub method {
   return {};
}

sub text {

}

sub sum {
    my ($self, $args) = @_;
    return reduce { $a + $b } @{$args->{values}}
}

sub range {
    my ($self, $args) = @_;
    return { value => [$args->{base} - $args->{offset},
           $args->{base} + $args->{offset}
          ] };
}

sub range2 {
    my ($self, $args) = @_;
    return { value => [{ num => $args->{base} - $args->{offset} },
           { num => $args->{base} + $args->{offset} },
          ]};
}

sub extra {
    return { blah => 'bleh' };
}

sub texttest {
    return { next => 100, blah => "foo\nhate\n"};
}

sub params {
  my ($invoker, $args) = @_;
  return scalar keys %{ $args->{the_rest} };
}

1;
