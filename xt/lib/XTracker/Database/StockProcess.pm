package XTracker::Database::StockProcess;

=head1 NAME

XTracker::Database::StockProcess - Utility class for the 'Goods In' and 'Stock Control' processes

=head1 DESCRIPTION

Most of the methods require a database handle to be passed in.

=head2 Unit tests

At the time of writing, there is very low unit test coverage.
If you are editing this class, please consider adding some unit tests.

=head2 Documentation

Please fill out and update the method documentation to POD format if you touch a method

=head1 METHODS

=cut

use strict;
use warnings;
use Carp;

use Perl6::Export::Attrs;
use XTracker::Database qw(get_schema_using_dbh);
use XTracker::Database::Utilities qw(last_insert_id results_list results_hash);
use XTracker::Config::Local 'config_var';
use XTracker::Constants::FromDB qw(
    :stock_process_type
    :stock_process_status
    :putaway_type
    :shipment_class
);
use XTracker::Database::Return;
use XTracker::Database::Shipment qw( get_shipment_info );
use XTracker::Database::FlowStatus qw( :iws :prl :stock_process );
use XTracker::Logfile qw(xt_logger);
use XTracker::Utilities qw/ undef_or_equals /;


### Subroutine : get_process_group_total        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_process_group_total :Export(:DEFAULT){

    my ( $dbh, $process_group_id ) = @_;

    $process_group_id =~ s/^p-//i;

    my $qry = "select sum( quantity )
               from stock_process where group_id = ?";

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $process_group_id );

    my $value = 0;
    $sth->bind_columns( \$value );
    $sth->fetch();

    return $value;
}


### Subroutine : get_delivery_id                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_delivery_id :Export(:DEFAULT){

    my ( $dbh, $process_group_id ) = @_;

    $process_group_id =~ s/^p-//i;

    my $qry = "select delivery_id from delivery_item where id =
                    ( select delivery_item_id
                      from stock_process where group_id = ? limit 1)";

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $process_group_id );

    my $value = 0;
    $sth->bind_columns( \$value );
    $sth->fetch();

    return $value;
}


### Subroutine : get_process_group_type         ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_process_group_type :Export(:DEFAULT){

    my ( $dbh, $process_group_id ) = @_;

    $process_group_id =~ s/^p-//i;

    my $qry = "select type_id from stock_process where group_id = ?";

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $process_group_id );

    my $value = 0;
    $sth->bind_columns( \$value );
    $sth->fetch();

    return $value;
}


### Subroutine : get_process_group_id           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_process_group_id :Export(:DEFAULT){

    my ( $dbh, $stock_process_id ) = @_;

    my $qry = "select group_id from stock_process where id = ?";

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $stock_process_id );

    my $value = 0;
    $sth->bind_columns( \$value );
    $sth->fetch();

    return $value;
}


### Subroutine : get_delivery_item_id           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_delivery_item_id :Export(){

    my ( $dbh, $stock_process_id ) = @_;

    my $qry = "select delivery_item_id from stock_process where id = ?";

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $stock_process_id );

    my $delivery_item_id;
    $sth->bind_columns( \$delivery_item_id );
    $sth->fetch();

    return $delivery_item_id;
}


### Subroutine : stock_process_data             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub stock_process_data :Export(:DEFAULT) {

    my ( $dbh, $stock_process_id, $type ) = @_;

    my %qry = ( 'passed'      => "select sum( quantity ) from stock_process
                                  where status_id in ($STOCK_PROCESS_STATUS__APPROVED, $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED, $STOCK_PROCESS_STATUS__PUTAWAY ) and type_id in ( $STOCK_PROCESS_TYPE__MAIN, $STOCK_PROCESS_TYPE__FAULTY, $STOCK_PROCESS_TYPE__SURPLUS, $STOCK_PROCESS_TYPE__FASTTRACK)
                                  and delivery_item_id in
                      ( select delivery_item_id from  link_delivery_item__stock_order_item where stock_order_item_id =
                           ( select stock_order_item_id from link_delivery_item__stock_order_item where delivery_item_id =
                                                ( select delivery_item_id from stock_process where id = ?)))",
                'delivered'   => "select quantity from stock_process where id = ?",
                'ordered'     => "select quantity from stock_order_item where id =
                                      ( select stock_order_item_id from
                                      link_delivery_item__stock_order_item where
                                      delivery_item_id =
                                            ( select delivery_item_id from stock_process where id = ? ))",
                'delivery_item_id' => "select delivery_item_id from stock_process where id = ?",
             );

    my $sth = $dbh->prepare( $qry{$type} );
    $sth->execute( $stock_process_id );

    my $value = 0;
    $sth->bind_columns( \$value );
    $sth->fetch();
    return ( $value );
}


### Subroutine : set_stock_process              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_stock_process {

    my ( $dbh, $stock_process_id, $sign, $quantity ) = @_;

    my %signs = ( 'minus' => '-',
                  'plus'  => '+',
                );

    my $qry  = "update stock_process
                set quantity = ( quantity $signs{$sign} ? )
                where id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $quantity,
                   $stock_process_id,
                 );

    return;
}


### Subroutine : set_stock_process_status       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_stock_process_status :Export(:DEFAULT) {

    my ( $dbh, $stock_process_id, $status ) = @_;

    my $qry  = "update stock_process
                set status_id = ?
                where id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $status, $stock_process_id );

    return;
}


### Subroutine : set_stock_process_type         ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_stock_process_type :Export(:DEFAULT) {

    my ( $dbh, $stock_process_id, $type_id ) = @_;

    my $qry  = "update stock_process
                set type_id = ?
                where id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $type_id, $stock_process_id );

    return;
}

sub set_stock_process_container :Export(:DEFAULT) {

    my ( $dbh, $stock_process_id, $container ) = @_;

    # NOTE: this 'container' column may or may not be
    # a foreign key to the container table -- this is
    # yet to be decided, and so remains unchanged for now.
    #
    # There is a JIRA ticket to resolve this:
    #
    # http://jira.nap/browse/DCEA-674
    #
    my $qry  = "update stock_process
                set container = ?
                where id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $container, $stock_process_id );

    return;
}


### Subroutine : set_process_group_status       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_process_group_status :Export(:DEFAULT) {

    my ( $dbh, $process_group_id, $status_id ) = @_;

    $process_group_id =~ s/^p-//i;

    my $qry  = "update stock_process
                set status_id = ?
                where group_id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $status_id, $process_group_id );

    return;
}


### Subroutine : create_stock_process           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_stock_process :Export(:DEFAULT) {

    my ( $dbh, $type_id, $delivery_item_id, $quantity, $process_group_ref ) = @_;

    my $stock_process_id = _create_stock_process_item( $dbh,
                                                       $type_id,
                                                       $delivery_item_id,
                                                       $quantity );
    unless( $$process_group_ref ){
        $$process_group_ref = _new_process_group( $dbh );
    }

    add_to_process_group( $dbh,
                          $stock_process_id,
                          $$process_group_ref );

    return $stock_process_id;
}


### Subroutine : add_to_process_group           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub add_to_process_group {

    my ( $dbh, $stock_process_id, $group_id ) = @_;

    $group_id =~ s/^p-//i;

    my $qry = "update stock_process set group_id = ?
               where id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $group_id, $stock_process_id );

    return;
}


