package XT::DC::Messaging::Producer::Stock::Update;
use NAP::policy "tt", 'class';
    with 'XT::DC::Messaging::Role::Producer',
         'XTracker::Role::WithSchema';

use XTracker::Config::Local qw( config_var );
use XTracker::Database::Product qw( get_fcp_sku );

sub message_spec {
    return {
        type => '//rec',

        required => {
            quantity_change         => '//int',
            sku                     => '//str',
            website_stock_location  => '//str',
        },
    };
}

=for consideration

This is the payload from the StockSummary Schwartz job ... I don't yet know if
it makes sense for a Stock Update job to include:

 - product and stock level changes
 - summary information

I have a feeling summary information runs on a 5 minute cron because it's
calculation-intensive; more research required.

For now make it optional.

    has payload => (
        is => 'ro',
        isa => ArrayRef[
                Dict[
                    product_id      => Int,
                    channel_id      => Int,
                    ordered         => Int,
                    delivered       => Int,
                    main_stock      => Int,
                    sample_stock    => Int,
                    sample_request  => Int,
                    reserved        => Int,
                    pre_pick        => Int,
                    cancel_pending  => Int,
                    last_updated    => Str,
                    arrival_date    => Str|Undef,
                ]
        ],

=cut

has '+type' => ( default => 'StockUpdate' );
has '+set_at_type' => ( default => 0 );

sub transform {
    my($self, $header, $data) = @_;
    my $dc_variant_id   = delete $data->{dc_variant_id};
    my $channel_id      = delete $data->{channel_id};

    $header->{destination} = $self->find_channel($channel_id)->web_name;

    # if the caller hasn't already given us the SKU, look it up for them
    if (not defined $data->{sku}) {
        my $sku;

        # find out if the variant_id is a Voucher
        my $vvariant    = $self->schema->resultset('Voucher::Variant')->find( $dc_variant_id );

        if ( not defined $vvariant ) {
            # not a voucher must be a normal product
            $sku = get_fcp_sku(
                $self->schema->storage->dbh,
                { type => 'variant_id', id => $dc_variant_id }
            );
        }
        else {
            $sku    = $vvariant->sku;
        }

        # set SKU in message
        $data->{sku} = $sku;
    }

    # if the caller hasn't told us who they are, grab it from the config
    # - I expect this to be the default behaviour; no need for people to worry
    # themselves about this unless they're doing something evil
    if (not defined $data->{website_stock_location}) {
        $data->{website_stock_location}
            = config_var('DistributionCentre', 'name');
    }

    # check for leading '+' in 'quantity_change'
    if ( $data->{quantity_change} =~ m/\+/ ) {
        $data->{quantity_change}    =~ s/\+//g;
    }

    return ($header, $data);
}


1;
__END__
