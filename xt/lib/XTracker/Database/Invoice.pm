package XTracker::Database::Invoice;

use strict;
use warnings;

use List::Util qw( sum );
use Perl6::Export::Attrs;
use XTracker::Comms::FCP qw( create_website_store_credit update_website_store_credit );
use XTracker::Constants::FromDB qw( :renumeration_class :renumeration_type :pre_order_refund_status);
use XTracker::Constants::PreOrderRefund qw( :pre_order_refund_class :pre_order_refund_type );
use XTracker::Database  qw( get_schema_using_dbh );
use XTracker::Database::Finance qw( get_credit_hold_check_priority);
use XTracker::DBEncode qw( decode_db );


use vars qw($r);

### Subroutine : generate_invoice_number        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub generate_invoice_number :Export(:DEFAULT) {

    my ( $dbh ) = @_;

    my $invoice_nr = "";

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst )
        = localtime(time);
    $mon++;
    $year = $year + 1900;

    if ( $mday < 10 ) { $mday = "0" . $mday; }
    if ( $mon < 10 )  { $mon  = "0" . $mon; }

    $year = substr( $year, 2, 2 );

    my $qry = "SELECT nextval('invoice_nr')";
    my $sth = $dbh->prepare($qry);
    $sth->execute();
    my $row = $sth->fetchrow_arrayref();

    $invoice_nr = $year . $mon . $mday . "-" . $row->[0];

    return $invoice_nr;

}

### Subroutine : create_invoice                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_invoice :Export(:DEFAULT) {

    my (  $dbh,    $shipment_id, $invoice_nr, $type_id,
        $class_id, $status, $shipping, $misc_refund, $alt_customer_num, $gift_credit, $store_credit, $currency_id, $gift_voucher
        )
        = @_;
    my ($qry, $sth);

    $gift_voucher   ||= 0;

    # note that renumeration_reason_id is not included for some reason

    $qry = "INSERT
              INTO renumeration (
                     id,
                     shipment_id,
                     invoice_nr,
                     renumeration_type_id,
                     renumeration_class_id,
                     renumeration_status_id,
                     shipping,
                     misc_refund,
                     alt_customer_nr,
                     gift_credit,
                     store_credit,
                     currency_id,
                     sent_to_psp,
                     gift_voucher
                   )
            VALUES (
                     DEFAULT,
                     ?,
                     ?,
                     ?,
                     ?,
                     ?,
                     ?,
                     ?,
                     ?,
                     ?,
                     ?,
                     ?,
                     DEFAULT,
                     ?
    )";
    $sth = $dbh->prepare($qry);
    $sth->execute(
                  $shipment_id,
                  $invoice_nr,
                  $type_id,
                  $class_id,
                  $status,
                  $shipping,
                  $misc_refund,
                  $alt_customer_num,
                  $gift_credit,
                  $store_credit,
                  $currency_id,
                  $gift_voucher
    );

    $qry
        = "SELECT id FROM renumeration WHERE shipment_id = ? AND invoice_nr = ? ORDER BY id DESC LIMIT 1";
    $sth = $dbh->prepare($qry);
    $sth->execute( $shipment_id, $invoice_nr );

    my $row = $sth->fetchrow_arrayref;

    my $invoice_id = $row->[0];

    return $invoice_id;
}

### Subroutine : create_invoice_item            ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_invoice_item :Export(:DEFAULT) {

    my ( $dbh, $inv_id, $item_id, $price, $tax, $duty ) = @_;

    my $qry = "INSERT
                 INTO renumeration_item (
                        id,
                        renumeration_id,
                        shipment_item_id,
                        unit_price,
                        tax,
                        duty
                      )
               VALUES (
                        DEFAULT,
                        ?,
                        ?,
                        ?,
                        ?,
                        ?
               )";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $inv_id, $item_id, $price, $tax, $duty );

}

### Subroutine : get_invoice_value               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_invoice_value :Export(:DEFAULT) {

    my ( $dbh, $invoice_id ) = @_;

    my $value = 0;

    # get invoice level values
    my $qry = "SELECT shipping, misc_refund, gift_credit, store_credit, gift_voucher
                FROM renumeration
                WHERE id = ?
    ";

    my $sth = $dbh->prepare($qry);
    $sth->execute($invoice_id);

    while ( my $row = $sth->fetchrow_hashref()){
        $value += sum map { sprintf "%.2f", $_ }
                    grep { defined } map { $row->{$_} }
                        qw(shipping misc_refund gift_credit store_credit gift_voucher)
    }

    # get item level values
    $qry = "SELECT unit_price, tax, duty
                FROM renumeration_item
                WHERE renumeration_id = ?
    ";

    $sth = $dbh->prepare($qry);
    $sth->execute($invoice_id);

    while ( my $row = $sth->fetchrow_hashref()){
        $value += sprintf( "%.2f", $row->{unit_price}) + sprintf( "%.2f", $row->{tax}) + sprintf( "%.2f", $row->{duty});
    }

    return sprintf( "%.2f", $value);

}