### Subroutine : split_stock_process            ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub split_stock_process :Export(:DEFAULT) {

    my ( $dbh, $type_id, $stock_process_id, $quantity, $process_group_ref, $delivery_item_id ) = @_;

    # minus the value from faulty group
    set_stock_process( $dbh, $stock_process_id, 'minus', $quantity );

    # create an new stock process entry
    my $new_stock_process_id
         = _create_stock_process_item( $dbh, $type_id, $delivery_item_id, $quantity );

    # create a new process group if required
    unless( $$process_group_ref ){
            $$process_group_ref = _new_process_group( $dbh );
    }

    # add stock process to process group
    add_to_process_group( $dbh, $new_stock_process_id, $$process_group_ref );

    return $new_stock_process_id;
}

{
my %process_map = (
    main         => { type => $STOCK_PROCESS_TYPE__MAIN,    status => $STOCK_PROCESS_STATUS__NEW },
    faulty       => { type => $STOCK_PROCESS_TYPE__FAULTY,  status => $STOCK_PROCESS_STATUS__NEW },
    surplus      => { type => $STOCK_PROCESS_TYPE__SURPLUS, status => $STOCK_PROCESS_STATUS__NEW },
    measurements => { type => 'any',                        status => $STOCK_PROCESS_STATUS__APPROVED },
    rtv          => { type => $STOCK_PROCESS_TYPE__RTV,     status => $STOCK_PROCESS_STATUS__NEW },
    rma_wait     => { type => $STOCK_PROCESS_TYPE__RTV,     status => $STOCK_PROCESS_STATUS__RMA_REQUESTED },
    bagandtag    => { type => 'any',                        status => $STOCK_PROCESS_STATUS__APPROVED },
    putaway      => { type => 'any',                        status => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED },
    putaway_prep => { type => 'any',                        status => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED },
    quarantine   => { type => $STOCK_PROCESS_TYPE__FAULTY,  status => $STOCK_PROCESS_STATUS__DEAD },
    deadstock    => { type => $STOCK_PROCESS_TYPE__FAULTY,  status => $STOCK_PROCESS_STATUS__DEAD },
);

### Subroutine : get_process_group              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_process_group :Export(:DEFAULT) {

    my ( $dbh, $type ) = @_;

    $type = lc $type;
    SMARTMATCH: {
        use experimental 'smartmatch';
        croak "Cannot use get_process_group for $type process"
            unless $type ~~ [qw/main faulty surplus rtv rma_wait bagandtag putaway deadstock/];
    }

    my @execute_vars = ($process_map{$type}->{status});

    my $type_constraint = '';
    if( $process_map{$type}->{type} ne 'any' ){
        $type_constraint = " AND sp.type_id = ?";
        push @execute_vars, $process_map{$type}->{type};
    }
 my $qry = <<END_OF_QUERY;
  SELECT sp.group_id,
         del.id AS delivery_id,
         del.on_hold,
         v.product_id,
         d.designer,
         c.colour,
         SUM( sp.quantity ) AS quantity,
         TO_CHAR( del.date, 'DD-MM-YYYY' ) AS date,
         spt.type,
         sp.type_id AS sp_type_id,
         v.legacy_sku,
         pc.live,
         TO_CHAR( pc.upload_date, 'DD-MM-YYYY' ) AS upload_date,
         CASE WHEN pc.upload_date IS NOT NULL
               AND pc.upload_date < current_timestamp - interval '3 days'
              THEN 1 ELSE 0
         END AS priority,
         ch.name AS sales_channel
    FROM delivery del
    JOIN delivery_item di ON (di.delivery_id = del.id)
    JOIN stock_process sp ON (sp.delivery_item_id = di.id
                              AND sp.complete = false
                              AND sp.quantity <> 0
                              AND sp.status_id = ?
                              $type_constraint
                          )
    JOIN link_delivery_item__stock_order_item di_soi ON (di_soi.delivery_item_id = di.id)
    JOIN stock_order_item soi ON (di_soi.stock_order_item_id = soi.id)
    JOIN super_variant v ON (soi.variant_id = v.id)
    LEFT JOIN product p ON (v.product_id = p.id)
    LEFT JOIN voucher.product vp ON (v.product_id = vp.id)
    LEFT JOIN product_channel pc ON (p.id = pc.product_id)
    LEFT JOIN colour c ON (p.colour_id = c.id)
    LEFT JOIN designer d ON (p.designer_id = d.id)
    JOIN stock_process_type spt ON (sp.type_id = spt.id)
    JOIN stock_order so ON (soi.stock_order_id = so.id)
    JOIN super_purchase_order po ON (so.purchase_order_id = po.id)
    JOIN channel ch ON (po.channel_id = ch.id OR vp.channel_id = ch.id)
GROUP BY sp.group_id, del.id, del.on_hold, p.id, d.designer, c.colour,
        v.product_id, v.legacy_sku,
         del.date, spt.type, sp.type_id, p.legacy_sku, pc.live, pc.upload_date, ch.name
END_OF_QUERY

    my $sth = $dbh->prepare($qry);
    $sth->execute( @execute_vars );

    my %data;

    while ( my $row = $sth->fetchrow_hashref ) {
        $data{ $row->{sales_channel} }{ $row->{group_id} } = $row
            if include_process_group( $row->{sp_type_id}, $type );
    }

    return \%data;
}


### Subroutine : get_quarantine_process_group              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_quarantine_process_group :Export(:DEFAULT) {

    my ( $dbh, $type ) = @_;

    $type = lc $type;
    SMARTMATCH: {
        use experimental 'smartmatch';
        croak "Cannot use get_quarantine_process_group for $type process"
            unless $type ~~ [qw/main faulty surplus rtv rma_wait bagandtag putaway putaway_prep deadstock/];
    }

    my @execute_vars = ($process_map{$type}->{status});

    my $type_constraint = '';
    if( $process_map{$type}->{type} ne 'any' ){
        $type_constraint = " AND sp.type_id = ? ";
        push @execute_vars, $process_map{$type}->{type};
    }

    my $qry = <<END_OF_QUERY;
  SELECT sp.group_id, del.id AS delivery_id, del.on_hold,
         p.id AS product_id,
         d.designer, c.colour,
         SUM( sp.quantity ) AS quantity,
         TO_CHAR( del.date, 'DD-MM-YYYY' ) AS date,
         spt.type,
         sp.type_id AS sp_type_id,
         p.legacy_sku,
         pc.live,
         TO_CHAR( pc.upload_date, 'DD-MM-YYYY' ) AS upload_date,
         CASE WHEN pc.upload_date IS NOT NULL
               AND pc.upload_date < current_timestamp - interval '3 days'
              THEN 1 ELSE 0
         END AS priority,
         ch.name AS sales_channel
    FROM delivery del
    JOIN delivery_item di ON (di.delivery_id = del.id)
    JOIN link_delivery_item__quarantine_process di_qp ON (di_qp.delivery_item_id = di.id)
    JOIN stock_process sp ON (sp.delivery_item_id = di.id
                              AND sp.complete = false
                              AND sp.quantity <> 0
                              AND sp.status_id = ?
                              $type_constraint
                          )
    JOIN quarantine_process qp ON (di_qp.quarantine_process_id = qp.id)
    JOIN variant v ON (qp.variant_id = v.id )
    JOIN product p ON (v.product_id = p.id)
    JOIN product_channel pc ON (p.id = pc.product_id AND qp.channel_id = pc.channel_id)
    JOIN colour c ON (p.colour_id = c.id)
    JOIN designer d ON (p.designer_id = d.id)
    JOIN stock_process_type spt ON (sp.type_id = spt.id)
    JOIN channel ch ON (qp.channel_id = ch.id )
GROUP BY sp.group_id, del.id, del.on_hold, p.id, d.designer, c.colour,
         del.date, spt.type, sp_type_id, p.legacy_sku, pc.live, pc.upload_date, ch.name
