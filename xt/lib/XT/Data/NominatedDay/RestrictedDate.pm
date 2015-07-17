package XT::Data::NominatedDay::RestrictedDate;
use NAP::policy "tt", 'class';
with "XTracker::Role::WithSchema";

use Memoize;
use Moose::Util::TypeConstraints;

use XT::Data::Types qw/ DateStamp /;
use XT::Data::Types;

=head1 NAME

XT::Data::NominatedDay::RestrictedDate - A Nominated Day Restricted Date, with a ShippingCharge and a Restriction Type

=cut

subtype "RestrictionType",
    as "Str",
    where { /^ dispatch | transit | delivery $/x };

has restriction_type => (
    is       => "ro",
    isa      => "RestrictionType",
    required => 1,
);

has date => (
    is       => "ro",
    isa      => "XT::Data::Types::DateStamp",
    coerce   => 1,
    required => 1,
);

has shipping_charge_id => (
    is       => "ro",
    isa      => "Int",
    required => 1,
);

has channel_row => (
    is           => "ro",
    isa          => "XTracker::Schema::Result::Public::Channel",
    lazy         => 1,
    default      => sub {
        my $self =  shift;
        _build_channel_row($self->schema, $self->shipping_charge_id);
    },
);

memoize("_build_channel_row");
sub _build_channel_row {
    my ($schema, $shipping_charge_id) = @_;
    my $rs = $schema->resultset("Public::ShippingCharge");
    my $shipping_charge_row = $rs->find($shipping_charge_id)
        or die("Invalid ShippingCharge id ($shipping_charge_id)\n");
    return $shipping_charge_row->channel;
}

sub key {
    my $self = shift;
    return join(
        "\t",
        $self->restriction_type,
        $self->date,
        $self->shipping_charge_id,
    );
}

sub date_restriction_rs {
    return shift->schema->resultset("Shipping::DeliveryDateRestriction");
}

sub date_restriction_type_rs {
    return shift->schema->resultset("Shipping::DeliveryDateRestrictionType");
}

sub date_restriction_log_rs {
    return shift->schema->resultset("Shipping::DeliveryDateRestrictionLog");
}

=head2 restrict(DBIC::Row $operator, $change_reason) :

Mark this date as restricted, and log the $change_reason against the
$operator.

=cut

sub restrict {
    my ($self, $operator, $change_reason) = @_;
    $self->create_or_update_with($operator, $change_reason, 1);
}

=head2 unrestrict(DBIC::Row $operator, $change_reason) :

Mark this date as not restricted, and log the $change_reason against
the $operator.

=cut

sub unrestrict {
    my ($self, $operator, $change_reason) = @_;
    $self->create_or_update_with($operator, $change_reason, 0);
}

sub create_or_update_with {
    my ($self, $operator, $change_reason, $is_restricted) = @_;

    my ($date_restriction_row, $date_restriction_log_row);
    $self->schema->txn_do( sub {

        my $restriction_type_id = _get_restriction_type(
            $self->schema,
            $self->restriction_type,
        );

        $date_restriction_row = $self->date_restriction_rs->search({
            "date"                => $self->date . "",
            "shipping_charge_id"  => $self->shipping_charge_id,
            "restriction_type_id" => $restriction_type_id
        })->first;

        if ($date_restriction_row) {
            $date_restriction_row->update({
                is_restricted => $is_restricted,
            });
        }
        else {
            $date_restriction_row = $self->date_restriction_rs->create({
                date                => $self->date . "",
                shipping_charge_id  => $self->shipping_charge_id,
                restriction_type_id => $restriction_type_id,
                is_restricted       => $is_restricted,
            });
        }

        $date_restriction_log_row = $self->date_restriction_log_rs->create({
            delivery_date_restriction_id => $date_restriction_row->id,
            new_is_restricted            => $is_restricted,
            change_reason                => $change_reason,
            operator_id                  => $operator->id,
        });
    } );

    return ($date_restriction_row, $date_restriction_log_row);
}

memoize("_get_restriction_type");
sub _get_restriction_type {
    my ($schema, $restriction_type) = @_;
    my $date_restriction_type_rs = $schema->resultset("Shipping::DeliveryDateRestrictionType");
    return $date_restriction_type_rs->search({
        token => $restriction_type,
    })->first->id;
}

