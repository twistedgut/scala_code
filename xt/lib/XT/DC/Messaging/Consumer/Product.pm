package XT::DC::Messaging::Consumer::Product;
# vim: ts=8 sts=4 et sw=4 sr sta
use NAP::policy "tt", 'class';

use XTracker::Database::Product qw(create_product_channel
                                   create_product_attributes
                                   create_shipping_attributes
                                   create_variant
                                   add_third_party_sku
                                   set_product_nav_attribute
                                   set_product_standardised_sizes);
use XTracker::Database::Pricing qw(set_default_price
                                   set_purchase_price
                                   set_region_price
                                   set_country_price
                                   set_markdown);
use XTracker::Database::Stock   qw( get_saleable_item_quantity );
use XTracker::Database::Attributes qw(set_shipping_restriction);
use XTracker::Constants qw(:application);
use XTracker::Constants::FromDB qw( :variant_type :shipment_status :shipment_item_status :storage_type);
use DateTime;
use DateTime::Format::Pg;
use DateTime::Format::ISO8601;
use XTracker::Utilities 'fix_encoding';
extends 'NAP::Messaging::Base::Consumer';
with 'NAP::Messaging::Role::WithModelAccess';
use XT::DC::Messaging::Spec::Product;
use XTracker::Config::Local qw/config_var config_section_slurp/;
use XT::Product::WebDataTransfer;

sub routes {
    return {
        destination => {
            create_orderless_voucher => {
                code => \&create_orderless_voucher,
                spec => XT::DC::Messaging::Spec::Product->create_orderless_voucher,
            },
            create_voucher => {
                code => \&create_voucher,
                spec => XT::DC::Messaging::Spec::Product->create_voucher,
            },
            update_voucher => {
                code => \&update_voucher,
                spec => XT::DC::Messaging::Spec::Product->update_voucher,
            },
            make_live => {
                code => \&make_live,
                spec => XT::DC::Messaging::Spec::Product->make_live,
            },
            delete_voucher => {
                code => \&delete_voucher,
                spec => XT::DC::Messaging::Spec::Product->delete_voucher,
            },
            assign_virtual_voucher_code_to_shipment => {
                code => \&assign_virtual_voucher_code_to_shipment,
                spec => XT::DC::Messaging::Spec::Product->assign_virtual_voucher_code_to_shipment,
            },
            create_product => {
                code => \&create_product,
                spec => XT::DC::Messaging::Spec::Product->create_product,
            },
            send_detailed_stock_levels => {
                code => \&send_detailed_stock_levels,
                spec => XT::DC::Messaging::Spec::Product->send_detailed_stock_levels,
            },
        },
    };
}

=head2 channel_exists( I<$channel_id> )

This sub returns a true value if the channel exists in this DC.

=cut

sub channel_exists {
    my ( $self, $channel_id ) = @_;
    return 1 if $self->model('Schema::Public::Channel')->find($channel_id);
    return;
}

sub create_orderless_voucher {
    my ( $self, $m, $h ) = @_;

    my $rs = $self->model('Schema')->resultset('Voucher::Product');

    for my $voucher_data ( @{$m->{vouchers}} ) {
        my $voucher = $rs->find($voucher_data->{pid});

        die "Couldn't find voucher ${[$voucher->id]}\n" unless $voucher;
        die "Expecting virtual voucher - pid ${[$voucher->id]} isn't\n"
            if $voucher->is_physical;

        $voucher->add_code( $_, {
            source => $m->{source},
            expiry_date => $m->{expiry_date},
            send_reminder_email => $m->{send_reminder_email},
        })->activate for @{$voucher_data->{codes}};

        $voucher->variant->notify_product_service();
    }
    return;
}

