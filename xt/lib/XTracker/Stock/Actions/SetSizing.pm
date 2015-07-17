package XTracker::Stock::Actions::SetSizing;
use strict;
use warnings;
use Carp;
use Try::Tiny;
#use Data::Dumper;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Database;
use XTracker::Database::Stock qw( get_delivered_quantity );
use XTracker::Database::Attributes qw ( set_product_attribute set_variant );
use XTracker::Database::Product qw ( set_product_standardised_sizes get_product_channel_info );
use XTracker::Comms::DataTransfer   qw( :transfer_handles :transfer );
use XTracker::Database::Channel     qw( get_channel_details );
use XTracker::Error;

use XTracker::Utilities qw( :edit );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $location;
    my $product_id;

    try {
        $handler->schema->txn_do(
            sub {
                # unpack request parameters
                my ( $data_ref, $rest_ref ) = unpack_edit_params( $handler->{request} );
                my $dbh = $handler->schema->storage->dbh;
                $product_id = $rest_ref->{product_id};

                # update size scheme
                if ($rest_ref->{size_scheme_id}) {
                    set_product_attribute(
                        $dbh,
                        $product_id,
                        size_scheme_id => $rest_ref->{size_scheme_id},
                        $handler->operator_id,
                    );
                }

                # update variant size / designer_size

              VARIANT:
                foreach my $variant_id ( keys %$data_ref ) {
                    set_variant(
                        $dbh,
                        $variant_id,
                        size_id => $data_ref->{$variant_id}{size_id}
                    )
                        if exists $data_ref->{$variant_id}{size_id};
                    set_variant(
                        $dbh,
                        $variant_id,
                        designer_size_id => $data_ref->{$variant_id}{designer_size_id}
                    )
                        if exists $data_ref->{$variant_id}{designer_size_id};
                }

                # reset standardised sizes on variants
                set_product_standardised_sizes($dbh, $product_id);

                # update website if required
                # get active channel info for product

                my $active_channel_name;
                my $product = $handler->schema()->resultset('Public::Product')->find($product_id);
                if ($product) {
                    my $current_product_channel = $product->get_product_channel();
                    $active_channel_name = $current_product_channel->channel()->name()
                        if $current_product_channel;
                }

                my $channel_data    = get_product_channel_info($dbh, $product_id);
                my $channel_details = get_channel_details( $dbh, $active_channel_name );

                # product is live on active channel
                if ( $channel_data->{ $active_channel_name }{live} == 1 ) {
                    # get web transfer handle
                    my $transfer_dbh_ref = get_transfer_sink_handle( {
                        environment => 'live',
                        channel => $channel_details->{config_section}
                    } );
                    $transfer_dbh_ref->{dbh_source} = $dbh;

                    try {
                        my @attributes = ['size', 'std_size_id'];

                        transfer_product_data({
                            dbh_ref             => $transfer_dbh_ref,
                            product_ids         => $product_id,
                            channel_id          => $channel_details->{id},
                            transfer_categories => 'catalogue_sku',
                            attributes          => \@attributes,
                            sql_action_ref      => {
                                catalogue_sku => { 'update' => 1 }
                            },
                        });

                        $transfer_dbh_ref->{dbh_sink}->commit();
                    }
                    catch {
                        $transfer_dbh_ref->{dbh_sink}->rollback();
                        die $_;
                    };
                }

                $handler->msg_factory->transform_and_send(
                    'XT::DC::Messaging::Producer::ProductService::Sizing', {
                        product => $handler->schema
                            ->resultset('Public::Product')->find({
                                id => $product_id,
                            }),
                        channel_id => $channel_details->{id},
                    });
            });

        xt_success('Sizing updated.');
        $location = "Sizing?product_id=$product_id";
    }
    catch {
        xt_warn($_);
        $location = "Sizing?product_id=$product_id";
    };

    return $handler->redirect_to( $location );
}

1;
