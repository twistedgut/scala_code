package XTracker::Stock::GoodsIn::Returns::BookingIn;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Image;
use XTracker::Database qw(get_schema_using_dbh);
use XTracker::Database::Order qw( get_order_info );
use XTracker::Database::Return qw( find_return get_return_info get_return_notes get_return_item_info get_returns_arrived get_return_item_by_sku );
use XTracker::Database::Shipment qw( get_product_shipping_attributes get_shipment_info get_shipment_item_info get_shipment_stock_transfer_id );
use XTracker::Database::StockTransfer qw( get_stock_transfer );

use XTracker::Utilities qw( exists_and_defined );

use XTracker::Config::Local qw( config_var );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new( $r );

    $handler->{data}{section}           = 'Goods In';
    $handler->{data}{subsection}        = 'Returns In';
    $handler->{data}{subsubsection}     = '';
    $handler->{data}{content}           = 'stocktracker/goods_in/returns_in/bookingin.tt';
    $handler->{data}{page}              = $handler->{param_of}{'page'} || 1;

    # possible error msg from url
    $handler->{data}{error_msg} = $handler->{param_of}{error_msg} // undef;

    # This returns a redirection if no printer is selected at start of page load
    return $handler->check_for_printer if $handler->check_for_printer;

    # waybill length for form field
    $handler->{data}{waybill_length} = 18;

    # show REMOVE option for managers only
    if ( $handler->{data}{is_manager} ) {
        $handler->{data}{show_remove} = 1;
    }

    # process form post

    # return set as Removed
    if ( $handler->{param_of}{remove_arrival_id} // 0 ) {
        _remove_arrival( $handler );
    }

    # search form submitted
    if ( $handler->{param_of}{search_string} // 0 ) {
        $handler->{data}{search}  = $handler->{param_of}{search_string};
        $handler->{data}{returns} = find_return($handler->{dbh}, $handler->{param_of}{search_string});
    }

    # SKU submitted
    if ( $handler->{param_of}{return_sku} // 0 ) {
        _check_sku( $handler );
    }


    # get data for returns if found
    if ( my @returns = keys %{$handler->{data}{returns}} ){

        # back link for left nav
        push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "/GoodsIn/ReturnsIn" } );

        $handler->{data}{subsubsection} = 'Process Return';

        foreach my $return_id ( @returns ) {
            _get_return_info( $handler, $return_id );
        }

    }
    # otherwise get list of returns arrivals for front page
    else {
        my $schema = XTracker::Database::get_database_handle(
            { name => 'xtracker_schema', }
        );

        $handler->{data}{sidenav} = [{ None => [ {
            title => 'Set Return Station',
            url   => '/My/SelectPrinterStation?section=GoodsIn&subsection=ReturnsIn&force_selection=1',
        } ] }];

        unless ( $handler->{data}{datalite} // 0 ) {
            my $page = delete $handler->{param_of}{page} // 1;
            my $return_arrivals_rs = $schema->resultset('Public::ReturnArrival')->get_returns_arrived($page);
            @{$handler->{data}{paged_list}} = $return_arrivals_rs->all;
            $handler->{data}{pager} = $return_arrivals_rs->pager;

            $handler->{data}{remove_reasons}= [ $schema->resultset('Public::ReturnRemovalReason')->search()->all ];
        }

        $handler->{data}{js}            = ['/yui/yahoo/yahoo-min.js','/yui/event/event-min.js'];
    }

    $handler->process_template( undef );
}


sub _remove_arrival {
    my $handler     = shift;

    my $return_arrival_id   = $handler->{param_of}{remove_arrival_id};

    my $schema = XTracker::Database::get_database_handle(
        { name => 'xtracker_schema', }
    );

    eval {
        $schema->resultset('Public::ReturnArrival')->find($return_arrival_id)
            ->update( {
                        removed                 => 1,
                        return_removal_reason_id=> $handler->{param_of}{remove_reason},
                        removal_notes           => $handler->{param_of}{remove_notes},
                    } );
    };
    if (my $error = $@) {
        $handler->{data}{error_msg} = "Error removing Arrival: $error";
    }
    else {
        $handler->{data}{display_msg}   = "Arrival Removed";
    }

    return;
}


