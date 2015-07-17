package XTracker::Schema::ResultSet::Public::StockRecode;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head2 stock_recode_data_for_ids

Returns a hashref of stock recode data keyed on id, given an arrayref of
stock_recode ids.

Designed specifically to fetch the data required for the putaway admin
handler (XTracker::Stock::GoodsIn::PutawayAdmin), which passes in the recode
ids linked to active putaway_prep_inventory rows.

=cut

sub stock_recode_data_for_ids {
    my ($self, $stock_recode_ids) = @_;

    my $stock_recode_rs = $self
        ->search({
            'id' => { IN => $stock_recode_ids }
        });
    $stock_recode_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

    my $stock_recodes;
    foreach my $recode ($stock_recode_rs->all) {
        $stock_recodes->{$recode->{id}} = $recode;
        $stock_recodes->{$recode->{id}}->{'quantity'} = $recode->{'quantity'};
    }

    return $stock_recodes;
}

=head2 putaway_prep_process_groups

Returns data to be displayed in putaway prep list (hashref in similar
format to lib::XTracker::Database::StockProcess->get[_*]_process_group
methods - keyed on channel name then pgid).

=cut

sub putaway_prep_process_groups {
    my $self = shift;

    my $dbh = $self->result_source->storage->dbh;

    my $query = "
    SELECT
        r.id AS group_id,
        r.quantity,
        'Main' AS type,
        ch.name AS sales_channel,
        p.id AS product_id,
        v.product_id || '-' || sku_padding(v.size_id) AS sku,
        d.designer
    FROM
        stock_recode r
        JOIN variant v ON r.variant_id=v.id
        JOIN product p ON v.product_id=p.id
        JOIN channel ch ON get_product_channel_id(p.id) = ch.id
        JOIN designer d ON p.designer_id=d.id
    WHERE
        r.complete=false
    ORDER BY r.id
    ";
    my $sth = $dbh->prepare($query);
    $sth->execute();

    my $group_rows_by_channel;

    while ( my $row = $sth->fetchrow_hashref ) {
        $group_rows_by_channel->{ $row->{sales_channel} }{ $row->{group_id} } = $row;
    }

    return $group_rows_by_channel;

}

1;
