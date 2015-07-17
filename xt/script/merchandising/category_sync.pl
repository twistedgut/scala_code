#!/opt/xt/xt-perl//bin/perl

# MERCH-1268
# This script will update the reporting categories so that they match Fulcrum
# It will also update all currently live and visible product so that their classification, product_type and
# sub_type match fulcrun
#
# Please note.
# This script does not try to keep the ids in sync (as it is not needed)
# No update is done on the product_classification_structure table as this does not appear
# to be used
#

use warnings;
use strict;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw/get_database_handle/;

use feature qw/say/;

my $fulcrum_dbh = get_database_handle({ name => 'Fulcrum' });
my $xtracker_schema = get_database_handle({ name => 'xtracker_schema' });

# update xtracker categories to match fulcrum
update_category_level({ level => 1, resultset => 'Public::Classification', column => 'classification' });
update_category_level({ level => 2, resultset => 'Public::ProductType', column => 'product_type' });
update_category_level({ level => 3, resultset => 'Public::SubType', column => 'sub_type' });

update_product_category();


sub update_category_level {
    my $params = shift;
    my $sql =
        'SELECT name '.
        'FROM reporting WHERE level = ? '.
        'ORDER BY id';

    my $category_sth = $fulcrum_dbh->prepare($sql);
    $category_sth->execute($params->{level});

    while (my $category = $category_sth->fetchrow_hashref) {
        say "updating level $params->{level} category $category->{name}";
        $xtracker_schema->resultset($params->{resultset})->update_or_create({
           $params->{column} => $category->{name}
        });
    }
}

sub update_product_category {

    my @channel_ids = $xtracker_schema->resultset('Public::Channel')->get_column('id')->all;

    my $sql =
        'SELECT pc.product_id, c.name classification, pt.name product_type, st.name sub_type '.
        'FROM product.product_channel pc, product p, reporting c, reporting pt, reporting st '.
        'WHERE pc.channel_id in ('. join(',',@channel_ids) . ')' .
        'AND pc.live = true '.
        'AND pc.visible = true '.
        'AND p.id = pc.product_id '.
        'AND c.id = p.classification_id '.
        'AND pt.id = p.product_type_id '.
        'AND st.id = p.sub_type_id '.
        'ORDER BY pc.product_id';

    my $product_sth = $fulcrum_dbh->prepare($sql);
    $product_sth->execute();

    while (my $product = $product_sth->fetchrow_hashref) {
        say "updating product $product->{product_id} category $product->{classification} / $product->{product_type} / $product->{sub_type}";
        update_product($product);
    }

}

sub update_product {
    my $params = shift;

    if (my $product = $xtracker_schema->resultset('Public::Product')->find($params->{product_id})) {

        my $classification = $xtracker_schema->resultset('Public::Classification')->find({
            classification => $params->{classification}
        });
        my $product_type = $xtracker_schema->resultset('Public::ProductType')->find({
            product_type => $params->{product_type}
        });
        my $sub_type = $xtracker_schema->resultset('Public::SubType')->find({
            sub_type => $params->{sub_type}
        });

        $product->update({
            classification_id => $classification->id,
            product_type_id => $product_type->id,
            sub_type_id => $sub_type->id
        });
    }

}
