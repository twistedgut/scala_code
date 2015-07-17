package XTracker::Retail::Attribute::AJAX::RemoveProduct;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Database              qw( :common );
use XTracker::DB::Factory::ProductAttribute;

use XTracker::Comms::DataTransfer   qw(:transfer_handles);

use XTracker::Handler;
use XTracker::DBEncode  qw( encode_it );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $response            = '';       # response string
    my $error               = '';       # error msg

    my $attribute_id        = $handler->{param_of}{'attribute_id'};     # attribute id to assign
    my $products            = $handler->{param_of}{'products'};         # should be a comma seperated list of PID's

    # get sales channel id & channel config section from the form
    my $channel_id          = $handler->{param_of}{'channel_id'};
    my $channel_config      = $handler->{param_of}{'channel_config'};

    my $no_prods_removed    = 0;
    my @prods;


    if ( $attribute_id && $products && $channel_id ) {

        my $schema                      = $handler->{schema};                   # get schema
        my $transfer_dbh_ref            = get_transfer_sink_handle({ environment => 'live', channel => $channel_config });      # get web transfer handles
        $transfer_dbh_ref->{dbh_source} = $schema->storage->dbh;                                                                # pass the schema handle in as the source for the transfer

        # get attribute Navigation DB Factory object
        my $factory = XTracker::DB::Factory::ProductAttribute->new({ schema => $schema });


        # tidy up product list - should just be PID's and comma's
        $products  =~ s/[^\d\,]//g;

        # split out PID's
        @prods = split(/,/, $products);

        if ( @prods ) {
            my @val_prods;

            eval {
                # transaction wraps XT and Website updates
                $schema->txn_do( sub {

                    foreach my $pid (@prods) {

                        my $success = $factory->remove_product_attribute( {
                                                                'attribute_id'      => $attribute_id,
                                                                'product_id'        => $pid,
                                                                'transfer_dbh_ref'  => $transfer_dbh_ref,
                                                                'operator_id'       => $handler->operator_id,
                                                                'channel_id'        => $channel_id
                        } );

                        if ( $success ) {
                            push @val_prods, $pid;
                        }
                        else {
                            $error  .= "  $pid - Not Assigned to this Attribute<br />";
                        }
                    }

                    # commit website changes
                    $transfer_dbh_ref->{dbh_sink}->commit();
                } );
            };
            if ($@) {
                # rollback website updates on error - XT updates rolled back as part of txn_do
                $transfer_dbh_ref->{dbh_sink}->rollback();
                $no_prods_removed   = 1;
                $error              = "No Products Were Removed<br/><br/>".$@;
            }
        }
        else {
            $error  = "No Valid Products Supplied";
        }

        # disconnect website transfer handles
        $transfer_dbh_ref->{dbh_sink}->disconnect()         if $transfer_dbh_ref->{dbh_sink};
    }
    else {
        $error  = "No Products Removed";
    }

    if ($error) {
        if ( @prods ) {
            if ( !$no_prods_removed ) {
                $response   = "The following products could not be removed:  <br/><br/>$error<br/>Please check and try again.";
            }
            else {
                $response   = "ERROR: There was a failure and $error";
            }
        }
        else {
            $response   = $error;
        }
    }
    else {
        $response = 'OK';
    }

    # write out response
    $handler->{r}->content_type( 'text/plain' );
    $handler->{r}->print( encode_it($response) );

    return OK;
}


1;
