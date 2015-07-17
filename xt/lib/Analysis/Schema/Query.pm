package Analysis::Schema::Query;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);

__PACKAGE__->table('query');

__PACKAGE__->add_columns(
    qw/
        id
        request_id
        time_elapsed
        start_time
        end_time
        sql
        sql_params
    /
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(
    request => 'Analysis::Schema::Request',
    { 'foreign.id' => 'self.request_id' },
 #   { 'self.request_id' => 'foreign.id' },
);

foreach my $datecol (qw/start_time end_time/) {
    __PACKAGE__->inflate_column($datecol, {
        inflate => sub {
            return DateTime->from_epoch(epoch => shift);
        },
        # XXX - needs fixing
        deflate => sub {
        },
    });
}

1;
