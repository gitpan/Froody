#!perl

###########################################################################
# This does some fairly high level tests on Method and the associated XML
# parsing code.  We create some XML, feed it to Froody::API::XML and then
# check to see if the Method contains the right stuff
###########################################################################

use strict;
use warnings; 

use Test::More tests => 14;
use Test::Exception;
use Froody::API::XML;
use Froody::Response::PerlDS;
use Froody::Response::Terse;
use Data::Dumper;

use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

sub _spec {
    "<spec><methods>$_[0]</methods></spec>"
}
my $message = <<'END';
<method name="my.test.method" needslogin="1">
  <description>This is a test method</description>
  <arguments>
    <argument name="foo" optional="1">The optional foo argument</argument>
    <argument name="bar" optional="0" type="text">The non-optional bar argument</argument>
    <argument name="baz" type="multipart">This is required, too</argument>
    <argument name="shizzle" type="csv">Arguments are the shizniz</argument>
  </arguments>
  <response>
    <spell name="rezrov">
      <target>book</target>
      <target>stove</target>
      <description>Open anything</description>
    </spell>
  </response>
  <errors>
  </errors>
</method>
END

my ($method) = Froody::API::XML->load_spec(_spec($message));

is($method->full_name, 'my.test.method', 'full name');
is($method->service, 'my', 'service');
is($method->object,'Test', 'object');
is($method->name, 'method', 'name');
is($method->module, 'My::Test', "full module");
is($method->description, 
  'This is a test method',
  'description is correct');

use Params::Validate qw{:all};

my $arguments;

my $actual_arguments = $method->arguments;
ok delete $actual_arguments->{baz}{callbacks}, 
  "There is a callback hook for dealing with the multipart argument";
is_deeply($method->arguments, $arguments = {
   'bar' => {
            'type' => 1,
            'doc' => 'The non-optional bar argument',
            'optional' => '0',
            'usertype' => 'text'
          },
   'baz' => {
            'type' => 2,
            'doc' => 'This is required, too',
            'optional' => 0,
            'multiple' => 1,
            'usertype' => 'multipart'
          },
   'foo' => {
            'type' => 1,
            'doc' => 'The optional foo argument',
            'optional' => '1',
            'usertype' => 'text'
          },
   'shizzle' => {
                'type' => 2,
                'doc' => 'Arguments are the shizniz',
                'optional' => 0,
                'multiple' => 1,
                'usertype' => 'csv'
              }
}, "arguments with docs.") or diag Dumper $method->arguments;
  
my $errors;
is_deeply($method->errors, $errors = {
  }, "errors") or diag Dumper $method->errors;

my $structure;
is_deeply($method->structure, $structure = +{
   'spell/target' => {
                     'elts' => [],
                     'text' => 1,
                     'multi' => 1,
                     'attr' => []
                   },
   'spell' => {
              'elts' => [
                          'description',
                          'target'
                        ],
              'attr' => [
                          'name'
                        ]
            }
}) or diag Dumper($method->structure);

my $example_response = $method->example_response->as_terse->content;
is_deeply($example_response, +{
           'target' => [
                       'book',
                       'stove'
                     ],
           'name' => 'rezrov',
           'description' => 'Open anything'
        }) or diag(Dumper $example_response);

($method) = Froody::API::XML->load_spec(_spec(<<XML));
<method name="text.objcet.method" needslogin="0">
  <arguments></arguments>
  <description></description>
  <response>
    <value>0</value>
  </response>
  <errors></errors>
</method>
XML

is_deeply($method->structure, {
  value => { elts => [], text => 1, attr => []}
  },
  "When there is a top level element which only has CDATA, we have proper XPath.") 
    or diag Dumper($method->structure);

throws_ok {
($method) = Froody::API::XML->load_spec(_spec(<<XML));
<method name="text.method" needslogin="0">
  <arguments></arguments>
  <description></description>
  <response>
    <value>0</value>
  </response>
  <errors></errors>
</method>
XML
} "Froody::Error";

ok Froody::Error::err("perl.methodcall.param"), "method right type";
