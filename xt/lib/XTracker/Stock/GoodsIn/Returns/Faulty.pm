package XTracker::Stock::GoodsIn::Returns::Faulty;

use strict;
use warnings;
use Carp;

use XTracker::Handler;
use XTracker::Database::Delivery;
use XTracker::Database::Invoice;
use XTracker::Database::Order;
use XTracker::Database::Product qw( :DEFAULT );
use XTracker::Database::Return;
use XTracker::Database::RTV qw( list_item_fault_types );
use XTracker::Database::Shipment;
use XTracker::Database::StockProcess;
use XTracker::Error;
use XTracker::Image;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    $handler->{data}{section}           = 'Goods In';
    $handler->{data}{subsection}        = 'Returns Faulty';
    $handler->{data}{subsubsection}     = '';
    $handler->{data}{content}           = 'stocktracker/goods_in/returns_in/faulty.tt';

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    # process group id from for post or url
    if ( $handler->{request}->param('process_group_id') ) {
        $handler->{data}{process_group_id} = $handler->{request}->param('process_group_id');
        $handler->{data}{process_group_id} =~ s/^p-//i;

        # check if RMA number submitted rather than process group id
        if ($handler->{data}{process_group_id} =~ m/-/){
            $handler->{data}{process_group_id} =  get_process_group_by_rma($dbh, $handler->{data}{process_group_id});
        }
    }

    # if process group id defined we're processing a delivery
    if ( my $process_group_id = $handler->{data}{process_group_id} ) {
        # page title
        $handler->{data}{subsubsection} = 'Process Return';

        # get process group details
        my $pg_info = _get_process_group_info( $schema, $process_group_id );
        unless ( %$pg_info ) {
            xt_warn( "Return for PGID $process_group_id has already been processed" );
            return $handler->redirect_to( '/GoodsIn/ReturnsFaulty' );
        }
        $handler->{data} = { %{$handler->{data}}, %$pg_info };

        # get fault types for RTV
        $handler->{data}{item_fault_types} = list_item_fault_types( { dbh => $dbh } );

        # left nav links
        my $order_id = $handler->{data}{return}{shipment_info}{orders_id};
        push @{ $handler->{data}{sidenav}[0]{None} },
            { title => 'Back', url => "/GoodsIn/ReturnsFaulty" },
            { title => 'Add Note',
              url => '/GoodsIn/ReturnsQC/Note?' . join q{&},
                'note_category=Return',
                "sub_id=$handler->{data}{return_id}",
                "came_from=returns_faulty",
                "process_group_id=$process_group_id",
                ( $order_id ? "parent_id=$order_id" : () ),
            };
        push @{ $handler->{data}{sidenav}[0]{None} }, {
            title => 'Order Summary',
            url => "/GoodsIn/ReturnsQC/OrderView?order_id=$order_id",
        } if $order_id;
    }
    # otherwise get all faulty returns for overview
    else {
        $handler->{data}{deliveries} = get_return_process_group( $dbh, 'faulty' );
    }

    $handler->{data}{process_group_id} ||= 0;
    return $handler->process_template;
}

sub _get_process_group_info {
    my ( $schema, $process_group_id ) = @_;

    my $dbh = $schema->storage->dbh;
    # get general return and order info
    my %data;
    $data{return_id}              = get_return_id_by_process_group($dbh, $process_group_id);
    $data{return}                 = get_return_info($dbh, $data{return_id});
    $data{return}{return_items}   = get_return_item_info($dbh, $data{return_id});
    $data{return}{notes}          = get_return_notes($dbh, $data{return_id});
    $data{return}{shipment_info}  = get_shipment_info($dbh, $data{return}{shipment_id});
    $data{return}{shipment_items} = get_shipment_item_info($dbh, $data{return}{shipment_id});
    $data{return}{order_info}     = get_order_info($dbh, $data{return}{shipment_info}{orders_id});

    my $shipment = $schema->resultset('Public::Shipment')->find($data{return}{shipment_id});
    $data{sales_channel}          = $shipment->get_channel->name;
    $data{return}{shipment_info}{is_sample} = $shipment->is_sample_shipment;

    # Get the customer category if there is one
    if ( %{$data{return}{order_info}||{}} ) {
        $data{customer_category}
            = $schema->resultset('Public::Orders')
                     ->search({'me.id' => $data{return}{shipment_info}{orders_id}})
                     ->related_resultset('customer')
                     ->related_resultset('category')
                     ->get_column('category')
                     ->first;
    }

    # get product images
    foreach my $item_id ( keys %{$data{return}{shipment_items}} ) {
        my $current_channel_name;
        my $product = $schema->resultset('Public::Product')->find($data{return}{shipment_items}{$item_id}{product_id});
        $current_channel_name = $product->get_current_channel_name() if $product;

        $data{return}{shipment_items}{$item_id}{active_channel} = $current_channel_name;
        $data{return}{shipment_items}{$item_id}{image} = get_images({
            product_id => $data{return}{shipment_items}{$item_id}{product_id},
            live => 1,
            schema => $schema,
        });
    }

    # get stock process items
    my $stock_ref = get_return_stock_process_items( $dbh, 'process_group', $process_group_id, 'faulty' );

    # error if already processed
    return {} unless @$stock_ref;

    foreach my $item ( @$stock_ref ){
        if ($item->{complete} == 0){
            $data{return}{process_items}{$item->{return_item_id}} = $item;
        }
    }
    return \%data;
}

1;
