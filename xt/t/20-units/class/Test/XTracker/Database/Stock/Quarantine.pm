package Test::XTracker::Database::Stock::Quarantine;
use NAP::policy "tt", qw/test class/;

BEGIN {
    extends 'NAP::Test::Class';
    with 'XTracker::Role::WithSchema';
    with 'XTracker::Role::WithPRLs';
    with 'XTracker::Role::WithIWSRolloutPhase';
    with 'Test::XT::Data::Quantity';
    with 'Test::XTracker::Data::Quarantine';
};

use Test::XTracker::Data;
use XTracker::Database::Stock::Quarantine qw( :quarantine_stock );
use XTracker::Constants qw{ :application };
use XTracker::Constants::FromDB qw( :flow_status );

sub test__quarantine_stock :Tests {
    my ($self) = @_;

    my $schema = $self->schema();

    my $quantity = $self->get_pre_quarantine_quantity();
    my $variant = $quantity->variant();

    note('Created some stock in a location that it can be quarantined from');

    my $initial_quarantined_count = $self->get_quarantined_quantity_count($variant);
    note('Created some stock in a location that it can be quarantined from');
    note("Make a note of how many quarantined quantities there are for this variant: "
         . $initial_quarantined_count);

    lives_ok {
        quarantine_stock(
            dbh         => $self->dbh(),
            quantity_row=> $quantity,
            quantity    => 2,
            reason      => 'L',
            notes       => 'The cake is a lie',
            operator_id => $APPLICATION_OPERATOR_ID,
            uri_path    => '/StockControl/Inventory/StockQuarantine',
        );
    } 'Call to quarantine_stock() lives';

    $quantity->discard_changes();
    is($quantity->in_storage(), 0, 'Original quantity has been removed from db');

    is($self->get_quarantined_quantity_count($variant), $initial_quarantined_count+1,
       'Quarantined quantity count has been incremented by 1');

}

sub get_quarantined_quantity_count {
    my ($self, $variant) = @_;
    return $self->schema()->resultset('Public::Quantity')->search({
        variant_id  => $variant->id(),
        status_id   => $FLOW_STATUS__QUARANTINE__STOCK_STATUS
    })->count();
}
