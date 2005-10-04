# test that loading of FAPI classes occur
package DTest::Test;
use base qw(Froody::Implementation);

use strict;
use warnings;

sub implements { DTest => "foo.test.*" }


sub add { return { '-text' => "\x{e9}" } }

sub getGroups { return { '-text' => "\x{2264}" } }

sub thunktest { 
  my ($class, $params) = @_;
  return { '-text' => $params->{foo} + 1 }
}

sub empty { return {} }

use Froody::Error;
sub haltandcatchfire {
  Froody::Error->throw('test.error', "I'm on fire", {
    fire => '++good',
    napster => '++ungood',
  });
}

1;
