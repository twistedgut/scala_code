package PWS::Schema::DetailWebsites;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Data::Dump qw(pp);

use base 'DBIx::Class';
__PACKAGE__->load_components('PK::Auto', 'Core');
__PACKAGE__->table('detail_websites');

__PACKAGE__->add_columns(
    'id' => {
        data_type       => 'integer',
    },
    event_id => {
    },
    website_id => {
    },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to(
    detail => 'PWS::Schema::Detail',
    { 'foreign.id' => 'self.event_id' }
);
__PACKAGE__->belongs_to(
    website => 'PWS::Schema::Website',
    { 'foreign.id' => 'self.website_id' }
);

1;

# XXX do we use this at all?