### Subroutine : get_invoice_info               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_invoice_info :Export(:DEFAULT) {

    my ( $dbh, $invoice_id ) = @_;

    my $qry
        = "SELECT r.id, r.invoice_nr, r.shipment_id, r.renumeration_type_id, r.renumeration_class_id, r.renumeration_status_id, r.shipping, r.misc_refund, r.gift_credit, r.store_credit, r.alt_customer_nr, r.currency_id, c.currency, rt.type, rc.class, rs.status, o.id as orders_id, o.order_nr, a.first_name, a.last_name, ch.name as sales_channel, r.sent_to_psp, r.gift_voucher
                FROM renumeration r, currency c, shipment s, renumeration_type rt, renumeration_class rc, renumeration_status rs, link_orders__shipment los, orders o, order_address a, channel ch
                WHERE r.id = ?
                AND r.currency_id = c.id
                AND r.shipment_id = s.id
                AND s.id = los.shipment_id
                AND los.orders_id = o.id
                AND o.invoice_address_id = a.id
                AND o.channel_id = ch.id
                AND r.renumeration_type_id = rt.id
                AND r.renumeration_class_id = rc.id
                AND r.renumeration_status_id = rs.id
    ";

    my $sth = $dbh->prepare($qry);
    $sth->execute($invoice_id);

    my $renum = $sth->fetchrow_hashref();
    $renum->{$_} = decode_db( $renum->{$_} ) for (qw(
        first_name
        last_name
    ));

    return $renum;

}

### Subroutine : get_invoice_item_info          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_invoice_item_info :Export(:DEFAULT) {

    my ( $dbh, $invoice_id ) = @_;

    my %info = ();

    my $qry
        = "SELECT ri.id, ri.renumeration_id, ri.shipment_item_id, ri.unit_price, ri.tax, ri.duty, v.id as variant, v.size_id, v.legacy_sku, v.product_id || '-' || sku_padding(v.size_id) as sku, v.product_id, s.size, d.designer, pa.name
                FROM renumeration_item ri, shipment_item si, variant v, size s, product p, designer d, product_attribute pa
                WHERE ri.renumeration_id = ?
                AND ri.shipment_item_id = si.id
                AND si.variant_id = v.id
                AND v.size_id = s.id
                AND v.product_id = p.id
                AND p.designer_id = d.id
                AND v.product_id = pa.product_id
    ";

    my $sth = $dbh->prepare($qry);
    $sth->execute($invoice_id);

    while ( my $renum = $sth->fetchrow_hashref() ) {
        $info{ $$renum{id} } = $renum;
    }

    # get voucher products second
    my $schema  = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    my $vouchers= $schema->resultset('Public::RenumerationItem')->search(
                                                            {
                                                                renumeration_id => $invoice_id,
                                                                'shipment_item.voucher_variant_id' => { 'IS NOT' => undef }
                                                            },
                                                            {
                                                                prefetch => [ { shipment_item => 'voucher_variant' } ],
                                                            } );
    while ( my $item = $vouchers->next ) {
        $info{ $item->id }  = {
            id                  => $item->id,
            renumeration_id     => $item->renumeration_id,
            shipment_item_id    => $item->shipment_item_id,
            unit_price          => $item->unit_price,
            tax                 => $item->tax,
            duty                => $item->duty,
            variant             => $item->shipment_item->voucher_variant_id,
            size_id             => $item->shipment_item->voucher_variant->size_id,
            legacy_sku          => '',
            sku                 => $item->shipment_item->voucher_variant->sku,
            product_id          => $item->shipment_item->voucher_variant->voucher_product_id,
            size                => $item->shipment_item->voucher_variant->size_id,
            designer            => $item->shipment_item->voucher_variant->product->designer,
            name                => $item->shipment_item->voucher_variant->product->name,
            voucher             => 1,
            is_physical         => $item->shipment_item->voucher_variant->product->is_physical,
        }
    }

    return \%info;

}

### Subroutine : get_invoice_log_info           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_invoice_log_info :Export(:DEFAULT) {

    my ( $dbh, $invoice_id ) = @_;

    my %info = ();

    ### ORDER INFO
    ###############
    my $qry
        = "SELECT rsl.id, rs.status, o.name, to_char(rsl.date, 'DD-MM-YYYY  HH24:MI') as date
                FROM renumeration_status_log rsl, renumeration_status rs, operator o
                WHERE rsl.renumeration_id = ?
                AND rsl.renumeration_status_id = rs.id
                AND rsl.operator_id = o.id
    ";

    my $sth = $dbh->prepare($qry);
    $sth->execute($invoice_id);

    while ( my $renum = $sth->fetchrow_hashref() ) {
        $info{ $$renum{id} } = $renum;
    }

    return \%info;

}


### Subroutine : get_invoice_change_log           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_invoice_change_log :Export(:DEFAULT) {

    my ( $dbh, $invoice_id ) = @_;

    my %log_data = ();

    ### ORDER INFO
    ###############
    my $qry
        = "SELECT rcl.id, rcl.pre_value, rcl.post_value, o.name, to_char(rcl.date, 'DD-MM-YYYY  HH24:MI') as date
                FROM renumeration_change_log rcl, operator o
                WHERE rcl.renumeration_id = ?
                AND rcl.operator_id = o.id
    ";

    my $sth = $dbh->prepare($qry);
    $sth->execute($invoice_id);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $log_data{ $row->{id} } = $row;
    }

    return \%log_data;

}

