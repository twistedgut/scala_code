package Test::XTracker::StockQuantity;

use strict;
use warnings;

use XTracker::Constants::FromDB qw/
  :flow_status
  :stock_action
/;

use NAP::policy "tt", 'class';

=head1 NAME

Test::XTracker::StockQuantity - Helper functions for accessing stock information

=head1 DESCRIPTION

Helper functions for accessing stock information

=head1 ATTRIBUTES

=head2 schema

=cut


has schema => (
    is          => 'ro',
    isa         => 'DBIx::Class::Schema|XTracker::Schema|XT::DC::Messaging::Model::Schema',
    required    => 1,
);

=head2 get_quantity

Returns the quanity for an a specific location, variant and status.
Used to ensure stock adjustments are accurate.

=cut

sub get_quantity {
    my ($self, $variant_id, $prl_location, $status_id) = @_;

    $status_id ||= $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;

    my $quantity =  $self->schema->resultset('Public::Quantity')->search({
        location_id => $prl_location->id,
        variant_id => $variant_id,
        status_id => $status_id,
    })->get_column('quantity')->sum();

    $quantity ||= 0;

    return $quantity;
}

=head2 check_stock_log

Returns a balance (a variant's current stock quantity on a channel) if an
entry in a log file is found. This is used to ensure stock adjustments are
captured and logged correctly.

=cut

sub check_stock_log {
    my ($self, $variant_id, $quantity, $reason) = @_;

    my $log_qry = $self->schema->resultset('Public::LogStock')->search({
        variant_id => $variant_id,
        stock_action_id => $STOCK_ACTION__MANUAL_ADJUSTMENT,
        quantity => $quantity
    }, {
        order_by => { -desc => 'date' },
    });

    if (defined($reason)) {
        $log_qry->search({ notes => $reason });
    }

    my $log_row = $log_qry->slice(0,0)->single;

    return $log_row;
}

1;
