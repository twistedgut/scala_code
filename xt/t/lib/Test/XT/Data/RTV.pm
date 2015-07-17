package Test::XT::Data::RTV;

use NAP::policy "tt",     qw( test role );

#
# Data for RTV workflow testing
#
use Test::XTracker::Data;
use XTracker::Constants                 qw{ :application };
use XTracker::Database::RTV             qw(insert_rtv_quantity create_rma_request);
use XTracker::Config::Local;
use XTracker::Database::StockProcess    qw(
    create_stock_process
    get_stock_process_items
    set_putaway_item
);
use XTracker::Database::Stock qw(insert_quantity);



use Log::Log4perl ':easy';
Log::Log4perl->easy_init({ level => $INFO });

use XTracker::Constants::FromDB qw(
    :channel
    :business
    :stock_order_status
    :authorisation_level
    :delivery_status
    :flow_status
    :stock_process_type
    :stock_process_status
    :rma_request_detail_type
);

has rtv_quantity_id => (
    is          => 'rw',
    isa         => 'Int',
    lazy        => 1,
    builder     => '_set_rtv_quantity_id',
    );

has quantity_id => (
    is          => 'rw',
    isa         => 'Int',
    lazy        => 1,
    builder     => '_set_quantity_id',
    );

############################
# Attribute default builders
############################

sub _set_rtv_quantity_id {
    my ($self) = @_;

    # Create an RTV location
    my $schema  = Test::XTracker::Data->get_schema;

    # Create an rtv_quantity for this purchase order
    my $dbh     = $schema->storage->dbh;

    my $po      = $self->purchase_order;
    note "po_id = ".$po->id;
    my $so      = $po->stock_orders->first;
    note "so_id = ".$so->id;
    my $de      = $so->deliveries->first;
    note "de_id = ".$de->id;

    my $del     = $self->purchase_order->stock_orders->first->deliveries->first;
    my $del_id  = $del->id;

    my $stock_order = $self->purchase_order->stock_orders->first;
    my $product     = $self->product;
    my $variant     = $product->variants
        ->search({},{order_by=>{-asc=>'id'}})->first;

    note "about to 'insert_rtv_quantity'";
    my $rtv_quantity_id = insert_rtv_quantity({
        dbh                     => $dbh,
        location_id             => $self->location->id,
        variant_id              => $variant->id,
        quantity                => 5,
        delivery_item_id        => $del->delivery_items->first->id,
        transfer_di_fault_data  => 1,
        origin                  => 'GI',
        channel_id              => $self->channel->id,
        initial_status_id       => $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS,
    });
    note "rtv_quantity_id = [$rtv_quantity_id]";
    return $rtv_quantity_id;

}

sub _set_quantity_id {
    my ($self) = @_;

    note "SUB _set_quantity_id";
    my $schema  = Test::XTracker::Data->get_schema;

    my $product     = $self->product;
    my $variant     = $product->variants
        ->search({},{order_by=>{-asc=>'id'}})->first;

    note "  location_id = [".$self->location->id."]";
    my $quantity_id = insert_quantity($schema, {
        location_id             => $self->location->id,
        variant_id              => $variant->id,
        quantity                => 5,
        channel_id              => $self->channel->id,
        initial_status_id       => $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS,
    });
    return $quantity_id;

}

# Update the rtv_quantity_id in the event that it changes
#
sub _update_rtv_quantity_id {
    my ($self) = @_;

    my $schema  = Test::XTracker::Data->get_schema;
    my $variant     = $self->product->variants
        ->search({},{order_by=>{-asc=>'id'}})->first;

    my $rtv_quantity = $schema->resultset('Public::RTVQuantity')->search({
        variant_id      => $variant->id,
    })->first;

    if (!defined $rtv_quantity) {
        return;
    }

    $self->rtv_quantity_id($rtv_quantity->id);
    return $rtv_quantity->id;
}

# Obtain the RMA Request Detail object
#
sub data__rtv__rma_request_detail {
    my ($self) = @_;

    $self->_update_rtv_quantity_id;

    my $schema  = Test::XTracker::Data->get_schema;
    my $rma_request_detail = $schema->resultset('Public::RmaRequestDetail')->search({
        rtv_quantity_id => $self->rtv_quantity_id,
    })->first;

    return $rma_request_detail;
}


# Obtain the RMA Request ID
#
sub data__rtv__rma_request_id {
    my ($self) = @_;

    return $self->data__rtv__rma_request_detail->rma_request_id;
}


# Obtain the RMA Request object
#
sub data__rtv__rma_request {
    my ($self) = @_;

    my $schema  = Test::XTracker::Data->get_schema;
    my $rma_request = $schema->resultset('Public::RmaRequest')->find(
        $self->data__rtv__rma_request_id()
    );

    return $rma_request;
}

# Obtain the RTV Shipment object
#
sub data__rtv__rtv_shipment {
    my ($self) = @_;

    my $schema  = Test::XTracker::Data->get_schema;
    my $rtv_shipment_detail = $schema->resultset('Public::RTVShipmentDetail')->search({
        rma_request_detail_id => $self->data__rtv__rma_request_detail->id,
    })->first;
    my $rtv_shipment = $rtv_shipment_detail->rtv_shipment;

    return $rtv_shipment;
}

