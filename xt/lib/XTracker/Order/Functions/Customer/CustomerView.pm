package XTracker::Order::Functions::Customer::CustomerView;
use NAP::policy "tt";
use Plack::App::FakeApache1::Constants qw(:common);
use Hash::Util qw(lock_hash);
use XTracker::Handler;
use XTracker::Database::Address;
use XTracker::Database::Customer qw( :DEFAULT match_customer );
use XTracker::Database::Finance;
use XTracker::Database::Order;
use XTracker::Database::Return;
use XTracker::Database::Shipment;
use XTracker::Config::Local qw(config_var);
use XTracker::Constants::FromDB qw(:department);
use XTracker::Utilities qw( parse_url );
use XTracker::Error qw( xt_warn );
use DateTime::Format::ISO8601;
use XTracker::Role::WithCreditClient;
use XTracker::Logfile qw(xt_logger);
use XT::Net::Seaview::Client;
use XTracker::Database::Utilities;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{seaview}
      = XT::Net::Seaview::Client->new({schema => $handler->{schema}});

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Customer View';
    $handler->{data}{content}       = 'ordertracker/shared/customerview.tt';
    $handler->{data}{short_url}     = $short_url;
    $handler->{data}{js}            = [
        '/javascript/customer_view.js'
    ];

    # get customer id from query string - may be an email address rather than id
    $handler->{data}{customer_id}   = $handler->{request}->param('customer_id');

    # get customer id from email
    if (
        defined $handler->{data}{customer_id} &&
        $handler->{data}{customer_id} =~ m/@/
    ) {
        $handler->{data}{customer_email}    = $handler->{data}{customer_id};
        $handler->{data}{customer_id}       = get_customer_by_email($handler->{dbh}, $handler->{data}{customer_email});
    }

    # optional view type from query string
    $handler->{data}{view_type} = $handler->{request}->param('view_type');

    # hash of department id's for display logic
    my $TT_CONSTANTS_REF = {
        DEP_PERSONALSHOPPING    => $DEPARTMENT__PERSONAL_SHOPPING,
        DEP_MARKETING           => $DEPARTMENT__MARKETING,
    };
    lock_hash(%$TT_CONSTANTS_REF);

    $handler->{data}{tt_constants} = $TT_CONSTANTS_REF;

    my $customer = is_valid_database_id( $handler->{data}{customer_id} )
        ? $handler->schema->resultset('Public::Customer')->find( $handler->{data}{customer_id} )
        : undef;

    # get customer data for display
    if ( $customer ) {

        # Request Seaview account information if we have an account URN
        my $account_urn = undef;
        my $sv_customer_info = undef;
        try{
            if($account_urn
                 = $handler->{seaview}
                           ->registered_account($handler->{data}{customer_id})){

                # Making this request has the side effect of updating the local XT
                # database with any account data changes from Seaview.
                my $seaview_account = $handler->{seaview}->account($account_urn);

                if ( defined $seaview_account ) {

                    $sv_customer_info = $seaview_account->as_dbi_like_hash;

                    # SVW-354: Remove Seaview sourced customer info that is
                    # present in the XT database. This data should be updated by
                    # accessing Seaview anyway
                    delete $sv_customer_info->{title};
                    delete $sv_customer_info->{first_name};
                    delete $sv_customer_info->{last_name};
                    delete $sv_customer_info->{category_id};
                }
            }
        }
        catch {
            # We tried to load some Seaview data but failed - log and carry on
            xt_logger->warn($_);
        };

        # Grab customer information from XT db
        $handler->{data}{customer_info}
          = get_customer_info($handler->{dbh}, $handler->{data}{customer_id});

        if(defined $account_urn){
            # Overlay Seaview information if we have a linked account
            @{$handler->{data}{customer_info}}{keys %$sv_customer_info}
              = values %$sv_customer_info;
        }

        $handler->{data}{orders} = get_customer_orders( $handler->{dbh}, $handler->{data}{customer_id} );
        $handler->{data}{customer}{notes} = get_customer_notes( $handler->{dbh}, $handler->{data}{customer_id} );
        $handler->{data}{customer_categories} = get_customer_categories($handler->{dbh});
        $handler->{data}{contact_subjects}= $customer->get_csm_available_to_change();
        $handler->{data}{has_marketing_high_value} = $customer->has_new_high_value_action;

        my $last_new_high_value = $customer
            ->customer_actions
            ->get_last_new_high_value;

        # Only set this value if we have a defined new_high_value, otherwise default
        # to 'Unknown Date' (a user should never see this, as this value is only
        # displayed when the customer has a new_high_value action).
        $handler->{data}{marketing_high_value_date} = $last_new_high_value
            ? $last_new_high_value
                ->date_created
                ->strftime( '%Y-%m-%d %H:%M' )
            : 'Unknown Date';

        eval {
            get_customer_credit($handler, $customer);
        };

        if ($@) {
            xt_warn($@);
        }

        $handler->{data}{sales_channel} = $handler->{data}{customer_info}{sales_channel};


        # loop through customer orders to get extra info - address, shipments and returns history
        foreach my $order_id ( sort {$a <=> $b} keys %{ $handler->{data}{orders} } ) {
            my $inv_addr_id = $handler->{data}{orders}{$order_id}{invoice_address_id};

            # check if an address we haven't seen yet was used for this order
            if (!$handler->{data}{address_history}{invoice}{ $inv_addr_id }){
                $handler->{data}{address_history}{invoice}{ $inv_addr_id }{order_nr}= $handler->{data}{orders}{$order_id}{order_nr};
                $handler->{data}{address_history}{invoice}{ $inv_addr_id }{address} = get_address_info( $handler->{schema}, $inv_addr_id );
            }

            # get shipments on the order
            $handler->{data}{orders}{$order_id}{shipments}
                = get_order_shipment_info( $handler->{dbh}, $order_id );

            # loop through shipments and get extra info
            foreach my $ship_id ( sort {$a <=> $b} keys %{ $handler->{data}{orders}{$order_id}{shipments} } ){
                my $ship_addr_id = $handler->{data}{orders}{$order_id}{shipments}{$ship_id}{shipment_address_id};

                ## check if an address we haven't seen yet was used for the shipment
                if (!$handler->{data}{address_history}{shipment}{ $ship_addr_id }){
                    $handler->{data}{address_history}{shipment}{ $ship_addr_id }{order_nr} = $handler->{data}{orders}{$order_id}{order_nr};
                    $handler->{data}{address_history}{shipment}{ $ship_addr_id }{shipment_nr}= $ship_id;
                    $handler->{data}{address_history}{shipment}{ $ship_addr_id }{address} = get_address_info( $handler->{schema}, $ship_addr_id );
                }

                # get returns on shipment
                $handler->{data}{orders}{$order_id}{shipments}{$ship_id}{returns} = get_shipment_returns( $handler->{dbh}, $ship_id );

                # loop through returns to get items
                foreach my $return_id ( keys %{ $handler->{data}{orders}{$order_id}{shipments}{$ship_id}{returns} } ){
                    $handler->{data}{orders}{$order_id}{shipments}{$ship_id}{returns}{$return_id}{return_items} = get_return_item_info( $handler->{dbh}, $return_id );
                }
            }

        }

        # get any matching customer accounts for display on page
        my $matched_customers = match_customer($handler->{dbh}, $handler->{data}{customer_id});

        foreach my $customer_id ( @$matched_customers ) {
            $handler->{data}{matched_customers}{ $customer_id } = get_customer_info($handler->{dbh}, $customer_id);
        }

        # build left hand navigation
        push(
            @{ $handler->{data}{sidenav}[0]{'None'} },
            { 'title' => 'Back', 'url' => "javascript:history.go(-1)" }
        );

        push(
            @{ $handler->{data}{sidenav}[0]{'None'} },
            {   title => "Add Note",
                url   => "$short_url/Note?parent_id=$handler->{data}{customer_id}&note_category=Customer&sub_id=$handler->{data}{customer_id}"
            }
        );

        # link to eGain contact history
        my $egain_url = config_var('eGain', 'url');
        push(
            @{ $handler->{data}{sidenav}[0]{'None'} },
            {   title => "Contact History",
                url   => "javascript:void window.open('$egain_url/system/web/view/platform/agent/info/custhist/Custom_Customer_history_NAP/getCustomerCaseNap.jsp?email_address=".$handler->{data}{customer_info}{email}."');"
            }
        );

        push(
            @{ $handler->{data}{sidenav}[1]{'View Type'} },
            {   title => "Summary",
                url   => "$short_url/CustomerView?customer_id=$handler->{data}{customer_id}"
            }
        );

        push(
            @{ $handler->{data}{sidenav}[1]{'View Type'} },
            {   title => "Full Details",
                url   => "$short_url/CustomerView?customer_id=$handler->{data}{customer_id}&view_type=Full"
            }
        );

    }
    else {
        $handler->{data}{error_msg} = "No customer record could be found";
        # Set the customer_id to undef, so the template does not render an empty
        # customer record.
        $handler->{data}{customer_id} = undef;
    }

    $handler->process_template( undef );

    return OK;
}

