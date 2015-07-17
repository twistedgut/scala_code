package XTracker::Stock::Actions::SetStockQuarantine;
use NAP::policy 'class', 'tt';

use XTracker::Handler;
use XTracker::Database::Stock::Quarantine qw( :quarantine_stock );
use XTracker::Error;

sub handler {
    my $r           = shift;
    my $uri_path    = $r->parsed_uri->path;
    my $handler     = XTracker::Handler->new($r);

    my $product_id  = $handler->{param_of}{product_id} || 0;
    my $variant_id  = $handler->{param_of}{variant_id} || 0;
    my $view_channel= $handler->{param_of}{view_channel} || '';

    my $redirect_url = "StockQuarantine?product_id=$product_id&variant_id=$variant_id&view_channel=$view_channel";

    try {
        my %variant_data;

        # loop over form post and get location data
        # into a format we can use
        foreach my $form_key ( keys %{ $handler->{param_of} } ) {
            # look for two embedded underscores, separated by anything but underscores
            if ( $form_key =~ m/_[^_]+_/ ) {
                my ($field_name,   $variant_id,   $location_id) = split( /_/, $form_key );

                if ($field_name && $variant_id && $location_id) {
                    $variant_data{ $variant_id }{ $location_id }{ $field_name } = $handler->{param_of}{$form_key};
                }
            }
        }

        my $schema = $handler->schema;
        # loop over variant data and update locations
        foreach my $variant_id ( keys %variant_data ) {
            foreach my $location_id ( keys %{ $variant_data{$variant_id} } ) {
                my %variant_datum = %{$variant_data{$variant_id}{$location_id}};

                next if ($variant_datum{quantity}||0) < 1;

                $schema->txn_do(sub{
                    # Ensure there is a matching db quantity entry (why couldn't they have just
                    # passed a quantity-id? :/)
                    my $quantity_row = $schema->resultset('Public::Quantity')->search({
                        variant_id  => $variant_id,
                        location_id => $location_id,
                        channel_id  => $variant_datum{channel},
                        status_id   => $variant_datum{status},
                        quantity    => $variant_datum{locationquantity},
                    })->first() or die "The stock to quarantine could not be found. (Has it already been quarantined?)\n";

                    quarantine_stock(
                        dbh         => $schema->storage->dbh,
                        quantity_row=> $quantity_row,
                        quantity    => $variant_datum{quantity},
                        reason      => $variant_datum{reason},
                        notes       => $variant_datum{notes},
                        operator_id => $handler->{data}{operator_id},
                        uri_path    => $uri_path,
                    );
                });
            }
        }
        xt_success('Stock successfully quarantined');
    } catch {
        xt_warn("An error occured whilst updating the locations:<br />$_");
    };

    return $handler->redirect_to( $redirect_url );
}

1;
