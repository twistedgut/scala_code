package XTracker::QuickSearch;

use NAP::policy "tt";

use XTracker::Constants::FromDB qw(
    :flag
    :order_status
    :pre_order_status
    :shipment_status
    :authorisation_level
);

use XTracker::Handler;
use XTracker::Error;

use XTracker::Utilities qw( :string ff_deeply);
use XTracker::Logfile qw( xt_logger );
use XTracker::Config::Local qw( config_var order_nr_regex_including_legacy );

use XTracker::Order::CustomerCare::OrderSearch::Search    qw( :search );
use XTracker::Order::CustomerCare::PreOrderSearch::Search    qw( :search );
use XTracker::Order::CustomerCare::CustomerSearch::Search qw( :search );
use XTracker::Database::Product qw( get_product_data );

use XTracker::Database::Channel qw( get_channels );

sub handler {
    my $handler = XTracker::Handler->new(shift);
    my $query = $handler->{param_of}{'quick_search'};

    $handler->{data}{content} = 'quicksearch/quicksearch.tt';

    $handler->{data}{order_results}     = {};
    $handler->{data}{customer_results}  = {};
    $handler->{data}{query}             = $query;
    $handler->{data}{query_description} = '';
    $handler->{data}{search_type}       = '';

    my $max_size_limit = config_var('Limit','max_query_results') || 50;

    # redirection uri base elements for single result handling
    my $redirect_uri = {
        order       => '/CustomerCare/OrderSearch/OrderView?order_id=',
        pre_order   => '/StockControl/Reservation/PreOrder/Summary?pre_order_id=',
        product     => '/StockControl/Inventory/Overview?product_id=',
        sample      => '/StockControl/Inventory/ShipmentView/'
    };

    # figure out the nature of the query we've been given

    my ( $query_param, $query_handler ) = _decode_quick_search( $query );

    if ( $query_param && $query_handler ) {
        $handler->{data}{query_description} = $query_handler->{description};
        $handler->{data}{search_type}       = $query_handler->{search_type};

        local $@;
        my $redirect;
        my $error;
        my @sidenav;

        $redirect = eval {
            if ( ($query_handler->{search_type} eq 'product_id') &&
                        ( $query !~ /\Aop\s+\d+\z/i ) &&
                        get_product_data( $handler->{dbh}, {
                            type => 'product_id', id => $query_param
                        } ) ) {
                return $redirect_uri->{product}.$query_param;
            }
            return;
        };
        $error .= $@ if $@;
        return $handler->redirect_to($redirect) if $redirect;

        $redirect = eval {
            if ( _sub_section_auth($handler, 'Customer Care', 'Order Search') ) {
                my $orders = find_orders( $handler->{dbh},
                    { search_type => $query_handler->{search_type},
                      search_terms => $query_param },
                      $max_size_limit );

                $handler->{data}{order_results} = $orders;

                if ( @$orders == 1
                  && $query_handler->{search_type} =~ qr/\A(?:
                    order_number |
                    shipment_id |
                    rma_number |
                    airwaybill
                  )\z/x
                ) {
                    # Redirect to sample shipment if necessary
                    my $uri = $orders->[0]{order_id}
                            ? $redirect_uri->{order}.$orders->[0]{order_id}
                            : $redirect_uri->{sample}.$orders->[0]{id};
                    return $uri;
                }
                if ( @$orders ) {
                    push @sidenav, {
                        title => 'Orders / Shipments',
                        url => '#orderresults'
                    };
                }
            }
            return;
        };
        $error .= $@ if $@;
        return $handler->redirect_to($redirect) if $redirect;

        $redirect = eval {
            if ( _sub_section_auth($handler, 'Customer Care', 'Customer Search') ) {

                if ( $handler->operator->is_operator('Customer Care', 'Customer Search' ) ) {
                    # Ensure old authorisation level requirement is satisfied.
                    # TODO we will need to change/remove this once ACL migration complete
                    $handler->{data}{is_operator}       = 1;
                }

                # find_customers expects a scalar for the search_terms so make sure it is
                if ( ref $query_param eq 'HASH' ) {
                    $query_param = $query_param->{$query_handler->{search_type}};
                }

                my $customers = find_customers( $handler->{dbh},
                    { search_type => $query_handler->{search_type},
                      search_terms => $query_param },
                      $max_size_limit );

                $handler->{data}{customer_results} = $customers || 0;

                if ( $customers && ( scalar (keys %$customers) > 0 ) ) {
                    push @sidenav, {
                        title => 'Customers',
                        url => '#customerresults'
                    };
                }
            }
            return;
        };
        $error .= $@ if $@;
        return $handler->redirect_to($redirect) if $redirect;

        $redirect = eval {
            # Access to Pre_Order information is limited to those with Reservation auth_level
            if ( _sub_section_auth($handler, 'Stock Control', 'Reservation') ) {
                my $pre_orders = find_pre_orders($handler->{schema},
                    { search_type => $query_handler->{search_type},
                      search_terms => $query_param },
                      $max_size_limit );

                $handler->{data}{pre_order_results} = $pre_orders || 0;

                if ( $query_handler->{search_type} eq 'pre_order_number' &&
                        (scalar (my @keys = keys %$pre_orders) == 1) ) {
                    return $redirect_uri->{pre_order}.$keys[0];
                }
                if ( $pre_orders && ( scalar (keys %$pre_orders) > 0 ) ) {
                    push @sidenav, {
                        title => 'PreOrders',
                        url => '#preorderresults'
                    };
                }
            }
            return;
        };
        $error .= $@ if $@;
        return $handler->redirect_to($redirect) if $redirect;

        xt_warn($error) if $error;
        if ( @sidenav ) {
            $handler->{data}{sidenav} = [{ 'QuickSearch' => \@sidenav }];
        }
    }

    return $handler->process_template(undef);
}

