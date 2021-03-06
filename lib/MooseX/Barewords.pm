package MooseX::Barewords;

=head1 NAME

MooseX::Barewords - Turn barewords into attribute/argument getters

=head1 DESCRIPTION

The idea is to make C<$self> look like an object and avoid shifting off
arguments given to a method.

This module is a proof of concept and will probably never be published
on CPAN.

=head1 SEE ALSO

L<MooseX::Method::Signatures>, L<subs::auto>, L<self> and L<selfvars>.

=head1 SYNOPSIS

 package Foo;

 use MooseX::Barewords;

 has foo => ( is => 'ro' );

 sub my_method {
    print self->foo; # this will always return the attribute value
    print foo;       # will print whatever $self->foo holds
                     # unless 'foo' is set in argument list
                     # should that be considered a bug or feature..? ;)
 }

 sub add {
    print a + b;
 }

 # this will make 'foo' bareword return 42 instead of
 # what $self->foo holds.
 $self->my_method(foo => 42); 

 # will print 66
 $self->add(a => 42, b => 24);

 # will die since "a" and "b" are not given as arguments
 $self->add(foo => 1);

=cut

use Moose ();
use Moose::Exporter;
use Moose::Util::MetaRole;
use Symbol qw/gensym/;
use Variable::Magic qw/wizard cast dispell getdata/;
use constant DATA => 1;
use constant FUNC => 2;

our $VERSION = "0.01";

Moose::Exporter->setup_import_methods(
    with_caller => [qw/has self/],
    also        => 'Moose',
);

=head1 FUNCTIONS

=head2 self

 $self = self;

Returns the current object in caller method.

=cut

sub self {
    package DB;
    () = caller(2); # set DB:: to work on the right level
    return $DB::args[0];
}

=head2 has

 has $name => %args;

Same as L<Moose::has()>, but with some extra sugar to make barewords work
as expected.

Accessor will be prefixed with "__", but can still be accessed by C<$name>:

 $acc = "__$name";
 $self->$name eq $self->$acc; # true

=cut

sub has {
    my $class = shift;
    my $name  = shift;

    if(@_ % 2 == 1) {
        Moose->throw_error('Usage: has \'name\' => ( key => value, ... )');
    }

    my %options  = ( definition_context => Moose::Util::_caller_info(), @_ );
    my $attrs    = ref($name) eq 'ARRAY' ? $name : [ $name ];
    my $accessor = "__$name";

    if($options{'is'}) {
        if($options{'is'} eq 'rw') {
            $options{'accessor'} = $accessor;
        }
        else {
            $options{'reader'} = $accessor;
        }
        delete $options{'is'};
        no strict 'refs';
        *{"$class\::$name"} = sub { get_attr($name, @_) };
    }

    for(@$attrs) {
        Class::MOP::Class->initialize($class)->add_attribute( $_, %options );
    }

    return;
}

=head2 init_meta

 $class->init_meta(%options);

Called on C<import()>. Will set up L<Variable::Magic> on caller package and
turn all barewords into subs.

=cut

sub init_meta {
    my $class   = shift;
    my %options = @_;
    my $caller  = $options{'for_class'};

    # turn barewords into functions
    $^H{'subs__auto'} = 1;

    # do Variable::Magic on caller namespace
    no strict 'refs';
    cast %{"$caller\::"}, init_wizard(), $caller;
}

=head1 INTERNAL FUNCTIONS

=head2 get_attr

 $value = get_attr($name, @args);

Will return either the argument or attribute valued named C<$name>, or
confess if no such arg/attr exists.

Arguments will be prioritized over attributes names.

=cut

sub get_attr {
    my $name  = shift || '__UNDEF__';
    my @args  = @_;
    my $acc   = "__$name";
    my $level = 4;
    my $obj;

    if(@args) {
        $obj = shift @args if(Scalar::Util::blessed($args[0]));
    }
    elsif(my $value = eval { get_arg($name, $level) }) {
        return $value;
    }

    if(!$obj) {
        package DB;
        ()   = caller($level - 1); # make DB:: work on the correct level
        $obj = $DB::args[0];
    }

    if($obj and $obj->can($acc)) {
        return $obj->$acc(@args);
    }
    else {
        local $Carp::CarpLevel = $level - 1; # skip stacktrace from this module
        Carp::confess("'$name' attribute is not defined");
    }
}

=head2 get_arg 

 $value = get_arg($name, $level);

Will return the argument named C<$name> or confess if no such argument
exists in caller method.

