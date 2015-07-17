package XTracker::Order::Actions::ChooseAddress;

use NAP::policy;
use DateTime::Format::Pg;

use XTracker::Handler;
use XTracker::Logfile qw(xt_logger);
use XTracker::Utilities qw(parse_url);
use XTracker::Config::Local qw( config_var );
use XTracker::Order::Utils;
use XTracker::Database::Order qw/ get_order_info /;
use XTracker::Database::Shipment qw/ get_shipment_info
                                     get_order_shipment_info /;
use XTracker::Database::Address qw/ get_address_info
                                    get_seaview_address_for_id
                                    add_addr_key /;

use XTracker::Constants::Address    qw( :address_update_messages );

use XTracker::Error;

use XT::Net::Seaview::Client;
use XT::Net::Seaview::Utils;

=head1 NAME

XTracker::Order::Actions::ChooseAddress

=head1 DESCRIPTION

Request a change to an order address by using or editing an existing address
or creating a new address. The customer's available address list is sourced
from either previously used addresses in XT database or the current address
list from Seaview, if the customer has a Seaview account. From here the
process moves to EditAddress using the chosen address as a base for edits.

=cut

sub handler {
    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    # Put Seaview client into handler
    $handler->{seaview}
      = XT::Net::Seaview::Client->new({schema => $handler->{schema}});

    # Order utilities
    my $utils = XTracker::Order::Utils->new( { schema => $handler->{schema} } );

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    # URL Parameters
    $handler->{data}{address_type} = $handler->{param_of}{address_type};
    $handler->{data}{order_id} = $handler->{param_of}{order_id};
    $handler->{data}{shipment_id} = $handler->{param_of}{shipment_id};

    if ( $handler->{data}{order_id} ) {
        # pass the Order Object to the TT
        $handler->{data}{order_obj} =
                $handler->schema->resultset('Public::Orders')
                                    ->find( $handler->{data}{order_id} );
    }

    $handler->{data}{section} = $section;
    $handler->{data}{subsection} = $subsection;
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content} = 'ordertracker/shared/chooseaddress.tt';
    $handler->{data}{short_url} = $short_url;
    $handler->{data}{css} = '/css/breadcrumb.css';
    $handler->{data}{js}  = [
        '/javascript/jquery/plugin/nap/utilities.js',
        '/javascript/customercare/choose_address.js',
        '/javascript/customercare/customer_addresses.js',
    ];
    $handler->{data}{layout}{notitle} = 1;

    # Get order info
    $handler->{data}{order_data}
      = get_order_info($handler->{dbh}, $handler->{data}{order_id});

    # back link in left nav
    my $back_url = '';
    if($short_url =~ m/InvalidShipments$/){ $back_url = $short_url }
    else{ $back_url = "$short_url/OrderView?order_id=$handler->{data}{order_id}" }
    push(@{ $handler->{data}{sidenav}[0]{'None'} },
         {'title' => 'Back',
          'url' => $back_url,
         });

    # Sales channel for layout
    $handler->{data}{sales_channel}
      = $handler->{data}{order_data}{sales_channel};

    my $curr_addr_key = undef;
    if ($handler->{data}{address_type} eq "Billing"){
        $curr_addr_key = $handler->{data}{order_data}{invoice_address_id};

        # Breadcrumb
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
            my $shipment_data
              = get_shipment_info($handler->{dbh}, $handler->{data}{shipment_id});
            $curr_addr_key = $shipment_data->{shipment_address_id};

            # Breadcrumb
            $handler->{data}{breadcrumb}{steps}
              = ['1. Change Address','2. Check Order','3. Confirmation'];
            $handler->{data}{breadcrumb}{current} = '1. Change Address';

            # Is address editable in order's current flow state?
            my $addr_change_ok
              = $utils->shipping_address_change_allowed($handler->{data}{order_id},
                                                        $handler->{data}{shipment_id},
                                                        $handler->{data}{department_id});

            #Message for non-ascii characters
            my $shipment = $handler->{schema}->resultset('Public::Shipment')->find($handler->{data}{shipment_id});
            if($shipment->is_on_hold_for_invalid_address_chars) {
                $handler->{data}{non_ascii_message} = "Please update address to remove all accents and non-English characters to release shipment from hold";
            }

            # Invert for the template
            $handler->{data}{no_edit} = $addr_change_ok ? 0 : 1;
        }
        else{
            $handler->{data}{subsubsection}  = 'Select Shipment';
            $handler->{data}{shipments}      = get_order_shipment_info( $handler->{dbh}, $handler->{data}{order_id} );
            $handler->{data}{layout}{notitle} = 0;

            return $handler->process_template( undef );
        }
    }
    else{
        # TODO: oh dear
        die "Unknown address type - $handler->{data}{address_type}";
    }

    # Get the current address from XT db
    $handler->{data}{current_address}
      = get_address_info( $handler->{dbh}, $curr_addr_key);
    my $curr_addr_id = $handler->{data}{current_address}{id};

    # Add form access key to current address
    $handler->{data}{current_address}
      = add_addr_key($handler->{data}{current_address});

    my $seaview_address = get_seaview_address_for_id( $handler->schema, $curr_addr_id );
    if ( $seaview_address ) {
        $seaview_address = add_addr_key( $seaview_address );
        $handler->{data}{seaview_current_address} = XT::Net::Seaview::Utils->state_county_switch(
            $seaview_address,
        );
    }

    return $handler->process_template( undef );
}

