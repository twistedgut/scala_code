package XT::Product::WebDataTransfer;

=head1 NAME

XT::Product::WebDataTransfer

=head1 DESCRIPTION

A place for product web db update helpers to live

=head1 METHODS

=cut
use NAP::policy 'tt', 'class';

with 'XTracker::Role::WithSchema';

use XTracker::Logfile qw( xt_logger );
use XTracker::Comms::DataTransfer qw( :upload_transfer :transfer_handles :transfer );

has log => (
    lazy_build => 1,
    is => 'ro',
);

sub _build_log {
    return xt_logger();
}

=head2 update_product_in_webdb

Will update the product, searchable_product and stock_location information
for the product in the staging and live environments if the product is flagged
as such in XT.

=cut

sub update_product_in_webdb {
    my ( $self, $product ) = @_;

    my $dbh = $self->schema->storage->dbh;
    my $pc = $product->get_product_channel; # gets the 'active' product channel
    my $channel_id = $pc->channel_id;
    my $business_name = $pc->channel->business->config_section;
    my $pid = $product->id;

    foreach my $env ( qw/ staging live / ) {

        # We only need to update if the product is in the relevant environment
        # already
        #
        next unless $pc->$env();

        $self->log->info("Update product $pid details in $env web db $business_name");

        my $web_dbh = get_transfer_db_handles({
            dbh_source  => $dbh,
            environment => $env,
            channel     => $business_name,
        });

        # Research in BAU scripts tells me that we don't pass in a log dbh ref
        # when we're updating new variants (i.e. the product is already there).
        # If we change our minds, we need to set up a log ref here and pass into
        # each transfer_product_* call --JS

        # This gets the product, channel_pricing and price_adjustment in
        my $transfer_categories =  [ "catalogue_product", "catalogue_sku", "catalogue_pricing", "catalogue_markdown"];
        transfer_product_data({
            dbh_ref             => $web_dbh,
            channel_id          => $channel_id,
            product_ids         => $pid,
            skip_navcat         => 1,
            transfer_categories => $transfer_categories,
            sql_action_ref      => {map {$_ => {insert => 1}} @$transfer_categories},
        });

        # This gets the stock_location in
        transfer_product_inventory({
            dbh_ref         => $web_dbh,
            channel_id      => $channel_id,
            product_ids     => $pid,
            new_variant     => 1, # prevents creating duplicate log_pws_stock records
            sql_action_ref  => { saleable_inventory => {insert => 1} },
        });

        # Commit the transaction with all of the product details into the DB
        $web_dbh->{dbh_sink}->commit;
    }

    return;
}
