package XTracker::AJAX::ReservationOperatorLog;
use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Database qw( get_database_handle );
use XTracker::XTemplate;
use JSON;

sub handler {
    my $r = shift;

    my $request = $r;
    my $schema  = get_database_handle( { name => 'xtracker_schema' } );
    my $result  = {};

    my $log = $schema->resultset('Public::ReservationOperatorLog')->search(
        {
            reservation_id => $request->param('reservation_id'),
        },
        {
            order_by => { '-asc' => 'created_timestamp' },
        },
    );

    if ( defined $log && $log->count > 0 ) {

        $result = {
            result  => 'OK',
            data    => []
        };

        while ( my $row = $log->next ) {

            push @{ $result->{'data'} }, {
                id                  => $row->id,
                created_timestamp   => $row->created_timestamp->ymd . ' ' . $row->created_timestamp->hms,
                reservation_id      => $row->reservation_id,
                operator            => $row->operator->name,
                from_operator       => $row->from_operator->name,
                to_operator         => $row->to_operator->name,
                reservation_status  => $row->reservation_status->status,
            };

        }

    } else {

        $result = {
            result  => 'FAIL',
        };

    }

    $r->content_type( 'text/plain' );
    $r->print( encode_json( $result ) );

    return OK;
}

1;
