package XTracker::Script::Packaging::Migrate;
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

                say "migrating packaging products for channel "
                    . $channel->name if $args->{verbose};

                # connect to web db
                my $web_dbh = _connect_to_web_db($channel);

                # read packaging products
                my $packaging_products = _select_packaging_products($web_dbh);

                foreach my $packaging_product ( @{ $packaging_products } ) {

                    # insert into packaging_attribute / packaging_type
                    say "Migrating packaging_product product: "
                        . $packaging_product->{name}
                        if $args->{verbose};

                    # Find the packaging_type
                    my $pt = $self->schema->resultset(
                        'Public::PackagingType'
                    )->find_or_create({
                        sku => $packaging_product->{sku},
                        name => $packaging_product->{type},
                    });

                    # Create the new packaging attribute
                    $self->schema->resultset(
                        'Public::PackagingAttribute'
                    )->update_or_create({
                        packaging_type_id=> $pt->id,
                        channel_id       => $channel->id,
                        name             => $packaging_product->{name},
                        public_name      => $packaging_product->{public_name},
                        title            => $packaging_product->{title},
                        public_title     => $packaging_product->{public_title},
                        description
                            => ( $packaging_product->{short_description}
                                 ? $packaging_product->{short_description}
                                 : $packaging_product->{long_description} ),
                    }) unless $args->{dryrun};

                }

                $web_dbh->disconnect();

            }
        });
    }
    catch {
        say "Problem migrating packaging products: $_";
    };
}

sub _connect_to_web_db {
    my $channel = shift;

    return get_transfer_sink_handle({
        environment => 'live',
        channel => $channel->config_name(),
    })->{dbh_sink};

}

sub _select_packaging_products {
    my $dbh = shift;

    # Get the packaging code
    my $sql = "
        SELECT code FROM product_type WHERE description = 'packaging'
    ";

    my $packaging_product_code = $dbh->selectall_arrayref($sql)->[0][0];

    # Get the packaging products
    $sql = "
        SELECT
            p.sku, p.name, p.public_name, p.title, p.public_title,
            p.short_description, p.long_description, po.type
        FROM product p
        JOIN searchable_product sp on p.search_prod_id = sp.id
        JOIN packaging_option po on p.sku = po.sku
        JOIN product_type t on sp.product_type = t.code where t.code = ?
    ";

    my $sth = $dbh->prepare($sql);

    $sth->execute($packaging_product_code);

    return $sth->fetchall_arrayref({});
}