### Subroutine : get_invoice_date               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_invoice_date :Export(:DEFAULT) {

    my ( $dbh, $inv_id ) = @_;

    my $date = "";

    my $qry
        = "SELECT to_char(date, 'DD/MM/YYYY') as date
            FROM renumeration_status_log
            WHERE renumeration_status_id = 5
            AND renumeration_id = ?
            LIMIT 1";

    my $sth = $dbh->prepare($qry);
    $sth->execute($inv_id);

    my $row = $sth->fetchrow_hashref();
    $date = $$row{date};

    return $date;

}

### Subroutine : get_invoice_status             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_invoice_status :Export(:DEFAULT) {

    my ( $dbh ) = @_;

    my %info = ();

    my $qry = "SELECT * FROM renumeration_status";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_arrayref ) {
        $info{ $row->[0] } = $row->[1];
    }

    return \%info;

}

### Subroutine : get_invoice_type               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_invoice_type :Export(:DEFAULT) {

    my ( $dbh ) = @_;

    my %info = ();

    my $qry = "SELECT * FROM renumeration_type";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_arrayref ) {
        $info{ $row->[0] } = $row->[1];
    }

    return \%info;

}

### Subroutine : get_shipment_invoices          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_shipment_invoices :Export(:DEFAULT) {

    my ( $dbh, $shipment_id ) = @_;

    my %renum = ();

    my $qry
        = "SELECT r.id                      AS id,
                  r.invoice_nr              AS invoice_nr,
                  r.renumeration_type_id    AS renumeration_type_id,
                  r.renumeration_class_id   AS renumeration_class_id,
                  r.renumeration_status_id  AS renumeration_status_id,
                  r.shipping                AS shipping,
                  r.misc_refund             AS misc_refund,
                  c.currency                AS currency,
                  rt.type                   AS type,
                  rc.class                  AS class,
                  rs.status                 AS status,
                  ri.unit_price             AS unit_price,
                  ri.tax                    AS tax,
                  ri.duty                   AS duty,
                  r.gift_credit             AS gift_credit,
                  r.store_credit            AS store_credit,
                  r.gift_voucher            AS gift_voucher
             FROM renumeration r
        LEFT JOIN renumeration_item ri ON r.id = ri.renumeration_id,
                  currency c,
                  renumeration_type rt,
                  renumeration_class rc,
                  renumeration_status rs
            WHERE r.shipment_id = ?
              AND r.currency_id = c.id
              AND r.renumeration_type_id = rt.id
              AND r.renumeration_class_id = rc.id
              AND r.renumeration_status_id = rs.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    while ( my $row = $sth->fetchrow_hashref() ) {

        if ( $renum{ $row->{id} }) {
            $renum{ $row->{id} }{total}
                += _d2( $row->{unit_price} + $row->{tax} + $row->{duty} );
        }
        else {

            $renum{ $row->{id} }{ invoice_nr             } = $row->{ invoice_nr             };
            $renum{ $row->{id} }{ renumeration_type_id   } = $row->{ renumeration_type_id   };
            $renum{ $row->{id} }{ renumeration_class_id  } = $row->{ renumeration_class_id  };
            $renum{ $row->{id} }{ renumeration_status_id } = $row->{ renumeration_status_id };
            $renum{ $row->{id} }{ currency               } = $row->{ currency               };
            $renum{ $row->{id} }{ type                   } = $row->{ type                   };
            $renum{ $row->{id} }{ class                  } = $row->{ class                  };
            $renum{ $row->{id} }{ status                 } = $row->{ status                 };
            $renum{ $row->{id} }{ shipping               } = $row->{ shipping               };
            $renum{ $row->{id} }{ misc_refund            } = $row->{ misc_refund            };
            $renum{ $row->{id} }{ gift_voucher           } = $row->{ gift_voucher           };

            $renum{ $row->{id} }{total} = _d2(
                ($row->{ shipping     } || 0)
              + ($row->{ misc_refund  } || 0)
              + ($row->{ gift_credit  } || 0)
              + ($row->{ store_credit } || 0)
              + ($row->{ gift_voucher } || 0)
              + ($row->{ unit_price   } || 0)
              + ($row->{ tax          } || 0)
              + ($row->{ duty         } || 0)
            );

        }

    }

    return \%renum;

}

### Subroutine : get_shipment_sales_invoice     ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

# In DBIC superseded by XTracker::Schema::Result::Public::Shipment::get_sales_invoice
sub get_shipment_sales_invoice :Export(:DEFAULT) {

    my ( $dbh, $shipment_id ) = @_;

    my $qry = "SELECT id FROM renumeration WHERE shipment_id = ? AND renumeration_class_id = 1 ORDER BY id ASC LIMIT 1";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my $row = $sth->fetchrow_arrayref();

    return $row->[0];

}

### Subroutine : get_invoice_return             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_invoice_return :Export(:DEFAULT) {

    my ( $dbh, $renum_id ) = @_;

    my $return_id = 0;

    my $qry
        = "SELECT return_id FROM link_return_renumeration WHERE renumeration_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($renum_id);

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $return_id = $row->[0];
    }

    return $return_id;

}


### Subroutine : get_invoice_country_info       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_invoice_country_info :Export(:DEFAULT) {

    my ( $dbh, $country ) = @_;

    my $qry
        = "SELECT ctr.* FROM country_tax_rate ctr, country c WHERE LOWER(c.country) = LOWER(?) AND c.id = ctr.country_id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($country);

    my $renum = $sth->fetchrow_hashref();

    return $renum;

}