END_OF_QUERY

    my $sth = $dbh->prepare($qry);
    $sth->execute( @execute_vars );

    my %data;

    my $schema = get_schema_using_dbh($dbh, 'xtracker_schema');
    while ( my $row = $sth->fetchrow_hashref ) {
        $data{ $row->{sales_channel} }{ $row->{group_id} } = $row
            if include_process_group( $row->{sp_type_id}, $type, $row->{group_id}, $schema );
    }

    return \%data;
}

### Subroutine : get_return_process_group       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #


sub get_customer_return_process_group :Export(:DEFAULT) {
    my ( $dbh, $type) = @_;
    return get_return_process_group($dbh, $type, 1);
}

sub get_samples_return_process_group :Export(:DEFAULT) {
    my ( $dbh, $type) = @_;
    return get_return_process_group($dbh, $type, 0);
}

sub get_return_process_group :Export(:DEFAULT) {
    my ( $dbh, $type, $return_type) = @_;

    $type = lc $type;
    SMARTMATCH: {
        use experimental 'smartmatch';
        croak "Cannot use get_return_process_group for $type process"
            unless $type ~~ [qw/main faulty surplus measurements putaway putaway_prep quarantine deadstock/];
    }

    my @execute_vars = ($process_map{$type}->{status});

    my $type_constraint = '';
    if( $process_map{$type}->{type} ne 'any' ){
        $type_constraint = " AND sp.type_id = ? ";
        push @execute_vars, $process_map{$type}->{type};
    }

    my $return_type_sql = "";
    if(defined($return_type)) {
        $return_type_sql = " WHERE s.shipment_class_id " . ($return_type ? '<>' : '=' ) . " $SHIPMENT_CLASS__TRANSFER_SHIPMENT";
    }

 my $qry = <<END_OF_QUERY;
   SELECT sp.group_id,
          del.id AS delivery_id,
          del.ON_hold, p.id, d.designer,
          SUM( sp.quantity ) AS quantity,
          TO_CHAR(MAX( risl.date ), 'DD-MM-YYYY') AS date,
          TO_CHAR(MAX( risl.date ), 'YYYYMMDD') AS date_string,
          spt.type,
          sp.type_id AS sp_type_id,
          r.rma_number, ri.return_item_status_id, v.legacy_sku, cit.description,
          product_id || '-' || sku_padding(size_id) as sku,
          CASE WHEN och.name IS NOT null THEN och.name ELSE stch.name END AS sales_channel,
          CASE WHEN lsts.stock_transfer_id IS NULL THEN 'Customer' ELSE 'Sample' END AS return_type
     FROM delivery del
     JOIN delivery_item di ON (del.id = di.delivery_id)
     JOIN stock_process sp ON (di.id = sp.delivery_item_id
                               AND sp.complete = false
                               AND sp.status_id = ?
                               $type_constraint
                           )
     JOIN link_delivery_item__return_item di_ri ON (di.id = di_ri.delivery_item_id)
     JOIN return_item ri ON (di_ri.return_item_id = ri.id)
     JOIN variant v ON (ri.variant_id = v.id)
     JOIN product p ON (v.product_id = p.id)
     JOIN designer d ON (p.designer_id = d.id)
     JOIN stock_process_type spt ON (sp.type_id = spt.id)
     JOIN return_item_status_log risl ON (risl.return_item_id = ri.id)
     JOIN return r ON (ri.return_id = r.id)
     JOIN shipment s ON (r.shipment_id = s.id)
LEFT JOIN link_orders__shipment los ON (los.shipment_id = s.id)
LEFT JOIN orders o ON (los.orders_id = o.id)
LEFT JOIN channel och ON (o.channel_id = och.id)
LEFT JOIN link_stock_transfer__shipment lsts ON (s.id = lsts.shipment_id)
LEFT JOIN stock_transfer st ON (lsts.stock_transfer_id = st.id)
LEFT JOIN channel stch ON (st.channel_id = stch.id)
     JOIN customer_issue_type cit ON (ri.customer_issue_type_id = cit.id)
     $return_type_sql
 GROUP BY sp.group_id, del.id, del.on_hold, p.id, d.designer, spt.type, sp_type_id, r.rma_number,
          ri.return_item_status_id, v.legacy_sku, cit.description, v.product_id, v.size_id, sales_channel, return_type
END_OF_QUERY

    my $sth = $dbh->prepare($qry);
    $sth->execute( @execute_vars );

    my %data;

    my $schema = get_schema_using_dbh($dbh, 'xtracker_schema');

    while ( my $row = $sth->fetchrow_hashref ) {
        $data{ $row->{sales_channel} }{ $row->{date_string}.$row->{group_id} } = $row
            if include_process_group( $row->{sp_type_id}, $type , $row->{group_id}, $schema);
    }

    return \%data;
}

### Subroutine : get_sample_process_group       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_sample_process_group :Export(:DEFAULT) {

    my ( $dbh, $type ) = @_;

    $type = lc $type;
    SMARTMATCH: {
        use experimental 'smartmatch';
        croak "Cannot use get_sample_process_group for $type process"
            unless $type ~~ [qw/main faulty surplus measurements putaway putaway_prep quarantine deadstock/];
    }

    my @execute_vars = ($process_map{$type}->{status});

    my $type_constraint = '';
    if ( $process_map{$type}->{type} ne 'any' ) {
        $type_constraint = " AND sp.type_id = ? ";
        push @execute_vars, $process_map{$type}->{type};
    }

 my $qry = <<END_OF_QUERY;
  SELECT sp.group_id, del.id as delivery_id, del.on_hold, p.id, d.designer, c.colour,
         SUM( sp.quantity ) AS quantity,
         TO_CHAR(MAX( del.date ), 'DD-MM-YYYY') AS date,
         TO_CHAR(del.date, 'YYYYMMDD') AS date_string,
         spt.type,
         sp.type_id AS sp_type_id,
         si.shipment_id, v.legacy_sku,
         product_id || '-' || sku_padding(size_id) as sku,
         ch.name AS sales_channel
    FROM delivery del
    JOIN delivery_item di ON (di.delivery_id = del.id)
    JOIN stock_process sp ON (sp.delivery_item_id = di.id
                              AND sp.complete = false
                              AND sp.status_id = ?
                              $type_constraint
                          )
    JOIN link_delivery_item__shipment_item di_si ON (di_si.delivery_item_id = di.id)
    JOIN shipment_item si ON (di_si.shipment_item_id = si.id)
    JOIN variant v ON (si.variant_id = v.id)
    JOIN product p ON (v.product_id = p.id)
    JOIN colour c ON (p.colour_id = c.id)
    JOIN designer d ON (p.designer_id = d.id)
    JOIN stock_process_type spt ON (sp.type_id = spt.id)
    JOIN link_stock_transfer__shipment sts ON (si.shipment_id = sts.shipment_id)
    JOIN stock_transfer st ON (sts.stock_transfer_id = st.id)
    JOIN channel ch ON (st.channel_id = ch.id)
GROUP BY sp.group_id, del.id, del.on_hold, p.id, d.designer, c.colour, del.date,
         spt.type, sp_type_id, si.shipment_id, v.legacy_sku, v.product_id, v.size_id, ch.name
ORDER BY to_char( del.date, 'YYYY-MM-DD' ), del.id, sp.group_id
END_OF_QUERY

    my $sth = $dbh->prepare($qry);
    $sth->execute( @execute_vars );

    my %data;

    my $schema = get_schema_using_dbh($dbh, 'xtracker_schema');
    while ( my $row = $sth->fetchrow_hashref ) {
        $data{ $row->{sales_channel} }{ $row->{date_string}.$row->{group_id} } = $row
            if include_process_group( $row->{sp_type_id}, $type, $row->{group_id}, $schema );
    }

    return \%data;
}
}

