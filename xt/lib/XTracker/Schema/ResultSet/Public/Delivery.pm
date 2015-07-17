package XTracker::Schema::ResultSet::Public::Delivery;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';
use XTracker::Constants::FromDB qw/
    :delivery_type
    :delivery_status
    :delivery_action
/;

use Carp;
use DateTime;

use XTracker::Constants::FromDB qw( :delivery_status );
use XTracker::Database::Delivery qw( get_delivery_channel );

sub get_held_deliveries {
    my ( $self ) = @_;

    my $dbh = $self->result_source->storage->dbh();

    my $deliveries = $self->search(
        { on_hold => 1, },
        { prefetch => [
            { link_delivery__stock_order => 'stock_order', },
            {
              'delivery_notes' => {
                creator => 'department',
              },
            },
            'status',
          ],
        },
    );

    my %data;
    while ( my $row = $deliveries->next ) {
      my $channel = get_delivery_channel( $dbh, $row->id );
      push @{$data{$channel}}, $row;
    }

    return \%data;
}

=head2 get_delivery_order

This function returns an array with the deliveries sorted by the date they
were held

=cut

sub get_delivery_order {
    my ( $self ) = @_;

    my $delivery_rs = $self->search(
        { 'me.on_hold' => 1, },
        { join => 'delivery_notes',
          select => [ 'me.id', ],
          group_by => 'me.id',
          order_by => \'min(delivery_notes.created)',
        },
    );
    return [ $delivery_rs->get_column('id')->all ];
}

=head2 get_deliveries_by_status

Returns a resultset of deliveries with a given status. This is currently
unused.

=cut

sub get_deliveries_by_status {
    my ( $self, $status_id ) = @_;
    return $self->search({
        'me.status_id' => $status_id,
        'me.cancel'    => 0,
    });
}

=head2 get_deliveries_by_channel

Returns a resultset of deliveries on a given channel. This is currently
unused.

=cut

sub get_deliveries_by_channel {
    my ( $self, $channel_id ) = @_;
    croak 'Missing $channel_id' unless $channel_id;
    return $self->search(
        { 'super_purchase_order.channel_id' => $channel_id },
        { prefetch => [
            { link_delivery__stock_order => {
                stock_order => [
                    { 'super_purchase_order' => [ 'public_purchase_order' ] },
                    { public_product => [ 'colour', 'product_channel', 'designer' ] },
                ],
            },},
        ],}
    );
}

=head2 for_item_count

Return a hashref of delivery information for Item Count. A wrapper around
get_delivery_data_by_status.

=cut

sub for_item_count {
    return $_[0]->get_delivery_data_by_status( $DELIVERY_STATUS__NEW );
}

=head2 for_qc

Return a hashref of delivery information for Quality Control. A wrapper around
get_delivery_data_by_status.

=cut

sub for_qc {
    return $_[0]->get_delivery_data_by_status( $DELIVERY_STATUS__COUNTED, $DELIVERY_ACTION__COUNT );
}


=head2 get_delivery_data_by_status

Returns a hashref of information that some goods in process (Item Count and
Quality Control) at the moment display. If someone wants to DBIC this they're
welcome to.

=cut

