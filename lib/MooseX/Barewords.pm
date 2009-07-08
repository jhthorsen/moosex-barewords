package MooseX::Barewords;

=head1 NAME

MooseX::Barewords - Does magical stuff with barewords in Moose methods

=head1 DESCRIPTION

This module has modified code from L<subs::auto>.

=head1 SYNOPSIS

 package Foo;

 use Moose;
 use MooseX::Barewords;

 has foo => (
    is => 'ro',
    isa => 'Str',
 );

 method my_method => sub {
    print self->foo; # this will always return the attribute value
    print foo;       # will print whatever $self->foo holds
                     # unless 'foo' is set in argument list
 };

 # this will make 'foo' bareword return 42 instead of
 # what $self->foo holds.
 $self->my_method(foo => 42); 

=cut

use Moose ();
use Moose::Exporter;
use Moose::Util::MetaRole;
use Symbol qw/gensym/;
use Variable::Magic qw/wizard cast dispell getdata/;
use constant DATA => 1;
use constant FUNC => 2;

our $VERSION = "0.01";
our $_SELF;
our %_ARGS;
our %_PACKAGES;

Moose::Exporter->setup_import_methods(
    with_caller => [qw/has method self/],
    also        => 'Moose',
);

=head1 FUNCTIONS

=head2 method

 method $name => sub { ... };

This will create a method, which can use barewords to access either
variables from parameter list or object attribute values.

See L<SYNOPSIS> for more information.

=cut

sub method {
    my $class = shift;
    my $name  = shift;
    my $sub   = shift;
    my $meta  = $class->meta;

    $class->meta->add_method($name => sub {
        my $self = shift;
        my $args = @_ == 1 ? $_[0] : {@_};

        $_ARGS{$_} = $args->{$_} for keys %$args;

        local $_SELF = $self;

        return $sub->(@_);
    });
}

=head2 has

 has $name => %args;

Same as L<Moose::has()>, but with some extra sugar to make barewords work
as expected.

Accessors will be prefixed with "__"

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
        if(!exists $options{'reader'} or !exists $options{'writer'}) {

            if(!exists $options{'writer'} and $options{'is'} eq 'rw') {
                $options{'writer'} = $accessor;
            }
            if(!exists $options{'reader'}) {
                $options{'reader'} ||= $accessor;
            }

            no strict 'refs';
            *{"$class\::$name"} = sub {
                if(Scalar::Util::blessed($_[0])) {
                    return shift->$accessor(@_);
                }
                else {
                    return exists $_ARGS{$name} ? $_ARGS{$name}
                         :                        $_SELF->$accessor;
                }
            };
        }
    }

    delete $options{'is'};

    for(@$attrs) {
        Class::MOP::Class->initialize($class)->add_attribute( $_, %options );
    }

    return;
}

=head2 self

 $self = self;

Will return the current object, inside a L<method()>.

=cut

sub self {
    return $_SELF;
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

    $_PACKAGES{$caller}++;

    no strict 'refs';

    # turn barewords into functions
    $^H{'subs__auto'} = 1;

    # do Variable::Magic on caller namespace
    cast %{"$caller\::"}, init_wizard(), $caller;
}

=head1 INTERNAL FUNCTIONS

=head2 init_wizard

 $wiz = init_wizard();

Will return a L<Variable::Magic> wizard, used on caller package.

=cut

sub init_wizard {
    my $tag  = wizard(data => sub { 1 });
    my %core = corelist_map();

    # $reset->($pkg, $func);
    my $reset = sub {
        my ($pkg, $func) = @_;
        my $fqn = join '::', @_;
        my $cb = do {
            no strict 'refs';
            no warnings 'once';
            *$fqn{CODE};
        };
        if($cb and getdata(&$cb, $tag)) {
            no strict 'refs';
            my $sym = gensym;
            for (qw/SCALAR ARRAY HASH IO FORMAT/) {
                no warnings 'once';
                *$sym = *$fqn{$_} if defined *$fqn{$_}
            }
            undef *$fqn;
            *$fqn = *$sym;
        }
    };

    my $wizard = wizard(
        data  => sub { +{ pkg => $_[1], guard => 0 } },
        store => sub {
            return if($_[DATA]->{'guard'});
            local $_[DATA]->{'guard'} = 1;
            $reset->($_[DATA]->{'pkg'}, $_[FUNC]);
            return;
        },
        fetch => sub {
            return if($_[DATA]->{'guard'});
            return if($_[FUNC] =~ /::/);
            return if(exists $core{$_[FUNC]});

            local $_[DATA]->{'guard'} = 1;

            my $hints = (caller 0)[10];
            my $func  = $_[FUNC];

            if($hints and $hints->{'subs__auto'}) {
                my $mod = "$func.pm";
                if(not exists $INC{$mod}) {
                    my $fqn = $_[DATA]->{'pkg'} . '::' . $func;
                    if(do { no strict 'refs'; not *$fqn{CODE} || *$fqn{IO}}) {
                        my $cb = sub () {
                            if(@_ and Scalar::Util::blessed(shift)) {
                                return $_SELF->$func(@_) 
                            }
                            else {
                                return $_ARGS{$func};
                            }
                        };
                        cast &$cb, $tag;
                        no strict 'refs';
                        *$fqn = $cb;
                    }
                }
            }
            else {
                $reset->($_[DATA]->{'pkg'}, $func);
            }

            return;
        },
    );

    return $wizard;
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