=head2 include_process_group( $stock_process_type_id, $context, $group_id?, $schema? ) : Bool

Only include stock process group if it's relevant at the current stage of
the goods in process.

=cut

sub include_process_group {
    my ( $stock_process_type_id, $context, $group_id, $schema ) = @_;
    # If we are using an XTracker with PRLs turned on then we differentiate
    # between putaway and putaway prep, for the rest of goods in we always
    # display the row
    if ( config_var(qw/PRL rollout_phase/) ) {
        if ($context eq 'putaway_prep') {

            return unless stock_process_type_handled_by_prl($stock_process_type_id);

            my $putaway_prep_started;
            # Putaway prep counts as being started if there is at least
            # one item for this group in a container already, which means
            # there must be a row in the putaway_prep_inventory table for it.
            if ($schema && $group_id) {
                $putaway_prep_started = $schema->resultset('Public::PutawayPrepGroup')
                        ->search({group_id => $group_id})
                        ->search_related('putaway_prep_inventories', {})
                        ->count;
            } else {
                confess("Missing parameters: include_process_group requires schema and group id when called for types handled by PRL at putaway prep.");
            }
            # PGIDs handled by PRLs need to go through putaway prep, but if
            # putaway prep has already been started they will show on the
            # putaway prep admin list so don't need to appear here.
            return !$putaway_prep_started;
        }

        # PGIDs not handled by PRLs go through putaway
        return !stock_process_type_handled_by_prl($stock_process_type_id)
            if $context eq 'putaway';
    }
    # If we have IWS then don't display the PGID if we're in putaway or
    # putaway_prep
    elsif ( config_var(qw/IWS rollout_phase/) ) {
        SMARTMATCH: {
            use experimental 'smartmatch';
            return !stock_process_type_handled_by_iws($stock_process_type_id)
                if $context ~~ [qw/putaway putaway_prep/];
        }
    }
    # If we're in neither then always display the PGID or we're at any other
    # stage of the Goods In process we always include the row
    return 1;
}



### Subroutine : get_stock_process_row          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #
sub get_stock_process_row :Export() {

    my ($dbh, $arg_ref)         = @_;
    my $stock_process_id        = $arg_ref->{stock_process_id};
    my $stock_process_type_id   = $arg_ref->{stock_process_type_id};
    my $delivery_item_id        = $arg_ref->{delivery_item_id};

    ## validate input arguments
    if ( exists $arg_ref->{stock_process_id} ) {
        croak "Invalid stock_process_id ($stock_process_id)" if $stock_process_id !~ m{\A\d+\z}xms;
    }
    else {
        croak "Invalid stock_process_type_id ($stock_process_type_id)" if $stock_process_type_id !~ m{\A\d+\z}xms;
        croak "Invalid delivery_item_id ($delivery_item_id)" if $delivery_item_id !~ m{\A\d+\z}xms;
    }


    my $where_clause    = undef;
    my @exec_args       = ();
    my $limit_clause    = undef;

    if ( $stock_process_id ) {

        $where_clause = q{id = ?};
        push @exec_args, $stock_process_id;

    }
    elsif ( $stock_process_type_id and $delivery_item_id ) {

        $where_clause = q{delivery_item_id = ? AND type_id = ?};
        push @exec_args, $delivery_item_id, $stock_process_type_id;
        $limit_clause = 'LIMIT 1';

    }

    my $qry = qq{SELECT * FROM stock_process};
    $qry   .= qq{ WHERE $where_clause} if defined $where_clause;
    $qry   .= qq{ $limit_clause} if defined $limit_clause;


    my $sth = $dbh->prepare($qry);
    $sth->execute(@exec_args);

    my $row_ref = $sth->fetchrow_hashref();

    return $row_ref;

} ## END sub get_stock_process_row


sub get_stock_process_items :Export(:DEFAULT) {
    my ( $dbh, $type, $id, $status ) = @_;

    $id =~ s/^p-//i;

    croak "You must provide a value for $_->[0]"
        for grep { !$_->[1] } [dbh => $dbh],[type => $type],[id => $id];

    my %status_id = (
        quality_control => { type => "= $STOCK_PROCESS_TYPE__MAIN", status => $STOCK_PROCESS_STATUS__NEW },
        faulty          => { type => "= $STOCK_PROCESS_TYPE__FAULTY", status => $STOCK_PROCESS_STATUS__NEW },
        surplus         => { type => "= $STOCK_PROCESS_TYPE__SURPLUS", status => $STOCK_PROCESS_STATUS__NEW },
        bagandtag => {
            type  => sprintf( 'IN (%s)', join q{, },
                $STOCK_PROCESS_TYPE__MAIN,
                $STOCK_PROCESS_TYPE__FAULTY,
                $STOCK_PROCESS_TYPE__SURPLUS,
                $STOCK_PROCESS_TYPE__FASTTRACK
            ),
            status => $STOCK_PROCESS_STATUS__APPROVED,
        },
        putaway  => {
            type => sprintf( 'IN (%s)', join q{, },
                $STOCK_PROCESS_TYPE__MAIN,
                $STOCK_PROCESS_TYPE__FAULTY,
                $STOCK_PROCESS_TYPE__SURPLUS,
                $STOCK_PROCESS_TYPE__RTV,
                $STOCK_PROCESS_TYPE__DEAD,
                $STOCK_PROCESS_TYPE__FASTTRACK,
                $STOCK_PROCESS_TYPE__RTV_NON_DASH_FAULTY,
                $STOCK_PROCESS_TYPE__RTV_CUSTOMER_REPAIR,
                $STOCK_PROCESS_TYPE__RTV_FIXED,
                $STOCK_PROCESS_TYPE__QUARANTINE_FIXED
            ),
            status => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
        },
    );

    my $qry  = <<EOQ
SELECT sp.id,
    sp.quantity,
    spt.type,
    sp.type_id AS stock_process_type_id,
    di.type_id,
    di.delivery_id,
    COALESCE(soi.variant_id,soi.voucher_variant_id)                AS variant_id,
    COALESCE(v.product_id,vv.product_id)                           AS product_id,
    COALESCE(v.legacy_sku,vv.sku)                                  AS legacy_sku,
    sku_padding(COALESCE(v.size_id,vv.size_id))                    AS size_id,
    COALESCE(v.size_id,vv.size_id)                                 AS size_id_numeric,
    COALESCE(s.size,vv.size_id::TEXT)                              AS size,
    COALESCE(s2.size,'None/Unknown')                               AS designer_size,
    COALESCE(v.product_id || '-' || sku_padding(v.size_id),vv.sku) AS sku
FROM delivery_item di
JOIN stock_process sp ON di.id = sp.delivery_item_id
JOIN stock_process_type spt ON sp.type_id = spt.id
JOIN link_delivery_item__stock_order_item ldi_soi ON di.id = ldi_soi.delivery_item_id
JOIN stock_order_item soi ON ldi_soi.stock_order_item_id = soi.id
LEFT JOIN (
    SELECT id,
        product_id,
        legacy_sku,
        size_id,
        designer_size_id,
        'product' AS vtype
    FROM variant
) v ON soi.variant_id = v.id
JOIN size s ON v.size_id = s.id
JOIN size s2 ON v.designer_size_id = s2.id
JOIN product p ON v.product_id = p.id
LEFT JOIN (
    SELECT id,
        voucher_product_id AS product_id,
        voucher_product_id::TEXT || '-999' AS sku,
        999 AS size_id,
        'voucher' AS vtype
    FROM voucher.variant
) vv ON soi.voucher_variant_id = v.id
%s
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14
ORDER BY size_id_numeric ASC
EOQ
;

    my @conds = (
        'WHERE sp.quantity > 0',
        {
            process_group => 'sp.group_id = ?',
            delivery_id   => 'di.delivery_id = ?'
        }->{$type}
    );

    push( @conds,
        "sp.status_id = $status_id{$status}{status}",
        "sp.type_id $status_id{$status}{type}",
    ) if $status;

    my $sth = $dbh->prepare(sprintf $qry, join q{ AND }, @conds);
    $sth->execute( $id );

    return results_list($sth);
}