sub create_voucher {
    my ( $self, $m, $h ) = @_;

    return unless $self->channel_exists($m->{channel_id});

    my %args = %{$m};
    delete $args{'@type'};

    my $schema = $self->model('Schema')->schema;
    eval {
        $args{currency_id}
            = $schema->resultset('Public::Currency')
                     ->find_by_name( delete $args{currency_code} )
                     ->id;

        my $guard = $schema->txn_scope_guard;
        my $variant_id = delete $args{variant_id};
        $schema->resultset('Voucher::Product')
               ->create({ map { $_ => $args{$_} } keys %args })
               ->create_related('variant', {id=>$variant_id});
        my $variant = $schema->resultset('Voucher::Variant')->find({
            id => $variant_id
        });
        $variant->send_sku_update_to_prls({'amq'=>$self->model('MessageQueue')});
        $guard->commit;
        $variant->notify_product_service();
    };
    if ( my $e = $@ ) {
        die "Couldn't create voucher $m->{id}: $e\n";
    }
}

sub update_voucher {
    my ($self, $m, $h) = @_;

    return unless $self->channel_exists($m->{channel_id});

    my %args = %{$m};
    my $variant_id = $args{variant_id};
    delete @args{qw{@type variant_id}};

    my $schema = $self->model('Schema')->schema;
    eval {
        $args{currency_id}
            = $schema->resultset('Public::Currency')
                     ->find_by_name( delete $args{currency_code} )
                     ->id;

        my $guard = $schema->txn_scope_guard;
        $schema->resultset('Voucher::Product')
               ->find( delete $args{id} )
               ->update({ map { $_ => $args{$_} } keys %args });
        my $variant = $schema->resultset('Voucher::Variant')->find({
            id => $variant_id
        });
        $variant->send_sku_update_to_prls({'amq'=>$self->model('MessageQueue')});
        $guard->commit;
        $variant->notify_product_service();
    };
    if ( my $e = $@ ) {
        die "Couldn't update voucher $m->{id}: $e\n";
    }
}

=head2 make_live

This tells xTracker that either a Product or Voucher is live on the web-site.

At the time of writting only the Voucher is implemented.

See Queue::Spec::Product for definition of the message structure.

=cut

sub make_live {
    my ($self, $m, $h) = @_;

    my $schema  = $self->model('Schema')->schema;

    # see if it's a voucher we're going to make live
    if ( exists $m->{voucher} ) {
        my $msg_voucher = $m->{voucher};

        return unless $self->channel_exists( $msg_voucher->{channel_id} );

        eval {
            my $voucher = $schema->resultset('Voucher::Product')
                                ->find( $msg_voucher->{id} );

            # only update voucher if 'upload_date' is NOT set
            if ( !defined $voucher->upload_date ) {
                $voucher->update( { upload_date => $msg_voucher->{upload_date} } );
                # get stock level to send to web-site
                my $avail_stock     = get_saleable_item_quantity( $schema->storage->dbh, $voucher->id );
                my $var_stock_qty   = $avail_stock->{ $voucher->channel->name }{ $voucher->variant->id } || 0;
                $self->model('MessageQueue')->transform_and_send( 'XT::DC::Messaging::Producer::Stock::Update', {
                                                        quantity_change => $var_stock_qty,
                                                        sku => $voucher->variant->sku,
                                                        channel_id => $msg_voucher->{channel_id},
                                                    } );
                $self->send_detailed_stock_levels({
                    product_id => $voucher->id,
                    channel_id => $voucher->channel_id,
                });
                $self->model('MessageQueue')->transform_and_send('XT::DC::Messaging::Producer::ProductService::Upload', {
                    upload_date => $msg_voucher->{upload_date},
                    upload_timestamp
                        => DateTime->now->set_time_zone('UTC')->iso8601,
                    channel_id => $voucher->channel_id,
                    pids => [ $voucher->id ],
                });
            }
        };
        if ( my $e = $@ ) {
            die "Couldn't make live voucher $msg_voucher->{id}: $e\n";
        }
    }

    return;
}