### Subroutine : update_invoice_status          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub update_invoice_status :Export(:DEFAULT) {

    my ( $dbh, $invoice_id, $status ) = @_;

    my $qry
        = "UPDATE renumeration SET renumeration_status_id = ? WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $status, $invoice_id );

}


### Subroutine : update_sent_to_psp          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #
sub update_sent_to_psp :Export(:DEFAULT) {

    my ( $dbh, $invoice_id, $is_sent_to_psp ) = @_;

    my $qry
        = "UPDATE renumeration SET sent_to_psp = ? WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $is_sent_to_psp, $invoice_id );

}



### Subroutine : update_invoice_number          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub update_invoice_number :Export(:DEFAULT) {

    my ( $dbh, $invoice_id, $invoice_number ) = @_;

    my $qry
        = "UPDATE renumeration SET invoice_nr = ? WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $invoice_number, $invoice_id );

}

### Subroutine : log_invoice_status             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub log_invoice_status :Export(:DEFAULT) {

    my ( $dbh, $invoice_id, $status, $operator_id ) = @_;

    my $qry
        = "INSERT INTO renumeration_status_log VALUES (default, ?, ?, ?, current_timestamp)";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $invoice_id, $status, $operator_id );

}

### Subroutine : log_invoice_change               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub log_invoice_change :Export(:DEFAULT) {

    my ( $dbh, $invoice_id, $pre, $post, $operator_id ) = @_;

    my $value = 0;

    # get invoice level values
    my $qry = "INSERT INTO renumeration_change_log (renumeration_id, pre_value, post_value, operator_id) VALUES (?, ?, ?, ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute($invoice_id, $pre, $post, $operator_id);

    return;

}

### Subroutine : edit_invoice                   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub edit_invoice :Export(:DEFAULT) {

    my ( $dbh, $invoice_id, $type_id, $status_id, $shipping, $misc_refund, $gift_credit, $store_credit, $alt_customer )
        = @_;

    $shipping       ||= 0;
    $misc_refund    ||= 0;
    $gift_credit    ||= 0;
    $store_credit   ||= 0;

    my $qry
        = "UPDATE renumeration SET renumeration_type_id = ?, renumeration_status_id = ?, shipping = ?, misc_refund = ?, gift_credit = ?, store_credit = ?, alt_customer_nr = ? WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $type_id, $status_id, $shipping, $misc_refund, $gift_credit, $store_credit, $alt_customer,
        $invoice_id );

}

### Subroutine : edit_invoice_item             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub edit_invoice_item :Export(:DEFAULT) {

    my ( $dbh, $item_id, $unit_price, $tax, $duty ) = @_;

    my $qry = "UPDATE renumeration_item SET unit_price = ?, tax = ?, duty = ? WHERE id = ?";
    my $sth = $dbh->prepare($qry);

    $sth->execute(
            $unit_price,
            $tax,
            $duty,
            $item_id
    );
}

### Subroutine : get_active_invoices            ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_active_invoices :Export(:DEFAULT) {

    my ($schema)    = @_;
    my $dbh         = $schema->storage->dbh;


    my %renum = ();

    # get the High Priority Customer Classes used
    # in determining the priority of each row
    my $hp_customer_classes = $schema->resultset('Public::CustomerClass')->get_finance_high_priority_classes;


    # sub qry to check if AWB's were used for return
    my $sub_qry = "SELECT return_airway_bill FROM return_item WHERE return_id IN (SELECT return_id FROM link_return_renumeration WHERE renumeration_id = ?)";
    my $sub_sth = $dbh->prepare($sub_qry);

    # get list of invoices which are awaiting action
    my $qry = qq{ SELECT r.id, r.shipment_id, r.renumeration_type_id,
                         r.renumeration_class_id, r.renumeration_status_id, r.shipping,
                         r.misc_refund, r.gift_credit, r.store_credit, c.currency, ri.id as
                         ren_item_id, ri.unit_price, ri.tax, ri.duty, o.id as orders_id,
                         o.order_nr, ch.name as sales_channel, a.first_name, a.last_name,
                         age(date_trunc('day',rsl.date)) as renum_age, rsl.date, rs.status,
                         op.fulfilled, r.sent_to_psp, r.gift_voucher,
                         s.shipment_type_id,
                         cust.category_id AS customer_category_id,
                         ccat.category AS customer_category,
                         ccat.customer_class_id,
                         cclass.class AS customer_class,
                         op.id AS payment_id
                  FROM renumeration r
                         LEFT  JOIN renumeration_item ri ON r.id = ri.renumeration_id
                         LEFT  JOIN renumeration_status_log rsl ON r.id = rsl.renumeration_id
                  AND rsl.renumeration_status_id = 3
                         INNER JOIN currency c ON r.currency_id = c.id
                         INNER JOIN shipment s ON r.shipment_id = s.id
                         INNER JOIN link_orders__shipment los ON s.id = los.shipment_id
                         INNER JOIN orders o ON los.orders_id = o.id
                         LEFT  JOIN orders.payment op ON o.id = op.orders_id
                         JOIN customer cust ON cust.id = o.customer_id
                         JOIN customer_category ccat ON ccat.id = cust.category_id
                         JOIN customer_class cclass ON cclass.id = ccat.customer_class_id
                         INNER JOIN channel ch ON o.channel_id = ch.id
                         INNER JOIN order_address a ON o.invoice_address_id = a.id
                         INNER JOIN renumeration_status rs ON r.renumeration_status_id = rs.id
                         WHERE r.renumeration_status_id in(3,4) };

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %got = ();

    # arguments required by the '_transform_active_invoice_row' function
    my $transform_args  = {
                    hp_customer_classes => $hp_customer_classes,
                    sub_qry_sth         => $sub_sth,
                    got                 => \%got,
                };
    while ( my $row = $sth->fetchrow_hashref() ) {
        $row->{$_} = decode_db( $row->{$_} ) for (qw(
            first_name
            last_name
        ));
        _transform_active_invoice_row( $row, \%renum, $transform_args );
    }

    # PreOrder data
    my $preorder_data =  _preorder_active_invoice($schema);
    foreach my $data_row (@{$preorder_data}) {
        _transform_active_invoice_row( $data_row, \%renum, $transform_args,1 );
    }
    return \%renum;

}