# Make up an RMA number to use
#
sub data__rtv__rma_number {
    my ($self) = @_;

    return "RMAT".$self->data__rtv__rma_request_id;
}

# Make up an airway bill ID to use
#
sub data__rtv__airway_bill_id {
    my ($self) = @_;

    return "AWB".$self->data__rtv__rtv_shipment->id;
}

# methods to ensure data is setup for thepage
# does purchase order, delivery, quality control processing
sub data__rtv__faultygi {
    my($self,$data) = @_;

    note "SUB data__rtv_faultygi";

    my $schema  = Test::XTracker::Data->get_schema;

    my $del_data = \%{ $data->{delivery} };
    $del_data = {
        status_id   => $DELIVERY_STATUS__COUNTED,
    };
    my $so = $self->purchase_order->stock_orders->first;

    note "stockorder : ". $so->id;

    # this seems to be effectively what
    # mech_stockcontrol_purchaseorder_stockorder_submit does but from a db level
    note "stockcontrol_purchaseorder_stockorder_submit";
    my $delivery = Test::XTracker::Model->instantiate_delivery_for_so(
        $so, $del_data
    );

    my $ditems = $delivery->delivery_items;
    my $ditems_data = undef;
    if ($data->{delivery}) {
        my $del = \%{ $data->{delivery} };
        my $items = delete $del->{items};

        Test::XTracker::Model->apply_values($delivery,$del);

        if ($items) {
            while (my $item = $ditems->next) {
                my $i_data = shift @{$items};
                Test::XTracker::Model->apply_values($item,$i_data);
            }
        }
    }
    # end

    note "delivery_id ". $delivery->id;
    my @quants = $ditems->get_column('quantity')->all;
    my $group_id = undef;

    note "about to create stock processes";
    $ditems->reset;
    while (my $item = $ditems->next) {
        note "  creating stock process for ditem ". $item->id;
        my $spid = create_stock_process( $self->dbh,
            $STOCK_PROCESS_TYPE__MAIN,
            $item->id,
            $item->quantity, # this may possibly want to be parameterised
            \$group_id
        );
        note "spid $spid";
    }
    $self->dbh->commit;
    # end


    my $qc_vals = \@{ $data->{qc} };
    $ditems->reset;

    while (my $item = $ditems->next) {
        note "di (". $item->id .") d (". $item->delivery_id .")";
    }

    my @stock_processes = map {$_->stock_processes->first }
        $delivery->delivery_items;

    my $faulty_group_id = undef;
    for my $sp (@stock_processes) {
        my $new_sp = $sp;
        note " from";
        note "  sp: ". $new_sp->id ." ". $new_sp->type->type ." "
            . $new_sp->status->status;

        foreach my $item (@{$qc_vals}) {

            if ($item->{faulty}) {
                # reuse the same faulty group
                $new_sp = $sp->split_stock_process(
                    $STOCK_PROCESS_TYPE__FAULTY, $item->{faulty},
                    $faulty_group_id);

                $faulty_group_id   = $new_sp->group_id;


            }
            $sp->update({
                status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
            });
            $new_sp->update({
                status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
            });


        }
        note " to";
        note "  sp: ". $new_sp->id ." ". $new_sp->type->type ." "
            . $new_sp->status->status;
    }
    note "faulty_group_id $faulty_group_id";
    # end

    # putaway the faulty one too
    my @faulty= $schema->resultset('Public::StockProcess')
        ->get_group( $faulty_group_id )->all;
    push @stock_processes, @faulty;

    my $locs = delete $data->{locs};
    my $putaway = delete $data->{putaway};


    foreach my $sp (@stock_processes) {
        note "  stock process " . $sp->id;
        my $gi_check = get_stock_process_items(
            $self->dbh, 'process_group', $sp->id, 'putaway' );
        my $type = undef;
        if ($gi_check > 0) {
            note "  doing a Goods In for " . $sp->id;
            my $loc = shift @{$locs};
            my $q = shift @{$putaway} || 1;
            set_putaway_item( $self->dbh, $sp->id, $loc, $q);
        }
    }
    my $rtv_quantity_id = $self->rtv_quantity_id;
    my $quantity_id = $self->quantity_id;
    note "channel = ".$self->channel->id." rtv_quantity_id = ".$self->rtv_quantity_id." product = ".$self->product->id." quantity_id = ".$self->quantity_id."\n";

    return $self;
}

sub create_a_request_rma {
    my ($self, $rtv_quantity) = @_;

    my $rma_request_id = create_rma_request({
        dbh         => $self->dbh(),
        head_ref    => {
            operator_id => $APPLICATION_OPERATOR_ID,
            comments    => 'Testing',
            channel_id  => $rtv_quantity->channel_id(),
        },
        dets_ref    => {
            $rtv_quantity->id() => { type_id => $RMA_REQUEST_DETAIL_TYPE__CREDIT },
        },
    });
    return $self->schema()->resultset('Public::RmaRequest')->find($rma_request_id);
}

1;
