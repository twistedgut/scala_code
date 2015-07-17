package Test::XTracker::Model;

use Moose;
use Log::Log4perl ':easy';
use Data::Dump qw/pp/;
use Test::More;

use Test::Differences qw/eq_or_diff/;

use XTracker::Database qw/get_database_handle schema_handle/;
use XTracker::Database::Channel qw( get_web_channels );
use XTracker::Constants qw/:application/;
use XTracker::Constants::FromDB qw/
    :currency
    :delivery_item_status
    :delivery_item_type
    :delivery_status
    :delivery_type
    :purchase_order_status
    :purchase_order_type
    :season
    :season_act
    :shipment_class
    :shipment_item_returnable_state
    :shipment_item_status
    :shipment_status
    :shipment_type
    :shipment_window_type
    :std_size
    :stock_order_status
    :stock_order_type
    :stock_order_item_status
    :stock_order_item_type
    :variant_type
    :authorisation_level
/;

with    qw(
    Test::Role::AccessControls
);

sub get_schema { schema_handle; }

sub get_dbh { get_schema->storage->dbh; }

# We are adding these accessors so we can use of the roles we normally use
# for Flow tests (i.e. in the Test::XT::Data namespace) in this module's
# subclass L<Test::XTracker::Data> without having to instantiate
# Test::XT::Flow, as they require the class that consumes them to provide
# C<schema> and C<dbh> methods.
sub schema { get_schema; }
sub dbh { get_dbh; }

{
    my $jq_schema;
    sub get_jq_schema {
        $jq_schema ||= get_database_handle({
            name => 'jobqueue_schema',
        });
        return $jq_schema;
    }
}

sub get_webdbhs {
    my($class, $type) = @_;

    $type ||= 'readonly';

    my $channels = get_web_channels($class->get_dbh( $type ));
    my $dbh_web;
    foreach my $channel_id ( keys %{$channels}) {
        # FIXME: this to Test::XTracker::Model
        $dbh_web->{$channel_id} = get_database_handle({
            name => 'Web_Live_' . $channels->{$channel_id}{config_section},
            type => 'transaction',
        }) || die print "Error: Unable to connect to website DB for "
            . "channel: $channels->{$channel_id}{name}";
    }
    return $dbh_web;
}

=head2 create_from_hash

    my $purchase_order = create_from_hash({
        channel_id      => 1,
        colour_id       => 2,
        stock_order     => [{
            status_id       => $STOCK_ORDER_STATUS__ON_ORDER,
            product         => {
                product_type_id => 6,
                variant         => [{
                    size_id         => 1,
                    stock_order_item    => {
                        quantity            => 40,
                    },
                },{
                    size_id         => 2,
                    stock_order_item    => {},
                }],
            },
        }],
    });

Create a purchase order and associated tables (product, stock_order, variant, stock_order_item)
based on a hash which allows any default values to be over-ridden

=cut