sub get_customer_credit {
    my ($handler, $customer) = @_;

    # APS-591 - we're not going to get any store credit info from
    # the website if this channel doesn't actually have a website
    if ($customer->channel->is_fulfilment_only) {
        return;
    }

    my $client = XTracker::Role::WithCreditClient->build_customer_credit_client;

    my ($status,$credits) = $client->get_store_credit_and_log(
        $customer->channel->web_name,
        $customer->pws_customer_id,
    );

    if ($status ne 'ok') {
        require Data::Dumper;
        die "Unable to query website for store credit information: ".Data::Dumper::Dumper($credits);
    }

    return unless @$credits;

    my $currency = $handler->schema->resultset('Public::Currency')
        ->find_by_name( $credits->[0]{currencyCode} // 'UNK' )
        //
        $handler->schema->resultset('Public::Currency')->find_by_name( 'UNK' );


    $handler->{data}{credit} = {
        credit => $credits->[0]{credit},
        currency_id => $currency->id,
        currency => $currency->currency,
        sales_channel => $customer->channel->name
    };

    my $balance = $handler->{data}{credit}{credit};
    my $deltas = $credits->[0]{log};

    my %actions = (
        'REFUNDED' => 'Refund',
        'ORDERED' => 'Order',
        'ORDER_PAYMENT' => 'Order',
    );

    for my $l ( @{ $deltas } ) {
        my $created_by = delete $l->{createdBy};

        $l->{action} = $actions{$l->{type}} || $l->{type};

        if( $created_by =~ /^xt-([0-9]+)$/){
            my $op =  $handler->schema->resultset('Public::Operator')->find($1);
            $l->{name} = $op->name if $op;
        }
        else {
           $l->{name} = $created_by;
        }

        $l->{date} = DateTime::Format::ISO8601->parse_datetime( $l->{date}{iso8601} );

        if (my $o_nr = delete $l->{orderNumber}) {
            my $o = $handler->schema->resultset('Public::Orders')
                ->search({ order_nr => $o_nr }, { rows => 1 })->next;
            if ( $o ) {
                $l->{orders_id} = $o->id;
                $l->{action}    .= " (O.Nr: $o_nr)";
            }
        }

        $l->{balance}   = $balance;
        $balance        -= $l->{delta};
        $l->{change}    = delete  $l->{delta};

        push @{$handler->{data}{credit_log}}, $l;
    }

}

1;
