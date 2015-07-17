
=head1 NAME

XTracker::Schema::Row::Delta::Shipment - Shipment ==> shipment_note

=head1 DESCRIPTION

Keep track of changes to a Shipment row and ->report() as a
shipment_note.

=cut

package XTracker::Schema::Row::Delta::Shipment;
use NAP::policy "tt", "class";
extends "DBIx::Class::Row::Delta";

use XTracker::Database::Shipment qw();
use XT::Data::DateTimeFormat qw/ web_format_from_datetime /;

has "+changes_sub" => (
    default => sub {
        sub {
            my ($row) = @_;
            return {
                "Shipment Type"           => $row->shipment_type->type,
                "Shipping Charge"         => $row->shipping_charge_table->description,
                "Shipping SKU"            => $row->shipping_charge_table->sku,
                "Shipping Charge Price"   => $row->shipping_charge_as_money,
                "Shipment Status"         => $row->shipment_status->status,
                "Nominated Delivery Date" => web_format_from_datetime(
                    $row->nominated_delivery_date,
                ),
                "Address"                 => $row->shipment_address->as_string,
            };
        },
    },
);

has operator_id => (is => "ro", required => 1);

sub report {
    my $self = shift;

    my $changes = $self->changes // return undef;

    my $dbh = $self->dbic_row->result_source->schema->storage->dbh;
    XTracker::Database::Shipment::insert_shipment_note(
        $dbh,
        $self->dbic_row->id,
        $self->operator_id,
        $changes,
    );

    return $changes;
}