sub get_delivery_data_by_status {
    my ( $self, $status_id, $action_id ) = @_;

    my $dbh = $self->result_source->storage->dbh();

    my %log_delivery_sql = map { $_ => '' } qw{ column join join_cond group_by};

    if ( $action_id ) {
        $log_delivery_sql{column}       = q{TO_CHAR(ld.date, 'DD-MM-YYYY') AS count_date,};
        $log_delivery_sql{join}         = q{LEFT JOIN log_delivery ld ON ( del.id = ld.delivery_id )};
        $log_delivery_sql{join_cond}    = q{AND ld.delivery_action_id = ?};
        $log_delivery_sql{group_by}     = q{ld.date,};
    }

    my $qry = sprintf(qq{
SELECT del.id,
       del.on_hold,
       to_char( del.date, 'DD-MM-YYYY' ) as date,
       SUM( di.quantity ) AS quantity,
       SUM( di.packing_slip ) AS packing_slip,
       ds.status,
       del.type_id,
       ch.name AS sales_channel,

-- Product fields
       p.id AS product_id,
       pc.live,
       CASE
            WHEN d.designer IS NULL AND voucher.id IS NOT NULL THEN 'Gift Voucher'
            ELSE d.designer
       END AS designer,
       c.colour,
       CASE
            WHEN pc.upload_date IS NOT NULL THEN
                TO_CHAR( pc.upload_date, 'DD-MM-YYYY' )
            ELSE
                TO_CHAR( voucher.created, 'DD-MM-YYYY' )
            END AS upload_date,
       CASE
           WHEN pc.upload_date IS NOT NULL AND pc.upload_date < current_timestamp - interval '3 days'
           THEN 1
           ELSE 0
        END AS priority,

-- Log delivery fields
        %s

-- Voucher fields
        voucher.id AS voucher_id


FROM delivery del
JOIN delivery_item di                            ON ( del.id                        = di.delivery_id )
JOIN delivery_status ds                          ON ( del.status_id                 = ds.id )
JOIN link_delivery_item__stock_order_item di_soi ON ( di.id                         = di_soi.delivery_item_id )
JOIN stock_order_item soi                        ON ( di_soi.stock_order_item_id    = soi.id )
JOIN stock_order so                              ON ( soi.stock_order_id            = so.id )
JOIN super_purchase_order po                     ON ( so.purchase_order_id          = po.id )
JOIN channel ch                                  ON ( po.channel_id                 = ch.id )

-- Product joins
LEFT JOIN product p                              ON ( so.product_id                 = p.id )
LEFT JOIN product_channel pc                     ON ( ch.id = pc.channel_id AND p.id = pc.product_id )
LEFT JOIN designer d                             ON ( p.designer_id                 = d.id )
LEFT JOIN colour c                               ON ( p.colour_id                   = c.id )

-- Voucher joins
LEFT JOIN voucher.product voucher                ON ( so.voucher_product_id = voucher.id AND ch.id = voucher.channel_id )

-- Log delivery joins
%s

WHERE del.cancel = 'f'
  AND del.status_id = ?
  %s
GROUP BY del.id,
         del.on_hold,
         del.date,
         ds.status,
         del.type_id,
         ch.name,

-- Product group bys
         p.id,
         pc.live,
         d.designer,
         c.colour,
         pc.upload_date,

-- Log delivery group bys
         %s

-- Voucher group bys
         voucher.id,
         voucher.created
}, map { $log_delivery_sql{$_} } qw{ column join join_cond group_by});

    my $sth = $dbh->prepare($qry);

    if ( $action_id ) {
        $sth->execute( $status_id, $action_id );
    } else {
        $sth->execute( $status_id );
    }

    my %data;
    while ( my $row = $sth->fetchrow_hashref ) {
        $data{ delete $row->{sales_channel} }{ delete $row->{id} } = $row;
    }

    return \%data;
}

=head2 recent_deliveries

Get all the recent deliveries within the last X weeks

=cut

sub recent_deliveries {
    my ($self, $weeks) = @_;

    my $rs = $self->search(
        { 'me.date' => { '>=' => \"NOW() - INTERVAL '$weeks weeks'" },
          'me.type_id' => $DELIVERY_TYPE__STOCK_ORDER
        },
        { prefetch => [
            'status',
            'type',
            { delivery_items => {
                link_delivery_item__stock_order_items => {
                  stock_order_item => [
                    { stock_order => [
                        { purchase_order => 'channel' },
                        { public_product => 'designer' },
                      ],
                    }
                  ]
                }
              }
            }
          ]
        }
    );

    return $rs;
}

sub order_by_oldest {
    my ($self) = @_;

    my $me = $self->current_source_alias;

    return $self->search_rs({}, { order_by => { -asc => "$me.date" } } );
}

1;
