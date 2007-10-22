package Froody::Renderer::json;
use strict;
use warnings;

use JSON::XS qw( to_json );

use Froody::Response;
use Froody::Response::Terse;
use Encode;

# If we don't know how to do it ourselves, convert to
# a terse and try again
*Froody::Response::render_json = sub {
  my $self = shift;
  return $self->as_terse->render_json;
};

# Terse format just gets the main data structure out
# and renders it with JSON
*Froody::Response::Terse::render_json = sub {
  my $self = shift;
  my $callback = $self->callback;
  my $bytes = to_json( { stat => $self->status, data => $self->content } );
  return $callback ? "$callback( $bytes )" : $bytes;
};

1;