sub create_from_hash {
    ## no critic(ProhibitDeepNests)
    my ($self, $args) = @_;

    # First create a purchase_order, over-riding any default values
    my $purchase_order = $self->create_purchase_order($args);

    # Create stock orders

    for my $stock_order_args (@{$args->{stock_order}}) {
        my $product_args = $stock_order_args->{product};

        my $product = $self->create_product($product_args);

        # Certain shipping-related bits require something in shipping_attribute
        # for products
        $self->create_shipping_attribute($product,$product_args->{shipping_attribute} || {});

        # If we have a $product we can create a stock_order
        if ($product) {
            my $stock_order = $self->create_stock_order({
                purchase_order_id       => $purchase_order->id,
                product_id              => $product->id,
                %$stock_order_args,
            });

            # Create any product_channels
            my @product_channels = ();
            for my $product_channel_args (@{$stock_order_args->{product}{product_channel}}) {
                my $product_channel = $self->create_product_channel({
                    product_id          => $product->id,
                    %$product_channel_args,
                });
                push @product_channels, $product_channel;
            }
            # Create the price_purchase
            if ($stock_order_args->{product}{price_purchase}) {
                my $price_purchase = $self->create_price_purchase({
                    product_id          => $product->id,
                    %{$stock_order_args->{product}{price_purchase}},
                });
            }

            # Create the product_attributes
            if ($stock_order_args->{product}{product_attribute}) {
                my $product_attribute = $self->create_product_attribute({
                    product_id          => $product->id,
                    %{$stock_order_args->{product}{product_attribute}},
                });
            }

            # Always create a variant even if none are specified
            $self->create_variant({
                skip_measurements   => $args->{skip_measurements},
                product_id          => $product->id,
                product_channels    => \@product_channels
            }) unless @{ $stock_order_args->{product}{variant} || []};
            # Create any product variants
            for my $variant_args (@{$stock_order_args->{product}{variant}}) {
                my $variant = $self->create_variant({
                    skip_measurements   => $args->{skip_measurements},
                    product_id          => $product->id,
                    product_channels    => \@product_channels ,
                    %$variant_args,
                });
                # Create a stock_order_item if there is (even an empty) hash
                if (defined $variant_args->{stock_order_item}) {
                    my $hash = $variant_args->{stock_order_item}
                        ? $variant_args->{stock_order_item} : { };
                    $hash->{stock_order_id} = $stock_order->id;
                    $hash->{variant_id} = $variant->id;
                    my $stock_order_item = $self->create_stock_order_item(
                        $hash
                    );
                }
                # Create stock order items even if there is (even an empty) hash
                for my $stock_transfer_args (@{$variant_args->{stock_transfer}}) {
                    my $stock_transfer = $self->create_stock_transfer({
                        variant_id      => $variant->id,
                        channel_id      => $purchase_order->channel_id,
                        %{$stock_transfer_args},
                    });
                    # Create shipments for the stock transfer item
                    for my $shipment_args (@{$stock_transfer_args->{shipment}}) {
                        my $shipment = $self->create_shipment({
                            stock_transfer_id   => $stock_transfer->id,
                            %{$shipment_args},
                        });
                        # Create shipment items for the shipment
                        for my $shipment_item_args (@{$shipment_args->{shipment_item}}) {
                            my $shipment_item = $self->create_shipment_item({
                                shipment_id     => $shipment->id,
                                variant_id      => $variant->id,
                                %{$shipment_item_args},
                            });
                        }
                    }
                }
            }
            # Create a delivery if there is (even an empty) hash
            if (defined $stock_order_args->{product}{delivery}) {
                my $del_data = $stock_order_args->{product}{delivery};

                # Create a delivery for the Stock Order
                my $delivery = $self->instantiate_delivery_for_so(
                    $stock_order, $del_data
                );
#                my $delivery = $self->create_delivery_for_so($stock_order);
#                for my $key (keys %{$stock_order_args->{product}{delivery}}) {
#                    $delivery->$key($stock_order_args->{product}{delivery}{$key});
#                    $delivery->update;
#                }
            }
        }
    }

    return $purchase_order;
}

sub instantiate_delivery_for_so {
    my($self,$so,$data) = @_;

    my $del = $self->create_delivery_for_so($so);

    # update each field
    $self->apply_values($del,$data) if ($data);

    return $del;
}

sub apply_values {
    my($self,$obj,$data) = @_;

    for my $key (keys %{$data}) {
        $obj->$key($data->{$key});
    }
    $obj->update;
}

=head2 create_purchase_order( $args )

Creates a dummy purchase_order with defaults or given arguments.

=cut

sub create_purchase_order {
    my ( $class, $args ) = @_;
    my $id = $class->get_schema->storage->dbh_do( sub {
        my ($storage, $dbh) = @_;
        my $x = $dbh->selectall_arrayref("SELECT nextval('purchase_order_id_seq')");
        return $x->[0][0];
    });
    my $local_channel = Test::XTracker::Data->get_local_channel;

    TRACE "Will create purchase order with id of $id and args:", pp($args);
    my $po = $class->get_schema->resultset('Public::PurchaseOrder')->create({
        id                    => $id,
        purchase_order_number => _def($args->{purchase_order_nr}     , "test po $id"),
        description           => _def($args->{description}           , 'test description'),
        designer_id           => _def($args->{designer_id}           , 1),
        status_id             => _def($args->{status_id}             , $PURCHASE_ORDER_STATUS__ON_ORDER),
        comment               => _def($args->{comment}               , 'test comment'),
        currency_id           => _def($args->{currency_id}           , $CURRENCY__GBP),
        season_id             => _def($args->{season_id}             , $SEASON__CONTINUITY),
        type_id               => _def($args->{type_id}               , $PURCHASE_ORDER_TYPE__FIRST_ORDER),
        cancel                => _def($args->{cancel}                , 0),
        supplier_id           => _def($args->{supplier_id}           , 1),
        act_id                => _def($args->{act_id}                , $SEASON_ACT__MAIN),
        confirmed             => _def($args->{confirmed}             , 0),
        confirmed_operator_id => _def($args->{confirmed_operator_id} , $APPLICATION_OPERATOR_ID),
        placed_by             => _def($args->{placed_by}             , 'Application'),
        channel_id            => _def($args->{channel_id}            , $local_channel->id),
    });
    return $po;
}

=head2 create_product( $args )

Creates a dummy product with defaults or given arguments.

=cut