### Subroutine : get_quarantine_process_items        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_quarantine_process_items :Export(:DEFAULT) {

    my ( $dbh, $type, $id, $status ) = @_;

    $id =~ s/^p-//i;

    my %subqry = ( 'process_group' => ' and sp.group_id = ?',
        'delivery_id'         => ' and d.id = ?',
    );

    my %status_id
    = (
        'quality_control' => { type => "= $STOCK_PROCESS_TYPE__MAIN", status => $STOCK_PROCESS_STATUS__NEW },
        'faulty'          => { type => "= $STOCK_PROCESS_TYPE__FAULTY", status => $STOCK_PROCESS_STATUS__NEW },
        'surplus'         => { type => "= $STOCK_PROCESS_TYPE__SURPLUS", status => $STOCK_PROCESS_STATUS__NEW },
        'bagandtag' => {
            type    => "in ($STOCK_PROCESS_TYPE__MAIN, $STOCK_PROCESS_TYPE__FAULTY,
            $STOCK_PROCESS_TYPE__SURPLUS, $STOCK_PROCESS_TYPE__FASTTRACK) ",
            status  => $STOCK_PROCESS_STATUS__APPROVED,
        },
        'putaway'   => {
            type    => "in ($STOCK_PROCESS_TYPE__MAIN, $STOCK_PROCESS_TYPE__FAULTY,
            $STOCK_PROCESS_TYPE__SURPLUS, $STOCK_PROCESS_TYPE__RTV,
            $STOCK_PROCESS_TYPE__DEAD, $STOCK_PROCESS_TYPE__FASTTRACK,
            $STOCK_PROCESS_TYPE__RTV_NON_DASH_FAULTY, $STOCK_PROCESS_TYPE__RTV_CUSTOMER_REPAIR,
            $STOCK_PROCESS_TYPE__RTV_FIXED, $STOCK_PROCESS_TYPE__QUARANTINE_FIXED) ",
            status  => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
        },
    );


    my $qry  = qq{
    select sp.id,
    sku_padding(v.size_id) as size_id,
    s.size,
    s2.size as designer_size,
    sp.quantity,
    v.id as variant_id,
    v.product_id,
    di.type_id,
    v.legacy_sku,
    product_id || '-' || sku_padding(size_id) as sku,
    spt.type,
    sp.type_id AS stock_process_type_id
    from product p,
    variant v,
    quarantine_process qp,
    delivery_item di,
    size s,
    size s2,
    delivery d,
    stock_process sp,
    stock_process_type spt,
    link_delivery_item__quarantine_process di_qp
    where sp.delivery_item_id = di.id
        and di.delivery_id = d.id
        and di_qp.delivery_item_id = di.id
        and di_qp.quarantine_process_id = qp.id
        and qp.variant_id = v.id
        and v.product_id = p.id
        and v.size_id = s.id
        and v.designer_size_id = s2.id
        and sp.type_id = spt.id
        and sp.quantity > 0
    $subqry{ $type }
};


if( $status ){
    $qry .= " and sp.status_id = $status_id{ $status }->{status}
        and sp.type_id $status_id{ $status }->{type}";
}

# order results by variant size
$qry .= " order by v.size_id asc";

my $sth = $dbh->prepare($qry);
$sth->execute( $id );

return results_list($sth);
}


### Subroutine : get_return_stock_process_items ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_return_stock_process_items :Export(:DEFAULT) {

    my ( $dbh, $type, $id, $status ) = @_;

    $id =~ s/^p-//i;

    my %subqry = ( 'process_group'  => ' and sp.group_id = ?',
        'delivery_id'    => ' and d.id = ?',
    );

    my %status_id = ( 'quality_control' => { type => $STOCK_PROCESS_TYPE__MAIN, status => $STOCK_PROCESS_STATUS__NEW },
        'faulty'          => { type => $STOCK_PROCESS_TYPE__FAULTY, status => $STOCK_PROCESS_STATUS__NEW },
    );

    my $qry  = qq{
    select sp.id, sp.status_id, sp.delivery_item_id, sp.type_id, sp.complete,
    s.size, 1 as quantity,
    v.size_id, v.id as variant_id, v.legacy_sku, v.product_id, ri.id as return_item_id,
    sp.type_id AS stock_process_type_id, spt.type, sd.size as designer_size
    from product p, variant v, size sd, return_item ri,
    delivery_item di, size s, delivery d, stock_process sp, stock_process_type spt,
    link_delivery_item__return_item di_ri
    where sp.delivery_item_id = di.id
        and di.delivery_id = d.id
        and di_ri.delivery_item_id = di.id
        and di_ri.return_item_id = ri.id
        and ri.variant_id = v.id
        and v.product_id = p.id
        and v.size_id = s.id
        and v.designer_size_id = sd.id
        and sp.type_id = spt.id
    $subqry{ $type }
};

if( $status ){
    if ( $status eq 'putaway') {
        $qry .= " and sp.status_id = $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED and sp.complete = false";
    }
    else {
        $qry .= " and sp.status_id = $status_id{ $status }->{status}
            and sp.type_id = $status_id{ $status }->{type}";
    }
}

my $sth = $dbh->prepare($qry);
$sth->execute( $id );

return results_list($sth);
}

### Subroutine : get_sample_process_items       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_sample_process_items :Export(:DEFAULT) {

    my ( $dbh, $type, $id, $status ) = @_;

    $id =~ s/^p-//i;

    my %subqry = ( 'process_group' => ' and sp.group_id = ?',
        'delivery_id'   => ' and d.id = ?',
    );

    my %status_id = ( 'quality_control' => { type => $STOCK_PROCESS_TYPE__MAIN, status => $STOCK_PROCESS_STATUS__NEW },
        'faulty'          => { type => $STOCK_PROCESS_TYPE__FAULTY, status => $STOCK_PROCESS_STATUS__NEW },
        'putaway'         => { type => $STOCK_PROCESS_TYPE__MAIN, status => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED },
    );

    my $qry  = qq{
    select sp.id, sp.status_id, sp.delivery_item_id, sp.type_id, sp.complete,
    v.size_id, s.size, v.id as variant_id, v.legacy_sku, v.product_id,
    si.id as shipment_item_id, 1 as quantity,
    product_id || '-' || sku_padding(v.size_id) as sku,
    sp.type_id AS stock_process_type_id, spt.type
    from product p, variant v, shipment_item si,
    delivery_item di, size s, delivery d, stock_process sp, stock_process_type spt,
    link_delivery_item__shipment_item di_si
    where sp.delivery_item_id = di.id
        and di.delivery_id = d.id
        and di_si.delivery_item_id = di.id
        and di_si.shipment_item_id = si.id
        and si.variant_id = v.id
        and v.product_id = p.id
        and v.size_id = s.id
        and sp.type_id = spt.id
    $subqry{ $type }
};

if( $status ){
    if ( $status eq 'putaway') {
        $qry .= " and sp.status_id = $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED
            and sp.type_id in ($STOCK_PROCESS_TYPE__MAIN, $STOCK_PROCESS_TYPE__DEAD)";
    }
    else {
        $qry .= " and sp.status_id = $status_id{ $status }->{status}
            and sp.type_id = $status_id{ $status }->{type}";
    }
}