# get the RegEx pattern for any possible Order Number in the DC
my $order_number_regex = order_nr_regex_including_legacy();

my $query_handlers = [
    {
        description => 'Customer number',
        search_type => 'customer_number',
        match => qr{\Ac\s+(?<term>\d+)\z}i,
    },
    {
        description => 'Customer name',
        search_type => 'customer_name',
        match => qr{\Ac\s+(?<term>.+)\z}i,
    },
    {
        description => 'Customer first name',
        search_type => 'first_name',
        match => qr{\Af\s+(?<term>.+)\z}i,
    },
    {
        description => 'Customer last name',
        search_type => 'last_name',
        match => qr{\Al\s+(?<term>.+)\z}i,
    },
    {
        description => 'Order number',
        search_type => 'order_number',
        match => qr{\Ao\s+(?<term>${order_number_regex})\z}i,
    },
    {
        description => 'PreOrder Number',
        search_type => 'pre_order_number',
        match => qr{\A(?:pr\s+p(?<term>\d+)|pr\s+(?<term>\d+)|p(?<term>\d+)|o\s+p(?<term>\d+))\z}i,
    },
    {
        description => 'Product ID / SKU',
        search_type => 'product_id',
        match => qr{\Ap\s+(?<term>\d+)(?:|-\d+)\z}i,
    },
    {
        description => 'Orders for Product ID',
        search_type => 'product_id',
        match => qr{\Aop\s+(?<term>\d+)\z}i,
    },
    {
        description => 'Orders for SKU',
        search_type => 'sku',
        match => qr{\A(?:op|ok)\s+(?<term>\d+-\d+)\z}i,
    },
    {
        description => 'Box ID',
        search_type => 'box_id',
        match => qr{\Ax\s+(?<term>\d+)\z}i,
    },
    {
        description => 'Shipment number',
        search_type => 'shipment_id',
        match => qr{\As\s+(?<term>\d+)\z}i,
    },
    {
        description => 'RMA number',
        search_type => 'rma_number',
        match => qr{\Ar\s+(?<term>[ur]\d+-\d+(?:|-[^-]+))\z}i, # R for DC1 returns, U for DC2
    },
    {
        description => 'Airwaybill number',
        search_type => 'airwaybill',
        match => qr{\Aw\s+(?<term>.+)\z}i,
    },
    {
        description => 'Billing address',
        search_type => 'billing_address',
        match => qr{\Ab\s+(?<term>.+)\z}i,
    },
    {
        description => 'Shipping address',
        search_type => 'shipping_address',
        match => qr{\Aa\s+(?<term>.+)\z}i,
    },
    {
        description => 'Post/Zip code',
        search_type => 'postcode',
        match => qr{\Az\s+(?<term>.+)\z}i,
    },
    {
        description => 'Telephone number',
        search_type => 'telephone_number',
        match => qr{\At\s+(?<term>[0-9 \(\)\+\-]+)\z}i,
    },
    {
        description => 'Customer email',
        search_type => 'email',
        match => qr{\Ae\s+(?<term>(?:[^@]+|@[^@]+|[^@]+@[^@]+))\z}i,
    },
];


# passing through the above data structure in order, return the first
# match against the search term we have, or nothing if nothing matches

sub _decode_quick_search {
    my $search_term = trim( shift );

    return unless $search_term;

    if ( $search_term =~ m{\A(?<term>\d+)\z} ) {
        return ( $+{term}, { description => 'any ID', search_type => 'any' } );
    }

    foreach my $query_handler (@$query_handlers) {
        if ($search_term =~ $query_handler->{match} ){
            if ( grep { /$query_handler->{search_type}/ } qw/first_name last_name customer_name/ ) {
                return ( { $query_handler->{search_type} => $+{term} },
                         $query_handler );
            }
            else {
                return $+{term}, $query_handler;
            }
        }
    }
    if ( $search_term =~ m{\A(?<term>.+)\z} ) {
        return ( { customer_name => $+{term} },
                 { search_type => 'customer_name',
                   description => 'Customer name' } );
    }
    return;
}

sub _sub_section_auth {
    my ( $handler, $section, $sub_section ) = @_;
    die "No handler passed to _sub_section_auth" unless $handler;
    die "No section name passed to _sub_section_auth" unless $section;
    die "No sub section name passed to _sub_section_auth" unless $sub_section;

    return $handler->operator_authorised( {
        section     => $section,
        sub_section => $sub_section,
    } );
}

1;
