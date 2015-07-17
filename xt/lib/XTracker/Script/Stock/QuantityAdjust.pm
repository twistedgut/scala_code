package XTracker::Script::Stock::QuantityAdjust;

use NAP::policy "tt", 'class';

use MooseX::Params::Validate;

extends 'XTracker::Script';
with map { "XTracker::Script::Feature::$_" } qw{Schema SingleInstance};

use XT::Data::Types;
use XTracker::Constants ':application';
use XTracker::WebContent::StockManagement::Broadcast;

sub invoke {
    my ( $self, $sku, $location, $delta ) = validated_list( \@_,
        sku      => { isa => 'XT::Data::Types::SKU' },
        location => { isa => 'Str' },
        delta    => { isa => 'Int' },
    );

    die 'Nothing to do, pass a value for your quantity_delta' unless $delta;

    output("Processing delta $delta for SKU $sku in location '$location'");

    # TODO: We don't need this functionality yet so I won't add it... the
    # script would be more complicated so skipping for now. We can add this at
    # a later date if needed.
    die 'Increasing quantities has not been implemented yet' if $delta > 0;

    my $schema = $self->schema;
    my $guard = $schema->txn_scope_guard;

    my $variant_rs = $schema->resultset('Public::Variant')->search_by_sku($sku);
    die "Could not find SKU $sku\n" unless $variant_rs->count;

    my $quantity_rs = $variant_rs->search_related('quantities',
        { 'location.location' => $location },
        { join => 'location' }
    );

    die "There is more than one variant matching SKU $sku at location $location, don't know which one to adjust"
        if $quantity_rs->count > 1;

    my $quantity = $quantity_rs->single or die 'No quantity found at given location';

    # Limit this script to only support adjusting sample quantities. Having a
    # look at iws_name 'Creative', which probably *should* be supported,
    # isn't...
    my $status = $quantity->status;
    my $is_sample = $status->iws_name eq 'sample';
    die sprintf(
        q{This script currently only supports adjusting 'sample' type quantities, %s is not supported},
        $status->name
    ) unless $is_sample;

    die sprintf( q{Location only has %d item%s, you can't remove any more than that},
        $quantity->quantity, $quantity->quantity == 1 ? q{} : q{s}
    ) if $quantity->quantity + $delta < 0;

    if ( $is_sample ) {
        $quantity->update_and_log_sample({
            delta       => $delta,
            operator_id => $APPLICATION_OPERATOR_ID,
            notes       => 'Quantity adjusted by script to fix a data inconsistency - balance is unchanged',
        });
    }
    # This else clause so if/when we extend this script to work for non-sample
    # shipments, we don't forget to log in another table.
    else {
        die sprintf q{ },
            'Need to implement logging for non-sample shipments - this will',
            'most likely need to be done in the transaction log table',
            '(log_stock) in the db. Also you might not need to reduce the',
            'balance when you log. Double-check this with Nuno';
    }
    # Commit our changes to the db
    $guard->commit;
    # Tell the product service about our update.
    $self->broadcast_sample_quantity($quantity);

    output("Done");
}

=head2 broadcast_sample_quantity( $quantity_row ) :

Send the product service full updated stock levels for this product.

If we were dealing with main stock this wouldn't be enough, because it doesn't
do any updates to the websites or to JC product, but this is all we need to do
here because this script is only used for samples.

=cut

sub broadcast_sample_quantity {
    my ( $self, $quantity ) = @_;
    my $broadcast = XTracker::WebContent::StockManagement::Broadcast->new({
        schema     => $self->schema,
        channel_id => $quantity->channel_id,
    });
    $broadcast->stock_update(product => $quantity->variant->product);
    $broadcast->commit,
}

=head2 output

Use this method for output, so it can be easily modified or turned on/off.

=cut

sub output {
    my ($message) = @_;
    my @date = `date`; chomp(@date); ## no critic(ProhibitBacktickOperators)
    print "$date[0] : $message\n";
}
