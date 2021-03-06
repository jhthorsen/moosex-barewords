#!perl

use Test::More tests => 10;

require_ok("MooseX::Barewords");
can_ok("MooseX::Barewords", qw/has/);

create_test_class() or die $@;

my $obj = Test::Class->new( foo => 42 );

# foo
is(eval { $obj->foo }, 42, "foo attribute is set") or diag $@;
is(eval { $obj->get_foo }, 42, "foo bareword returned attribute value") or diag $@;
is(eval { $obj->get_foo_override(foo => 2) }, 42 + 2, "foo is overridden") or diag $@;
eval { $obj->foo(42) };
like($@, qr{Cannot assign a value}i, "foo attribute is ro") or diag $@;

# arguments
is(eval { $obj->ab(a => 1, b => 2) }, 3, "a + b args == 3") or diag $@;
eval { $obj->ab };
like($@, qr{'a' is not defined}, "ab() failed without args") or diag $@;

# foo_rw
eval { $obj->foo_rw(-42); 1 } or diag $@;
is(eval { $obj->foo_rw }, -42, "foo_rw attribute is set") or diag $@;
is(eval { $obj->set_foo_rw(to => 10) }, 10, "foo_rw bareword is set") or diag $@;

#my $cb = $obj->cb;
#like($cb->(), 42, "callback works");

#=============================================================================
sub create_test_class {
    eval q[
        package Test::Class;

        use MooseX::Barewords;
        
        has foo => ( is => 'ro', isa => 'Int' );
        has foo_rw => ( is => 'rw', isa => 'Int' );

        sub ab {
            return a + b; # return two attribute values
        };

        sub get_foo {
            return foo; # return attribute value
        };

        sub get_foo_override {
            return foo + self->foo; # return arg + attribute value
        };

        sub set_foo_rw {
            # foo_rw(to) results in a warning:
            # "Test::Class::foo_rw() called too early to check
            # prototype at (eval 208) line 22."
            self->foo_rw(to);
            return foo_rw;
        }

        sub cb {
            return sub { self->get_foo };
        }

        1;
    ];
}
