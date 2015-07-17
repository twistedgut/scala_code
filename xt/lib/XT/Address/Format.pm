package XT::Address::Format;
use NAP::policy 'class';

=head1 NAME

XT::Address::Format

=head1 DESCRIPTION

A base class for XT::Address::Format::* plugins for L<XT::Address>.

=head1 SYNOPSIS

    package XT::Address::Format::MyFormat;
    use NAP::policy 'class';

    extends 'XT::Address::Format';

=head1 ATTRIBUTES

=head2 address

A reference to the L<XT::Address> object that was used to invoke this plugin.

=head2 schema

A schema object.

=cut

has address => (
    is          => 'rw',
    isa         => 'XT::Address',
    required    => 1,
    handles     => ['schema'],
);