my $sth = $dbh->prepare($qry);
$sth->execute( $id );

return results_list($sth);
}

### Subroutine : get_putaway                    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_putaway :Export(:putaway) {

    my ( $dbh, $process_group_id ) = @_;

    $process_group_id =~ s/^p-//i;

    my $qry  = "
    SELECT
        sp.id, sku_padding(v.size_id) as size_id, s.size, sd.size as designer_size, sp.quantity as sp_quant,
        v.id as variant_id, sp.group_id, put.location_id,
        put.quantity, l.location, v.legacy_sku, sp.type_id AS stock_process_type_id
    FROM
        product p, variant v, stock_order_item soi,
        link_delivery_item__stock_order_item di_soi,
        delivery_item di, size s, size sd, delivery d, stock_process sp
    LEFT JOIN putaway put on ( put.stock_process_id = sp.id)
    LEFT JOIN location l on ( put.location_id = l.id)
    WHERE sp.delivery_item_id = di.id
        and di.delivery_id = d.id
        and di_soi.delivery_item_id = di.id
        and di_soi.stock_order_item_id = soi.id
        and soi.variant_id = v.id
        and v.product_id = p.id
        and v.size_id = s.id
        and v.designer_size_id = sd.id
        and put.complete = false
        and sp.group_id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $process_group_id );

    return results_list($sth);
}

=head2 get_stored_putaway_type($schema, $group_id) : $putaway_type_string | undef

Return the previously stored putaway_type string (e.g. "Goods In") for
the $group_id, or undef if no putaway_type was stored.

=cut

sub get_stored_putaway_type {
    my ($schema, $group_id) = @_;
    my $stock_process_rs = $schema->resultset("Public::StockProcess");
    return $stock_process_rs->get_putaway_type_id_for_group_id(
        $group_id,
    );
}

=head2 store_putaway_type($schema, $group_id, $data) : $data

Store the $data->{putaway_type} string (e.g. "Returns") against the
$group_id.

It's stored against Stock Processes with the $group_id, so it there
are none, this won't have any effect.

Return the $data parameter.

=cut

sub store_putaway_type {
    my ($schema, $group_id, $data) = @_;
    my $putaway_type_id = $data->{putaway_type};

    my $stock_process_rs = $schema->resultset("Public::StockProcess");
    my $putaway_type = $stock_process_rs->set_putaway_type_id_for_group_id(
        $group_id,
        $putaway_type_id,
    );

    return $data;
}

=head2 get_putaway_type

B<Description>

Try to find out what type of putaway is being performed for a given PGID.

Vouchers are always considered 'Goods In' type.

B<Synopsis>

    use XTracker::Database::StockProcess qw/putaway_type/;

    my $putaway_data = get_putaway_type( $dbh, $pgid );
    if ($putaway_data->{putaway_type} == $PUTAWAY_TYPE__GOODS_IN) {
        # do something
    }

B<Parameters>

=over

=item C<$dbh>

A database handle

=item C<$pgid>

Process Group ID of which to determine putaway type

=back

B<Returns>

A hashref, guaranteed to contain a 'putaway_type' key. For a list of
possible values see $PUTAWAY_TYPE__* in XTracker::Constants::FromDB

The hashref will also contain other data, depending on what the
putaway type actually is.

An empty hashref will be returned if the putaway type cannot be
determined

B<See also>

=over 4

=item L</get_stock_process_items>

=item L</get_return_stock_process_items>

=item L</get_sample_process_items>

=item L</get_quarantine_process_items>

=back

=cut

# Store the looked up putaway_type and populate the putaway_type_name
# key in $data.
sub _complete_putaway_type {
    my ($schema, $group_id, $data) = @_;

    store_putaway_type($schema, $group_id, $data);

    my $putaway_type_rs = $schema->resultset("Public::PutawayType");
    my $putaway_type_id = $data->{putaway_type};
    my $putaway_type_row = $putaway_type_rs->find($putaway_type_id)
        or confess("Unknown putaway_type_id ($putaway_type_id)\n");
    $data->{putaway_type_name} = $putaway_type_row->name;

    return $data;
}

sub get_putaway_type :Export(:putaway) {
    my ($dbh, $process_group_id) = @_;
    $process_group_id =~ s/^p-//i;

    my $schema = get_schema_using_dbh($dbh, 'xtracker_schema');

    my %data;
    my $putaway_type = get_stored_putaway_type($schema, $process_group_id);

    # check if it's a Goods In group
    if ( undef_or_equals($putaway_type, $PUTAWAY_TYPE__GOODS_IN) ) {
        if($putaway_type) {
            $data{putaway_type} = $PUTAWAY_TYPE__GOODS_IN;
            return _complete_putaway_type($schema, $process_group_id, \%data);
        }

        my $gi_check = get_stock_process_items(
            $dbh,
            'process_group',
            $process_group_id,
            'putaway',
        );
        if (@{$gi_check} > 0) {
            $data{putaway_type} = $PUTAWAY_TYPE__GOODS_IN;
            return _complete_putaway_type($schema, $process_group_id, \%data);
        }
    }

    # Customer Return
    my $is_customer_return_or_transfer_shipment = undef_or_equals(
        $putaway_type,
        $PUTAWAY_TYPE__STOCK_TRANSFER,
        $PUTAWAY_TYPE__RETURNS,
    );
    if ( $is_customer_return_or_transfer_shipment ) {
        my $ret_check = get_return_stock_process_items(
            $dbh,
            'process_group',
            $process_group_id,
            'putaway',
        );
        if (@{$ret_check} > 0) {
            # get return info for this item
            $data{return_id}     = get_return_id_by_process_group($dbh, $process_group_id);
            $data{return_info}   = get_return_info  ($dbh, $data{return_id});
            $data{shipment_info} = get_shipment_info($dbh, $data{return_info}{shipment_id});

            # stock transfer shipment
            if ($data{shipment_info}{class} eq "Transfer Shipment") {
                $data{putaway_type} = $PUTAWAY_TYPE__STOCK_TRANSFER;
            }
            else {
                # customer return
                $data{putaway_type} = $PUTAWAY_TYPE__RETURNS;
            }

            # get variant id
            foreach my $record (@{$ret_check}) {
                $data{variant_id} = $record->{variant_id};
            }

            return _complete_putaway_type($schema, $process_group_id, \%data);
        }
    }

    # not a Return - try Vendor Samples
    if ( undef_or_equals($putaway_type, $PUTAWAY_TYPE__SAMPLE) ) {
        my $samp_check = get_sample_process_items(
            $dbh,
            'process_group',
            $process_group_id,
        );
        if (@{$samp_check} > 0) {
            $data{putaway_type} = $PUTAWAY_TYPE__SAMPLE;

            # get variant id
            foreach my $record (@{$samp_check}) {
                $data{variant_id} = $record->{variant_id};
            }

            return _complete_putaway_type($schema, $process_group_id, \%data);
        }
    }

    # not a Vendor Sample - try Processed Quarantine
    if ( undef_or_equals($putaway_type, $PUTAWAY_TYPE__PROCESSED_QUARANTINE) ) {
        my $q_check = get_quarantine_process_items(
            $dbh,
            'process_group',
            $process_group_id,
        );
        if (@{$q_check} > 0) {
            $data{putaway_type} = $PUTAWAY_TYPE__PROCESSED_QUARANTINE;

            # get variant id
            foreach my $record (@{$q_check}) {
                $data{variant_id} = $record->{variant_id};
            }

            return _complete_putaway_type($schema, $process_group_id, \%data);
        }
    }

    # check if it's a gift voucher
    if ( undef_or_equals($putaway_type, $PUTAWAY_TYPE__GOODS_IN) ) {
        my $voucher = $schema->resultset('Public::StockProcess')
            ->get_group($process_group_id)->get_voucher;
        if ($voucher) {
            $data{putaway_type} = $PUTAWAY_TYPE__GOODS_IN;

            return _complete_putaway_type($schema, $process_group_id, \%data);
        }
    }


    # I think we should croak here, but our tests (namely channel_transfer.t)
    # gets down to this croak and dies. So either the test is preparing the
    # data poorly or we need to revisit this sub
    # croak "Could not determine putaway type for process group id $process_group_id";
    return {}
}