sub create_product {
    my ( $class, $args ) = @_;

    my $id = Test::XTracker::Data->next_id([qw{voucher.product product}]);

    my $product = $class->get_schema->resultset('Public::Product')->create({
        id                      => $id,
        world_id                => _def($args->{world_id}               , 1),
        designer_id             => _def($args->{designer_id}            , 1),
        division_id             => _def($args->{division_id}            , 1), # default is 'Women'
        classification_id       => _def($args->{classification_id}      , 5), # default is 'Clothing'
        product_type_id         => _def($args->{product_type_id}        , 1), # default is 'Bags'
        sub_type_id             => _def($args->{sub_type_id}            , 57), # default is 'Dress'
        colour_id               => _def($args->{colour_id}              , 2), # default is 'Black'
        style_number            => _def($args->{style_number}           , '9999999 - TEST'),
        season_id               => _def($args->{season_id}              , $SEASON__CONTINUITY),
        hs_code_id              => _def($args->{hs_code_id}             , 1), # unset
        note                    => _def($args->{note}                   , ''),
        legacy_sku              => _def($args->{legacy_sku}             , $id ),
        colour_filter_id        => _def($args->{colour_filter_id}       , 1), # black
        payment_term_id         => _def($args->{payment_term_id}        , 1),
        payment_settlement_discount_id  => _def($args->{payment_settlement_discount_id}, 0),
        payment_deposit_id      => _def($args->{payment_deposit_id}     , 0),
        watch                   => _def($args->{watch}                  , 0),
        ( $args->{storage_type_id} ? (storage_type_id => $args->{storage_type_id}) : () ),
        operator_id             => $APPLICATION_OPERATOR_ID,
    });
    $product->create_related('price_default',{
        currency_id => _def($args->{currency_id}, $CURRENCY__GBP),
        price => _def($args->{price_default}, 100),
        operator_id => _def($args->{operator_id}, $APPLICATION_OPERATOR_ID),
        complete => _def($args->{price_default_complete},0),
        complete_by_operator_id => _def($args->{price_default_complete_operator_id}, $APPLICATION_OPERATOR_ID),
    });
    return $product;
}

=head2 create_stock_order( $args )

Creates a dummy stock_order with defaults or given arguments.

=cut

sub create_stock_order {
    my ( $class, $args ) = @_;
    LOGCONFESS 'You must specify purchase_order_id'
        unless defined $args->{purchase_order_id};

    LOGCONFESS 'You must specify a product_id xor a voucher_id'
        unless defined $args->{product_id}
           xor defined $args->{voucher_product_id};

    my $so = $class->get_schema->resultset('Public::StockOrder')->create({
        product_id              => $args->{product_id},
        voucher_product_id      => $args->{voucher_product_id},
        purchase_order_id       => $args->{purchase_order_id},
        start_ship_date         => $args->{start_ship_date}         || DateTime->now,
        cancel_ship_date        => $args->{cancel_ship_date}        || DateTime->now->add( days => 7 ),
        status_id               => $args->{status_id}               || $STOCK_ORDER_STATUS__ON_ORDER,
        comment                 => $args->{comment}                 || 'test comment',
        type_id                 => $args->{type_id}                 || $STOCK_ORDER_TYPE__MAIN,
        consignment             => $args->{consignment}             || 0,
        cancel                  => $args->{cancel}                  || 0,
        confirmed               => $args->{confirmed}               || 0,
        shipment_window_type_id => $args->{shipment_window_type_id} || $SHIPMENT_WINDOW_TYPE__DELIVERED,
    });
    return $so;
}

=head2 create_shipping_attribute ( $product )

Creates a blank shipping_attribute entry for this product

=cut

sub create_shipping_attribute {
    my ( $self, $product, $attrs ) = @_;

    my $sa = $self->get_schema->resultset('Public::ShippingAttribute')->create({
        product_id => $product->id,
        %$attrs
    });

    return $sa;

}

=head2 create_price_purchase( $args )

Creates a price_purchase with defaults or given arguments

=cut

sub create_price_purchase {
    my ( $class, $args ) = @_;

    my $price_purchase = $class->get_schema->resultset('Public::PricePurchase')->create({
        product_id              => $args->{product_id},
        wholesale_price         => _def($args->{wholesale_price}, 0),
        wholesale_currency_id   => _def($args->{wholesale_currency_id}, 1),
        original_wholesale      => _def($args->{original_wholesale}, 0.00),
        uplift_cost             => _def($args->{uplift_cost}, 0.00),
        uk_landed_cost          => _def($args->{uk_landed_cost}, 28.00),
        uplift                  => _def($args->{uplift}, 0),
        trade_discount          => _def($args->{trade_discount}, 0),
    });
    return $price_purchase;
}


=head2 create_product_channel( $args )

Creates product_channel with defaults or given arguments.

=cut

