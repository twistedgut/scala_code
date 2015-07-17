package XTracker::Schema::ResultSet::Public::ShippingAccount;

use strict;
use warnings;

use base 'XTracker::Schema::ResultSetBase';

use Carp;
use Scalar::Util qw(blessed);

use XTracker::Constants::FromDB qw(:carrier :shipment_type :shipping_charge_class);
use XTracker::Config::Local qw( config_var default_carrier );

=head1 NAME

XTracker::Schema::ResultSet::Public::ShippingAccount - DBIC resultset

=head1 DESCRIPTION

DBIx::Class resultset for shipping accounts

=head1 METHODS

=cut

sub _find_by_name {
    my ($self, $args) = @_;
    $args ||= {};
    my $schema = $self->result_source->schema;

    my @channel_where;
    if ($args->{channel_name}) {
        @channel_where = (
            channel_id => $schema->resultset("Public::Channel")->search({
                name => $args->{channel_name},
            })->first->id,
        );
    }
    elsif ($args->{channel}) {
        @channel_where = (channel_id => $args->{channel}->id);
    }

    return $self->search({
        name => $args->{name},
        @channel_where,
    })->first;
}

=head2 find_premier({ :$channel_name?, Channel::Row :$channel? }) : $shipping_account_row

Return the Premier ShippingAccount row for a channel (This is
currently identified by the name "Unknown").

You may provide an arg to identify the channel if the resultset isn't
already narrowed down.

=cut

sub find_premier {
    my ($self, $args) = @_;
    $args ||= {};
    return $self->_find_by_name({ %$args, name => "Unknown" });
}

=head2 find_no_shipment({ :$channel_name?, Channel::Row :$channel? }) : $shipping_account_row

Return the ShippingAccount row for Not-a-Shipment (e.g. for a
virtual-vouchers-only shipment) for a channel (This is
currently identified by the name "Unknown").

You may provide an arg to identify the channel if the resultset isn't
already narrowed down.

=cut

sub find_no_shipment {
    my ($self, $args) = @_;
    $args ||= {};
    return $self->_find_by_name({ %$args, name => "Unknown" });
}

=head2 by_name($shipping_account_name) : $shipping_account_rs

Constrain by supplied ShippingAccount name.

=cut

sub by_name {
    my $self = shift;
    my $shipping_account_name = shift || croak 'Please supply a shipping account name';
    return $self->search({ 'me.name' => $shipping_account_name });
}

=head2 by_default_carrier($is_ground) : $shipping_account_rs

Constrain by the configured default carrier (depending on whether it
$is_ground shipping or not).

=cut

sub by_default_carrier {
    my ($self, $is_ground) = @_;

    my $default_carrier = default_carrier($is_ground);

    return $self->search(
        { 'carrier.name' => $default_carrier },
        { join => 'carrier' },
    );
}


=head1 SEE ALSO

L<XTracker::Schema>,
L<XTracker::Schema::Result::Public::ShippingAccount>

=head1 AUTHOR

Pete Smith <pete.smith@net-a-porter.com>

=cut

1;


