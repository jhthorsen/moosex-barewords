#!perl

use Test::More tests => 5;

require_ok("MooseX::MagicVar");
can_ok("MooseX::MagicVar", qw/method/);

create_test_class() or die $@;

my $obj = Test::Class->new( foo => 42 );

is($obj->foo, 42, "foo attribute is set");
is($obj->test(a => 1, b => 2), 3, "a + b is set");
is($obj->get_foo, 42, "get_foo() returned correct value");
is($obj->get_foo_override(foo => 2), 42 + 2, "foo is overridden");

#=============================================================================
sub create_test_class {
    eval q[
        package Test::Class;

        use Moose;
        use MooseX::MagicVar;
        
        has foo => ( is => 'ro', isa => 'Int' );

        method test => sub {
            return a + b;
        };

        method get_foo => sub {
            return foo;
        };

        method get_foo_override => sub {
            return foo + self->foo;
        };
    ];
}
