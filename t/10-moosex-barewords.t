#!perl

use Test::More tests => 7;

require_ok("MooseX::Barewords");
can_ok("MooseX::Barewords", qw/has/);

create_test_class() or die $@;

my $obj = Test::Class->new( foo => 42 );

is(eval { $obj->foo }, 42, "foo attribute is set") or diag $@;
is(eval { $obj->ab(a => 1, b => 2) }, 3, "a + b args == 3") or diag $@;
is(eval { $obj->get_foo }, 42, "foo bareword returned attribute value") or diag $@;
is(eval { $obj->get_foo_override(foo => 2) }, 42 + 2, "foo is overridden") or diag $@;

#print eval { $obj->foo(-42) };
#is(eval { $obj->foo }, -42, "foo attribute is reset") or diag $@;
#like(eval { $obj->foo_ro(42) }, qr{asdasd}, "foo attribute is reset") or diag $@;

eval { $obj->ab };
like($@, qr{'a' is not defined}, "ab() failed without args") or diag $@;

#my $cb = $obj->cb;
#like($cb->(), 42, "callback works");

#=============================================================================
sub create_test_class {
    eval q[
        package Test::Class;

        use MooseX::Barewords;
        
        has foo => ( is => 'ro' );

        sub ab {
            return a + b; # return two attribute values
        };

        sub get_foo {
            return foo; # return attribute value
        };

        sub get_foo_override {
            return foo + self->foo; # return arg + attribute value
        };

        sub cb {
            return sub { self->get_foo };
        }

        1;
    ];
}
