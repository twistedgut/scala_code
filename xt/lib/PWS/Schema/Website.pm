package PWS::Schema::Website;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Data::Dump qw(pp);

use base 'DBIx::Class';
__PACKAGE__->load_components('PK::Auto', 'Core');
__PACKAGE__->table('website');

__PACKAGE__->add_columns(
    id => {
        data_type       => 'integer',
    },
    name => {
    },
);

__PACKAGE__->set_primary_key('id');
#__PACKAGE__->resultset_class('PWS::ResultSet::Website');

__PACKAGE__->has_many(
    detail_websites => 'PWS::Schema::DetailWebsites',
    'website_id'
);

__PACKAGE__->many_to_many(
    details => 'detail_websites' => 'detail'
);

1;

# XXX do we use this at all?