sub create_product_channel {
    my ( $class, $args ) = @_;

    my $id = $class->get_schema->storage->dbh_do( sub {
        my ($storage, $dbh) = @_;
        my $x = $dbh->selectall_arrayref("SELECT nextval('product_channel_id_seq')");
        return $x->[0][0];
    });
    my $now = time;
    my $local_channel = Test::XTracker::Data->get_local_channel;
    my $product_channel = $class->get_schema->resultset('Public::ProductChannel')->create({
        id                      => $id,
        product_id              => _def($args->{product_id}, 1),
        channel_id              => _def($args->{channel_id}, $local_channel->id),
        live                    => _def($args->{live}, 1),
        staging                 => _def($args->{staging}, 1),
        visible                 => _def($args->{visible}, 1),
        disable_update          => _def($args->{disable_update}, 0),
        cancelled               => _def($args->{cancelled}, 0),
        arrival_date            => _def($args->{arrival_date}, undef),
        upload_date             => _def($args->{upload_date}, undef),
        transfer_status_id      => _def($args->{transfer_status_id}, 1),
        transfer_date           => _def($args->{transfer_date}, undef),
        pws_sort_adjust_id      => _def($args->{pws_sort_adjust_id}, 0),
    });
    return $product_channel;
}

=head2 create_product_attribute( $args )

Creates a dummy product_attribute with defaults or given arguments.

=cut

sub create_product_attribute {
    my ( $class, $args ) = @_;

    my $id = $class->get_schema->storage->dbh_do( sub {
        my ($storage, $dbh) = @_;
        my $x = $dbh->selectall_arrayref("SELECT nextval('product_attribute_id_seq')");
        return $x->[0][0];
    });

    my $variant = $class->get_schema->resultset('Public::ProductAttribute')->create({
        id                      => $id,
        product_id              => $args->{product_id},
        description             => _def($args->{description}            , 'Description'),
        name                    => _def($args->{name}                   , 'Name'),
        long_description        => _def($args->{long_description}       , 'Long Description'),
        short_description       => _def($args->{short_description}      , 'Short Desc'),
        designer_colour         => _def($args->{designer_colour}        , 'Octarine'),
        editors_comments        => _def($args->{editors_comments}       , 'Editors comments'),
        keywords                => _def($args->{keywords}               , 'Key Word'),
        recommended             => _def($args->{recommended}            , ''),
        designer_colour_code    => _def($args->{designer_colour_code}   , 102),
        size_scheme_id          => _def($args->{size_scheme_id}         , 10),
        custom_lists            => _def($args->{custom_lists}           , ''),
        act_id                  => _def($args->{act_id}                 , 1),
        pre_order               => _def($args->{pre_order}              , 0),
        operator_id             => _def($args->{operator_id}            , $APPLICATION_OPERATOR_ID),
        sample_correct          => _def($args->{sample_correct}         , 0),
        sample_colour_correct   => _def($args->{sample_colour_correct}  , 0),
        product_department_id   => _def($args->{product_department_id}  , 17),
        fit_notes               => _def($args->{fit_notes}              , 'Fit Notes'),
        style_notes             => _def($args->{style_notes}            , 'Style Notes'),
        editorial_approved      => _def($args->{editorial_approved}     , 0),
        use_measurements        => _def($args->{use_measurements}       , 0),
        editorial_notes         => _def($args->{editorial_notes}        , 'Editorial notes'),
        outfit_links            => _def($args->{outfit_links}           , 0),
        use_fit_notes           => _def($args->{use_fit_notes}          , 0),
        size_fit                => _def($args->{size_fit}               , 'Size Fit'),
        runway_look             => _def($args->{runway_look}            , 0),
    });
    return $variant;
}

=head2 create_variant( $args )

Creates a dummy variant with defaults or given arguments.
Also creates a third party sku if it's a fulfilment_only channel
in the args

=cut

sub create_variant {
    my ( $class, $args ) = @_;

    my $schema = $class->get_schema;

    my $id = Test::XTracker::Data->next_id([qw{voucher.variant variant}]);

    my $size_id = _def($args->{size_id}, $STD_SIZE__L);
    my $legacy_sku = $args->{product_id}.'-'.$size_id;
    # XXX remove this when we change the length of legacy_sku
    if (length($legacy_sku)>10) {
        $legacy_sku=substr($legacy_sku,0,10);
    }
    my $variant = $schema->resultset('Public::Variant')->create({
        id                  => $id,
        product_id          => $args->{product_id},
        size_id_old         => _def($args->{size_id_old}, $size_id),
        legacy_sku          => _def($args->{legacy_sku}, $legacy_sku),
        type_id             => _def($args->{type_id}, $VARIANT_TYPE__STOCK),
        size_id             => $size_id,
        designer_size_id    => _def($args->{designer_size_id}, 1),
        nap_size_id         => _def($args->{nap_size_id}, $STD_SIZE__L),
        std_size_id         => _def($args->{std_size_id}, $STD_SIZE__L),
    });

    if ( not $args->{skip_measurements} ) {
        # Add some variant_measurements
        my $product = $schema->resultset('Public::Product')->find($args->{product_id});
        # Find the measurements for the first product channel
        my $ptm_rs = $product->product_type->product_type_measurements->search({
            channel_id => $product->product_channel->first->channel->id
        });
        # Create some measurements for the variant
        while ( my $ptm = $ptm_rs->next ) {
            $schema->resultset('Public::VariantMeasurement')->create({
                variant_id => $variant->id,
                measurement_id => $ptm->measurement_id,
                value => 10,
            });
        }
    }

    # If there are product_channels, create relevant third_party_SKUs
    # (if they're not already there)

    foreach my $pc (@{$args->{product_channels}}) {
        next unless $pc->channel->business->fulfilment_only;

        # See whether we have a third_party_sku
        my $third_party_sku = $class->get_schema->resultset('Public::ThirdPartySku')->search({
            variant_id  => $variant->id,
            business_id => $pc->channel->business->id
        })->first;
        next if defined($third_party_sku);

        # And make it if not
        $class->get_schema->resultset('Public::ThirdPartySku')->create({
            variant_id          => $variant->id,
            business_id         => $pc->channel->business->id,
            third_party_sku     =>  $pc->channel->business->config_section.'_'.
                                    $variant->product_id.'_'.
                                    $variant->id.'_'.$pc->channel_id
        });
    }

    return $variant;
}

