=head1 NAME

Froody::SimpleClient

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

package Froody::SimpleClient;
use warnings;
use strict;
use base qw( Class::Accessor::Chained::Fast );
__PACKAGE__->mk_accessors(qw( endpoint ));

use LWP::UserAgent;
use JSON::Syck;
use HTTP::Request::Common;
use Encode qw( encode_utf8 );

=head1 ATTRIBUTES

=over

=item endpoint

=back

=head1 METHODS

=over

=item new( endpoint )

=cut

sub new {
  my $class = shift;
  my $endpoint = shift;
  my $self = $class->SUPER::new({ endpoint => $endpoint });
  $self->{ua} = LWP::UserAgent->new();
  return $self;
}

=item call( method, arg => value, arg => value, etc... )

=cut

sub call {
  my $self = shift;
  my $method = shift;
  my %args = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;

  # we want json
  $args{_froody_type} = "json";

  my $response = $self->call_raw($method, %args);
  
  # parse as Frooy/JSON response
  my $data = eval {
    local $JSON::Syck::ImplicitUnicode = 1; # bah.
    JSON::Syck::Load( $response );
  };
  unless (ref $data eq "HASH") {
    die "Error parsing ".$response.": $@";
  }
  unless ($data->{stat} eq 'ok') {
    Froody::Error->throw($data->{data}{code}, $data->{data}{msg}, $data->{data}{error});
  }
  return $data->{data};
}

=item call_raw( method, args )

makes a raw call, returns the exact thing returned by the server.

=cut

sub call_raw {
  my $self = shift;
  my $method = shift;
  my %args = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;
  
  die "no endpoint set" unless $self->endpoint;
  die "no UA" unless $self->{ua};

  # fudge args so we can do the Right Thing with lists and uploads.
  for (keys %args) {
    my $value = $args{$_};
    if (!defined $value) {
      delete $args{$_};
      next;
    }

    my $ref = ref($value);
    if ($ref eq 'ARRAY' and ref $value->[0] eq 'Froody::Upload') {
      # upload
      $args{$_} = [ $value->[0]->filename, $value->[0]->client_filename ];
      die "too many uploads" if $value->[1];

    } elsif ($ref eq 'ARRAY') {
      # just CSV
      $args{$_} = join(",", @$value );

    } elsif (ref($args{$_})) {
      die "can't handle type of argument '$_' (is a ".ref($args{$_}).")";
    } else {
      $args{$_} = encode_utf8( $args{$_} ) 
    }
  }

  # make the request
  my $request = POST( $self->endpoint,
    Content_Type => 'form-data',
    Content => [ method => $method, %args ] );
  my $response = $self->{ua}->request( $request );

  Froody::Error->throw('froody.invoke.remote', 'Bad response from server: '. $response->status_line)
    unless $response->is_success;

  return $response->content;
}

=back

=head1 AUTHOR

Copyright Fotango 2005.  All rights reserved.

Please see the main L<Froody> documentation for details of who has worked
on this project.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