sub _preorder_active_invoice {

    my $schema = shift;

    # PreOrder data
    my $pre_order_refund = $schema->resultset('Public::PreOrderRefund');
    my $preorder_refund_rs =  $pre_order_refund->rs_for_active_invoice_page();

    my @pre_order_data = ();
    while ( my $row= $preorder_refund_rs->next ) {
        my $preorder_row = {};

        $preorder_row->{id} = $row->id;
        $preorder_row->{renumeration_type_id} = $PRE_ORDER_REFUND_TYPE__REFUND;
        $preorder_row->{renumeration_class_id} = $PRE_ORDER_REFUND_CLASS__REFUND;
        $preorder_row->{renumeration_status_id} = $row->pre_order_refund_status_id;
        $preorder_row->{shipping} = '';
        $preorder_row->{misc_refund} = '';
        $preorder_row->{gift_credit} = '';
        $preorder_row->{store_credit} = '';
        $preorder_row->{currency} = $row->pre_order->currency->currency;
        $preorder_row->{ren_item_id} = $row->get_column('pre_order_item_id');
        $preorder_row->{unit_price} = $row->get_column('unit_price');
        $preorder_row->{tax} = $row->get_column('tax');
        $preorder_row->{duty} = $row->get_column('duty');
        $preorder_row->{orders_id} = $row->pre_order_id;
        $preorder_row->{order_nr} = $row->pre_order->pre_order_number;
        $preorder_row->{sales_channel} = $row->pre_order->channel->name;
        $preorder_row->{first_name} = $row->pre_order->customer->first_name;
        $preorder_row->{last_name} = $row->pre_order->customer->last_name;
        $preorder_row->{renum_age} = $row->get_column('log_age');
        $preorder_row->{date} = $row->get_column('log_date');
        $preorder_row->{status} = $row->get_column('status');
        $preorder_row->{fulfilled} = $row->pre_order->pre_order_payment->fulfilled;
        $preorder_row->{sent_to_psp } = $row->sent_to_psp;
        $preorder_row->{gift_voucher} = '';
        $preorder_row->{shipment_type_id} = '0'; # get ignored for pre-order
        $preorder_row->{customer_category_id} = $row->pre_order->customer->category_id;
        $preorder_row->{customer_category} = $row->pre_order->customer->category->category;
        $preorder_row->{customer_class_id} = $row->pre_order->customer->category->customer_class_id;
        $preorder_row->{customer_class} = $row->pre_order->customer->category->customer_class->class;
        $preorder_row->{payment_id} = $row->pre_order->get_payment ? $row->pre_order->get_payment->id : '';

        push( @pre_order_data, $preorder_row );
    }

    return \@pre_order_data;


}
# used to transform the data got from 'get_active_invoices
# so that it can be used on the Active Invoices page
sub _transform_active_invoice_row {
    my ( $row, $data_out, $args, $is_preorder )   = @_;

    if (!$is_preorder ) {
        $is_preorder = 0;
    }
    # get the High Priority Customer Classes used
    # in determining the priority of each row
    my $hp_customer_classes = $args->{hp_customer_classes};

    # sub qry to check if AWB's were used for return
    my $sub_sth     = $args->{sub_qry_sth};

    # used to find out what has already been got
    my $got         = $args->{got};


    # DCS-2237 - stop page from spewing out warnings!
    if (not defined $row->{ren_item_id}) {
        $row->{ren_item_id} = 'undefined_for_' . $row->{id};
    }

    if ( ! $got->{ $row->{id} }->{ $row->{ren_item_id} } ){
        $got->{$row->{id}}{$row->{ren_item_id}} = 1;

        my $sales_channel   = $row->{sales_channel};
        my $class_id        = $row->{renumeration_class_id};
        my $type_id         = $row->{renumeration_type_id};

        my ( $date, $time ) = split( /\s+/, $row->{date}||" " );
        my ( $year,  $month, $day )  = split /-/, $date;
        my ( $hours, $mins,  $secs ) = split /:/, $time;

        my $key_sort = join "", grep { defined } $year, $month, $day, $hours, $mins, $row->{id};
        my $renum_data = $data_out->{ $sales_channel }{ $class_id }{ $type_id }{$key_sort} ||= {};
        if ( %$renum_data ) {
            my $calc = _d2( $row->{unit_price} + $row->{tax} + $row->{duty} );
            if (defined $renum_data->{total}) {
                $renum_data->{total} += $calc;
            } else {
                $renum_data->{total} = $calc;
            }
        }
        else {
            $renum_data->{renum_id}    = $row->{id};
            $renum_data->{shipment_id} = $row->{shipment_id};
            $renum_data->{status_id}   = $row->{renumeration_status_id};
            $renum_data->{currency}    = $row->{currency};

            $row->{unit_price}   ||= 0;
            $row->{tax}          ||= 0;
            $row->{duty}         ||= 0;
            $row->{shipping}     ||= 0;
            $row->{misc_refund}  ||= 0;
            $row->{gift_credit}  ||= 0;
            $row->{store_credit} ||= 0;
            $row->{gift_voucher} ||= 0;
            $renum_data->{total} = _d2(
                $row->{unit_price}  +
                $row->{tax}         +
                $row->{duty}        +
                $row->{shipping}    +
                $row->{misc_refund} +
                $row->{gift_credit} +
                $row->{store_credit} +
                $row->{gift_voucher}
            );

            $renum_data->{is_preorder} = $is_preorder;
            $renum_data->{orders_id}   = $row->{orders_id};
            $renum_data->{order_nr}    = $row->{order_nr};
            $renum_data->{name}        = $row->{first_name} . " " . $row->{last_name};
            $renum_data->{status}      = $row->{status};
            $renum_data->{fulfilled}   = $row->{fulfilled};
            $renum_data->{age}         = $row->{renum_age};
            $renum_data->{other_awb}   = 0;  # default flag for 'other' awb used on returns to 0
            $renum_data->{sent_to_psp} = $row->{sent_to_psp};

            # customer category information->{customer_class_id}    =
            $renum_data->{customer_class_id}    = $row->{customer_class_id};
            $renum_data->{customer_category_id} = $row->{customer_category_id};
            $renum_data->{customer_class}       = $row->{customer_class};
            $renum_data->{customer_category}    = $row->{customer_category};
            $renum_data->{payment_id}           = $row->{payment_id} // '';

            $renum_data->{priority} = get_credit_hold_check_priority( $hp_customer_classes, $row );

            unless (defined $renum_data->{age} && $renum_data->{age} ne "00:00:00" ) {
                $renum_data->{age} = "Today";
            }

            # check if other awb's used for returns on Outnet only
            if ( $sales_channel eq 'theOutnet.com' && $class_id == $RENUMERATION_CLASS__RETURN ) {
                $sub_sth->execute( $row->{id} );
                while ( my $sub_row = $sub_sth->fetchrow_hashref() ) {
                    if ( defined $sub_row->{return_airway_bill} && lc( $sub_row->{return_airway_bill} ) eq 'other' ) {
                        $renum_data->{other_awb} = 1;
                    }
                }
            }
        }
        $data_out->{ $sales_channel }{ $class_id }{ $type_id }{$key_sort} = $renum_data;
    }

    return;
}

