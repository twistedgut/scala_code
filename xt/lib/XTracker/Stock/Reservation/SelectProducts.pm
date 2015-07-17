package XTracker::Stock::Reservation::SelectProducts;

use strict;
use warnings;

use XTracker::Logfile                   qw( xt_logger );
use XTracker::Image;
use XTracker::Error;
use XTracker::Navigation                qw( build_sidenav );
use XTracker::Config::Local;

use XTracker::Database::Reservation     qw( :DEFAULT get_reservation_variants );
use XTracker::Database::Product         qw( :DEFAULT );
use XTracker::Database::Utilities       qw( :DEFAULT );
use XTracker::Database::Customer        qw( get_customer_from_pws );
use XTracker::Database::Stock           qw( :DEFAULT get_saleable_item_quantity get_ordered_item_quantity get_reserved_item_quantity );

use XTracker::Constants::FromDB         qw( :variant_type :reservation_status :reservation_source );
use XTracker::Constants::Reservations   qw( :reservation_messages );

use Number::Format;
use Template::Stash;
use Try::Tiny;

my $logger = xt_logger(__PACKAGE__);

sub handler {
    __PACKAGE__->new(XTracker::Handler->new(shift))->process();
}

sub new {
    my ($class, $handler) = @_;

    $handler->{data}{pids_string}   = '';
    $handler->{data}{section}       = 'Reservation';
    $handler->{data}{subsection}    = 'Customer';
    $handler->{data}{subsubsection} = 'Multiple Reservations';
    $handler->{data}{content}       = 'stocktracker/reservation/selectproducts.tt';
    $handler->{data}{js}            = '/javascript/reservations.js';
    $handler->{data}{css}           = '/css/reservations.css';
    $handler->{data}{sidenav}       = build_sidenav({
        navtype    => 'reservations',
        res_filter => 'Personal'
    });

    my $self = {
        handler => $handler
    };

    return bless($self, $class);
}

