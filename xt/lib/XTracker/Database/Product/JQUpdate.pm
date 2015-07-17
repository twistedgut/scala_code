package XTracker::Database::Product::JQUpdate;
# NAP::policy causes this module to die on warnings, which is a problem because of all
# the logging what tries to concatinate (possibly) undef values
use Moose;
use Try::Tiny;

with 'XTracker::Role::WithXTLogger';

has ['dbh', 'schema'] => ( is => 'ro', required => 1 );

use XTracker::Constants             qw( :application );
use XTracker::Database::Operator    qw( get_operator_by_id );
use XTracker::Database::Channel     qw( get_channels get_channel );
use XTracker::Database::Product     qw( get_product_channel_info set_product_nav_attribute set_product_hierarchy_attributes set_product_channel);
use XTracker::Database::Attributes  qw( set_product set_classification_attribute set_product_attribute set_shipping_attribute set_shipping_restriction remove_shipping_restriction );
use XTracker::Database::Pricing     qw( set_purchase_price set_default_price set_region_price set_country_price delete_country_price delete_region_price complete_pricing );

sub update_product {
    my ($self, $payload) = @_;

    my $schema = $self->schema;
    my $guard = $schema->txn_scope_guard;

    # get channels on DC to know if channel data is relevant to us
    my $dc_channels = get_channels( $self->dbh );

    # process each product in the payload
    foreach my $record ( @{ $payload } ) {

        # grab product id and operator out of payload
        my $product_id  = $record->{product_id};

        # get operator id & check it is ok and exists in DC operator table
        my $operator_id = $record->{operator_id};
        if (
            (!defined $operator_id) || (!$operator_id) || ($operator_id <= 0)
        ) {
            $operator_id = $APPLICATION_OPERATOR_ID;
        }
        else {
            eval {
                my $chk_opid = get_operator_by_id( $self->dbh, $operator_id );
                if ( (!defined $chk_opid) || (!exists($chk_opid->{id})) || ($chk_opid->{id} != $operator_id) ) {
                    $operator_id = $APPLICATION_OPERATOR_ID;
                }
            };
            if ( $@ ) {
                $operator_id = $APPLICATION_OPERATOR_ID;
            }
        }

        $self->xtlogger->debug('Processing update for PID: '.$product_id);

        # Fetch actual product object
        my $product_obj = $self->schema->resultset('Public::Product')->find($product_id);
        if (!$product_obj) {
            $self->xtlogger->warn(
                sprintf('product with id %s was not found', $product_id)
            );
            # Really we should blow up with a die here. But we're waiting for Fulcrum
            # to fix a bug where they are sending through products that don't exist
            # on some DCs. So to stop their fail logs filling up we'll just skip
            next;
        }

        # map payload to XT functional grouping
        my $data = $self->_map_payload( $dc_channels, $record );

        # perform XT updates
        $self->_run_updates($product_obj, $data->{xt_data}, $operator_id );

        # kick off a website update if required
        $self->_create_web_update($product_id, $data);
    }
    $guard->commit();

    return;
}

