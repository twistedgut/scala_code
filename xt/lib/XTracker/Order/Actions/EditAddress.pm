package XTracker::Order::Actions::EditAddress;

use NAP::policy;
use DateTime::Format::Pg;
use URI::Escape;

use XTracker::Handler;
use XTracker::Logfile qw(xt_logger);
use XTracker::Database::Shipment;
use XTracker::Database::Order;
use XTracker::Database::Address;
use XTracker::Database::OrderPayment qw( get_order_payment check_order_payment_fulfilled );
use XTracker::Database::Channel qw(get_channel_details);

use XTracker::DHL::RoutingRequest qw( get_routing_request_log );

use XTracker::EmailFunctions;
use XTracker::Constants::Address    qw( :address_update_messages );
use XTracker::Constants::FromDB qw( :department );
use XTracker::Config::Local qw( config_var customercare_email );
use XTracker::Utilities qw( parse_url number_in_list );
use XTracker::Order::Utils;
use XT::Net::Seaview::Client;
use XT::Net::Seaview::Utils;

use XTracker::Error;


=head1 NAME

XTracker::Order::Actions::EditAddress

=head1 DESCRIPTION

Create or edit an order address. The changes are passed on to ConfirmAddress

=cut

sub handler {
    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    # If we're using an existing address without edits move on to Confirm
    # This is based on the name of the submit button which is clearly brittle
    # but it avoids any JavaScript wrangling and keeps the form submission
    # simple
    if(defined $handler->{param_of}{submit_use}){
        # Redirect to confirmation
        my $param_str = '?';
        $param_str .= join '&',
                           map { uri_escape($_)
                                   . '=' . uri_escape($handler->{param_of}{$_})}
                                keys %{$handler->{param_of}};

        return $handler->redirect_to('ConfirmAddress' . $param_str);
    }
    else{
        # Just display the address edit form
    }

    # get instance of XT (INTL or AM)
    my $instance   = config_var('XTracker', 'instance');

    # Put Seaview client into handler
    $handler->{seaview} = XT::Net::Seaview::Client->new({schema => $handler->{schema}});

    # Order utilities
    my $utils = XTracker::Order::Utils->new( { schema => $handler->{schema} } );

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content}       = 'ordertracker/shared/editaddress.tt';
    $handler->{data}{short_url}     = $short_url;
    $handler->{data}{css} = '/css/breadcrumb.css';
    $handler->{data}{js} = '/javascript/editaddress_dropdown.js';

    # get the list of available countries from the database for select box
    $handler->{data}{countries} = [ $handler->schema->resultset('Public::Country')->valid_countries_for_editing_address->by_name->all ];

    # Get country subdivision if any
    $handler->{data}{country_subdivision} = $handler->schema->resultset('Public::CountrySubdivision')->json_country_subdivision_for_ui;

    # Parameters
    $handler->{data}{order_id}     = $handler->{param_of}{order_id};
    $handler->{data}{address_type} = $handler->{param_of}{address_type};
    $handler->{data}{shipment_id}  = $handler->{param_of}{shipment_id};
    $handler->{data}{base_address} = $handler->{param_of}{address};
    # indicates whether the 'Force' option is shown on the final confirmation page
    $handler->{data}{can_show_force_address} = $handler->{param_of}{can_show_force_address};

    if ( $handler->{data}{order_id} ) {
        # pass the Order Object to the TT
        $handler->{data}{order_obj} =
                $handler->schema->resultset('Public::Orders')
                                    ->find( $handler->{data}{order_id} );
    }

    # Order and shipment information
    my $hd = $handler->{data};
    $handler->{data}{sales_channel}
      = $handler->{data}{order_data}{sales_channel};
    $handler->{data}{order_data}
      = get_order_info( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{shipment_data}
      = get_shipment_info($handler->{dbh}, $handler->{data}{shipment_id});

    # Create bail-out URL
    my $orderview_url
      = $short_url . '/ChooseAddress'
                   . '?address_type=' . $handler->{data}{address_type}
                   . '&order_id=' . $handler->{data}{order_id};

    if($handler->{data}{shipment_id}){
        $orderview_url .= '&shipment_id=' . $handler->{data}{shipment_id}
    }

    # Create back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} },
         {'title' => 'Back', 'url' => $orderview_url,});

    # Clear the title
    $handler->{data}{layout}{notitle} = 1;

    # Sales channel for layout
    $handler->{data}{sales_channel}
      = $handler->{data}{order_data}{sales_channel};

    my $addr_key = undef;
    if ($handler->{data}{address_type} eq "Billing"){
        # we're editing a billing address
        $handler->{data}{subsubsection} = 'Edit Billing Address';
        $addr_key = $handler->{data}{order_data}{invoice_address_id};

        $handler->{data}{breadcrumb}{steps}
          = ['1. Change Address','2. Confirmation'];
        $handler->{data}{breadcrumb}{current} = '1. Change Address';

        # Is address editable in order's current flow state?
        my $addr_change_ok
          = $utils->billing_address_change_allowed($handler->{data}{order_id});

        # Invert for the template
        $handler->{data}{no_edit} = $addr_change_ok ? 0 : 1;
    }
    elsif ($handler->{data}{address_type} eq "Shipping"){
        if ( my $order_obj = $handler->{data}{order_obj} ) {
            if ( $order_obj->payment_method_insists_billing_and_shipping_address_always_the_same ) {
                xt_info( $ADDRESS_UPDATE_MESSAGE__BILLING_AND_SHIPPING_ADDRESS_SAME );
            }
        }

        if($handler->{data}{shipment_id}){

            # we're editing a shipping address
            $handler->{data}{subsubsection} = 'Edit Shipping Address';
            $addr_key = $handler->{data}{shipment_data}{shipment_address_id};

            # Breadcrumb
            $handler->{data}{breadcrumb}{steps}
              = ['1. Change Address','2. Check Order','3. Confirmation'];
            $handler->{data}{breadcrumb}{current} = '1. Change Address';

            # Is address editable in order's current flow state?
            my $addr_change_ok
              = $utils->shipping_address_change_allowed($handler->{data}{order_id},
                                                        $handler->{data}{shipment_id},
                                                        $handler->{data}{department_id});

            # Invert for the template
            $handler->{data}{no_edit} = $addr_change_ok ? 0 : 1;
        }
        else{
            $handler->{data}{subsubsection}  = 'Select Shipment';
            $handler->{data}{shipments}      = get_order_shipment_info( $handler->{dbh}, $handler->{data}{order_id} );
            $handler->{data}{content}       = 'ordertracker/shared/chooseaddress.tt';
            $handler->{data}{layout}{notitle} = 0;
            return $handler->process_template( undef );
        }
    }
    else {
        # Unknown address type so bail - need a user message here
        xt_logger->warn('Failed to determine address type - redirect to order');
        return $handler->redirect_to($orderview_url);
    }

    # Grab the base address as selected in the previous step
    if(defined $handler->{data}{base_address}){
        if($handler->{seaview}
                   ->service
                   ->seaview_resource($handler->{data}{base_address})){
            try{
                # It's a Seaview resource - grab it
                my $address_urn
                  = uri_unescape($handler->{data}{base_address});

                $handler->{data}{current_address}
                  = $handler->{seaview}->address($address_urn)
                                       ->as_dbi_like_hash;

                $handler->{data}{current_address} =
                  XT::Net::Seaview::Utils->state_county_switch(
                                             $handler->{data}{current_address});
            }
            catch {
                # We think it's a Seaview address but we can't grab the remote
                # resource. Just use the local reference
                $handler->{data}{current_address}
                  = get_address_info( $handler->{dbh}, $addr_key);
                $handler->{data}{base_address} = $addr_key;
                xt_logger->info($_);
            };
        }
        elsif($handler->{data}{base_address} ne 'new'){
            # It's a local resouce - grab it
            $handler->{data}{current_address}
              = get_address_info($handler->{dbh},
                                 $handler->{data}{base_address});
        }
        else{
            # We want to create a new resource
            $handler->{data}{current_address} = undef;
        }
    }
    else{
        # No base - we'll just use the current local address
        $handler->{data}{base_address} = $addr_key;
        $handler->{data}{current_address}
          = get_address_info( $handler->{dbh}, $addr_key);
    }


    return $handler->process_template( undef );
}
