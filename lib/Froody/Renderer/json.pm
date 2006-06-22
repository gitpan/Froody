package Froody::Renderer::json;
use strict;
use warnings;

use JSON;

use Froody::Response;
use Froody::Response::Terse;

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
  return objToJson({ stat => $self->status, data => $self->content });
};

use Froody::Server;
Froody::Server->content_type_for_type(
  json => 'text/json'
);

1;