=head2 create_stock_order_item( $args )

Creates a dummy stock_order_item with defaults or given arguments.

=cut

sub create_stock_order_item {
    my ( $class, $args ) = @_;
    LOGCONFESS 'You must specify a variant_id xor a voucher_variant_id'
        unless defined $args->{variant_id}
           xor defined $args->{voucher_variant_id};


    LOGCONFESS 'You must specify a stock_order_id'
        unless defined $args->{stock_order_id};


    my $soi = $class->get_schema->resultset('Public::StockOrderItem')->create({
        variant_id         => $args->{variant_id},
        voucher_variant_id => $args->{voucher_variant_id},
        stock_order_id     => $args->{stock_order_id},
        quantity           => $args->{quantity}          || 10,
        original_quantity  => $args->{original_quantity} || 10,
        status_id          => $args->{status_id}         || $STOCK_ORDER_ITEM_STATUS__ON_ORDER,
        type_id            => $args->{type_id}           || $STOCK_ORDER_ITEM_TYPE__UNKNOWN,
        cancel             => $args->{cancel}            || 0,
    });

    if ($args->{voucher_variant_id}) {
        my $codes = $soi->voucher_variant->product->codes;
        # Link the codes to this SOI
        $codes->update({ stock_order_item_id => $soi->id });
    }
    return $soi;
}

sub create_stock_transfer {
    my ($class, $args) = @_;

    my $schema = $class->get_schema;

    my $stock_transfer = $schema->resultset('Public::StockTransfer')->create({
        variant_id          => $args->{variant_id},
        channel_id          => $args->{channel_id},
        date                => _def($args->{date},                  DateTime->now),
        type_id             => _def($args->{type_id},               1), # Sample
        status_id           => _def($args->{status_id},             1), # Requested
    });
    return $stock_transfer;
}

sub create_shipment {
    my ( $class, $args ) = @_;

    my $schema = $class->get_schema;

    my $shipment = $schema->resultset('Public::Shipment')->create({
        date                => _def($args->{date},                  DateTime->now),
        shipment_type_id    => _def($args->{shipment_type_id},      $SHIPMENT_TYPE__DOMESTIC),
        shipment_class_id   => _def($args->{shipment_class_id},     $SHIPMENT_CLASS__STANDARD),
        shipment_status_id  => _def($args->{shipment_status_id},    $SHIPMENT_STATUS__RECEIVED),
        shipment_address_id => _def($args->{shipment_address_id},   $class->create_order_address->id),
        gift                => _def($args->{gift},                  0),
        gift_message        => _def($args->{gift_message},          ''),
        outward_airway_bill => _def($args->{outward_airway_bill},   ''),
        return_airway_bill  => _def($args->{return_airway_bill},    ''),
        email               => _def($args->{email},                 'test@xtracker'),
        telephone           => _def($args->{telephone},             '12345'),
        mobile_telephone    => _def($args->{mobile_telephone},      '07855 123456'),
        packing_instruction => _def($args->{packing_instruction},   '-'),
        shipping_charge     => _def($args->{shipping_charge},       0.0),
        comment             => _def($args->{comment},               ''),
        delivered           => _def($args->{delivered},             0),
        gift_credit         => _def($args->{gift_credit},           0),
        store_credit        => _def($args->{store_credit},          0),
        legacy_shipment_nr  => _def($args->{legacy_shipment_nr},    '000000-0000'),
        destination_code    => _def($args->{destination_code},      'AAA'),
        shipping_charge_id  => _def($args->{shipping_charge_id},    0), # Unknown
        shipping_account_id => _def($args->{shipping_account_id},   1), # Domestic
        premier_routing_id  => _def($args->{premier_routing_id},    1), # Anytime before 9pm today
        real_time_carrier_booking   => _def($args->{real_time_carrier_booking}, 0),
        av_quality_rating   => _def($args->{av_quality_rating},     ''),
        sla_priority        => _def($args->{sla_priority},          1),
        sla_cutoff          => _def($args->{sla_cutoff},            DateTime->now),
    });
    # If a stock_transfer_id is provided, link the tables
    if ($args->{stock_transfer_id}) {
        $schema->resultset('Public::LinkStockTransferShipment')->create({
            stock_transfer_id   => $args->{stock_transfer_id},
            shipment_id         => $shipment->id,
        });
    }

    return $shipment;
}

