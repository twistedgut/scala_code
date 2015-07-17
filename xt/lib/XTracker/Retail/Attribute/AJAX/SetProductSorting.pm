package XTracker::Retail::Attribute::AJAX::SetProductSorting;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Database qw( :common );
use XTracker::DB::Factory::ProductAttribute;

use XTracker::Comms::DataTransfer   qw(:transfer_handles);

use XTracker::Handler;
use XTracker::Logfile qw( xt_logger );
use XTracker::Session;
use XTracker::DBEncode  qw( encode_it );

sub handler {

    my $r               = shift;
    my $req             = $r; # they're the same thing in our new Plack world

    my $response        = '';       # response string
    # TODO: Can we remove this? Doesn't look like $session is ever used
    my $session         = XTracker::Session->session();

    my $attribute_id    = $req->param('attribute_id');      # form data - attribute_id
    my $product_data    = $req->param('data');              # form data - string of product and sort info

    # get sales channel id & channel config section from the form
    my $channel_id      = $req->param('channel_id');
    my $channel_config  = $req->param('channel_config');


    if ( $attribute_id && $product_data ){

        my $schema                      = xtracker_schema;
        my $transfer_dbh_ref            = get_transfer_sink_handle({ environment => 'live', channel => $channel_config });      # get web transfer handles
        $transfer_dbh_ref->{dbh_source} = $schema->storage->dbh;                                                                # pass the schema handle in as the source for the transfer


        # get Category Navigation DB Factory object
        my $factory = XTracker::DB::Factory::ProductAttribute->new({ schema => $schema });

        eval {

            # loop counter to keep track of new ordering
            my $new_order = 1;

            # split form data to get individual product records
            my @products = split(/-/, $product_data);

            # transaction wraps XT and Website updates
            $schema->txn_do( sub {

                # process each product in turn
                foreach my $product (@products) {

                    # split product data to get current sort order and PID
                    my ($empty, $cur_order, $pid) = split(/_/, $product);

                    if ($pid) {

                        # current sort order different to new one - update db
                        if ($cur_order != $new_order) {

                            $factory->set_sort_order( $attribute_id, $pid, $new_order, $channel_id, $transfer_dbh_ref );

                        }

                        $new_order++;
                    }
                }
                # commit website changes
                $transfer_dbh_ref->{dbh_sink}->commit();
            } );

        };

        if ($@) {
            # rollback website updates on error - XT updates rolled back as part of txn_do
            $transfer_dbh_ref->{dbh_sink}->rollback();

            $@  =~ s/[\r\n]//g;
            $response = $@;
        }
        else {
            $response = 'OK';
        }


        # disconnect website transfer handle
        $transfer_dbh_ref->{dbh_sink}->disconnect()         if $transfer_dbh_ref->{dbh_sink};

    }
    else {
        $response = 'No attribute_id or product data provided';
    }

    # write out response
    $r->content_type( 'text/plain' );
    $r->print( encode_it($response) );

    return OK;
}

1;
