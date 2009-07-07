package MooseX::MagicVar;

=head1 NAME

MooseX::MagicVar

=head1 SYNOPSIS

 package Foo;

 use Moose;
 use MooseX::MagicVar;

 has foo => (
    is => 'ro',
    isa => 'Str',
 );

 method mymethod => sub {
 };

=cut

use Moose;

=head1 AUTHOR

Jan Henning Thorsen

=cut

1;
