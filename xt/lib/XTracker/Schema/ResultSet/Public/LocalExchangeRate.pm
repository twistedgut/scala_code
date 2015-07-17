package XTracker::Schema::ResultSet::Public::LocalExchangeRate;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub get_rates {

    my $resultset = shift;

    my $exchange_rates = $resultset->search(
        undef,
        {
            '+select'   => [
                { to_char => 'start_date, \'DD Mon YYYY, HH24:MI\'' },
            ],
            '+as'       => [
                'time',
            ],
            order_by    => [
                'country.country',
                'me.start_date DESC',
            ],
            prefetch    => [
                'country',
            ],
        },
    );

    return $exchange_rates;
}

sub set_new_rate {

    my ( $resultset, $country_id, $rate ) = @_;

    my $schema = $resultset->result_source->schema;

    my $timestamp = 'current_timestamp(0)';

    my $tx_ref = sub {
        $resultset->search(
            {
                country_id          => $country_id,
                end_date            => undef,
            },
            {},
        )->update(
            {
                end_date            => \$timestamp,
            },
        );

        $resultset->create(
            {
                country_id          => $country_id,
                rate                => $rate,
            }
        );
    };

    eval {
        $schema->txn_do($tx_ref);
    };

    if ($@) {
        require XTracker::Error;
        XTracker::Error::xt_warn( "There was an error setting the new rate: $@" );
        return 0;
    }

    return 1;

}

1;
