=head1 NAME

Froody::Server::Test

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

package Froody::Server::Test;
use warnings;
use strict;
use Froody::Dispatch;

=head1 METHODS

=over

=item client( 'Froody::Service', 'Froody::Service', .. )

Starts a standalone Froody server, implementing the passed service classes,
and returns a Froody::Client object that will talk to the server, for local
testing of implementations. The server will be stopped on script exit.

=cut

# This is our random port, which is an attempt to not tromp over other users who might
# be testing their own froody clients at the same time.
my $port = 30_000 + ( $> % 400 );

my $child;

# start the web server
sub client {
  my ($class, @impl) = @_;
  
  unless ($child = fork()) {
  
    # loading Froody::Server::Standalone does some things
    # to our enviroment (for example, it piddles with the SIG handlers
    # so we only want to do that in the child.)
  
    eval q[ use lib 't/lib'; ]; die $@ if $@;
    for (@impl) {
      eval qq[ use $_ ]; die $@ if $@;
    }
    eval q[ use Froody::Server::Standalone; ]; die $@ if $@;
    
    my $server = Froody::Server::Standalone->new();
    $server->port($port);
    $server->run;
  }
  
  sleep 1;
  my $client = Froody::Dispatch->new();
  $client->repository( Froody::Repository->new() );
  $client->add_endpoint("http://localhost:$port");
  return $client;
}


END {
  if ($child) {
    # what the gosh-darn signals numbered on this box then?
    use Config;
    defined $Config{sig_name} || die "No sigs?";
    my ($i, %signo);
    foreach my $name (split(' ', $Config{sig_name})) {
       $signo{$name} = $i;
       $i++;
    }
    
    # die with more and more nastyness
    for my $signal (qw(TERM KILL)) {
      kill $signo{$signal}, $child;
      exit unless kill 0, $child;
      sleep 1;
    }
  }
}

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

=cut

1;
