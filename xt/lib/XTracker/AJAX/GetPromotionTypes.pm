package XTracker::AJAX::GetPromotionTypes;
use NAP::policy "tt";

use XTracker::Handler;
use JSON;

use Plack::App::FakeApache1::Constants qw( :common );

use XTracker::Constants::FromDB qw(
    :promotion_class
);

sub handler {
    my $handler  = XTracker::Handler->new(shift);

    my $response = { data => [] };

    if ( my $channel_id = $handler->{param_of}{channel_id} ) {

        my $schema = $handler->{schema};

        my $promotion_types = $schema->resultset('Public::PromotionType')->search(
            {
                channel_id         => $channel_id,
                promotion_class_id => $PROMOTION_CLASS__IN_THE_BOX,
            },
            {
                order_by => [ 'channel_id', 'name' ]
            },
        );

        if ( defined $promotion_types && $promotion_types->count > 0 ) {
        # If we got some data, return the rows.

            while ( my $promotion_type = $promotion_types->next ) {

                push @{ $response->{'data'} }, { $promotion_type->get_columns };

            }

            $response->{result} = 'OK';

        } else {

            $response->{result} = 'NO_RESULTS';

        }

    } else {

        $response->{result} = 'ERROR';
        $response->{error}  = 'Missing parameter - channel_id';

    }

    $handler->{request}->print( encode_json( $response ) );

    return OK;

}

1;

=head1 NAME

XTracker::AJAX::GetPromotionTypes

=head1 DESCRIPTION

AJAX method to fetch rows from the public.promotion_type table.

At present it only returns rows with a promotion class of 'In The Box', as this is
the only place where it's used. It also only returns rows for a specific channel.

=cut
