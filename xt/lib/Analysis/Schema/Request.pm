package Analysis::Schema::Request;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use DateTime::Format::Strptime;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);

__PACKAGE__->table('request');

__PACKAGE__->add_columns(
    qw/
        id
        timestamp
        the_request
        query_count
        object
    /
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->has_many(
    queries => 'Analysis::Schema::Query',
    { 'foreign.request_id' => 'self.id' }
);

foreach my $datecol (qw/timestamp/) {
    __PACKAGE__->inflate_column($datecol, {
        inflate => sub {
            my $Strp = DateTime::Format::Strptime->new(
                pattern     => '%FT%T',
                locale      => 'en_GB',
                time_zone   => 'Europe/London',
            );

            $Strp->parse_datetime(shift);
        },
        # XXX - needs fixing
        deflate => sub {
        },
    });
}


1;