### Subroutine : get_pending_invoices           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_pending_invoices :Export(:DEFAULT) {

    my ( $dbh ) = @_;

    my %renum = ();

    my $qry
        = "SELECT r.id, r.shipment_id, r.renumeration_type_id, r.renumeration_class_id, r.renumeration_status_id, r.shipping, r.misc_refund, c.currency, ri.unit_price, ri.tax, ri.duty, o.id as orders_id, o.order_nr, ch.name as sales_channel, a.first_name, a.last_name, r.gift_voucher
                FROM renumeration r LEFT JOIN renumeration_item ri ON r.id = ri.renumeration_id, currency c, shipment s, link_orders__shipment los, orders o, channel ch, order_address a
                WHERE (r.renumeration_status_id = 1 OR r.renumeration_status_id = 2)
                AND r.currency_id = c.id
                AND r.shipment_id = s.id
                AND s.id = los.shipment_id
                AND los.orders_id = o.id
                AND o.channel_id = ch.id
                AND o.invoice_address_id = a.id
    ";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
        $row->{$_} = decode_db( $row->{$_} ) for (qw(
            first_name
            last_name
        ));

        my $key_sort = $$row{id};

        my $sales_channel   = $row->{sales_channel};
        my $class_id        = $row->{renumeration_class_id};
        my $type_id         = $row->{renumeration_type_id};

        if ( $renum{ $sales_channel }{ $class_id }{ $type_id }{$key_sort} ) {
            $renum{ $sales_channel }{ $class_id }{ $type_id }{$key_sort}{total} += _d2( $row->{unit_price} + $row->{tax} + $row->{duty} );
        }
        else {
            $renum{ $sales_channel }{ $class_id }{ $type_id }{$key_sort}{renum_id}    = $row->{id};
            $renum{ $sales_channel }{ $class_id }{ $type_id }{$key_sort}{shipment_id} = $row->{shipment_id};
            $renum{ $sales_channel }{ $class_id }{ $type_id }{$key_sort}{status}      = $row->{renumeration_status_id};
            $renum{ $sales_channel }{ $class_id }{ $type_id }{$key_sort}{currency}    = $row->{currency};
            $renum{ $sales_channel }{ $class_id }{ $type_id }{$key_sort}{total}       = _d2(
            _defval($row->{unit_price}) + _defval($row->{tax})
            + _defval($row->{duty}) + _defval($row->{shipping})
            + _defval($row->{misc_refund}) + _defval($row->{gift_credit})
            + _defval($row->{store_credit}) + _defval($row->{gift_voucher})
        );
            $renum{ $sales_channel }{ $class_id }{ $type_id }{$key_sort}{orders_id}   = $row->{orders_id};
            $renum{ $sales_channel }{ $class_id }{ $type_id }{$key_sort}{order_nr}    = $row->{order_nr};
            $renum{ $sales_channel }{ $class_id }{ $type_id }{$key_sort}{channel}     = $row->{sales_channel};
            $renum{ $sales_channel }{ $class_id }{ $type_id }{$key_sort}{name}        = $row->{first_name} . " " . $row->{last_name};

        }

    }

    return \%renum;

}

