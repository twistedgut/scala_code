package XTracker::Script::Shipping::Migrate;
use NAP::policy "tt", 'class';
extends 'XT::Common::Script';
with 'XTracker::Role::WithSchema';

use XTracker::Comms::DataTransfer qw/get_transfer_sink_handle/;

=head1 NAME

XTracker::Script::Shipping::Migrate - migrate shipping products

=head1 DESCRIPTION

Looks up all the shipping products in the web db and migrates them to
L<XTracker::Schema::Result::Shipping::Description> objects.

=head1 METHODS

=head2 C<invoke>

Do the work

=cut

sub invoke {
    my ($self,$args) = @_;

    try {
        $self->schema->txn_do(sub {
            # loop over channels
            my $channel_rs = $self->schema->resultset('Public::Channel');
            while ( my $channel = $channel_rs->next ) {

                # We can't migrate JC shipping products like this
                next if $channel->is_fulfilment_only();

                # We need a website to migrate from
                next unless $channel->has_public_website();

                say "migrating shipping products for channel "
                    . $channel->name if $args->{verbose};

                # connect to web db
                my $web_dbh = _connect_to_web_db($channel);

                # read shipping products
                my $shipping_products = _select_shipping_products($web_dbh);

                foreach my $shipping_product ( @{ $shipping_products } ) {

                    # insert into shipping.description
                    say "Migrating shipping product: "
                        . $shipping_product->{name}
                        if $args->{verbose};

                    # Find the shipping charge
                    my $charge = $self->schema->resultset(
                        'Public::ShippingCharge'
                    )->search({
                        sku => $shipping_product->{sku},
                    })->first;

                    if ( !$charge ) {
                        warn "cannot migrate "
                            . $shipping_product->{title}
                            . " because cannot locate matching shipping sku "
                            . $shipping_product->{sku};

                        next;
                    }

                    # Create the new shipping description
                    #
                    # We make our best guess about the estimated_delivery field
                    # which is usually either in notes01 or notes03, it's often
                    # an empty string, hence the ||
                    $self->schema->resultset(
                        'Shipping::Description'
                    )->update_or_create({
                        shipping_charge_id => $charge->id,
                        name               => $shipping_product->{name},
                        public_name        => $shipping_product->{public_name},
                        title              => $shipping_product->{title},
                        public_title       => $shipping_product->{public_title},
                        short_delivery_description
                            => $shipping_product->{short_description},
                        long_delivery_description
                            => $shipping_product->{long_description},
                        delivery_confirmation
                            => $shipping_product->{notes02},
                        estimated_delivery
                            => $shipping_product->{notes01}||$shipping_product->{notes03},
                    }) unless $args->{dryrun};

                    # Check if we need to migrate any country/region override pricing
                    my $pricing = _select_pricing($web_dbh,$shipping_product);

                    foreach my $price ( @{ $pricing } ) {
                        # We don't care about the default price
                        next if $price->{locality_type} eq 'DEFAULT';

                        my $currency = $self->schema->resultset(
                            'Public::Currency'
                        )->find({
                            currency => $price->{currency}
                        });

                        # Deal with country ovverides
                        if ($price->{locality_type} eq 'COUNTRY') {
                            my $country = $self->schema->resultset(
                                'Public::Country'
                            )->find({
                                code => $price->{locality}
                            });

                            if ( !$country ) {
                                warn "cannot migrate " . $shipping_product->{title}
                                . " country price for " . $price->{locality}
                                . " because cannot find the country";

                                next;
                            }

                            $charge->update_or_create_related('country_charges', {
                                charge      => $price->{offer_price},
                                currency_id => $currency->id,
                                country_id  => $country->id,
                            });
                        }

                        # Deal with region overrides
                        if ($price->{locality_type} eq 'TERRITORY') {
                            my $region = $self->schema->resultset(
                                'Public::Region'
                            )->search({
                                region => $price->{locality}
                            })->first;

                            if ( !$region ) {
                                warn "cannot migrate " . $shipping_product->{title}
                                . " region price for " . $price->{locality}
                                . " because cannot find the region";

                                next;
                            }

                            $charge->update_or_create_related('region_charges', {
                                charge      => $price->{offer_price},
                                currency_id => $currency->id,
                                region_id   => $region->id,
                            });

                        }
                    }

                }

                $web_dbh->disconnect();

            }
        });
    }
    catch {
        warn "Problem migrating shipping products: $_";
    };
}

sub _connect_to_web_db {
    my $channel = shift;

    return get_transfer_sink_handle({
        environment => 'live',
        channel => $channel->config_name(),
    })->{dbh_sink};

}

{
my $shipping_product_code;
sub _select_shipping_products {
    my $dbh = shift;

    # Get the shipping code
    my $sql = "
        SELECT code FROM product_type WHERE description = 'shipping'
    ";

    $shipping_product_code//= $dbh->selectall_arrayref($sql)->[0][0];

    # Get the shipping products
    $sql = "
        SELECT
            p.sku, p.name, p.public_name, p.title, p.public_title,
            p.short_description, p.long_description, p.notes01, p.notes02, p.notes03
        FROM product p
        JOIN searchable_product sp on p.search_prod_id = sp.id
        JOIN product_type t on sp.product_type = t.code where t.code = ?
    ";

    my $sth = $dbh->prepare($sql);

    $sth->execute($shipping_product_code);

    return $sth->fetchall_arrayref({});
}
}

sub _select_pricing {
    my ( $dbh, $shipping_product ) = @_;

    my $sql = "
        SELECT cp.offer_price, cp.locality, cp.locality_type, cp.currency
        FROM channel_pricing cp
        WHERE cp.sku = ?
    ";

    my $sth = $dbh->prepare($sql);

    $sth->execute($shipping_product->{sku});

    return $sth->fetchall_arrayref({});
}