=cut

sub get_arg {
    my $name  = shift || '__UNDEF__';
    my $level = shift || 1;

    package DB;
    () = caller($level); # make DB:: work on the correct level

    my @tmp  = @DB::args[1..@DB::args - 1];
    my $args = ref $tmp[0] eq 'HASH' ? $tmp[0]
             : @tmp % 2 == 0         ? {@tmp}
             :                         {};

    if(exists $args->{$name}) {
        return $args->{$name};
    }
    else {
        local $Carp::CarpLevel = $level; # skip stacktrace from this module
        Carp::confess("'$name' is not defined");
    }
}

=head2 init_wizard

 $wiz = init_wizard();

Will return a L<Variable::Magic> wizard, used on caller package.

=cut

sub init_wizard {
    my $tag  = wizard(data => sub { 1 });
    my %core = corelist_map();

    my $wizard = wizard(
        data  => sub { +{ pkg => $_[1], guard => 0 } },
        store => sub {
            return if($_[DATA]->{'guard'});
            local $_[DATA]->{'guard'} = 1;
            _reset($tag, $_[DATA]->{'pkg'}, $_[FUNC]);
            return;
        },
        fetch => sub {
            return if($_[DATA]->{'guard'});
            return if($_[FUNC] =~ /::/);
            return if(exists $core{$_[FUNC]});

            local $_[DATA]->{'guard'} = 1;

            my $hints = (caller 0)[10];
            my $pkg   = $_[DATA]->{'pkg'};
            my $func  = $_[FUNC];
            my $mod   = "$func.pm";

            if($hints and $hints->{'subs__auto'}) {
                if(not exists $INC{$mod}) {
                    no strict 'refs';
                    my $fqn = $pkg . '::' . $func;
                    *$fqn{'CODE'} || *$fqn{'IO'} and return;
                    my $cb = sub () { get_arg($func, 2) };
                    cast &$cb, $tag;
                    *$fqn = $cb;
                }
            }
            else {
                _reset($tag, $pkg, $func);
            }

            return;
        },
    );

    return $wizard;
}

# _reset($tag, $pkg, $func);
sub _reset {
    my $tag = shift;
    my $fqn = join '::', @_;
    my $cb  = do { no strict 'refs'; no warnings 'once'; *$fqn{'CODE'} };

    return unless($cb and getdata(&$cb, $tag));

    no strict 'refs';
    my $sym = gensym;

    for(qw/SCALAR ARRAY HASH IO FORMAT/) {
        *$sym = *$fqn{$_} if defined *$fqn{$_}
    }

    *$fqn = *$sym;
}

=head2 corelist_map

 %corelist = corelist_map();

Returns a hash, where the keys are the names of the core functions.

=cut

sub corelist_map {
    return map { $_ => 1 } qw/
        abs accept alarm atan2 bind binmode bless break caller chdir
        chmod chomp chop chown chr chroot close closedir connect
        continue cos crypt dbmclose dbmopen default defined delete die
        do dump each endgrent endhostent endnetent endprotoent endpwent
        endservent eof eval exec exists exit exp fcntl fileno flock fork
        format formline getc getgrent getgrgid getgrnam gethostbyaddr
        gethostbyname gethostent getlogin getnetbyaddr getnetbyname
        getnetent getpeername getpgrp getppid getpriority getprotobyname
        getprotobynumber getprotoent getpwent getpwnam getpwuid
        getservbyname getservbyport getservent getsockname getsockopt
        given glob gmtime goto grep hex index int ioctl join keys kill
        last lc lcfirst length link listen local localtime lock log
        lstat map mkdir msgctl msgget msgrcv msgsnd my next no oct open
        opendir ord our pack package pipe pop pos print printf prototype
        push quotemeta rand read readdir readline readlink readpipe recv
        redo ref rename require reset return reverse rewinddir rindex
        rmdir say scalar seek seekdir select semctl semget semop send
        setgrent sethostent setnetent setpgrp setpriority setprotoent
        setpwent setservent setsockopt shift shmctl shmget shmread
        shmwrite shutdown sin sleep socket socketpair sort splice split
        sprintf sqrt srand stat state study sub substr symlink syscall
        sysopen sysread sysseek system syswrite tell telldir tie tied
        time times truncate uc ucfirst umask undef unlink unpack unshift
        untie use utime values vec wait waitpid wantarray warn when
        write not __LINE__ __FILE__ DATA/;
}

=head1 AUTHOR

Jan Henning Thorsen

=cut

1;