sub _map_payload {
    my ($self, $dc_channels, $record) = @_;

    my $mapped_data;
    my $web_data = {};
    my $web_channel_data = {};

    my %mapping = (
        description               => 'attributes',
        designer_colour           => 'attributes',
        designer_colour_code      => 'attributes',
        editorial_approved        => 'attributes',
        editorial_notes           => 'attributes',
        editors_comments          => 'attributes',
        fit_notes                 => 'attributes',
        keywords                  => 'attributes',
        long_description          => 'attributes',
        name                      => 'attributes',
        outfit_links              => 'attributes',
        product_department        => 'attributes',
        related_facts             => 'attributes',
        season_act                => 'attributes',
        size_fit                  => 'attributes',
        size_fit_delta            => 'attributes',
        style_notes               => 'attributes',
        use_fit_notes             => 'attributes',
        pre_order                 => 'attributes',
        pricing_complete          => 'complete_pricing',
        hierarchy                 => 'hierarchy_attributes',
        landing_price             => 'landing_price',
        navigation_classification => 'nav_attributes',
        navigation_product_type   => 'nav_attributes',
        navigation_sub_type       => 'nav_attributes',
        pricing                   => 'pricing',
        visible                   => 'prod_channel',
        disableupdate             => 'prod_channel',
        pws_sort_adjust_id        => 'prod_channel',
        classification            => 'product',
        colour                    => 'product',
        designer                  => 'product',
        division                  => 'product',
        hs_code                   => 'product',
        product_type              => 'product',
        season                    => 'product',
        style_number              => 'product',
        sub_type                  => 'product',
        world                     => 'product',
        canonical_product_id      => 'product',
        fabric_content            => 'shipping',
        fish_wildlife_source      => 'shipping',
        origin_country_id         => 'shipping',
        packing_note              => 'shipping',
        dangerous_goods_note      => 'shipping',
        scientific_term           => 'shipping',
        weight_kgs                => 'shipping',
    );
    my %web_required = (
        hs_code                 => { field_name => 'hs_code',           categories => ['catalogue_sku'] },
        classification          => { field_name => 'classification',    categories => ['catalogue_attribute'] },
        colour                  => { field_name => 'colour',            categories => ['catalogue_attribute', 'catalogue_sku'] },
        designer                => { field_name => 'designer_id',       categories => ['catalogue_product', 'catalogue_sku'] },
        division                => { field_name => 'division',          categories => ['catalogue_attribute'] },
        product_type            => { field_name => 'product_type',      categories => ['catalogue_attribute'] },
        season                  => { field_name => 'season_id',         categories => ['catalogue_product'] },
        sub_type                => { field_name => 'sub_type',          categories => ['catalogue_attribute'] },
        world                   => { field_name => 'world',             categories => ['catalogue_attribute'] },
        description             => { field_name => 'description',       categories => ['catalogue_product'] },
        name                    => { field_name => 'name',              categories => ['catalogue_product', 'catalogue_sku'] },
        canonical_product_id    => { field_name => 'canonical_product_id', categories => ['catalogue_product'] },
    );
    my %web_required_channelised = (
        long_description        => { field_name => 'long_description',  categories => ['catalogue_product', 'catalogue_sku'] },
        editors_comments        => { field_name => 'editors_comments',  categories => ['catalogue_product', 'catalogue_sku'] },
        keywords                => { field_name => 'keywords',          categories => ['catalogue_product', 'catalogue_sku'] },
        size_fit                => { field_name => 'size_fit',          categories => ['catalogue_product', 'catalogue_sku'] },
        visible                 => { field_name => 'visible',           categories => ['pws_visibility'] },
        pricing                 => { field_name => 'pricing',           categories => ['catalogue_pricing'] },
        related_facts           => { field_name => 'related_facts',     categories => ['catalogue_product', 'catalogue_sku'] },
    );

    ## no critic(ProhibitDeepNests)
    # loop over remaining fields to map to functional grouping
    foreach my $field ( keys %{ $record }) {
        $self->xtlogger->debug('Checking payload field: '.$field.' ('.($record->{$field}//'').')');

        # drill down another level for channelised data
        if ( $field eq 'channel' ) {
            foreach my $channel ( @{ $record->{$field} } ) {

                my $channel_id = $channel->{channel_id};

                # check if channel is present on DC otherwise ignore data, not
                # for us
                next unless $dc_channels->{$channel_id};
                foreach my $subfield ( keys %{ $channel }) {
                    # check if field triggers an xt update
                    $self->xtlogger->debug(
                        sprintf('Processing payload field (key: %s, value: %s)',
                            $subfield, ($channel->{$subfield} // ''))
                    );
                    if ( my $grouping = $mapping{ $subfield } ) {
                        $self->xtlogger->debug("Triggered XT update: functional group: $grouping");
                        # Channelised attributes
                        if ( $grouping =~ m{^(?:prod_channel|nav_attributes|hierarchy_attributes)$}) {
                                $mapped_data->{ $grouping }{ $channel_id }{ $subfield } = $channel->{$subfield};
                        }
                        else {
                                $mapped_data->{ $grouping }{ $subfield } = $channel->{$subfield};
                        }
                    }
                    # check if field triggers a website update
                    if ( my $web_map = $web_required_channelised{ $subfield } ) {
                        foreach my $web_cat ( @{ $web_map->{categories} } ) {
                            # hack for catalogue attributes as they need to be uppercase
                            my $field_name = $web_cat eq 'catalogue_attribute'
                                            ? uc( $web_map->{field_name} )
                                            : $web_map->{field_name};
                            $self->xtlogger->debug("Triggered website update (PWS field_name: $field_name category: $web_cat)");
                            $web_channel_data->{ $channel_id }{ $web_cat }{ $field_name } = $channel->{$subfield};
                        }
                    }
                }
            }
        }
        # check for shipping restriction codes
        # (note below the legacy version via the restriction titles)
        elsif ( $field eq 'restriction_code' ) {
            $self->xtlogger->debug('Mapped payload field: restriction_code');
            foreach my $action (keys %{ $record->{$field} } ) {
                $self->xtlogger->debug('Action: '.$action);
                $mapped_data->{ 'restriction_code' }{ $action }
                    = $record->{$field}{$action};
                $web_data->{ 'catalogue_ship_restriction' }{ 'all' } = 1;
            }
        }
        # Legacy version of recording ship_restrictions via their titles
        elsif ( $field eq 'restriction' ) {
            $self->xtlogger->debug('Mapped payload field: restriction');
            $self->xtlogger->warn('Updating shipping restrictions via the "restriction" field is deprecated. Use "restriction_code" instead.');
            foreach my $action (keys %{ $record->{$field} } ) {
                $self->xtlogger->debug('Action: '.$action);
                $mapped_data->{ 'restriction' }{ $action }
                    = $record->{$field}{$action};
                $web_data->{ 'catalogue_ship_restriction' }{ 'all' } = 1;
            }
        }
        else {
            # map to XT grouping
            if ( $mapping{ $field } ) {
                my $grouping = $mapping{ $field };
                $self->xtlogger->debug(
                    'Mapped payload field: '.$field.' ('
                    .($record->{$field}//'').') to functional group: '.$grouping
                );
                $mapped_data->{ $grouping }{ $field } = $record->{$field};

                # check if field triggers a website update
                if ( $web_required{ $field } ) {
                    foreach my $web_cat ( @{ $web_required{$field}{categories} } ) {
                        # hack for catalogue attributes as they need to be uppercase
                        if ( $web_cat eq 'catalogue_attribute' ) { $web_required{ $field }{field_name} = uc($web_required{ $field }{field_name}); }
                        $web_data->{ $web_cat }{ $web_required{ $field }{field_name} } = $record->{$field};
                    }
                }
            }
        }
    }

    return {
        xt_data             => $mapped_data,
        common_web_data     => $web_data,
        channel_web_data    => $web_channel_data,
    };

}


sub _run_updates {
    my ($self, $product_obj, $mapped_data, $operator_id) = @_;

    my $dbh = $self->dbh();

    my $product_id = $product_obj->id();

    # general product data
    foreach my $field ( keys %{ $mapped_data->{product} } ) {
        set_product(
            $dbh, $product_id, $field, $mapped_data->{product}{$field}, $operator_id
        );
    }

    # classification data
    foreach my $field ( keys %{ $mapped_data->{classification} } ) {
        set_classification_attribute(
            $dbh, $product_id, $field, $mapped_data->{classification}{$field},
            $operator_id
        );
    }

    # general attribute data
    foreach my $field ( keys %{ $mapped_data->{attributes} } ) {
        set_product_attribute(
            $dbh, $product_id, $field, $mapped_data->{attributes}{$field},
            $operator_id
        );
    }

    # shipping attribute data
    foreach my $field ( keys %{ $mapped_data->{shipping} } ) {
        set_shipping_attribute(
            $dbh, $product_id, $field, $mapped_data->{shipping}{$field},
            $operator_id
        );
    }

    if (exists($mapped_data->{restriction})) {
        # shipping restrictions via title (legacy)
        foreach my $record ( @{ $mapped_data->{restriction}{add} } ) {
            XTracker::Database::Attributes::set_shipping_restriction(
                $dbh, { product_id => $product_id, restriction => $record }
            );
        }
        foreach my $record ( @{ $mapped_data->{restriction}{remove} } ) {
            XTracker::Database::Attributes::remove_shipping_restriction(
                $dbh, { product_id => $product_id, restriction => $record }
            );
        }
    } elsif(exists($mapped_data->{restriction_code})) {
        # Shipping restrictions new way (via code)
        if (exists($mapped_data->{restriction_code}->{add})) {
            $product_obj->add_shipping_restrictions({
                restriction_codes => $mapped_data->{restriction_code}->{add},
            });
        }
        if (exists($mapped_data->{restriction_code}->{remove})) {
            $product_obj->remove_shipping_restrictions({
                restriction_codes => $mapped_data->{restriction_code}->{remove},
            });
        }

    }

    # pricing
    foreach my $record ( @{ $mapped_data->{pricing}{pricing} } ) {
        if ( $record->{action} eq 'insert' || $record->{action} eq 'update' ) {
            if ( $record->{price_type} eq 'default' ) {
                set_default_price(
                    $dbh, $product_id, $record->{price}, $record->{currency},
                    $operator_id
                );
            }
            elsif ( $record->{price_type} eq 'region' ) {
                set_region_price(
                    $dbh, $product_id, $record->{price},
                    $record->{currency}, $record->{region_id}, $operator_id
                );
            }
            elsif ( $record->{price_type} eq 'country' ) {
                set_country_price( $dbh, $product_id, $record->{price}, $record->{currency}, $record->{country_code}, $operator_id );
            }
            else {
                die 'Unknown price type: '.$record->{price_type};
            }
        }
        elsif ( $record->{action} eq 'delete' ) {
            if ( $record->{price_type} eq 'default' ) {
                die 'Cannot delete a default price, only update';
            }
            elsif ( $record->{price_type} eq 'region' ) {
                delete_region_price( $dbh, $product_id, $record->{region_id}, $operator_id );
            }
            elsif ( $record->{price_type} eq 'country' ) {
                delete_country_price(
                    $dbh, $product_id, $record->{country_code}, $operator_id
                );
            }
            else {
                die 'Unknown price type: '.$record->{price_type};
            }
        }
        else {
            die 'Unknown price action: '.$record->{action};
        }
    }

    # complete pricing flag
    foreach my $field ( keys %{ $mapped_data->{complete_pricing} } ) {
        complete_pricing(
            $dbh, { product_id => $product_id, operator_id => $operator_id }
        );
    }


    # channel data
    foreach my $channel_id ( keys %{ $mapped_data->{prod_channel} } ) {
        foreach my $field ( keys %{ $mapped_data->{prod_channel}{$channel_id} } ) {
            set_product_channel(
                $dbh, {
                    product_id => $product_id,
                    channel_id => $channel_id,
                    field_name => $field,
                    value => $mapped_data->{prod_channel}{$channel_id}{$field},
                    operator_id => $operator_id
                }
            );
        }
    }

    # nav attributes
    foreach my $channel_id ( keys %{ $mapped_data->{nav_attributes} } ) {
        set_product_nav_attribute(
            $dbh, {
                product_id => $product_id,
                channel_id => $channel_id,
                attributes => $mapped_data->{nav_attributes}{$channel_id},
                operator_id => $operator_id
            }
        );
    }

    # hierarchy attributes
    foreach my $channel_id ( keys %{ $mapped_data->{hierarchy_attributes} } ) {
        foreach my $field ( keys %{ $mapped_data->{hierarchy_attributes}{$channel_id} } ) {
            set_product_hierarchy_attributes( $dbh, { product_id => $product_id, channel_id => $channel_id, values => $mapped_data->{hierarchy_attributes}{$channel_id}{$field}, operator_id => $operator_id } );
        }
    }

    # DCS-1000
    #   landing_price => {
    #        original_wholesale => "2237.006",
    #        payment_deposit => "1.000",
    #        "payment_settlement_discount" => "2.000",
    #        payment_term_id => 6,
    #        trade_discount => "4.01",
    #        uplift => "1.02",
    #    },

    if ( my $block = $mapped_data->{landing_price}{landing_price} ) {
        # yes this is awful! at the moment I'm more concerned with getting it
        # working - CCW 2009-09-15

        # public.product
        ## payment id
        set_product(
            $dbh,
            $product_id,
            'payment_term_id',
            $block->{payment_term_id},
            $operator_id
        );
        ## payment_settlement_discount_id
        set_product(
            $dbh,
            $product_id,
            'payment_settlement_discount_id',
            $self->_get_payment_settlement_discount_id_from_value(
                $block->{payment_settlement_discount}
            ),
            $operator_id
        );
        ## payment_deposit_id
        set_product(
            $dbh,
            $product_id,
            'payment_deposit_id',
            $self->_get_payment_deposit_id_from_value($block->{payment_deposit}),
            $operator_id
        );

        # public.price_purchase
        ## original_wholesale
        ## trade_discount
        ## uplift
        # we might as well use the existing update method
        set_purchase_price(
            $dbh, $product_id,
            $block->{original_wholesale},
            $block->{trade_discount},
            $block->{uplift},
            $block->{currency_id},
            $block->{unit_landed_cost},
        );

    }

    return;

}

sub _get_payment_settlement_discount_id_from_value {
    my ($self, $value) = @_;

    my $dbh = $self->dbh();

    my ($qry, $sth, $data);

    $qry = q{select id from payment_settlement_discount where discount_percentage=?};
    $sth = $dbh->prepare($qry);
    $sth->execute($value);

    my $row = $sth->fetchrow_hashref();

    if (defined $row && exists $row->{id}) {
        return $row->{id};
    }
    else {
        # create a new record in the DC
        my $qry = q{insert into payment_settlement_discount (discount_percentage) values (?)};
        $sth = $dbh->prepare($qry);
        $sth->execute($value);

        my $new_id = $dbh->last_insert_id(undef, undef, undef, undef, { sequence => 'payment_settlement_discount_id_seq' });
        if (defined $new_id) {
            return $new_id;
        }
        else {
            die "no existing payment_settlement_discount record for '$value' and failed to create a new one";
        }
    }
}

sub _get_payment_deposit_id_from_value {
    my ($self, $value) = @_;

    my $dbh = $self->dbh();

    my ($qry, $sth, $data);

    $qry = q{select id from payment_deposit where deposit_percentage=?};
    $sth = $dbh->prepare($qry);
    $sth->execute($value);

    my $row = $sth->fetchrow_hashref();

    if (defined $row && exists $row->{id}) {
        return $row->{id};
    }
    else {
        # create a new record in the DC
        my $qry = q{insert into payment_deposit (deposit_percentage) values (?)};
        $sth = $dbh->prepare($qry);
        $sth->execute($value);

        my $new_id = $dbh->last_insert_id(undef, undef, undef, undef, { sequence => 'payment_deposit_id_seq' });
        if (defined $new_id) {
            return $new_id;
        }
        else {
            die "no existing payment_deposit record for '$value' and failed to create a new one";
        }
    }
}


sub _create_web_update {

    my ($self, $product_id, $data) = @_;

    if (keys %{$data->{channel_web_data}}) {

        # send data to each channel included in data map
        for my $channel_id (sort keys %{ $data->{channel_web_data} }) {

            my $channel_name = get_channel($self->dbh(), $channel_id)->{name};

            # prepare transfer categories as union of commonm web update data and channelised data
            my %web_data = (%{ $data->{common_web_data} }, %{ $data->{channel_web_data}->{ $channel_id } });

            $self->_create_web_update_job($product_id, $channel_name, \%web_data);

        }

    } elsif (keys %{$data->{common_web_data}}) {

        # if we have common data then determine the product channel and send to web site
        my $active_channel_name;
        my $product = $self->schema()->resultset('Public::Product')->find($product_id);
        $active_channel_name = $product->get_current_channel_name() if $product;

        my %web_data = %{ $data->{common_web_data} };

        $self->_create_web_update_job($product_id, $active_channel_name, \%web_data);

    }

    return;

}


sub _create_web_update_job {
    my ($self, $product_id, $channel_name, $web_data) = @_;

    my $dbh = $self->dbh();

    my $channel_data  = get_product_channel_info($dbh, $product_id);
    my $environment   = undef;

    # product is live
    if ( $channel_data->{ $channel_name }{live} == 1 ) {
        $environment = 'live';
    }
    # product is on staging
    elsif ( $channel_data->{ $channel_name }{staging} == 1 ){
        $environment = 'staging';
    }

    if ( keys %{$web_data} && $environment ) {

        $self->xtlogger->debug(
            'Creating '. $environment .' web update job for PID: '
            .$product_id.' to channel: '.$channel_name
        );

        my $payload;

        $payload->{environment}         = $environment;
        $payload->{product_id}          = $product_id;
        $payload->{channel}             = $channel_name;
        $payload->{transfer_categories} = $web_data;

        my $job = XT::JQ::DC->new({ funcname => 'Send::Product::WebUpdate' });
        $job->set_payload( $payload );
        $job->send_job();

    }
    else {
        $self->xtlogger->debug(
            'Skipping web update for PID: '.$product_id.' to channel: '
            .$channel_name
        );
    }

}

1;

=head1 NAME

XT::JQ::DC::Receive::Product::Update - Notification of changes to product data from
Fulcrum to DC

=head1 DESCRIPTION

Data within payload crosses over multiple tables in XT so payload fields are mapped into
relevant DC groupings depending on what update function to call before any updates are performed.

After updating locally we also need to work out if a web update is required based on the fields
changed and the live status of the products 'active' channel.