sub create_product {
    my ($self, $m, $h) = @_;

    my $schema = $self->model('Schema')->schema;

    my %args = map {
        ref($_) ? $_ : ff($_)
    } %$m;
    delete $args{'@type'};
    my $operator_id = $args{operator_id};
    my $product_id  = $args{product_id};
    my $business_id = $args{business_id};

    my $product_args={
        product_id => $product_id,
        note       => undef,
        legacy_sku => $product_id,
        watch      => 0,
    };

    # All JC products need to have storage_type set to 'Flat' by default
    $product_args->{storage_type_id} = $PRODUCT_STORAGE_TYPE__FLAT
        if ($schema->resultset('Public::Business')->find($business_id)
            ->get_column('config_section') eq 'JC');

    for my $prod_field (
        qw(world division hs_code designer colour season colour_filter)
    ) {
        $product_args->{"${prod_field}_id"}=$schema->lookup_dictionary_by_name($prod_field,$args{$prod_field});
    }
    for my $prod_field (qw(classification product_type sub_type)) {
        $product_args->{"${prod_field}_id"}=
            eval{ $schema->lookup_dictionary_by_name($prod_field,$args{$prod_field}) }
                || $schema->lookup_dictionary_by_name($prod_field,'Unknown');
    }
    for my $prod_field (qw(style_number)) {
        $product_args->{$prod_field}=$args{$prod_field};
    }

    my $product_channel_args=[];

    # We will build up product attributes in here...
    # Please don't put defaults into this hash though, as this is also
    # used to update existing products and we will overwrite the contents
    # with the default (on reorder). See PM-1851
    my $product_attr_args={};

    for my $prod_field (qw(size_scheme act product_department)) {
        $product_attr_args->{"${prod_field}_id"}=$schema->lookup_dictionary_by_name($prod_field,$args{$prod_field});
    }
    for my $prod_field (qw(name description designer_colour designer_colour_code style_notes)) {
        $product_attr_args->{$prod_field}=$args{$prod_field};
    }

    # We will build up shipping attributes in here...
    # Please don't put defaults into this hash though, as this is also
    # used to update existing products and we will overwrite the contents
    # with the default (on reorder). See PM-1851
    my $shipping_attr_args={};

    my @external_image_urls;

    {
        my $prod_field = 'scientific_term';
        $shipping_attr_args->{$prod_field} = $args{$prod_field};
    }

    # We have to map from Fulcrum's product.restriction to XT's shipping_attributes
    foreach (@{ $args{restrictions} }) {
        $shipping_attr_args->{'fish_wildlife'} = 1
            if $_->{title} eq 'Fish & Wildlife';
    }

    my $purchase_args={};
    my $def_price_args={};
    my $region_prices=[];
    my $country_prices=[];
    my $variants=[];
    my $markdown_args={};

    for my $channel_slot (@{$args{channels}}) {
        my $channel_id=$channel_slot->{channel_id};
        next unless $schema->resultset('Public::Channel')->find($channel_id);

        for my $k (keys %$channel_slot) {
            next if ref $channel_slot->{$k};
            $channel_slot->{$k} = ff($channel_slot->{$k});
        }

        # NOTE:
        #
        # Yes, I'm storing channelised data into non-channelised structures.
        # this *works* (for the moment), because:
        # - a product can belong to only 1 business
        # - an XT instance deals with only 1 DC
        # - business x DC = channel
        # - thus, there will only be 1 channel that
        #   appears both in the product data and in this
        #   XT's database

        push @$product_channel_args,{
            product_id => $product_id,
            channel_id => $channel_id,
            operator_id => $operator_id,
        };

        for my $attr (qw(classification product_type sub_type)) {
            my $v=$args{$attr};
            $v=~s{&}{and}g;
            $v=~s{[^\w\s,.-]}{}g;
            $v=~s{\s+}{_}g;
            $product_channel_args->[-1]{attributes}{"navigation_$attr"}=$v;
        }

        if (exists $channel_slot->{initial_markdown}) {
            my $start_date = DateTime::Format::ISO8601->new->parse_datetime($channel_slot->{initial_markdown}{start_date});
            $start_date = DateTime::Format::Pg->new->format_datetime($start_date);
            $markdown_args={
                product_id => $product_id,
                start_date => $start_date,
                percentage => $channel_slot->{initial_markdown}{percentage},
                category   => '1st MD',
            };
        }

        for my $prod_field (qw(payment_term payment_settlement_discount payment_deposit)) {
            $product_args->{"${prod_field}_id"}=$schema->lookup_dictionary_by_name($prod_field,$channel_slot->{$prod_field});
        }
        for my $prod_field (qw(runway_look sample_correct sample_colour_correct)) {
            $product_attr_args->{$prod_field}=$channel_slot->{$prod_field};
        }
        for my $prod_field (qw(upload_after)) {
            my $value=$channel_slot->{$prod_field};
            next unless $value;
            $value = DateTime::Format::ISO8601->new->parse_datetime($value);
            $value = DateTime::Format::Pg->new->format_datetime($value);
            # "upload_after" is ignored
            # it should be set in the product_attribute table
            # but I'm not adding a column today
            # - Gianni Cecarelli 2010-06-18
            # $product_attr_args->{$prod_field}=$value;
        }

        for my $prod_field (qw(wholesale_currency landed_currency)) {
            $purchase_args->{"${prod_field}_id"}=$schema->lookup_dictionary_by_name($prod_field,$channel_slot->{$prod_field});
        }
        for my $prod_field (qw(original_wholesale trade_discount uplift unit_landed_cost)) {
            $purchase_args->{$prod_field}=$channel_slot->{$prod_field};
        }
        for my $prod_field (qw(default_currency)) {
            $def_price_args->{"${prod_field}_id"}=$schema->lookup_dictionary_by_name($prod_field,$channel_slot->{$prod_field});
        }
        for my $prod_field (qw(default_price)) {
            $def_price_args->{$prod_field}=$channel_slot->{$prod_field};
        }

        for my $region_price (@{$channel_slot->{region_prices}}) {
            my $price_args={};

            for my $price_field (qw(currency region)) {
                $price_args->{"${price_field}_id"}=$schema->lookup_dictionary_by_name($price_field,ff($region_price->{$price_field}));
            }
            for my $price_field (qw(price)) {
                $price_args->{$price_field}=ff($region_price->{$price_field});
            }
            push @$region_prices,$price_args;
        }
        for my $country_price (@{$channel_slot->{country_prices}}) {
            my $price_args={};

            for my $price_field (qw(currency)) {
                $price_args->{"${price_field}_id"}=$schema->lookup_dictionary_by_name($price_field,ff($country_price->{$price_field}));
            }
            for my $price_field (qw(price country)) {
                $price_args->{$price_field}=ff($country_price->{$price_field});
            }
            push @$country_prices,$price_args;
        }

        # Product tag handling.
        #
        # The presence of a tag indicates that property is true.
        # The tag names do not map directly to database fields.
        # Each tag should have a handler sub in this hash.
        # The sub should accept one boolean argument and set the propert(ies|y) accordingly
        # The keys of the hash will be used as the definitive tag list for validation.
        #
        # In other words, to add/remove or change the handling of a tag, change this hash.
        my %product_tag_handler = (
            preorder => sub { $product_attr_args->{pre_order} = $_[0] },
        );

        # Getting external image urls form the channelised block in order to store it
        # later as a product property.

        for my $url (@{$channel_slot->{external_image_urls}}) {
            next if grep { $_ eq $url} @external_image_urls;
            push @external_image_urls, $url;
        }

        $self->_process_product_tags(\%product_tag_handler, $channel_slot->{product_tags});
    }

    my $variant_pos=0;
    for my $variant (@{$args{size_scheme_variant_size}}) {
        my $variant_args={
            type       => $VARIANT_TYPE__STOCK,
            legacy_sku => $product_id.($variant_pos > 0 ? "_$variant_pos" : ''),
        };

        my $size_obj = $schema->resultset('Public::SizeSchemeVariantSize')->search(
            {
                'size.size' => $variant->{size},
                'designer_size.size' => $variant->{designer_size},
                'size_scheme_id' => $product_attr_args->{size_scheme_id},
            },
            {
                join => ['size','designer_size']
            }
        )->first;

        if (!$size_obj) {
            die sprintf q{Couldn't find a size %s (designer size %s) in size scheme '%s'},
                $variant->{size},
                $variant->{designer_size},
                $args{size_scheme};
        }

        for my $variant_field (qw(size_id designer_size_id)) {
            $variant_args->{$variant_field}=$size_obj->$variant_field;
        }
        for my $variant_field (qw(variant_id)) {
            $variant_args->{$variant_field}=$variant->{$variant_field};
        }

        # If we have a third party sku we store the business as well so we can map
        # third party SKUs to our variants (per third party)
        my $variant_field = 'third_party_sku';
        if ( defined $variant->{$variant_field} ) {
            $variant_args->{$variant_field} = $variant->{$variant_field};
            $variant_args->{'business_id'}  = $business_id;
        }

        push @$variants,$variant_args;
        ++$variant_pos;
    }

    # APS-1219: only create the product in the DC, if we've
    # been able to set up the channelised data
    return unless @$product_channel_args;

    my $is_this_a_new_product=0;
    eval {
        my $transaction = $schema->txn_scope_guard;

        my $dbh=$schema->storage->dbh;

        my $product=$schema->resultset('Public::Product')
            ->find({id => $product_args->{product_id}});

        if ($product) {

            delete $product_args->{product_id};
            # update!
            $product->update($product_args);

            for my $channel_args (@$product_channel_args) {
                for my $attr (qw(classification product_type sub_type)) {
                    set_product_nav_attribute(
                        $dbh,
                        $channel_args,
                    );
                }
            }

            $product->product_attribute->update($product_attr_args);
            $product->shipping_attribute->update($shipping_attr_args);

            $product->external_image_urls->delete();
            for my $url ( @external_image_urls ){
                $product->create_related('external_image_urls', {url => $url} );
            }

            # these also do all the updates on dependent fields
            set_purchase_price(
                $dbh,
                $product_id,
                $purchase_args->{original_wholesale},
                $purchase_args->{trade_discount},
                $purchase_args->{uplift},
                $purchase_args->{wholesale_currency_id},
                $purchase_args->{unit_landed_cost},
                $purchase_args->{landed_currency_id},
            );
            set_default_price(
                $dbh,
                $product_id,
                $def_price_args->{default_price},
                $def_price_args->{default_currency_id},
                $operator_id,
            );

            for my $region_price (@{$region_prices}) {
                set_region_price(
                    $dbh,
                    $product_id,
                    $region_price->{price},
                    $region_price->{currency_id},
                    $region_price->{region_id},
                    $operator_id,
                );
            }
            for my $country_price (@{$country_prices}) {
                set_country_price(
                    $dbh,
                    $product_id,
                    $country_price->{price},
                    $country_price->{currency_id},
                    $country_price->{country},
                    $operator_id,
                );
            }

            if (%$markdown_args) {
                my $md1st_cat=$schema->resultset('Public::PriceAdjustmentCategory')
                    ->search({category => '1st MD'})->first->id;

                my $markdown_1st=$product->search_related(
                    'price_adjustments',
                    {
                        category_id => $md1st_cat,
                        date_finish => { '>', $markdown_args->{start_date} },
                    })->first;

                my $markdown_others=$product->count_related(
                    'price_adjustments',
                    {
                        category_id => { '!=' => $md1st_cat },
                    });

                if ($markdown_others) {
                    # we have more than one markdown,
                    # this means that the information received
                    # is out of date, ignore it
                }
                elsif ($markdown_1st) {
                    # we only have a "1st markdown", active:
                    # clobber it, we have new information
                    $markdown_1st->update({
                        date_start => $markdown_args->{start_date},
                        percentage => $markdown_args->{percentage}
                    });
                }
                else {
                    # no markdown exists, create one
                    set_markdown(
                        $dbh,
                        $markdown_args,
                    );
                }
            }

            for my $variant (@{$variants}) {
                add_third_party_sku(
                    $dbh,
                    $product_id,
                    $variant,
                );
                create_variant(
                    $dbh,
                    $product_id,
                    $variant,
                );
            }
        }
        else {
            # create!
            $is_this_a_new_product=1;

            # As we're creating a new product, we need* blank defaults
            # for these fields that have (probably) not been set
            %{ $product_attr_args } = (
                long_description  => '',
                short_description => '',
                editors_comments  => '',
                keywords          => '',
                custom_lists      => '',
                %{ $product_attr_args },
            );

            # The shipping attributes set in XT won't be there yet
            # for a new product, so we need* blank defaults
            %{ $shipping_attr_args } = (
                country_id           => 0,
                dangerous_goods_note => '',
                packing_note         => '',
                weight               => 0,
                fabric_content       => '',
                %{ $shipping_attr_args },
            );

            # * We actually don't know why we need to have blanks rather
            # than nulls, but for PM-1851, and emergency fix to stop the
            # blanks clobbering existing products (up there where
            # PM-1851 is also referenced), we want to preserve this
            # just in case. A new bug, PM-1854 exists for us to get to
            # the bottom of this.

            # APS-1219:  only create the product in the DC, if we've been able to setup the channelised data
            XTracker::Database::Product::create_product(
                $dbh,
                $product_args,
                $operator_id,
            );

            for my $channel_args (@$product_channel_args) {
                create_product_channel(
                    $dbh,
                    $channel_args,
                );

                for my $attr (qw(classification product_type sub_type)) {
                    set_product_nav_attribute(
                        $dbh,
                        $channel_args,
                    );
                }
            }

            create_product_attributes(
                $dbh,
                $product_id,
                $product_attr_args,
            );

            # uncomment this when "upload_after" is added to the
            # product_attribute table
            # - Gianni Cecarelli 2010-06-18
            #$schema->resultset('Public::Product')
            #    ->find({id => $product_id})
            #    ->product_attribute->update($product_attr_args);

            create_shipping_attributes(
                $dbh,
                $product_id,
                $shipping_attr_args,
                $operator_id,
            );

            set_purchase_price(
                $dbh,
                $product_id,
                $purchase_args->{original_wholesale},
                $purchase_args->{trade_discount},
                $purchase_args->{uplift},
                $purchase_args->{wholesale_currency_id},
                $purchase_args->{unit_landed_cost},
                $purchase_args->{landed_currency_id},
            );

            set_default_price(
                $dbh,
                $product_id,
                $def_price_args->{default_price},
                $def_price_args->{default_currency_id},
                $operator_id,
            );

            for my $region_price (@{$region_prices}) {
                set_region_price(
                    $dbh,
                    $product_id,
                    $region_price->{price},
                    $region_price->{currency_id},
                    $region_price->{region_id},
                    $operator_id,
                );
            }
            for my $country_price (@{$country_prices}) {
                set_country_price(
                    $dbh,
                    $product_id,
                    $country_price->{price},
                    $country_price->{currency_id},
                    $country_price->{country},
                    $operator_id,
                );
            }

            if (%$markdown_args) {
                set_markdown(
                    $dbh,
                    $markdown_args,
                );
            }
            for my $variant (@{$variants}) {
                create_variant(
                    $dbh,
                    $product_id,
                    $variant,
                );
                # create variants even for sizes non explicitly
                # passed in, but present in the sizing scheme?
                #
                # no, we don't have the variant_id that has to be
                # created in Fulcrum so that it's the same across
                # DCs
            }
            set_product_standardised_sizes($dbh,$product_id);

            # Check if any product restrictions exist and update the shipping
            # restriction table. If a product has not been created on all DCs
            # we may create the product on another DC later. Check if any
            # restrictions have been added from fulcrum.
            foreach my $restriction ( @{ $args{restrictions} } ) {
                my $product_restriction = {};
                # The set_shipping_restriction method requires a product_id
                # and a restriction which is a string.
                $product_restriction->{ product_id } = $product_id;
                $product_restriction->{ restriction } = $restriction->{title};

                set_shipping_restriction(
                    $dbh,
                    $product_restriction
                );
            }
        }

        # Get whatever we've ended up with in the DB and update the PRLs
        $product ||=
            $schema->resultset('Public::Product')
            ->find({id => $product_args->{product_id}});

        # We should have created a product (or bailed out) by now...
        die "create_product message consumed but no product created"
            unless defined $product;

        # Stuff that relies on $product existing below:

        # Adding external image urls (if any) to product
        for my $url ( @external_image_urls ){
            $product->create_related('external_image_urls', {url => $url} );
        }

        $product->discard_changes();
        $product->send_sku_update_to_prls({'amq'=>$self->model('MessageQueue')});

        # Commit the transaction in XT's database
        $transaction->commit;

        # Now we notify external systems

        # If the product is live / staged, this will add to the
        # relevant WebDB (in case we have added variants etc):
        my $updater = XT::Product::WebDataTransfer->new;
        $updater->update_product_in_webdb( $product );

        # We 'may' have created new variants, so we'll broadcast product
        # sizing for good measure
        $product->broadcast_sizing;

    };
    if ( my $e = $@ ) {
        die "Couldn't create product $args{product_id}: $e\n";
    }
    if ($is_this_a_new_product) {
        my $product=$schema->resultset('Public::Product')
            ->find({id => $product_id});

        # This is a new product so we need to notify the product
        # service of its existance
        $product->notify_product_service if $product;
    }
}

# _process_product_tags
#
# Process product tags by checking the supplied ones are recognised
# and calling handler subs to set the corresponding attributes to true/false
#
# Done using a hash of handler subs so that there's one place (in XT)
# where the tags need to be listed and the subs are specified in the
# caller so they can change any of the attributes in scope at that time.
sub _process_product_tags {
    my ( $self, $product_tag_handler, $product_tags ) = @_;

    # Iterate through supplied tags
    my %set_product_tag;
    foreach my $tag_name (@{ $product_tags }) {
        # check it's a recognised tag
        unless ($product_tag_handler->{$tag_name}) {
            croak "Unrecognised product_tag '$tag_name' in product AMQ message";
        }
        # Remember the fact that it was specified.
        $set_product_tag{$tag_name} = 1;
    }

    # Loop through each known tag and set it to true or false by calling the handler sub
    foreach my $tag_name (keys %{ $product_tag_handler }) {
        $product_tag_handler->{$tag_name}->( $set_product_tag{$tag_name} // 0 );
    }
    return;
}

sub delete_voucher {
    my ( $self, $m, $h ) = @_;

    my $schema = $self->model('Schema')->schema;

    eval {
        my $guard = $schema->txn_scope_guard;
        my $voucher = $schema->resultset('Voucher::Product')
                             ->find( $m->{id} );
        if ($voucher) {
            $voucher->delete_related('variant');
            $voucher->delete;
        }
        $guard->commit;
    };
    if ( my $e = $@ ) {
        die "Couldn't delete voucher $m->{id}; $e\n";
    }
}

sub assign_virtual_voucher_code_to_shipment {
    my ( $self, $m, $h )    = @_;

    # if not for any of this DC's channels then don't want it
    return unless $self->channel_exists( $m->{channel_id} );

    my $schema  = $self->model('Schema')->schema;
    my $channel = $schema->resultset('Public::Channel')->find( $m->{channel_id} );

    eval {
        my $guard   = $schema->txn_scope_guard;

        # loop through all shipments and update the
        # shipment items
        my $shipments   = $m->{shipments};
        foreach my $shipment ( @{ $shipments } ) {
            my $shipment_rec= $schema->resultset('Public::Shipment')->find( $shipment->{shipment_id} );
            my $ship_items  = $shipment->{shipment_items};

            if ( !defined $shipment_rec ) {
                die "Couldn't find Shipment: ".$shipment->{shipment_id};
            }
            if ( $shipment_rec->shipment_status_id == $SHIPMENT_STATUS__CANCELLED ) {
                # no need if the shipment has been cancelled
                next;
            }

            # loop through all Shipment Items
            foreach my $item ( @{ $ship_items } ) {
                my $ship_item   = $schema->resultset('Public::ShipmentItem')->find( $item->{shipment_item_id} );
                my $voucher     = $schema->resultset('Voucher::Product')->find( $item->{voucher_pid} );
                my $vouch_code  = $item->{voucher_code};

                if ( !defined $ship_item ) {
                    die "Shipment Id: ".$shipment_rec->id.", Couldn't find Shipment Item: ".$item->{shipment_item_id};
                }
                if ( $ship_item->shipment_id != $shipment_rec->id ) {
                    die "Shipment Item: ".$ship_item->id." is not for Shipment Id: ".$shipment_rec->id;
                }
                if ( $ship_item->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__CANCELLED
                  || $ship_item->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING ) {
                    # don't bother if it's been cancelled
                    next;
                }
                if ( defined $ship_item->voucher_code_id ) {
                    # it's already got a Voucher Code so skip it
                    next;
                }
                if ( !defined $voucher ) {
                    die "Shipment Id: ".$shipment_rec->id.", Shipment Item Id: ".$ship_item->id.", Couldn't find Voucher for PID: ".$item->{voucher_pid};
                }

                # create Voucher Code
                my $code    = $voucher->add_code( $vouch_code );

                # assign it to the Shipment Item
                $ship_item->voucher_code_id( $code->id );

                # set Shipment Item to be picked if Shipment in correct status,
                # but also log Selected to be inline with normal processing
                if ( $shipment_rec->shipment_status_id == $SHIPMENT_STATUS__PROCESSING ) {
                    $ship_item->create_related( 'shipment_item_status_logs', {
                                                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED,
                                                                operator_id => $APPLICATION_OPERATOR_ID,
                                                        } );
                    $ship_item->update_status( $SHIPMENT_ITEM_STATUS__PICKED, $APPLICATION_OPERATOR_ID );
                }
                else {
                    # update changes to Shipment Item
                    $ship_item->update;
                }

                # activate code
                $code->assigned_code();
            }

            # after processing all items try and dispatch the shipment
            $shipment_rec->discard_changes;
            $shipment_rec->dispatch_virtual_voucher_only_shipment( $APPLICATION_OPERATOR_ID );
        }

        $guard->commit;
    };
    if ( my $err = $@ ) {
        die "Couldn't assign Virtual Voucher Codes to Shipments: ".$err;
    }

    return;
}

sub send_detailed_stock_levels {
    my ($self, $m, $h) = @_;

    my $schema = $self->model('Schema');
    my $product = $schema->resultset('Public::Product')->find({
        id => $m->{product_id},
    }) || $schema->resultset('Voucher::Product')->find({
        id => $m->{product_id},
    });

    require XTracker::WebContent::StockManagement::Broadcast;

    my $broadcast = XTracker::WebContent::StockManagement::Broadcast->new({
        schema => $schema,
        channel_id => $m->{channel_id},
    });

    $broadcast->stock_update(
        quantity_change => 0,
        product => $product,
        full_details => 1,
    );
    $broadcast->commit();

    return;
}

sub ff { fix_encoding(fix_encoding(@_)) }
