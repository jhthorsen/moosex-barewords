#!perl

use Test::More tests => 5;

require_ok("MooseX::Barewords");
can_ok("MooseX::Barewords", qw/bmethod/);

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

        use MooseX::Barewords;
        
        has foo => ( is => 'ro', isa => 'Int' );

        bmethod test => sub {
            return a + b;
        };

        bmethod get_foo => sub {
            return foo;
        };

        bmethod get_foo_override => sub {
            return foo + self->foo;
        };
    ];
}