### Subroutine : get_quarantine_putaway                    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_quarantine_putaway :Export(:putaway) {

    my ( $dbh, $process_group_id ) = @_;

    $process_group_id =~ s/^p-//i;

    my $qry  = "select sp.id, sku_padding(v.size_id) as size_id, s.size, sd.size as designer_size, sp.quantity as sp_quant,
    v.id as variant_id, sp.group_id, put.location_id,
    put.quantity, l.location, v.legacy_sku, sp.type_id AS stock_process_type_id
    from product p, variant v, quarantine_process qp,
    link_delivery_item__quarantine_process di_qp,
    delivery_item di, size s, size sd, delivery d, stock_process sp
    left join putaway put on ( put.stock_process_id = sp.id)
    left join location l on ( put.location_id = l.id)
    where sp.delivery_item_id = di.id
        and di.delivery_id = d.id
        and di_qp.delivery_item_id = di.id
        and di_qp.quarantine_process_id = qp.id
        and qp.variant_id = v.id
        and v.product_id = p.id
        and v.size_id = s.id
        and v.designer_size_id = sd.id
        and put.complete = false
        and sp.group_id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $process_group_id );

    return results_list($sth);
}


### Subroutine : get_return_putaway             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_return_putaway :Export(:putaway) {

    my ( $dbh, $process_group_id ) = @_;

    $process_group_id =~ s/^p-//i;

    my $qry  = "select sp.id, v.size_id, s.size, sp.quantity as sp_quant,
    v.id as variant_id, sp.group_id, put.location_id,
    put.quantity, l.location, v.legacy_sku, ri.id as return_item_id, r.shipment_id,
    sp.type_id AS stock_process_type_id, sz.size as designer_size
    from product p, variant v, size sz, return_item ri, return r,
    link_delivery_item__return_item di_ri,
    delivery_item di, size s, delivery d, stock_process sp
    left join putaway put on ( put.stock_process_id = sp.id)
    left join location l on ( put.location_id = l.id)
    where sp.delivery_item_id = di.id
        and di.delivery_id = d.id
        and di_ri.delivery_item_id = di.id
        and di_ri.return_item_id = ri.id
        and ri.return_id = r.id
        and ri.variant_id = v.id
        and v.product_id = p.id
        and v.designer_size_id = sz.id
        and v.size_id = s.id
        and put.complete = false
        and sp.group_id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $process_group_id );

    return results_list($sth);
}


### Subroutine : get_sample_putaway             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_sample_putaway :Export(:putaway) {

    my ( $dbh, $process_group_id ) = @_;

    $process_group_id =~ s/^p-//i;

    my $qry  = "select sp.id, v.size_id, s.size, sp.quantity as sp_quant,
    v.id as variant_id, sp.group_id, put.location_id,
    put.quantity, l.location, v.legacy_sku, si.id as shipment_item_id,
    sp.type_id AS stock_process_type_id
    from product p, variant v, shipment_item si,
    link_delivery_item__shipment_item di_si,
    delivery_item di, size s, delivery d, stock_process sp
    left join putaway put on ( put.stock_process_id = sp.id)
    left join location l on ( put.location_id = l.id)
    where sp.delivery_item_id = di.id
        and di.delivery_id = d.id
        and di_si.delivery_item_id = di.id
        and di_si.shipment_item_id = si.id
        and si.variant_id = v.id
        and v.product_id = p.id
        and v.size_id = s.id
        and put.complete = false
        and sp.group_id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $process_group_id );

    return results_list($sth);
}


### Subroutine : get_putaway_total              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_putaway_total :Export(:putaway) {

    my ( $dbh, $process_group_id ) = @_;

    $process_group_id =~ s/^p-//i;

    my $qry  = "select sp.id, sp.quantity, sum( put.quantity ) as total
    from stock_process sp, putaway put
    where put.stock_process_id = sp.id
        and sp.group_id = ?
    group by sp.id, sp.quantity";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $process_group_id );

    return results_hash($sth);
}


### Subroutine : set_putaway_item               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_putaway_item :Export(:putaway) {

    my ( $schema, $stock_process_id, $location, $quantity ) = @_;

    if (! $schema->isa('DBIx::Class::Schema')) {
        $schema=get_schema_using_dbh($schema,'xtracker_schema');
    }

    my $location_obj=$schema->resultset('Public::Location')
        ->get_location({location=>$location});

    my $putaway=$schema->resultset('Public::Putaway')->search({
        stock_process_id => $stock_process_id,
        location_id => $location_obj->id,
    })->first;

    if ($putaway) {
        $putaway->update({
            quantity => $putaway->quantity+$quantity,
        });
    }
    else {
        $schema->resultset('Public::Putaway')->create({
            stock_process_id => $stock_process_id,
            location_id => $location_obj->id,
            quantity => $quantity,
        });
    }

    return;
}


### Subroutine : get_suggested_measurements     ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_suggested_measurements :Export(:measurements) {

    my (  $dbh, $product_id ) = @_;

    # NOTE: Ok, here we are doing a union when we actually only want the
    # second query. The union is there because during the MrP projects there
    # were some data issues (Anne/Mia/product management know the details), so
    # once this has been cleared up we can remove the first part of the union
    # and the really_wanted column.
    # select suggested measurements
    my $qry = "
select m_id as id, m_name as measurement, max(m_wanted) as really_wanted, max(m_sort_order) as sort_order
from (
    select  m.id as m_id, m.measurement as m_name, 0 as m_wanted, 0 as m_sort_order
        from measurement m, variant_measurement vm, variant v
        where m.id = vm.measurement_id and vm.variant_id = v.id
        and v.product_id = ?
    union
    select  ptm.measurement_id as m_id, m.measurement as m_name, 1 as m_wanted, ptm.sort_order as m_sort_order
        from product_type_measurement ptm, measurement m, product_channel pc
        where ptm.measurement_id = m.id
        and pc.product_id = ? and pc.channel_id = ptm.channel_id
        and product_type_id =
        (select product_type_id from product where id = ?)
) as m
group by m_id, m_name
order by sort_order, measurement
    ";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $product_id, $product_id, $product_id );

    return results_list( $sth );
}


### Subroutine : get_measurements               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_measurements :Export(:measurements) {

    my ( $dbh, $product_id ) = @_;

    my %measurements = ();

    # select current measurements
    my $qry= "select vm.variant_id, vm.measurement_id, m.measurement, vm.value
    from variant_measurement vm, measurement m
    where vm.measurement_id = m.id
        and vm.variant_id in ( select id from variant where product_id = ? )";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $product_id );

    while( my $row = $sth->fetchrow_hashref() ){
        $measurements{ $row->{ variant_id } }->{ $row->{ measurement_id } }
        = $row->{ value };
    }

    return \%measurements;
}


