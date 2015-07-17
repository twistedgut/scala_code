package PWS::Schema::Product;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Data::Dump qw(pp);
use DateTime::Format::MySQL;

use base 'DBIx::Class';
__PACKAGE__->load_components('PK::Auto', 'Core');
__PACKAGE__->table('product');

__PACKAGE__->add_columns(
    sku                     => {},
    size                    => {},

    prd_status              => {},
    search_prod_id          => {},
    standardised_size_id    => {},
);

__PACKAGE__->set_primary_key('sku');
#__PACKAGE__->resultset_class('PWS::ResultSet::Product');



# seasons many-to-many

#
## Custom Record-Level Methods
#



1;