=head2 create_shipment_item

    my $ship_item = Test::XTracker::Model->create_shipment_item({
        shipment_id => 1234,
        variant_id  => 1234,
    })

Returns a dummy L<XTracker::Schema::Result::Public::ShipmentItem> object.

=cut

sub create_shipment_item {
    my ($class, $args) = @_;

    my $schema = $class->get_schema;

    my $shipment_item = $schema->resultset('Public::ShipmentItem')->create({
        shipment_id             => $args->{shipment_id},
        variant_id              => $args->{variant_id},
        unit_price              => _def($args->{unit_price},                0.00),
        tax                     => _def($args->{tax},                       0),
        duty                    => _def($args->{duty},                      0),
        shipment_item_status_id => _def($args->{shipment_item_status_id},   $SHIPMENT_ITEM_STATUS__NEW),
        special_order_flag      => _def($args->{special_order_flag},        0),
        shipment_box_id         => _def($args->{shipment_box_id},           undef),
        returnable_state_id     => _def($args->{returnable},                $SHIPMENT_ITEM_RETURNABLE_STATE__NO),
        voucher_code_id         => _def($args->{variant_code_id},           undef),
    });
    return $shipment_item;
}

=head2 create_delivery_for_so

    $delivery   = create_delivery_for_so( $stock_order );

This creates a delivery and delivery item records for a stock order.

=cut

sub create_delivery_for_so {
    my($self,$so) = @_;
    my $schema  = $self->get_schema;

    my $time    = time();
    my $items = delete $so->{items};

    my $delivery    = $schema->resultset('Public::Delivery')->create({
        invoice_nr  => 'Test Data ' . $time,
        status_id   => $DELIVERY_STATUS__NEW,
        type_id     => $DELIVERY_TYPE__STOCK_ORDER,
        cancel      => 0,
    });


    my $so_items    = $so->stock_order_items->search( undef, { order_by => 'me.id' } );
    while ( my $so_item = $so_items->next ) {
        my ($delivery_item) = $schema->resultset('Public::DeliveryItem')->create({
            delivery_id  => $delivery->id,
            quantity     => 0,
            packing_slip => 0,
            status_id    => $DELIVERY_ITEM_STATUS__NEW,
            type_id      => $DELIVERY_ITEM_TYPE__STOCK_ORDER,
            cancel       => 0,
        });

        my $data = shift @{$items};
        $self->apply_values($delivery_item,$data) if ($data);

        $schema->resultset('Public::LinkDeliveryItemStockOrderItem')->create({
            delivery_item_id    => $delivery_item->id,
            stock_order_item_id => $so_item->id,
        });
    }
    # Link the delivery with the stock order
    $schema->resultset('Public::LinkDeliveryStockOrder')->create({
        delivery_id     => $delivery->id,
        stock_order_id  => $so->id,
    });

    return $delivery;
}

#
# Return the expected order of channel data, as an array of hashes
#
sub get_channel_order {
    my ($self) = @_;
    my $channel_rs = Test::XTracker::Model->get_schema
        ->resultset('Public::Channel')->drop_down_options;

    my $channel_data = [];
    while (my $channel = $channel_rs->next) {
        push @{$channel_data}, {
            id => $channel->id,
            name => $channel->name,
            enabled => $channel->is_enabled,
        };
    }

    return $channel_data;
}

sub _has_id_or_order_nr {
    my($self,$order) = @_;
    my $too_many = 0;
    my $none = 0;

    if (defined $order->{id} and defined $order->{order_nr}) {
        $too_many = 1;
    }
    if (not defined $order->{id} and not defined $order->{order_nr}) {
        $none = 1;
    }

    is($too_many, 0, 'not both id and order_nr provided');
    is($none, 0, 'have provided either id and order_nr');
}

sub gimme_order {
    my($self,$order, $schema) = @_;
    $self->_has_id_or_order_nr($order);

    $schema ||= $self->get_schema;

    my $row = $schema->resultset('Public::Orders')
        ->find($order);

    is(ref($row), 'XTracker::Schema::Result::Public::Orders',
        'we have an order record');

    return $row;
}

sub diff_hash_with_ignore {
    my($self,$one,$two,$ignore) = @_;
    my $alpha = \%{ $one };
    my $beta = \%{ $two };

    if (defined $ignore and ref($ignore) eq 'ARRAY') {
        foreach my $key (@{$ignore}) {
            delete $alpha->{$key};
            delete $beta->{$key};
        }
    } else {
        note 'no keys ignored used with diff_hash_with_ignore';
    }

    return eq_or_diff($alpha,$beta,'records match taking into account ignores');
}

