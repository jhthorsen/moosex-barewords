package MooseX::MagicVar;

=head1 NAME

MooseX::MagicVar

=head1 DESCRIPTION

This module has modified code from L<subs::auto>.

=head1 SYNOPSIS

 package Foo;

 use Moose;
 use MooseX::MagicVar;

 has foo => (
    is => 'ro',
    isa => 'Str',
 );

 method mymethod => sub {
    # ...
 };

=cut

use Moose;
use Symbol qw/gensym/;
use Variable::Magic qw/wizard cast dispell getdata/;
use constant DATA => 1;
use constant FUNC => 2;

our $_SELF;
our %_ARGS;
our %_PACKAGES;

my %core = corelist_map();
my $tag  = wizard(data => sub { 1 });
my $wiz  = wizard(
               data  => sub { +{ pkg => $_[1], guard => 0 } },
               fetch => \&_fetch,
               store => \&_store,
           );

#CHECK {
#    no warnings 'void';
#    no strict 'refs';
#    dispell %{"$_\::"}, $wiz for keys %_PACKAGES;
#}

# $wiz->_store($data, $Str)
sub _store {
    return if($_[DATA]->{'guard'});
    local $_[DATA]->{'guard'} = 1;
    _reset($_[DATA]->{'pkg'}, $_[FUNC]);
    return;
}

# $wiz->_fetch($data, $Str)
sub _fetch {
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
                    return $_SELF->$func(@_) if(@_ and blessed shift);
                    return $_ARGS{$func};
                };
                cast &$cb, $tag;
                no strict 'refs';
                *$fqn = $cb;
            }
        }
    }
    else {
        _reset($_[DATA]->{'pkg'}, $func);
    }

    return;
}

# _reset($pkg, $func);
sub _reset {
    my ($pkg, $func) = @_;
    my $fqn = join '::', @_;
    my $cb = do {
        no strict 'refs';
        no warnings 'once';
        *$fqn{CODE};
    };
    if ($cb and getdata(&$cb, $tag)) {
        no strict 'refs';
        my $sym = gensym;
        for (qw/SCALAR ARRAY HASH IO FORMAT/) {
            no warnings 'once';
            *$sym = *$fqn{$_} if defined *$fqn{$_}
        }
        undef *$fqn;
        *$fqn = *$sym;
    }
}

# $bool = _is_bareword($fqn);
sub _is_bareword {
    my $fqn = $_[0];
    no strict 'refs';
    return ! (*$fqn{'CODE'} || *$fqn{'IO'});
}

=head1 FUNCTIONS

=head2 method

 method $name => sub { ... };

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

=cut

sub _attr_to_constant {
}

sub _arg_to_constant {
    my $self = shift;
    my $name = shift;
    my $args = shift;

    for(0..HERE) {
        warn "$_ => ", (caller $_)[2];
    }

    warn "$self => $name => $args->{$name}\n";

    if($self->can($name)) {
        localize $name => sub {
            warn $name, $args->{$name};
            #return shift->$name(@_) if(@_);
            return $args->{$name};
        } => SCOPE 2;
    }
    else {
        localize $name => sub {
            warn $name, $args->{$name};
            $args->{$name}
        } => SCOPE 2;
    }
}

=cut

=head2 import

 $class->import;

Will export C<self()> and C<method()>.

=cut

sub import {
    my $class  = shift;
    my $caller = caller;

    return if($caller eq 'main');

    $_PACKAGES{$caller}++;
    no strict 'refs';

    # export method() and self()
    *{"$caller\::method"} = sub { method($caller, @_) };
    *{"$caller\::self"} = sub { $_SELF };

    # turn barewords into functions
    $^H{'subs__auto'} = 1;

    # do Variable::Magic on caller namespace
    cast %{"$caller\::"}, $wiz, $caller;
}

=head2 unimport

 $class->unimport;

=cut

sub unimport {
    $^H{'subs__auto'} = 0;
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