### Subroutine : set_measurement                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_measurement :Export(:DEFAULT) {

    my ( $dbh, $measurement, $variant_id, $value ) = @_;

    my $qry  = "";

    # insert or update ?
    if( check_measurement( $dbh, $measurement, $variant_id ) ){
        if($value){
            xt_logger->info("Updating variant_measurement: $value (variant_id=$variant_id)");
            $qry  = "update variant_measurement
            set value = ?
            where measurement_id
            = ( select id from measurement where measurement = ? )
                and variant_id = ?";
            my $sth = $dbh->prepare($qry);
            $sth->execute( $value, $measurement, $variant_id );
        }else{
            xt_logger->info("Deleting variant_measurement (variant_id=$variant_id)");
            $qry  = "delete from variant_measurement
            where measurement_id =(
            select id from measurement where measurement = ?
            )
                and variant_id = ?";
            my $sth = $dbh->prepare($qry);
            $sth->execute( $measurement, $variant_id );
        }
    }
    else{
        if($value){
            xt_logger->info("Insering variant_measurement: $value");
            $qry  = "insert into variant_measurement
            ( value, measurement_id, variant_id  )
            values ( ?, ( select id
            from measurement
            where measurement = ? ), ? )";
            my $sth = $dbh->prepare($qry);
            $sth->execute( $value, $measurement, $variant_id );
        }
    }
    return;
}

sub clean_measurement :Export(:DEFAULT) {
    my $orig_val = shift;

    return undef unless (defined($orig_val));

    $orig_val =~ s/ //g;
    $orig_val =~ s/\t//g;

    my $len = length($orig_val);

    return undef if ($orig_val eq '0');
    return undef if ($len == 0);
    return undef unless defined($orig_val);

    die "The value is too complex (value=$orig_val)\n" if ($len > 10);

    die "The value is not a number (value=$orig_val) (1)\n" if ($orig_val !~ m/^[0-9]*\.?[0-9]*$/ );
    die "The value is not a number (value=$orig_val) (2)\n" if ($orig_val eq '.');

    return $orig_val . "";
}

### Subroutine : check_measurement              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub check_measurement {

    my ( $dbh, $measurement, $variant_id ) = @_;

    my $qry = "select count(*)
    from variant_measurement
    where variant_id = ?
        and measurement_id
    = ( select id
    from measurement where measurement = ? )";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $variant_id, $measurement );

    my $rows = 0;
    $sth->bind_columns( \$rows );
    $sth->fetch();

    return $rows;
}


### Subroutine : complete_putaway_item          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub complete_putaway_item :Export(:putaway) {

    my ( $dbh, $stock_process_id, $location_id ) = @_;

    my $qry   = "update putaway set complete = true
    where stock_process_id = ? and location_id = ?";

    my $sth   = $dbh->prepare( $qry );

    $sth->execute( $stock_process_id, $location_id );

    return;
}


### Subroutine : complete_stock_process         ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub complete_stock_process :Export(:DEFAULT) {

    my ( $dbh, $stock_process_id ) = @_;

    my $qry = "update stock_process set complete = true where id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $stock_process_id );

    return;
}



### Subroutine : putaway_completed              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub putaway_completed :Export(:putaway) {

    my ( $dbh, $stock_process_id ) = @_;

    my $qry = "select count(*) from putaway where stock_process_id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $stock_process_id );

    my $rows = 0;
    $sth->bind_columns( \$rows );
    $sth->fetch();

    return $rows > 0 ? 1 : 0;
}


#####################################
# Internal functions
#
#
#####################################


### Subroutine : check_stock_process_complete   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub check_stock_process_complete :Export(:DEFAULT) {

    my ( $dbh, $type, $id ) = @_;

    my $qry = "select quantity from stock_process where id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $id );

    my $rows = 0;
    $sth->bind_columns( \$rows );
    $sth->fetch();

    return $rows > 0 ? 0 : 1;
}



### Subroutine : _new_process_group             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _new_process_group {

    my ( $dbh ) = @_;

    my $qry = "select nextval('process_group_id_seq')";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my $group_id = 0;
    $sth->bind_columns( \$group_id );
    $sth->fetch();

    return $group_id;
}


### Subroutine : _create_stock_process_item     ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _create_stock_process_item {

    my ( $dbh, $type_id, $delivery_item_id, $quantity ) = @_;

    my $qry = "insert into stock_process
    ( delivery_item_id, quantity, group_id, type_id, status_id )
    values ( ?, ?, 0, ?, $STOCK_PROCESS_STATUS__NEW )";

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $delivery_item_id,
        $quantity,
        $type_id
    );

    return last_insert_id( $dbh, 'stock_process_id_seq' );
}



### Subroutine : check_delivery_item            ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub check_delivery_item :Export(:DEFAULT) {

    my ( $dbh, $delivery_item_id, $status_id ) = @_;

    my $qry = "select status_id from delivery_item where id = ? ";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $delivery_item_id );

    my $current_status_id = $sth->fetch()->[0];

    if( $current_status_id < $status_id ){
        return 0;
    }
    else{
        return 1;
    }
}


### Subroutine : check_delivery_item_count      ###
# returns      : true if packing slip is non zero #
#                and equal to item count, false   #
#                otherwise                        #

sub check_delivery_item_count :Export(:DEFAULT) {

    my ( $dbh, $delivery_item_id, $item_count ) = @_;

    my $qry = "select packing_slip,delivery_id from delivery_item where id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $delivery_item_id );

    my ($packing_slip, $delivery_id) = $sth->fetchrow_array();

    # BA-276 validate the 'Count' values entered against the corresponding Packing Slip value when Packing Slip is not 0.
    #return !$packing_slip || $packing_slip == $item_count;

    # EN-298 - change this so that it does not return ok for incorrect 0
    # ie it will only allow any count against a 0 if all the packing slip values
    # are 0
    my $all_zero = 1;
    {
        my $qry =  "select delivery_item.packing_slip from delivery_item, delivery where delivery.id = ? and delivery_item.delivery_id = delivery.id";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $delivery_id );
        while ( my $row = $sth->fetchrow_hashref() ) {
            my $tmp_packing_slip    = $row->{packing_slip};
            if ($tmp_packing_slip != 0) {$all_zero = 0; last;}
        }
    }

    if ($all_zero) { return 1; }

    if ($packing_slip == $item_count) { return 1; }

    return 0;
}


### Subroutine : get_stock_process_types                                     ###
# usage        : $sp_types_ref = get_stock_process_types($dbh);                #
# description  : return a hashref of stock process types                       #
#              :                                                               #
# parameters   : $dbh                                                          #
# returns      : hash ref of stock process types, keyed by id                  #

sub get_stock_process_types :Export(:DEFAULT) {

    my $dbh = shift;

    my $qry = q{SELECT * FROM stock_process_type};
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my $sp_types_ref = results_hash($sth);

    return $sp_types_ref;

}


# doesn't check the phase -- it's presumed that, if you're
# actually asking, then we're > phase 0
sub stock_process_type_handled_by_iws :Export(:iws) {
    return flow_status_handled_by_iws(flow_status_from_stock_process_type(@_));
}

sub stock_process_type_handled_by_prl {
    return flow_status_handled_by_prl(flow_status_from_stock_process_type(@_));
}

sub send_pre_advice :Export(:iws) {
    my ( $msg_factory, $schema, $group_id, $type_id, $stat) = @_;

    $group_id =~ s/^p-//i;

    my $sp_group = $schema->resultset('Public::StockProcess')->search({
        group_id => $group_id,
        type_id => $type_id,
        status_id => $stat,
        quantity => { '>' => 0 },
    });

    my $total = $sp_group->count;

    return unless $total;

    $msg_factory->transform_and_send(
        'XT::DC::Messaging::Producer::WMS::PreAdvice',
        { sp_group_rs => $sp_group },
    );

    return $total;
}



1;

__END__