sub order_to_hash {
    my($self,$order) = @_;
    my $hash = undef;

    is(ref($order), 'XTracker::Schema::Result::Public::Orders',
        'its an order row');

    $hash = $order->data_as_hash;
    # FIXME: order_flag - flag_id, orders_id
    $hash->{customer} = $order->customer->data_as_hash;
    push @{$hash->{addresses}}, $order->order_address->data_as_hash;

    my $shipments = $order->shipments;
    while (my $item = $shipments->next) {
        my $sitems = $item->shipment_items;
        # FIXME: may need this.. logging to shipment_status_log
        my $status_logs = $item->shipment_status_logs;
        while (my $log = $status_logs->next) {
            push @{$hash->{shipment_logs}}, $log->data_as_hash;
        }

        # FIXME: shipment_flag - shipment_id, flag_id
        my $shipment_flags = $item->shipment_flags;
        while (my $flag = $shipment_flags->next) {
            push @{$hash->{shipment_flags}}, $flag->data_as_hash;
        }

        while (my $woo = $sitems->next) {
            my $promotion = $woo->link_shipment_item__promotion;

            note "item: " . $woo->id;
            push @{$hash->{shipment_item_promotions}}, $promotion->data_as_hash if $promotion;
            push @{$hash->{shipment_items}}, $woo->data_as_hash;

            # add log_pws_stock
            my $logs = $order->result_source->schema->resultset('Public::LogPwsStock')->search({variant_id => $woo->variant_id});
            while (my $log = $logs->next) {
                push @{$hash->{shipment_item_pws_updates}}, $log->data_as_hash;
            }

            # add reservations
            my $reservations = $order->result_source->schema->resultset('Public::Reservation')->search({customer_id => $order->customer_id});
            while (my $reservation = $reservations->next) {
                push @{$hash->{reservations}}, $reservation->data_as_hash;
            }
        }

        push @{$hash->{addresses}}, $item->shipment_address->data_as_hash;
        push @{$hash->{shipments}}, $item->data_as_hash;
    }

    my $order_flags = $order->order_flags;
    while (my $item = $order_flags->next) {
        push @{$hash->{order_flags}}, $item->data_as_hash;
    }

    my $tenders = $order->tenders;
    while (my $item = $tenders->next) {
        push @{$hash->{tenders}}, $item->data_as_hash;
    }

    my $payments = $order->payments;
    while (my $item = $payments->next) {
        push @{$hash->{payments}}, $item->data_as_hash;
    }

    return $hash;
}

sub diff_orders_arrays {
    my($self,$one,$two,$ignores, $rh_options) = @_;
    my $ok = 0;

    if ($rh_options->{undef_ok}  && (!defined ($one) && !defined($two))) {
        ok(1, 'neither defined');
        return;
    }

    if (not (defined $one and defined $two)) {
        $ok++;
    }
    is($ok, 0, 'both defined');
    if (not (ref($one) eq 'ARRAY' and ref($two)eq 'ARRAY' )) {
        $ok++;
    }
    is($ok, 0, 'arrays and same size');
    if (ref $one and ref $two and not (scalar @{$one} == scalar @{$two})) {
        $ok++;
    }
    is($ok, 0, 'arrays and same size');

    while (scalar @{$one}) {
        my $x = shift @{$one};
        my $y = shift @{$two};
        $self->diff_hash_with_ignore( $x, $y, $ignores);
    }

    return;
}