sub process {
    my ($self) = @_;

    my $handler    = $self->{handler};
    my $customer   = undef;
    my $channel    = undef;
    my $pre_order  = undef;
    my $product    = undef;
    my $rtn_url    = '/StockControl/Reservation/Customer?';
    my @clean_pids = ();
    my @valid_pids = ();

    # Get customer data
    if ($handler->{param_of}{customer_id}) {
        $logger->debug('A customer_id was provided so lets use that');
        my $err;
        try {
            $handler->{data}{customer} = $handler->schema->resultset('Public::Customer')->find($handler->{param_of}{customer_id});
            $customer                  = $handler->{data}{customer};
            $err = 0;
        }
        catch {
            $logger->warn($_);
            xt_warn($RESERVATION_MESSAGE__INVALID_CUSTOMER_ID);
            $err = 1;
        };
        return $handler->redirect_to('/StockControl/Reservation/Customer') if $err;

        $handler->{data}{sales_channel} = $handler->{data}{customer}->channel->name;
        $channel                        = $customer->channel;
        $rtn_url                       .= '&customer_id='.$customer->id;

        $handler->{data}{reservation_source_id} = $handler->{param_of}{reservation_source_id};
        $handler->{data}{reservation_type_id} = $handler->{param_of}{reservation_type_id};
    }
    else {
        xt_warn($RESERVATION_MESSAGE__CUSTOMER_NOT_FOUND);
        return $handler->redirect_to('/StockControl/Reservation/Customer');
    }

    if ($handler->{param_of}{pids}) {
        foreach my $dirty_pid (split(/[\n\s,]+/,  $handler->{param_of}{pids})) {
            if ($dirty_pid =~ m/^(\d+)-?(\d+)*/g) {
                if (is_valid_database_id($1)) {
                    push(@clean_pids, {
                        id    => $1,
                        size  => $2,
                    });
                }
                else {
                    xt_warn(sprintf($RESERVATION_MESSAGE__NOT_A_PID_OR_SKU, $1));
                }
            }
        }
    }
    # Check if customer exists on PWS
    unless ($handler->{param_of}{skip_pws_customer_check}) {
        $logger->debug('Calling the PWS for customer check');
        my $err;
        try {
            my $dbh_web = XTracker::Database::get_database_handle({
                name => 'Web_Live_'.$handler->{data}{customer}->channel->business->config_section,
                type => 'readonly',
            });

            my $pws_customer = get_customer_from_pws($dbh_web, $handler->{data}{customer}->is_customer_number);
            $dbh_web->disconnect;
            $err = 0;
            # this needs to be disabled for dev
            unless ($pws_customer) {
                xt_warn($RESERVATION_MESSAGE__CUSTOMER_NOT_ON_PWS);
                $err = 1;
            }
        }
        catch {
            $logger->warn($_);
            xt_warn($RESERVATION_MESSAGE__UNABLE_TO_CONNECT_TO_PWS);
            $err = 1;
        };
        return $handler->redirect_to('/StockControl/Reservation/Customer') if $err;
    }
    else {
        $logger->debug('Skipping the PWS customer check');
    }

    # If these exists then user came back from confirmation page
    if ($handler->{param_of}{variants}) {
        $logger->debug('Variants and reservation source provided so lets repopulate the page');
        if (ref($handler->{param_of}{variants}) eq 'ARRAY') {
            foreach my $variant_id (@{$handler->{param_of}{variants}}) {
                $handler->{data}{checked_variants}{$variant_id} = 1;
            }
        }
        else {
            $handler->{data}{checked_variants}{$handler->{param_of}{variants}} = 1;
        }
    }

    # Loop through each PID submited
    foreach my $clean_product (@clean_pids) {
        my $skip_next;
        try {
            $product = $handler->{schema}->resultset('Public::Product')->find($clean_product->{id});
            $skip_next = 0;
        }
        catch {
            $logger->warn($_);
            xt_warn(sprintf($RESERVATION_MESSAGE__CANT_FIND_PRODUCT, $clean_product->{id}));
            $skip_next = 1;
        };
        next if $skip_next;

        # Skip if product not found
        unless ($product) {
            xt_warn(sprintf($RESERVATION_MESSAGE__CANT_FIND_PRODUCT, $clean_product->{id}));
            next;
        }

        # Skip if product not in this channel
        unless ($product->get_product_channel->channel_id == $channel->id) {
            xt_warn(sprintf($RESERVATION_MESSAGE__PRODUCT_WRONG_CHANNEL, $product->id));
            next;
        }

        $logger->debug('Fetching data for product #'.$product->id);

        try {
            # Get images for products
            $handler->{data}{products}{$product->id}{images} = get_images({
                product_id     => $product->id,
                live           => 1,
                schema         => $handler->{schema},
                business_id    => $channel->business_id,
                image_host_url => $handler->{data}{image_host_url},
            });

            my @variants  = $product->get_variants_with_defined_sizes();

            # Get product description
            $handler->{data}{products}{$product->id}{data} = {
                description => $product->wms_presentation_name,
            };

            my $rsvqty = get_reserved_item_quantity($handler->{dbh}, $product->id, $RESERVATION_STATUS__UPLOADED)->{$channel->name}; # TODO replace with dbix

            foreach my $variant (@variants) {
                $logger->debug('Fetching data for variant #'.$variant->id);
                $handler->{data}{products}{$product->id}{variants}{$variant->id} = {
                    sku           => $variant->sku,
                    size          => $variant->size->size,
                    designer_size => $variant->designer_size->size,
                    freestock     => $variant->current_stock_on_channel($channel->id) || 0,
                    on_order      => $variant->get_ordered_quantity_for_channel($channel->id) || 0,
                    reserved_qty  => $rsvqty->{$variant->id} || 0,
                    customer_rsv  => $customer->reservations->search({
                        variant_id  => $variant->id,
                        status_id   => {'IN' => [$RESERVATION_STATUS__PENDING, $RESERVATION_STATUS__UPLOADED]},
                    },{})->count || 0,
                }
            }

            push(@valid_pids, $clean_product->{id});

        }
        catch {
            $logger->warn($_);
            delete($handler->{data}{products}{$clean_product->{id}});
            xt_warn(sprintf($RESERVATION_MESSAGE__CANT_FIND_PRODUCT_DATA, $clean_product->{id}));
        };
    }

    # Get reservation sources
    $handler->{data}{reservation_source_list}
        = [$handler->schema->resultset('Public::ReservationSource')->active_list_by_sort_order->all];

    # Get reservation types
    $handler->{data}{reservation_type_list}
        = [$handler->schema->resultset('Public::ReservationType')->list_by_sort_order->all];

    $handler->{data}{pids}   = join("\n", @valid_pids);
    $handler->{data}{params} = $handler->{param_of};

    return $handler->process_template;
}

1;