### Subroutine : _d2                            ###
# usage        : my $two_decimals = _d2($number)  #
# description  : format a number to two decimal   #
#                places using sprintf()           #
# parameters   : number                           #
# returns      : string                           #

sub _d2 {
    my $val = shift;
    my $n = sprintf( "%.2f", $val );
    return $n;
}

sub _defval {
    my $val = shift;
    return 0 if (not defined $val);
    return $val;
}

### Subroutine : get_markdown_info              ###
# usage        : get_markdown_info( $dbh,         #
#                   $shipment_item_id             #
# description  : Returns a hashref containing the #
#                the applied markdown for the     #
#                item the current markdown and    #
#                the interval between the         #
#                shipping date and the date the   #
#                current markdown was set         #
# parameters   : $dbh, $shipment_item_id          #
# returns      : $markdown_info->{                #
#                   applied_markdown,             #
#                   current_markdown,             #
#                   interval}                     #

sub get_markdown_info :Export(:DEFAULT) {

    my ( $dbh, $shipment_item_id ) = @_;

    my $qry = "SELECT apa.percentage                                                  AS applied_markdown,
                      cpa.percentage                                                  AS current_markdown,
                      (DATE_TRUNC('day', cpa.date_start) - DATE_TRUNC('day', s.date)) AS interval
                 FROM shipment_item si
                 JOIN shipment s           ON si.shipment_id = s.id
                 JOIN variant v            ON si.variant_id  = v.id
                 JOIN product p            ON v.product_id   = p.id
            LEFT JOIN price_adjustment cpa ON p.id           = cpa.product_id
            LEFT JOIN link_shipment_item__price_adjustment link ON si.id                    = link.shipment_item_id
            LEFT JOIN price_adjustment apa                      ON link.price_adjustment_id = apa.id
                WHERE si.id = ?
                AND now() >= cpa.date_start
                AND now() <= cpa.date_finish
             ORDER BY cpa.date_start DESC LIMIT 1";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $shipment_item_id );

    my $markdown_info_ref = $sth->fetchrow_hashref();

    return $markdown_info_ref;

}

### Subroutine : get_invoice_shipment_info     ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_invoice_shipment_info :Export(:DEFAULT) {

    my ($dbh, $ship_id) = @_;

    ### ORDER INFO
    ###############
    my $qry
        = "SELECT los.shipment_id, o.id as orders_id, o.order_nr, a.first_name, a.last_name
                FROM link_orders__shipment los, orders o, order_address a
                WHERE los.shipment_id = ?
                AND los.orders_id = o.id
                AND o.invoice_address_id = a.id
    ";

    my $sth = $dbh->prepare($qry);
    $sth->execute($ship_id);

    my $renum = $sth->fetchrow_hashref();
    $renum->{$_} = decode_db( $renum->{$_} ) for (qw(
        first_name
        last_name
    ));

    return $renum;

}

### Subroutine : create_renum_tenders_for_refund                   ###
# usage        : create_renum_tenders_for_refund($order, $invoice, $refund_amount) #
# description  : Creates renumeration tenders for one or all tenders according to the amount being refunded #
# parameters   :
# returns      :

sub create_renum_tenders_for_refund :Export() {

    my ( $order, $invoice, $refund_amount )     = @_;

    my $diff_total  = $refund_amount;

    my $tenders = $order->tenders->search( {}, { order_by => 'rank DESC' } );
    while ( my $tender = $tenders->next ) {
        my $tmp = $tender->remaining_value - $diff_total;
        my $value;
        if ( $tmp > 0 ) {
            $value  = $diff_total;
            $diff_total = 0;
        }
        else {
            $value  = $tender->remaining_value;
            $diff_total -= $value;
        }
        $invoice->create_related( 'renumeration_tenders', {
                                            tender_id   => $tender->id,
                                            value       => $value,
                                        } );
        last        if ( $diff_total == 0 );
    }

    if ( $diff_total != 0 ) {
        die "Not enough Tenders to honour Refund Amount: $refund_amount, got left with $diff_total to do";
    }

    return;
}

### Subroutine : create_renum_tenders_for_order_tenders                   ###
# usage        : create_renum_tenders_for_order_tenders( $invoice, \@order_tenders ) #
# description  : Creates renumeration tenders for specific order tenders in the same order as they are passed in #
# parameters   :
# returns      :

