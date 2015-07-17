package XTracker::Sample::Actions::ProcessSampleTransfer;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Constants::FromDB         qw( :department :authorisation_level );
use XTracker::Database::SampleRequest   qw( :SampleTransfer );
use XTracker::Utilities                 qw( url_encode );
use XTracker::Error;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    if ( $handler->auth_level < $AUTHORISATION_LEVEL__OPERATOR ) {
        ## Redirect to Review Requests
        return  $handler->redirect_to( "/Sample/ReviewRequests" );
    }

    my $ret_url         = "/Sample/SampleTransfer";
    my $ret_params      = "?";

    $ret_params .= "active_channel=".($handler->{param_of}{active_channel} // '');
    $ret_params .= "&active_location=".($handler->{param_of}{active_location} // '');
    if ( exists $handler->{param_of}{search_param} ) {
        $ret_params .= "&submit_search=1";
        $ret_params .= "&".$handler->{param_of}{search_param}."=".$handler->{param_of}{search_value};
    }
    $ret_params .= "&";

    eval {
        my $schema = $handler->schema;
        my $dbh = $schema->storage->dbh;
        ## 'Transfer' button
        if ( exists($handler->{param_of}{submit_sample_transfer}) && $handler->{param_of}{transfer_sample_request_det_id}
             && $handler->{param_of}{transfer_variant_id} && $handler->{param_of}{transfer_loc_from} && $handler->{param_of}{transfer_loc_to} ) {

            ## perform transfer
            $schema->txn_do(sub{
                transfer_sample({
                    dbh                   => $dbh,
                    sample_request_det_id => $handler->{param_of}{transfer_sample_request_det_id},
                    variant_id            => $handler->{param_of}{transfer_variant_id},
                    quantity              => 1,
                    loc_from              => $handler->{param_of}{transfer_loc_from},
                    loc_to                => $handler->{param_of}{transfer_loc_to},
                    operator_id           => $handler->operator_id,
                });
            });
            xt_success("SKU $handler->{param_of}{transfer_sku} (ref. $handler->{param_of}{transfer_sample_request_det_id}) was transferred from $handler->{param_of}{transfer_loc_from} to $handler->{param_of}{transfer_loc_to}.");
        }
        ## transfer press sample (selected from Inventory >> Overview)
        elsif (
            $handler->{param_of}{action} eq 'transfer_press_sample'
         && ($handler->{param_of}{variant_id} =~ m{\A\d+\z}xms)
         && $handler->{param_of}{quantity}
         && $handler->{param_of}{channel_id}
        ) {

            # Just refactored this - the original code was lacking an 'else'
            # clause... we basically do nothing and no feedback message is
            # triggered if we hit it. Weird.
            if ( $handler->department_id != $DEPARTMENT__SAMPLE ) {
               die "Only members of the Sample Department may transfer Press Samples\n";
            }
            elsif ( ($handler->{param_of}{location_from} eq 'Sample Room') || ($handler->{param_of}{location_from} eq 'Press Samples') ) {

                $ret_params = "?variant_id=".$handler->{param_of}{variant_id}."&";
                $ret_url    = "/StockControl/Inventory/Overview";

                my $loc_to;

                $schema->txn_do(sub{
                    $loc_to = transfer_press_sample({
                        dbh         => $dbh,
                        variant_id  => $handler->{param_of}{variant_id},
                        loc_from    => $handler->{param_of}{location_from},
                        quantity    => 1,
                        channel_id  => $handler->{param_of}{channel_id}
                    });
                });
                xt_success("Product was transferred from $handler->{param_of}{location_from} to $loc_to.");
            }
        }
        # Nothing to do
        else {
            xt_success("Nothing to do. You might not have selected a Destination Location.");
        }
    };
    if ($@) {
        xt_warn($@);
    }

    return $handler->redirect_to( $ret_url.$ret_params );
}

1;