sub diff_orders {
    my($self,$alpha,$beta,$more_ignores) = @_;
    my $differences = 0;
    my $one = (ref($alpha) eq 'HASH') ? $alpha : $self->order_to_hash($alpha);
    my $two = (ref($beta) eq 'HASH') ? $beta : $self->order_to_hash($beta);

    #print "OLD ORDER:\n";
    #note pp $one;
    #print "NEW ORDER:\n";
    #note pp $two;

    my $ignores = {
        orders                      => [qw/ id customer_id date invoice_address_id /],
        customer                    => [qw/ id modified created is_customer_number /],
        shipments                   => [qw/ id date modified/ ],
        shipment_items              => [qw/ id shipment_id /],
        address                     => [qw/ id /],
        tenders                     => [qw/ id order_id /],
        payments                    => [qw/ id  orders_id preauth_ref psp_ref /],
        status_logs                 => [qw/ id shipment_id /],
        shipment_logs               => [qw/ id date shipment_id /],
        shipment_flags              => [qw/ id shipment_id /],
        shipment_item_promotions    => [qw/ id shipment_item_id promotion /],
        order_flags                 => [qw/ id orders_id /],
        shipment_item_pws_updates   => [qw/ id date notes /],
        reservations                => [qw/ id /],
        shipment_status_log         => [qw/ id shipment_id /],
        # log_pws_stock
    };

    # delete data we want to not test
    while (my ($key, $value) = each %{ $more_ignores }) {
        if (!ref($value) && $value == 0) {
            delete $ignores->{ $key };
            delete $more_ignores->{ $key };
            delete $one->{ $key };
            delete $two->{ $key };
        }
    }

    foreach my $key (keys %{$more_ignores}) {
        push @{$ignores->{$key}}, @{$more_ignores->{$key}};
    }

    # shipments
    note "comparing shipments ";
    $self->diff_orders_arrays(
        delete $one->{shipments},
        delete $two->{shipments},
        $ignores->{shipments},
    );

    # Sort the order flags by flag_id because we can't guarantee
    # we set the flags in the same order
    #
    # Also sort the shipment_items and shipment_item_pws_updates on variant_id
    # otherwise they sometimes are ordered randomly
    foreach ($one, $two) {
        if ( $_->{order_flags} ) {
            my $order_flags = $_->{order_flags};
            my @order_flags = sort {$a->{flag_id} <=> $b->{flag_id}} @{$order_flags};
            $_->{order_flags} = \@order_flags;
        }

        if ( $_->{shipment_items} ) {
            my $ship_items = $_->{shipment_items};
            my @ship_items = sort {$a->{variant_id} <=> $b->{variant_id}} @{$ship_items};
            $_->{shipment_items} = \@ship_items;
        }

        if ( $_->{shipment_item_pws_updates} ) {
            my $pws_updates = $_->{shipment_item_pws_updates};
            my @pws_updates = sort {$a->{balance} <=> $b->{balance}} @{$pws_updates};
            @pws_updates = sort {$a->{variant_id} <=> $b->{variant_id}} @{$pws_updates};
            $_->{shipment_item_pws_updates} = \@pws_updates;
        }

        if ( $_->{shipment_item_promotions} ) {
            my $ship_item_promos = $_->{shipment_item_promotions};
            my @ship_item_promos = sort {$a->{tax} <=> $b->{tax}} @{$ship_item_promos};

            $_->{shipment_item_promotions} = \@ship_item_promos;
        }
    }

    note "comparing shipment_items ";
    # shipment_items
    $self->diff_orders_arrays(
        delete $one->{shipment_items},
        delete $two->{shipment_items},
        $ignores->{shipment_items},
    );

    note "comparing shipment_item_promotions ";
    # shipment_logs
    $self->diff_orders_arrays(
        delete $one->{shipment_item_promotions},
        delete $two->{shipment_item_promotions},
        $ignores->{shipment_item_promotions},
        {undef_ok => 1},
    );

    foreach my $array (qw/payments shipment_status_log status_logs shipment_flags order_flags reservation/) {
#        shipment_item_promotions/) {
        note "comparing $array";
        # payments - they may not have a payment if they're store credit
        if (defined $one->{$array} or defined $two->{$array}) {
            $self->diff_orders_arrays(
                delete $one->{$array},
                delete $two->{$array},
                $ignores->{$array},
            );
        } else {
            note "  skipping checking $array - neither have $array";
        }
    }

    note "comparing shipment_logs ";
    # shipment_logs
    $self->diff_orders_arrays(
        delete $one->{shipment_logs},
        delete $two->{shipment_logs},
        $ignores->{shipment_logs},
        {undef_ok => 1},
    );

    note "comparing shipment_item_pws_updates ";
    # shipment_logs
    $self->diff_orders_arrays(
        delete $one->{shipment_item_pws_updates},
        delete $two->{shipment_item_pws_updates},
        $ignores->{shipment_item_pws_updates},
        {undef_ok => 1},
    );

    note "comparing addresses ";
    # payments - they may not have a payment if they're store credit
    if (defined $one->{addresses} or defined $two->{addresses}) {
        $self->diff_orders_arrays(
            delete $one->{addresses},
            delete $two->{addresses},
            $ignores->{payments},
        );
    }
    else {
        note "skipping checking payments - neither have payments";
    }

    note "comparing tenders ";
    # shipment_items
    $self->diff_orders_arrays(
        delete $one->{tenders},
        delete $two->{tenders},
        $ignores->{tenders},
    );

    # just hashes
    foreach my $rec (qw/customer/) {
        note "comparing $rec ";
        $self->diff_hash_with_ignore( delete $one->{$rec}, delete $two->{$rec},
            $ignores->{$rec});
    }

    note "comparing orders ";
    $self->diff_hash_with_ignore( $one, $two,
        $ignores->{orders});

note "TODO: this isn't completely finished yet and needs to check more";
note "TODO: records.";
note "TODO: Add log_pws_stock ";

    return;
}


# Utility function to simplify adding default values

sub _def {
    my ($defined, $default) = @_;

    return defined $defined ? $defined : $default;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