sub _get_return_info {

    my ( $handler, $return_id ) = @_;

    $handler->{data}{returns}{$return_id}                   = get_return_info($handler->{dbh}, $return_id);
    $handler->{data}{returns}{$return_id}{notes}            = get_return_notes($handler->{dbh}, $return_id);
    $handler->{data}{returns}{$return_id}{shipment_info}    = get_shipment_info($handler->{dbh}, $handler->{data}{returns}{$return_id}{shipment_id});
    $handler->{data}{returns}{$return_id}{shipment_items}   = get_shipment_item_info($handler->{dbh}, $handler->{data}{returns}{$return_id}{shipment_id});
    $handler->{data}{returns}{$return_id}{return_items}     = get_return_item_info($handler->{dbh}, $return_id);
    my $parent_id;

    my $order_id = $handler->{data}{returns}{$return_id}{shipment_info}{orders_id};

    if ($order_id) {
        $handler->{data}{returns}{$return_id}{order_info}   = get_order_info($handler->{dbh}, $order_id);
        $handler->{data}{sales_channel}                     = $handler->{data}{returns}{$return_id}{order_info}{sales_channel};
        $parent_id = $order_id;
    }
    else {
        my $stock_transfer_id                                   = get_shipment_stock_transfer_id($handler->{dbh}, $handler->{data}{returns}{$return_id}{shipment_id});
        $handler->{data}{returns}{$return_id}{stock_transfer}   = get_stock_transfer($handler->{dbh}, $stock_transfer_id);
        $handler->{data}{sales_channel}                         = $handler->{data}{returns}{$return_id}{stock_transfer}{sales_channel};
        $parent_id = $stock_transfer_id;
    }

    my $search_string = $handler->{data}{search};

    push(@{ $handler->{data}{sidenav}[0]{'None'} }, {
        'title' => "Add Note",
        'url'   => "/CustomerCare/OrderSearch/Note?parent_id=$parent_id&note_category=Return&sub_id=$return_id&came_from=returns_in&search_string=$search_string"
    });

    # get images and packing notes
    foreach my $item ( values %{$handler->{data}{returns}{$return_id}{shipment_items}} ) {
        my $product_id = $item->{product_id};
        $item->{ship_att}
            = get_product_shipping_attributes(
                $handler->{dbh},
                $product_id
        );

        $item->{image}
            = get_images({
                product_id => $product_id,
                live => 1,
                schema => $handler->schema,
            });
        $item->{product} =
            $handler->{schema}->resultset('Public::Product')->find($product_id);
    }

    return;

}

sub _check_sku {

    my ( $handler ) = @_;

    # loop through items already booked in
    foreach my $form_key ( keys %{ $handler->{param_of} } ) {
        if ( $form_key =~ m/book-(\d*)/ ) {
            $handler->{data}{booked}{$1} = 1;
        }
    }

    unless( exists_and_defined( $handler->{param_of},
                qw( return_id return_sku ) ) ) {
        $handler->{data}{msg} = "Please select or enter a SKU for this return and try again.";
        return;
    }

    # get details of sku entered
    my ($variant_id, $return_item_id, $wrong_sent_item)
        = get_return_item_by_sku(
            $handler->{dbh},
            $handler->{param_of}{return_id},
            $handler->{param_of}{return_sku}
    );

    # found sku in return
    if ($return_item_id) {

        # sku already scanned - maybe two of same sku ?
        if ($handler->{data}{booked}{$return_item_id}) {

            my ($other_variant_id, $other_return_item_id, $other_wrong_sent_item)
                = get_return_item_by_sku(
                    $handler->{dbh},
                    $handler->{param_of}{return_id},
                    $handler->{param_of}{return_sku},
                    $return_item_id
            );

            # found another instance of the sku in return - set to correct return_item_id
            if ($other_return_item_id) {
                $return_item_id     = $other_return_item_id;
                $wrong_sent_item    = $other_wrong_sent_item;
            }
        }

        # set item as booked in
        $handler->{data}{booked}{$return_item_id} = 1;

        # set wrong sent item flag
        if ($wrong_sent_item) {
            $handler->{data}{wrong_sent_item}{$return_item_id} = $wrong_sent_item;
        }
    }
    # sku not found - let user know
    else {
        $handler->{data}{msg} = "The SKU entered could not be found for this return, please check below and try again.";
    }

    return;
}

1;
