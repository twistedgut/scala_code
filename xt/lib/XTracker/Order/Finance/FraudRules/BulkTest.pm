package XTracker::Order::Finance::FraudRules::BulkTest;

use NAP::policy "tt";

use XTracker::Navigation qw( build_sidenav );
use XT::FraudRules::DryRun;
use XTracker::Constants::FromDB qw( :order_status );
use XTracker::Error;

use XT::Cache::Function         qw( :stop );

use XTracker::Config::Local     qw( order_nr_regex );


sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $schema                      = $handler->{schema};
    $handler->{data}{css}           = '/css/fraudrules-bulktest.css';
    $handler->{data}{content}       = 'ordertracker/finance/fraudrules/bulk_test.tt';
    $handler->{data}{section}       = 'Finance';
    $handler->{data}{subsection}    = 'Fraud Rules';
    $handler->{data}{subsubsection} = 'Bulk Test';
    $handler->{data}{sidenav}       = build_sidenav( {
        navtype => 'fraud_rules'
    } );

    # Data for dropdowns:

    $handler->{data}{order_statuses} = [
        $handler->{schema}->resultset('Public::OrderStatus')->find($ORDER_STATUS__CREDIT_HOLD),
        $handler->{schema}->resultset('Public::OrderStatus')->find($ORDER_STATUS__ACCEPTED)
    ];

    $handler->{data}{rulesets} = {
        live    => 'Live',
        staging => 'Staging',
    };

    # Stash data passed in from the form.
    $handler->{data}{ruleset}           = $handler->{param_of}{ruleset};
    $handler->{data}{expected_result}   = $handler->{param_of}{expected_result};
    $handler->{data}{orders}            = $handler->{param_of}{orders};

    if ( $handler->{param_of}{expected_result} ) {
    # If the form has been submitted.

        if ( $handler->{param_of}{orders} ) {
        # If we've been given some text.

            # Contains orders that from_text cannot find.
            my $invalid_orders = [];

            # Get the orders.
            my $orders = $schema
                ->resultset('Public::Orders')
                ->from_text(
                    $handler->{param_of}{orders},
                    $invalid_orders,
                    # get the Order Number Regex Pattern from Config
                    order_nr_regex(),
                );

            if ( scalar @$invalid_orders ) {
            # Stay on the input page until we have no invalid orders.

                # Stash the invalid orders.
                $handler->{data}{invalid_orders} = $invalid_orders;

                xt_warn( 'Some of the order numbers are invalid, please check and try again.' );

            } else {
            # If no invalid orders, carry on.

                if ( my $order_count = $orders->count ) {
                # If we have at least one valid order number.

                    # Get the expected order status object.
                    my $expected_result = $schema
                        ->resultset('Public::OrderStatus')
                        ->find( $handler->{param_of}{expected_result} );

                    # Instantiate a new DryRun object.
                    my $dry_run = XT::FraudRules::DryRun->new(
                        orders                => $orders,
                        expected_order_status => $expected_result,
                        rule_set              => $handler->{param_of}{ruleset},
                    );

                    # Run the tests.
                    $dry_run->execute;

                    # Stash everything in the template.
                    $handler->{data}{content}         = "ordertracker/finance/fraudrules/bulk_test_result.tt";
                    $handler->{data}{dry_run}         = $dry_run;
                    $handler->{data}{ruleset}         = $handler->{data}{rulesets}->{ $handler->{data}{ruleset} };
                    $handler->{data}{expected_result} = $expected_result->status;
                    $handler->{data}{valid_count}     = $order_count;

                } else {

                    xt_warn( 'No valid orders where entered, please check and try again.' );

                }

            }

        } else {

            xt_warn( 'Please enter some order numbers.' );

        }

    }

    # clear the Cache so that stuff like the Fraud Hotlist
    # doesn't persist, this is in lieu of Cache Expiration
    stop_all_caching();

    return $handler->process_template;

}

