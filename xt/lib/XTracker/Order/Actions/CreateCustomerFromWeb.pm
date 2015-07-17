package XTracker::Order::Actions::CreateCustomerFromWeb;

use strict;
use warnings;

use Try::Tiny;

use XTracker::Handler;

use XTracker::Constants::FromDB             qw( :customer_category );
use XTracker::Database::Customer            qw( get_customer_from_pws create_customer );

use XTracker::Error;
use XTracker::WebContent::StockManagement;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $schema      = $handler->schema;

    my $redirect    = "/CustomerCare/CustomerSearch";

    my $channel_id  = $handler->{param_of}{channel_id};
    my $customer_nr = $handler->{param_of}{customer_nr};
    my $channel;

    eval {
        $channel    = $schema->resultset('Public::Channel')->find( $channel_id );
    };

    if ( !$customer_nr || !$channel ) {
        xt_warn("No Customer Number or Channel found");
    }
    else {
        my $web_connection;
        try {
            # get the Customer deatils on the Web
            # for the right Sales Channel
            $web_connection = XTracker::WebContent::StockManagement->new_stock_manager({
                                            schema      => $schema,
                                            channel_id  => $channel->id,
                                    } );
            my $web_dbh = $web_connection->_web_dbh;

            my $cust_details    = get_customer_from_pws( $web_dbh, $customer_nr );
            if ( !$cust_details ) {
                die "Couldn't find Customer Details from the PWS for Customer Number: ${customer_nr} on Channel: " . $channel->name . "\n";
            }
            $web_connection->disconnect;

            $schema->txn_do(sub{
                create_customer( $schema->storage->dbh, {
                    is_customer_number  => $customer_nr,
                    first_name          => $cust_details->{first_name},
                    last_name           => $cust_details->{last_name},
                    email               => $cust_details->{email},
                    account_urn         => $cust_details->{global_id},
                    channel_id          => $channel->id,
                    category_id         => $CUSTOMER_CATEGORY__NONE,
                } );
            });

            # make sure the search page searches for the
            # Customer straightaway when we go back there
            $redirect   .= '?search=1' .
                           "&customer_number=${customer_nr}" .
                           # replicates what appears in the Sales Channel drop-down
                           '&channel=' . $channel->id . '-' . $channel->business->config_section;

            xt_success("Customer record Created in xTracker for Customer Number: ${customer_nr}");
        }
        catch {
            xt_warn( "Error trying to Create Customer:<br>" . $_ );
            $web_connection->disconnect         if ( $web_connection );
        };
    }


    return $handler->redirect_to( $redirect );
}

1;