sub create_renum_tenders_for_order_tenders :Export() {

    my ( $invoice, $order_tenders )     = @_;

    my $last_tender;

    # get the value of the invoice
    my $total_value = $invoice->total_value
                        + $invoice->shipping
                        + $invoice->misc_refund
                        + $invoice->gift_credit
                        + $invoice->store_credit
                        + $invoice->gift_voucher;

    foreach my $tender ( @{ $order_tenders } ) {
        # if no remaining value then don't use the tender
        next        if ( !$tender->remaining_value || $tender->remaining_value <= 0 );

        my $tmp = $tender->remaining_value - $total_value;
        my $value;
        if ( $tmp > 0 ) {
            $value  = $total_value;
            $total_value = 0;
        }
        else {
            $value  = $tender->remaining_value;
            $total_value -= $value;
        }
        $last_tender    = $invoice->create_related( 'renumeration_tenders', {
                                            tender_id   => $tender->id,
                                            value       => $value,
                                        } );
        last        if ( $total_value == 0 );
    }

    if ( $total_value != 0 ) {
        # if run out of tenders then apply the amount on the last one
        # so as not to use an orders.tender that wasn't used originally
        if ( ( $last_tender->value + $total_value ) > 0 ) {
            $last_tender->update( { value => $last_tender->value + $total_value } );
        }
    }

    return;
}

### Subroutine : adjust_existing_renum_tenders                   ###
# usage        : adjust_existing_renum_tenders($invoice, $new_amount) #
# description  : Adjusts existing renumeration tenders for new invoice amount
# parameters   :
# returns      :

sub adjust_existing_renum_tenders :Export() {

    my ( $invoice, $new_amount )    = @_;

    my $amount  = $new_amount;
    my $order_id;
    my $schema  = $invoice->result_source->schema;

    my @renum_tenders   = $invoice->renumeration_tenders->search( {}, { join => 'tender', order_by => 'tender.rank DESC' } )->all;
    if ( !@renum_tenders ) {
        # if there aren't any - nothing to do
        return;
    }
    my @tender_ids;
    foreach ( @renum_tenders ) {
        # store only the tender id's we are going to use
        push @tender_ids, $_->tender_id;
        $order_id   = $_->tender->order_id;
        # delete this to re-apply
        $_->delete;
    }

    # re-apply amount only using the tenders available
    my $tenders = $schema->resultset('Orders::Tender')->search( {
                                                                    order_id => $order_id,
                                                                    id => { 'IN' => \@tender_ids },
                                                                },
                                                                { order_by => 'rank DESC' } );
    my $last_tender;
    while ( my $tender = $tenders->next ) {
        my $tmp = $tender->remaining_value - $amount;
        my $value;
        if ( $tmp > 0 ) {
            $value  = $amount;
            $amount = 0;
        }
        else {
            $value  = $tender->remaining_value;
            $amount -= $value;
        }
        $last_tender = $invoice->create_related( 'renumeration_tenders', {
                                            tender_id   => $tender->id,
                                            value       => $value,
                                        } );
        last    if ( $amount == 0 );
    }

    if ( $amount != 0 ) {
        # if run out of tenders then apply the amount on the last one
        # so as not to use an orders.tender that wasn't used originally
        if ( ( $last_tender->value + $amount ) > 0 ) {
            $last_tender->update( { value => $last_tender->value + $amount } );
        }
    }

    return;
}

### Subroutine : update_card_tender_value                   ###
# usage        : update_card_tender_value($order, $amount)    #
# description  : Updates the Card tender (or creates) in orders.tender to maintain the values #
# parameters   :
# returns      :

sub update_card_tender_value :Export() {

    my ( $order, $amount )  = @_;

    $order->discard_changes;
    my $card_tender = $order->tenders->search( { type_id => $RENUMERATION_TYPE__CARD_DEBIT }, { order_by => 'rank DESC' } )->first;

    if ( $card_tender ) {
        # if exists update
        $card_tender->update( { value => $card_tender->value + $amount } );
    }
    elsif ( $amount > 0 ) {
        # else create a card debit
        # only if there is something to charge
        my $max_rank    = $order->tenders->get_column('rank')->max() || 0;
        $card_tender    = $order->create_related( 'tenders', {
                            rank    => $max_rank + 1,
                            value   => $amount,
                            type_id => $RENUMERATION_TYPE__CARD_DEBIT,
                        } );
    }

    return $card_tender;
}

=head2 payment_can_allow_goodwill_refund_for_card

    $boolean = payment_can_allow_goodwill_refund_for_card(
        $order_rec,
        $goodwill_refund_amount,
        $renumeration_type_id,
    );

This will check whether a Goodwill Refund Amount can be Refunded to the
option 'Card Refund' based on what the Order's actual Payment Method
allows. Some Payment Methods such as 'Klarna' can't handle pure Goodwill
Refunds and so need to be restricted to only use Store Credit.

Pass in the DBIC Order Object, the Amount that is to be Refunded and the
Renumeration Type Id for the Type that wants to be used for the Refund.

Currently this function is used when Operators can create Invoices (Refunds)
and Edit Invoices.

=cut

sub payment_can_allow_goodwill_refund_for_card :Export() {
    my ( $order, $refund_value, $reunmeration_type_id ) = @_;

    $reunmeration_type_id //= 0;
    $refund_value         //= 0;

    if (    $reunmeration_type_id == $RENUMERATION_TYPE__CARD_REFUND
        && !$order->payment_method_allows_pure_goodwill_refunds ) {

        # if '$refund_value' is anything other than zero then return FALSE
        if ( $refund_value =~ m/\D/ || $refund_value != 0 ) {
            return 0;
        }
    }

    return 1;
}

1;
