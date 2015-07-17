package XT::Data::Money;

use Moose;

use overload (
    '""'        => \&_stringify,
    '+'         => \&_add,
    fallback    => 1,
);

use Carp;
use Moose::Util::TypeConstraints;
use MooseX::Types::LaxNum;
use Scalar::Util qw(blessed);
use XT::Data::Types qw(Currency);

=head1 NAME

XT::Data::Money - A monetary value

=head1 DESCRIPTION

This class represents a monetary value with currency

=head1 ATTRIBUTES

=head2 schema

=cut

with 'XTracker::Role::WithSchema';

=head2 currency

Must be one of USD, GBP, EUR, AUD, JPY, HKD, CNY, KRW

=cut

has currency => (
    is          => 'rw',
    isa         => Currency,
    required    => 1,
);

has currency_id => (
    is          => 'ro',
    writer      => undef,
    isa         => 'Int',
    lazy_build  => 1,
);

sub _build_currency_id {
    my ( $self ) = @_;

    return $self->schema->resultset('Public::Currency')->search({
        currency => $self->currency,
    })->first->id;
}

=head2 value

=cut

# We need this extra coercion step as 'Num' doesn't accept leading/trailing
# whitespace any more, and the 'Number' trait only works with a 'Num' type
subtype 'MoneyValue', as 'Num';
coerce 'MoneyValue', from 'LaxNum', via { $_+0 };

has value => (
    is          => 'rw',
    isa         => 'MoneyValue',
    default     => 0,
    traits      => ['Number'],
    handles     => {
        add_value       => 'add',
        subtract_value  => 'sub',
        multiply_value  => 'mul',
    },
    coerce => 1,
);

# overload addition operator

sub _add {
    my $a = shift;
    my $b = shift;

    croak 'You can only add two ' . __PACKAGE__ . ' objects together'
        unless $a || $b;

    unless ($a && $b) {
        my $money = $a || $b;
        croak 'You can only add zero to a ' . __PACKAGE__ . ' object'
            unless blessed($money) and $money->isa(__PACKAGE__);
        return __PACKAGE__->new (
            schema      => $money->schema,
            currency    => $money->currency,
            value       => $money->value,
        );
    }

    croak 'You can only add two ' . __PACKAGE__ . ' objects together'
        unless blessed($a) and $a->isa(__PACKAGE__) and blessed($b) and $b->isa(__PACKAGE__);

    croak 'Both Money objects must be of the same currency when adding together'
        unless $a->currency eq $b->currency;

    return __PACKAGE__->new(
        schema      => $a->schema,
        currency    => $a->currency,
        value       => $a->value + $b->value,
    );
}

# overload stringification

sub _stringify {
    my $self = shift;

    return sprintf('%s %0.2f', $self->currency, $self->value);
}

=head1 METHODS

=head2 clone

Returns a clone of this object

=cut

sub clone {
    my ($self, %params) = @_;
    return $self->meta->clone_object($self, %params);
}

=head1 AUTHOR

Pete Smith <pete.smith@net-a-porter.com>

=cut

__PACKAGE__->meta->make_immutable;

1;
