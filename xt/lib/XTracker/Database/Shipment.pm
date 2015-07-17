package XTracker::Database::Shipment;
use strict;
use warnings;

=head1 NAME

XTracker::Database::Shipment

=cut

use Perl6::Export::Attrs;
use Carp qw(carp croak confess);
use MooseX::Params::Validate qw/ validated_list pos_validated_list /;

use XTracker::XTemplate;
use XTracker::EmailFunctions;

use XTracker::Postcode::Analyser;
use XTracker::Database::Address;
use XTracker::Database::Currency qw( get_currency_conversion_rate get_local_conversion_rate get_conversion_rate_from_local);
use XTracker::Database::Stock;
use XTracker::Database::Container qw( get_container_by_id :validation);
use XTracker::Database::Utilities;
use XTracker::Database::Channel         qw( get_channel );
use XTracker::Database qw/ get_schema_using_dbh /;
use XTracker::DBEncode qw/ decode_db encode_db /;
use XTracker::Utilities 'number_in_list';
use XTracker::Error;
use XTracker::Logfile qw(xt_logger);
my $LOG = xt_logger(__PACKAGE__);

use XTracker::DHL::XMLDocument;
use XTracker::DHL::XMLRequest;

use XTracker::Constants::FromDB qw(
    :business
    :correspondence_templates
    :flag
    :flag_type
    :note_type
    :return_status
    :shipment_class
    :shipment_hold_reason
    :shipment_item_on_sale_flag
    :shipment_item_returnable_state
    :shipment_item_status
    :shipment_status
    :shipment_type
    :allocation_status
    :allocation_item_status
);
use XTracker::Config::Local qw( config_var dispatch_email shipping_email customercare_email get_packing_stations );
use List::MoreUtils 'uniq';
use XT::Rules::Solve;
use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

use NAP::DC::Barcode::Container;

=head2 shipment_id create_shipment_with_defaulted_premier_routing($dbh,$parent_id,$type,$data)

A simple wrapper for create_shipment so it can set a default for
premier_routing_id without impacting the behaviour of other calls

=cut

sub create_shipment_with_defaulted_premier_routing {
    my($dbh,$parent_id,$type,$data,$config_key) = @_;
    my $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    my $premier_routing_code = $config_key
        ? config_var('Carrier_Premier',$config_key) : undef;

    my $default_premier_routing = (defined $premier_routing_code)
        ? $schema->resultset('Public::PremierRouting')
            ->find_code( $premier_routing_code )
        : undef;

    if (defined $default_premier_routing) {
        $data->{premier_routing_id} //= $default_premier_routing->id;
    }
    return create_shipment($dbh,$parent_id,$type,$data);
}

sub create_returns_shipment :Export(:DEFAULT) {
    my($dbh,$parent_id,$type,$data) = @_;
    return create_shipment_with_defaulted_premier_routing(
        $dbh,$parent_id,$type,$data,
        'default_returns_routing_code'
    );
}

sub create_reshipment_replacement_shipment :Export(:DEFAULT) {
    my($dbh,$parent_id,$type,$data) = @_;
    return create_shipment_with_defaulted_premier_routing(
        $dbh,$parent_id,$type,$data,
        'default_exchange_reshipment_replacement_routing_code'
    );
}

sub create_shipment :Export(:DEFAULT) {
    my ( $dbh, $parent_id, $type, $data ) = @_;

    if ( !$data->{address_id} ) {
        ### hash address
        $data->{address}{hash} = hash_address( $dbh, $data->{address} );

        ### check if address exists in db
        $data->{address_id} = check_address( $dbh, $data->{address}{hash} );

        ### if not insert new address
        if ( $data->{address_id} == 0 ) {
            create_address( $dbh, $data->{address} );

            $data->{address_id} = check_address( $dbh, $data->{address}{hash} );
        }
    }

    $data->{gift_credit}            = $data->{gift_credit}         || 0;
    $data->{store_credit}           = $data->{store_credit}        || 0;
    $data->{shipping_charge_id}     = $data->{shipping_charge_id}  || 0;
    $data->{shipping_account_id}    = $data->{shipping_account_id} || 0;
    $data->{premier_routing_id}     = $data->{premier_routing_id}  || 0;

    if ( $data->{premier_routing_id} eq q{} ) {
        $data->{premier_routing_id} = 0;
    }

    my @cols = qw{
        shipment_type_id
        shipment_class_id
        shipment_status_id
        shipment_address_id
        gift
        gift_message
        email
        telephone
        mobile_telephone
        packing_instruction
        shipping_charge
        comment
        gift_credit
        store_credit
        destination_code
        shipping_charge_id
        shipping_account_id
        premier_routing_id
        av_quality_rating
    };
    # Optional columns
    for my $col ( qw{date signature_required force_manual_booking} ) {
        push @cols, $col if exists $data->{$col};
    }
    # Hard-coded columns
    my %hardcoded_cols = (
        delivered           => 'false',
        legacy_shipment_nr  => q{},
        outward_airway_bill => 'none',
        return_airway_bill  => 'none',
    );

    # Sometimes our input args don't match our colnames
    my %arg_map = (
        shipment_type_id    => 'type_id',
        shipment_class_id   => 'class_id',
        shipment_status_id  => 'status_id',
        shipment_address_id => 'address_id',
        packing_instruction => 'pack_instruction',
    );

    ## create shipment
    my $insqry = sprintf 'INSERT INTO shipment (%s) VALUES (%s)',
        map { join q{, }, (join q{, }, @$_) }
            [ @cols, keys %hardcoded_cols ],
            [ map { q{?} } (@cols, keys %hardcoded_cols) ];

    my $inssth = $dbh->prepare($insqry);
    $inssth->execute(
        (map { $data->{$arg_map{$_} // $_} } @cols), values %hardcoded_cols
    );

    my $shipment_id = last_insert_id( $dbh, 'shipment_id_seq' );

    ### create link table entry
    my %link_qry = (
        "order"    => "INSERT INTO link_orders__shipment (
            orders_id, shipment_id ) VALUES (?,?)",
        "transfer" => "INSERT INTO link_stock_transfer__shipment (
            stock_transfer_id, shipment_id ) VALUES (?,?)",
        "rtv"      => "INSERT INTO link_rtv__shipment (
            rtv_id, shipment_id ) VALUES (?,?)"
    );

    my $linksth = $dbh->prepare($link_qry{$type});
    $linksth->execute($parent_id, $shipment_id);

    my $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);

    $shipment->apply_SLAs;

    return $shipment_id;
}

sub create_shipment_item :Export(:DEFAULT) {
    my ( $dbh, $shipment_id, $data ) = @_;

    my $key_id;
    my $key_field;

    # if we've got a voucher variant then use that
    if ( exists $data->{voucher_variant_id} && $data->{voucher_variant_id} ) {
        $key_id     = $data->{voucher_variant_id};
        $key_field  = 'voucher_variant_id';
    }
    else {
        # no variant id passed through - get it using SKU
        if ( !defined $data->{variant_id} || $data->{variant_id} == 0 ) {
            # check if sku exists in db
            my $varqry = "SELECT id FROM variant WHERE legacy_sku = ? AND type_id = 1";
            my $varsth = $dbh->prepare($varqry);
            $varsth->execute($data->{sku});

            while ( my $row = $varsth->fetchrow_arrayref ) {
                $data->{variant_id} = $row->[0];
            }
        }

        $key_id     = $data->{variant_id};
        $key_field  = 'variant_id';
    }

    # create shipment item
    my $insqry = "
      INSERT INTO shipment_item
        (id, shipment_id, $key_field, unit_price, tax, duty, shipment_item_status_id, special_order_flag, returnable_state_id, gift_from, gift_to, gift_message, pws_ol_id, gift_recipient_email, sale_flag_id )
      VALUES
        (default, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
    my $inssth = $dbh->prepare($insqry);

    # If no returnable is passed, default it true
    my $returnable = exists $data->{returnable_state_id}
                   ? $data->{returnable_state_id}
                   : $SHIPMENT_ITEM_RETURNABLE_STATE__YES;

    my $sale_item = exists $data->{sale_flag_id}
                  ? $data->{sale_flag_id}
                  : $SHIPMENT_ITEM_ON_SALE_FLAG__NO;

    $inssth->execute(
      $shipment_id,
      $key_id,
      $data->{unit_price},
      $data->{tax},
      $data->{duty},
      $data->{status_id},
      $data->{special_order},
      $returnable,
      encode_db($data->{gift_from}),
      encode_db($data->{gift_to}),
      encode_db($data->{gift_message}),
      $data->{pws_ol_id},
      encode_db($data->{gift_recipient_email}),
      $sale_item,
    );

    # get id we just of record we just inserted
    my $shipment_item_id = last_insert_id( $dbh, 'shipment_item_id_seq' );

    # check if link to price_adjustment required
    my $qry = "SELECT id
                    FROM price_adjustment
                    WHERE product_id = (SELECT product_id FROM variant WHERE id = ?)
                    AND date_start < (SELECT date FROM shipment WHERE id = ?)
                    AND date_finish > (SELECT date FROM shipment WHERE id = ?) LIMIT 1";

    my $sth = $dbh->prepare($qry);
    $sth->execute($data->{variant_id}, $shipment_id, $shipment_id);

    $insqry = "INSERT
                 INTO link_shipment_item__price_adjustment (
                        shipment_item_id,
                        price_adjustment_id
                      )
               VALUES (?, ?)";

    $inssth = $dbh->prepare($insqry);
    while ( my $row = $sth->fetchrow_arrayref ) {
        $inssth->execute($shipment_item_id, $row->[0]);
    }
    return $shipment_item_id;
}

sub get_shipment_order_id :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my $qry
        = "SELECT orders_id FROM link_orders__shipment WHERE shipment_id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my $orders_id = 0;

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $orders_id = $row->[0];
    }
    return $orders_id;
}

sub get_shipment_id :Export(:DEFAULT) {
    my ( $dbh, $params ) = @_;

    my $qry = "select shipment_id from shipment_item where id = ?";

    my $sth = $dbh->prepare($qry);
    # add $params->{type} checking
    $sth->execute($params->{id});

    my $shipment_id = 0;

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $shipment_id = $row->[0];
    }
    return $shipment_id;
}


### Subroutine : get_order_channel_from_shipment             ###
# usage        : $scalar = get_order_channel_from_shipment(    #
#                      $dbh,                                   #
#                      $shipment_id                            #
#                  );                                          #
# description  : Given a shipment id this joins to the orders  #
#                table and returns the channel id for the      #
#                order.                                        #
# parameters   : A Database Handle & a Shipment Id.            #
# returns      : A Channel Id.                                 #

sub get_order_channel_from_shipment {
    my ( $dbh, $shipment_id )   = @_;

    my $channel_id;

    my $qry=<<QRY
SELECT  o.channel_id
FROM    link_orders__shipment los,
        orders o
WHERE   los.shipment_id = ?
AND     o.id = los.orders_id
QRY
;
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $shipment_id );
    ($channel_id)   = $sth->fetchrow_array();
    return $channel_id;
}

### Subroutine : get_order_business_from_shipment            ###
# usage        : $scalar = get_order_business_from_shipment(   #
#                      $dbh,                                   #
#                      $shipment_id                            #
#                  );                                          #
# description  : Given a shipment id this joins to the orders  #
#                table and returns the business id for the     #
#                order.                                        #
# parameters   : A Database Handle & a Shipment Id.            #
# returns      : A Business Id.                                #
sub get_order_business_from_shipment :Export() {
    my ($dbh, $shipment_id) = @_;
    my $business_id;

    my $qry=<<QRY
SELECT b.id
FROM business b
    JOIN channel c ON (c.business_id=b.id)
    JOIN orders o ON (o.channel_id=c.id)
    JOIN link_orders__shipment los ON (los.orders_id=o.id)
WHERE los.shipment_id=?
QRY
;
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $shipment_id );
    ($business_id)  = $sth->fetchrow_array();
    return $business_id;
}

sub get_shipment_stock_transfer_id :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my $qry
        = "SELECT stock_transfer_id FROM link_stock_transfer__shipment WHERE shipment_id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my $stock_transfer_id = 0;

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $stock_transfer_id = $row->[0];
    }
    return $stock_transfer_id;
}

### Subroutine : get_original_sample_shipment_id                         ###
# usage        : $scalar = get_original_sample_shipment_id(                #
#                     $dbh,                                                #
#                     $args_ref = { type,id }                              #
#                  );                                                      #
# description  : This returns the Id of the Shipment Record originally     #
#                created for a Sample Stock Transfer. At the moment you    #
#                can only pass in a Variant Id to search on.               #
# parameters   : Database Handle, Args Ref containing 'type' (variant_id)  #
#                and the 'id' of the type.                                 #
# returns      : The Shipment Id                                           #

sub get_original_sample_shipment_id :Export() {
    my ($dbh, $args_ref)= @_;

    my $type            = $args_ref->{type};
    my $id              = $args_ref->{id};
    my $channel_id          = $args_ref->{channel_id};

    my $shipment_id     = 0;

    my %clause  = (
            'variant_id' => ' si.variant_id = ? '
        );

    my $qry =<<QRY
SELECT
   si.shipment_id
FROM
   shipment_item si,
   link_stock_transfer__shipment lsts,
   stock_transfer st
WHERE
   $clause{$type}
   AND si.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__DISPATCHED
   AND si.shipment_id IN (
      SELECT   s.id
      FROM  shipment s
      WHERE s.shipment_class_id = $SHIPMENT_CLASS__TRANSFER_SHIPMENT
   )
   AND lsts.shipment_id = si.shipment_id
   AND st.id = lsts.stock_transfer_id
   AND st.channel_id = ?
LIMIT 1
QRY
;
    my $sth = $dbh->prepare($qry);
    $sth->execute( $id, $channel_id );
    ($shipment_id)  = $sth->fetchrow_array();
    return $shipment_id;
}

sub get_shipment_ids_from_id_or_container :Export(:DEFAULT) {
    my ($schema, $id, $opts) = @_;

    if (!$schema->isa('DBIx::Class::Schema')) {
        $schema = get_schema_using_dbh($schema,'xtracker_schema');
    }

    my @shipments;
    if ($id =~ /^\d+$/) {
        @shipments = ( $schema->resultset('Public::Shipment')->find({id => $id}) || () );
    }
    else {
        @shipments = $schema->resultset('Public::Shipment')->search({
            'shipment_items.container_id' => ( ref($id) eq "ARRAY" ? { -in => $id } : $id ),
            ( $opts->{exclude_cancelled_items} ?
                  ('shipment_items.shipment_item_status_id' => { '!=' => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING })
            : () ),
        },{
            join => 'shipment_items',
            select => ['me.id', 'me.shipment_status_id'],
            distinct => 1,
        })->all;
    }
    @shipments = grep { !$_->is_at_packing_exception } @shipments
        if $opts->{exclude_packing_exception};
    @shipments = grep { !$_->is_cancelled } @shipments
        if $opts->{exclude_cancelled};
    @shipments = grep { $_->is_cancelled } @shipments
        if $opts->{only_cancelled};

    return map { $_->id } @shipments;
}

sub get_shipment_ids_from_id_or_container_and_sku :Export(:DEFAULT) {
    my ($schema, $id, $sku, $opts) = @_;

    if (!$schema->isa('DBIx::Class::Schema')) {
        $schema = get_schema_using_dbh($schema,'xtracker_schema');
    }

    if (!$sku) {
        return get_shipment_ids_from_id_or_container($schema,$id, $opts);
    }

    my ($pid,$sid)=split /-/,$sku;
    my @shipments = $schema->resultset('Public::Shipment')->search({
        'shipment_items.container_id' => ( ref($id) eq "ARRAY" ? { -in => $id } : $id ),
        ( $opts->{exclude_cancelled_items} ?
              ('shipment_items.shipment_item_status_id' => { '!=' => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING })
        : () ),
        -or => [
            { 'variant.product_id' => $pid, 'variant.size_id' => $sid },
            { 'voucher_variant.voucher_product_id' => $pid },
        ]
    },{
        select => ['me.id', 'me.shipment_status_id'],
        distinct => 1,
        join => { 'shipment_items' => [ 'variant','voucher_variant' ] },
    })->all;

    @shipments = grep { !$_->is_at_packing_exception } @shipments
        if $opts->{exclude_packing_exception};
    @shipments = grep { !$_->is_cancelled } @shipments
        if $opts->{exclude_cancelled};
    @shipments = grep { $_->is_cancelled } @shipments
        if $opts->{only_cancelled};

    return map { $_->id } @shipments;
}

sub get_sample_shipment_return_pending :Export(:DEFAULT) {
    my ( $dbh, $args_ref ) = @_;

    my $qry = "SELECT r.shipment_id, r.rma_number, r.id as return_id
               FROM return r, shipment s, shipment_item si
               WHERE si.variant_id = ?
               AND si.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__RETURN_PENDING
               AND si.shipment_id = s.id
               AND s.shipment_class_id = $SHIPMENT_CLASS__TRANSFER_SHIPMENT
               AND s.id = r.shipment_id
               AND r.return_status_id = $RETURN_STATUS__AWAITING_RETURN
               LIMIT 1";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $args_ref->{id} );
    my $row = $sth->fetchrow_arrayref();
    return ($row->[0] || undef, $row->[1] || undef, $row->[2] || undef);
}

sub get_order_shipment_info :Export(:DEFAULT) {
    my ( $dbh, $order_id ) = @_;

    my $qry = qq{
SELECT s.id,
       to_char(s.date, 'DD-MM-YYYY  HH24:MI') AS date,
       s.gift,
       s.gift_message,
       s.outward_airway_bill,
       s.return_airway_bill,
       s.email,
       s.packing_instruction,
       s.shipping_charge,
       s.shipment_type_id,
       s.shipment_class_id,
       s.shipment_status_id,
       s.shipment_address_id,
       s.comment,
       s.gift_credit,
       s.store_credit,
       s.telephone,
       s.mobile_telephone,
       s.destination_code,
       s.shipping_account_id,
       s.has_packing_started,
       sc.class,
       st.type,
       ss.status,
       scc.class AS shipping_class,
       car.name AS carrier,
       car.tracking_uri AS carrier_tracking_uri,
       sa.name AS shipping_account_name,
       sa.account_number AS shipping_account_number,
       s.real_time_carrier_booking,
       s.av_quality_rating,
       sh.shipment_hold_reason_id,
       s.signature_required,
       COALESCE( s.signature_required, TRUE ) AS is_signature_required
  FROM link_orders__shipment los
       JOIN shipment s ON los.shipment_id = s.id
       JOIN shipment_type st ON s.shipment_type_id = st.id
       JOIN shipment_class sc ON s.shipment_class_id = sc.id
       JOIN shipment_status ss ON s.shipment_status_id = ss.id
       JOIN shipping_charge shc ON s.shipping_charge_id = shc.id
       JOIN shipping_charge_class scc ON shc.class_id = scc.id
       JOIN shipping_account sa ON s.shipping_account_id = sa.id
       JOIN carrier car ON sa.carrier_id = car.id
  LEFT JOIN shipment_hold sh ON (sh.shipment_id = s.id AND (sh.release_date IS NULL OR sh.release_date > NOW()))
      WHERE los.orders_id = ?
   ORDER BY s.id asc
};

    my $sth = $dbh->prepare($qry);
    $sth->execute($order_id);

    my %shipments;

    while ( my $shipment = $sth->fetchrow_hashref() ) {
        $shipment->{gift_message} = decode_db( $shipment->{gift_message} );
        $shipments{ $$shipment{id} } = $shipment;
    }
    return \%shipments;
}

sub get_shipment_info :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my $qry = qq{
SELECT  s.id,
        los.orders_id,
        to_char(s.date, 'DD-MM-YYYY  HH24:MI') AS date,
        s.gift,
        s.gift_message,
        s.outward_airway_bill,
        s.return_airway_bill,
        s.email,
        s.telephone,
        s.mobile_telephone,
        s.packing_instruction,
        s.shipping_charge,
        s.shipment_type_id,
        s.shipment_class_id,
        s.shipment_status_id,
        s.shipment_address_id,
        s.comment,
        s.gift_credit,
        s.store_credit,
        s.destination_code,
        s.shipping_account_id,
        s.has_packing_started,
        to_char(s.sla_cutoff, 'DD-MM-YYYY  HH24:MI') AS sla_cutoff,
        sc.class,
        st.type,
        ss.status,
        shc.id AS shipping_charge_id,
        shc.description AS shipping_name,
        shc.sku AS shipping_charge_sku,
        shc.premier_routing_id as shipping_charge_premier_routing_id,
        scc.id AS shipping_class_id,
        scc.class AS shipping_class,
        car.name AS carrier,
        sa.name AS shipping_account_name,
        sa.account_number AS shipping_account_number,
        s.premier_routing_id,
        pr.description AS premier_routing_description,
        s.real_time_carrier_booking,
        s.av_quality_rating,
        s.signature_required,
        COALESCE( s.signature_required, TRUE ) AS is_signature_required,
        s.nominated_delivery_date,
        s.force_manual_booking,
        s.has_valid_address
FROM    shipment s
            LEFT JOIN link_orders__shipment los ON s.id = los.shipment_id
            LEFT OUTER JOIN premier_routing pr ON s.premier_routing_id = pr.id,
        shipment_type st,
        shipment_class sc,
        shipment_status ss,
        shipping_charge shc,
        shipping_charge_class scc,
        shipping_account sa
            LEFT JOIN carrier car ON sa.carrier_id = car.id
WHERE   s.id = ?
AND     s.shipment_type_id = st.id
AND     s.shipment_class_id = sc.id
AND     s.shipment_status_id = ss.id
AND     s.shipping_charge_id = shc.id
AND     shc.class_id = scc.id
AND     s.shipping_account_id = sa.id
ORDER BY s.id ASC
};

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my $shipment = $sth->fetchrow_hashref() // return undef;

    $shipment->{is_premier} = (
        $shipment->{shipment_type_id} == $SHIPMENT_TYPE__PREMIER
    );

    $shipment->{nominated_delivery_date} = XTracker::Database::Row->transform(
        $shipment->{nominated_delivery_date},
        "DateStamp",
    );

    $shipment->{gift_message} = decode_db( $shipment->{gift_message} );

    return $shipment;
}

=head2 get_shipment_item_voucher_usage

Returns the orders that the voucher was used for.

=head3 NOTE:

Currently the search checks the source != 'AMEX' - this may need to be changed
to a 'source IS NULL' as we do more promotions, though this is already there.
WTF, someone investigate if this breaks.

=cut

sub get_shipment_item_voucher_usage  :Export(){
    my ($schema, $shipment_item_id) = @_;

    die "expecting params schema, shipment_item_id"
        unless $schema->can('resultset');

    # get code for shipment_item
    my $id = $schema->resultset('Public::ShipmentItem')
    ->find($shipment_item_id)->voucher_code->id;

    # can't call search_related 'order' as it confuses pg
    my @tender = $schema->resultset('Orders::Tender')
        ->search({voucher_code_id => $id, source => [ {'!=' => 'AMEX' }, { 'is' => undef } ] }, { join => 'voucher_instance'});

    # return list of orders
    return map { $_->order } @tender;
}

sub get_country_info :Export(:DEFAULT) {
    my ( $dbh, $country ) = @_;

    my $qry = "SELECT
            c.*,
            sb.sub_region
        FROM
            country c,
            sub_region sb
        WHERE
            c.country = ?
            AND c.sub_region_id = sb.id;";

    my $sth = $dbh->prepare($qry);
    $sth->execute($country);

    my $info = $sth->fetchrow_hashref();
    return $info;
}

sub get_country_shipment_type :Export(:DEFAULT) {
    my ( $dbh, $country, $channel_id ) = @_;

    my $qry = "SELECT shipment_type_id
                FROM country_shipment_type
                WHERE country_id = (SELECT id FROM country WHERE country = ?)
                AND channel_id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($country, $channel_id);

    my $info = $sth->fetchrow_hashref();
    return $info->{shipment_type_id} || undef;
}

sub get_shipment_boxes :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    # DCS-1210: Have renamed field 'licence_plate_number' to 'tracking_number'
    my $qry
        = "SELECT sb.id as shipment_box_id, sb.box_id, sb.tracking_number, sb.inner_box_id, b.box, b.weight, b.volumetric_weight, ib.inner_box,
            sb.outward_box_label_image, sb.return_box_label_image
            FROM shipment_box sb LEFT JOIN inner_box ib ON sb.inner_box_id = ib.id, box b
            WHERE sb.shipment_id = ?
            AND sb.box_id = b.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my %shipments;

    while ( my $shipment = $sth->fetchrow_hashref() ) {
        $shipments{ $$shipment{shipment_box_id} } = $shipment;
    }
    return \%shipments;
}

sub get_shipment_ddu_status :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my $qry
        = "SELECT id FROM shipment_flag WHERE shipment_id = ? AND flag_id = $FLAG__DDU_PENDING";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my $pending = 0;

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $pending = $row->[0];
    }
    return $pending;
}

### Subroutine : get_shipment_preorder_status        ###
# usage        :                                  #
# description  :  returns value if shipment has Pre-Order flag set     #
# parameters   :   shipment_id                               #
# returns      :   0 or flag_id                               #

sub get_shipment_preorder_status :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my $qry = "SELECT id FROM shipment_flag WHERE shipment_id = ? AND flag_id = $FLAG__PRE_DASH_ORDER";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my $pending = 0;

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $pending = $row->[0];
    }
    return $pending;
}

sub _get_shipment_item_operator_name {
    my ($dbh,$item_id)=@_;

    my $qry=q{SELECT o.name
                FROM operator o
                JOIN shipment_item_status_log sl ON o.id=sl.operator_id
                JOIN shipment_item si ON sl.shipment_item_id=si.id
               WHERE sl.shipment_item_status_id=?
                 AND si.id=?
               ORDER BY sl.date DESC
               LIMIT 1};

    my $sth = $dbh->prepare($qry);

    $sth->execute($SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION, $item_id);

    if ( my $row = $sth->fetchrow_arrayref ) {
        return $row->[0];
    }
    else {
        return;
    }
}

sub get_shipment_item_info :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    unless ( is_valid_database_id( $shipment_id ) ) {
        Carp::carp( q{Don't call this sub if you're not going to pass it a shipment_id} );
        return {};
    }

    # get normal products first
    my $qry =
    "SELECT si.id, si.shipment_id, si.variant_id, si.unit_price, si.tax, si.duty, si.shipment_item_status_id, si.special_order_flag, si.shipment_box_id, si.qc_failure_reason, si.container_id, si.is_incomplete_pick, sis.status, v.size_id, sku_padding(v.size_id) as sku_size, v.designer_size_id, v.legacy_sku, v.product_id, s.size, s2.size as designer_size, d.designer, pa.name, pa.description, pa.long_description, pa.editors_comments, ss.short_name, c.colour, sa.weight, v.product_id || '-' || sku_padding(v.size_id) as sku, 0 as voucher_code_id, si.returnable_state_id, si.sale_flag_id, si.pws_ol_id, si.gift_recipient_email, sa.is_hazmat, pl.human_name as pack_lane_name
                FROM shipment_item si
                     LEFT JOIN container cn ON (si.container_id = cn.id)
                     LEFT JOIN pack_lane pl ON (cn.pack_lane_id = pl.pack_lane_id),
                     shipment_item_status sis, variant v, size s, size s2, product p, designer d, product_attribute pa, size_scheme ss, colour c, shipping_attribute sa
                WHERE si.shipment_id = ?
                AND si.shipment_item_status_id = sis.id
                AND si.variant_id = v.id
                AND v.size_id = s.id
                AND v.designer_size_id = s2.id
                AND v.product_id = p.id
                AND p.designer_id = d.id
                AND v.product_id = pa.product_id
                AND pa.size_scheme_id = ss.id
                AND p.colour_id = c.id
                AND p.id = sa.product_id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my %items;
    my $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );

    my $shipment = $schema->resultset('Public::Shipment')
                          ->find($shipment_id);

    # If we pass a non-existent shipment return an empty hash
    return {} unless $shipment;

    my $is_on_mrp = $shipment->get_channel->is_on_mrp;

    while ( my $item = $sth->fetchrow_hashref() ) {

        # make sure that fetched container ID is instance of Barcode
        $item->{container_id} &&= NAP::DC::Barcode::Container->new_from_id(
            $item->{container_id},
        );

        $items{ $$item{id} } = $item;

        $item->{display_description} = $is_on_mrp
                                     ? $item->{editors_comments}
                                     : $item->{long_description};

        # This should no longer be necessary
        # $items{ $$item{id} }{designer} = "Chlo&eacute;"
        #     if ( $items{ $$item{id} }{designer} =~ m/^Chlo/ );

        # Decode strings that might contain utf8
        foreach (qw[name description display_description editors_comments
                    gift_recipient_email long_description designer]) {
            $item->{$_} = decode_db($item->{$_});
        }

        # I shall re-write the previous SELECT to have some outer joins in due course,
        # once this works...
        if (
            ( $$item{shipment_item_status_id} == $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION ) ||
            (
                $$item{shipment_item_status_id} == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING &&
                $$item{qc_failure_reason}
            )
        ) {
            $items{ $$item{id} }{qc_packer_name} = _get_shipment_item_operator_name( $dbh, $$item{id} );
            $items{ $$item{id} }{is_qc_failed}   = 1;
            $items{ $$item{id} }{is_missing}     = ($items{ $$item{id} }{container_id}? '': 1);
        }

        if ($$item{container_id}) {
            $items{ $$item{id} }{container_is_pigeonhole} = 1
                if $item->{container_id}->is_type('pigeon_hole');
            $items{ $$item{id} }{container_status_id} =
                 get_container_by_id($schema,$items{ $$item{id} }{container_id})->status_id;
        }
    }

    # get voucher products second
    my $vouchers= $shipment->search_related('shipment_items',
        { shipment_id => $shipment_id,
          voucher_variant_id => { 'IS NOT' => undef } },
        { prefetch => 'voucher_variant' } );

    while ( my $item = $vouchers->next ) {
        $items{ $item->id } = {
                id          => $item->id,
                shipment_id => $item->shipment_id,
                variant_id  => $item->voucher_variant_id,
                unit_price  => $item->unit_price,
                tax         => $item->tax,
                duty        => $item->duty,
                returnable_state_id  => $item->returnable_state_id,
                sale_flag_id => $item->sale_flag_id,
                gift_from   => $item->gift_from,
                gift_to     => $item->gift_to,
                gift_message=> $item->gift_message,
                pws_ol_id   => $item->pws_ol_id,
                voucher_code_id => $item->voucher_code_id,
                voucher_code    => ( defined $item->voucher_code_id ? $item->voucher_code->code : '' ),
                shipment_item_status_id => $item->shipment_item_status_id,
                special_order_flag => $item->special_order_flag,
                shipment_box_id => $item->shipment_box_id,
                status      => $item->shipment_item_status->status,
                size_id     => $item->voucher_variant->size_id,
                sku_size    => sprintf('%03d', $item->voucher_variant->size_id ),
                designer_size_id => $item->voucher_variant->size_id,
                legacy_sku  => '',
                product_id  => $item->voucher_variant->voucher_product_id,
                size        => $item->voucher_variant->size_id,
                designer_size => $item->voucher_variant->size_id,
                designer    => $item->voucher_variant->product->designer,
                name        => $item->voucher_variant->product->name,
                long_description => $item->voucher_variant->product->name,
                short_name  => '',
                colour      => 'Unknown',
                weight      => $item->voucher_variant->product->weight || 0,
                sku         => $item->voucher_variant->sku,
                voucher     => 1,
                is_physical => $item->voucher_variant->product->is_physical,
                qc_failure_reason => $item->qc_failure_reason,
                container   => $item->container_id,     # <- keep for a while
                container_id=> $item->container_id,     # <- the inevitable future
                is_qc_failed=> $item->is_qc_failed || undef,
                is_missing  => $item->is_missing,
                gift_recipient_email => $item->gift_recipient_email || undef,
                display_description => $item->voucher_variant->product->name,
                is_hazmat   => 0,
            };

        # if there's a clean way to do this on the previous DBIC call,
        # please re-write and show me
        if ($item->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION) {
            $items{ $item->id }->{qc_packer_name} = _get_shipment_item_operator_name( $dbh, $item->id );
        }
    }
    return \%items;
}

sub get_shipment_item_status :Export(:DEFAULT) {
    my ( $dbh, $shipment_item_id ) = @_;

    my $status = 0;

    my $qry
        = "SELECT shipment_item_status_id FROM shipment_item WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_item_id);
    while ( my $row = $sth->fetchrow_arrayref ) {
        $status = $row->[0];
    }
    return $status;
}

sub get_shipment_item_by_sku :Export(:DEFAULT) {
    my ( $dbh, $shipment_id, $sku ) = @_;

    my %qry = (
        'new' =>
            'SELECT si.id
             FROM   shipment_item si
                    LEFT JOIN variant v ON v.id = si.variant_id
                    LEFT JOIN voucher.variant vv ON vv.id = si.voucher_variant_id
             WHERE  si.shipment_id = ?
             AND (
               ( v.product_id = ? AND v.size_id = ? )
               OR ( vv.voucher_product_id = ? )
             )
             ORDER BY si.shipment_item_status_id DESC,si.id DESC',

        'old' => 'SELECT si.id FROM shipment_item si, variant v WHERE si.shipment_id = ? AND si.variant_id = v.id AND v.legacy_sku = ? order by si.shipment_item_status_id desc',
    );

    my $sth;

    if ( $sku =~ m/-/ ) {
        my ($product_id, $size_id) = split /-/, $sku;
        $sth = $dbh->prepare( $qry{"new"} );
        $sth->execute( $shipment_id, $product_id, $size_id, $product_id );
    }
    else {
        $sth = $dbh->prepare( $qry{"old"} );
        $sth->execute($shipment_id, $sku);
    }

    my $shipment_item_id = 0;

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $shipment_item_id = $row->[0];
    }
    return $shipment_item_id;
}

sub insert_shipment_note :Export(:DEFAULT)
{
    my ($dbh, $ship_id, $op_id, $note) = @_;

    my $sql = "INSERT INTO shipment_note (shipment_id, note, note_type_id, operator_id, date) VALUES (?, ?, ?, ?, NOW())";
    my $sth = $dbh->prepare($sql);
    $sth->execute($ship_id, $note, $NOTE_TYPE__SHIPPING, $op_id);
    $sth->finish;
}

sub get_shipment_notes :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my $qry
        = "SELECT sn.id, to_char(sn.date, 'DD-MM-YY HH24:MI') as date, extract(epoch from sn.date) as date_sort, sn.note, sn.operator_id, nt.description, op.name, d.department
            FROM shipment_note sn, note_type nt, operator op LEFT JOIN department d ON op.department_id = d.id
            WHERE sn.shipment_id = ?
            AND sn.note_type_id = nt.id
            AND sn.operator_id = op.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my %notes;

    while ( my $note = $sth->fetchrow_hashref() ) {
        $note->{$_} = decode_db( $note->{$_} ) for (qw( note ));
        $notes{ $$note{id} } = $note;
    }
    return \%notes;
}

sub get_shipment_status_log :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my $qry
        = "SELECT id, to_char(date, 'DD-MM-YYYY  HH24:MI') as display_date, shipment_status_id, operator_id FROM shipment_status_log WHERE shipment_id = ? ORDER BY date ASC";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my %log;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $log{ $$row{id} } = $row;
    }
    return \%log;
}

sub get_shipment_emails :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my $qry
        = "SELECT s.id, op.name as operator, to_char(date, 'DD-MM-YYYY  HH24:MI') as date, ct.name as template FROM shipment_email_log s, operator op, correspondence_templates ct WHERE s.shipment_id = ? AND s.operator_id = op.id and s.correspondence_templates_id = ct.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my %shipments;

    while ( my $shipment = $sth->fetchrow_hashref() ) {
        $shipments{ $$shipment{id} } = $shipment;
    }
    return \%shipments;
}

# TODO Need to look at merging/wrapping this with or around
# Public::Shipment::update_status
sub update_shipment_status :Export(:DEFAULT) {
    my ( $dbh, $id, $status_id, $operator_id )   = @_;
    my $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );

    my $shipment = $schema->resultset('Public::Shipment')->find($id);
    my $virt_vouch_only_dispatched  = 0;

    # Any hold (check for virtual voucher autopick/dispatch)
    my $was_on_any_hold = $shipment->is_on_hold;

    $shipment->result_source->schema->txn_do(sub {
        $shipment->change_status_to($status_id, $operator_id);

        # Do nothing else unless the shipment was released from any hold
        return unless $shipment->is_processing;
        return unless $was_on_any_hold;

        # The shipment's been released, clear the below hold records and
        # validate the address again
        $shipment->clear_shipment_hold_records_for_reasons(
            $SHIPMENT_HOLD_REASON__INCOMPLETE_ADDRESS,
            $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS,
        );
        # Note that if the address fails due to non-Latin-1 characters this
        # will put the shipment on hold
        $shipment->validate_address({ operator_id => $operator_id });

        # If we're still processing, check the address and hold if it's invalid
        $shipment->hold_if_invalid({ operator_id => $operator_id })
            if $shipment->discard_changes->is_processing;

        # If we're still processing check if we need to hold for third party
        # payment reasons
        $shipment->update_status_based_on_third_party_psp_payment_status($operator_id)
            if $shipment->discard_changes->is_processing;

        # If we're not processing any more, we're done
        return unless $shipment->discard_changes->is_processing;

        # We shouldn't have a hold reason if we're not on hold any more, so
        # delete any if we still have some
        $shipment->shipment_holds->delete;

        $shipment->apply_SLAs();
        if ( $shipment->is_standard_class ){
            $shipment->auto_pick_virtual_vouchers( $operator_id );
            $virt_vouch_only_dispatched
                = $shipment->dispatch_virtual_voucher_only_shipment( $operator_id );
        }

        # Shipments coming off hold should be reallocated
        $shipment->allocate({ operator_id => $operator_id });

        # Shipment is now processing, so send update to Mercury - we have the
        # usual message sending/transaction race condition here - don't know
        # which way round cause us less pain, so keeping it in the transaction
        # is just an arbitrary decision
        $shipment->send_release_update();
    });

    # Shipment is on hold so send an update to Mercury
    $shipment->send_hold_update() if $shipment->is_on_hold;

    return $virt_vouch_only_dispatched;
}

sub log_shipment_status :Export(:DEFAULT) {
    my ( $dbh, $id, $status, $operator_id ) = @_;

    my $qry
        = "INSERT INTO shipment_status_log VALUES (default, ?, ?, ?, current_timestamp)";

    my $sth = $dbh->prepare($qry);

    $sth->execute( $id, $status, $operator_id );
    return last_insert_id( $dbh, 'shipment_status_log_id_seq' );
}

sub update_shipment_item_status :Export(:DEFAULT) {
    my ( $dbh, $id, $status ) = @_;

    my $qry
        = "UPDATE shipment_item SET shipment_item_status_id = ? WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $status, $id );
}

sub update_shipment_item_pricing :Export(:DEFAULT) {
    my ( $dbh, $id, $price, $tax, $duty ) = @_;

    my $qry
        = "UPDATE shipment_item SET unit_price = ?, tax = ?, duty = ? WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $price, $tax, $duty, $id );
}

sub log_shipment_item_status :Export(:DEFAULT) {
    my ( $dbh, $id, $status, $operator_id ) = @_;

    my $qry
        = "INSERT INTO shipment_item_status_log VALUES (default, ?, ?, ?, current_timestamp)";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $id, $status, $operator_id );
}

sub update_shipment_type :Export(:DEFAULT) {
    my ( $dbh, $id, $type_id ) = @_;

    my $qry = "UPDATE shipment SET shipment_type_id = ? WHERE id = ?";

    my $sth = $dbh->prepare($qry);

    $sth->execute( $type_id, $id );
}

sub update_shipment_shipping_charge_id :Export(:DEFAULT) {
    my ( $dbh, $id, $charge_id ) = @_;

    # Update the shipment with the Shipping Charge and the Shipping
    # Charge's premier_routing_id (fall back to premier_routing_id 0)
    my $qry = "
UPDATE shipment
SET
    shipping_charge_id = ?,
    premier_routing_id = COALESCE(
        (
            SELECT pr.id
            FROM
                premier_routing pr, shipping_charge sc
            WHERE
                    pr.id = sc.premier_routing_id
                AND sc.id = ?
        ),
        0
    )
WHERE id = ?
";
     my $sth = $dbh->prepare($qry);
     $sth->execute( $charge_id, $charge_id, $id );
}

sub update_shipment_address :Export(:DEFAULT) {
    my ( $dbh, $id, $shipment_address_id ) = @_;

    my $qry = "UPDATE shipment SET shipment_address_id = ? WHERE id = ?";

    my $sth = $dbh->prepare($qry);

    $sth->execute( $shipment_address_id, $id );
}

sub log_shipment_address_change :Export(:DEFAULT) {
    my ( $dbh, $shipment_id, $change_from, $change_to, $operator_id ) = @_;

    my $qry
        = "INSERT INTO shipment_address_log VALUES (default, ?, ?, ?, ?, current_timestamp)";

    my $sth = $dbh->prepare($qry);

    $sth->execute( $shipment_id, $change_from, $change_to, $operator_id );
}

sub get_shipment_address_log :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my $qry
        = "SELECT   sal.*,
                    TO_CHAR(sal.date, 'DD-MM-YYYY  HH24:MI') AS date,
                    op.name
           FROM     shipment_address_log sal,
                    operator op
           WHERE sal.shipment_id = ?
           AND   sal.operator_id = op.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my %docs;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $docs{ $$row{id} } = $row;
    }
    return \%docs;
}

sub update_shipment_shipping_charge :Export(:DEFAULT) {
    my ( $dbh, $id, $shipping_charge ) = @_;

    my $qry = "UPDATE shipment SET shipping_charge = ? WHERE id = ?";

    my $sth = $dbh->prepare($qry);

    $sth->execute( $shipping_charge, $id );
}

sub set_shipment_flag :Export(:DEFAULT) {
    my ( $dbh, $id, $flag_id ) = @_;

    my $qry = "INSERT INTO shipment_flag VALUES (default, ?, ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute($flag_id, $id);
}

sub delete_shipment_ddu_flags :Export(:DEFAULT) {
    my ( $dbh, $id ) = @_;

    my $qry = "DELETE FROM shipment_flag WHERE flag_id IN (SELECT flag_id FROM flag WHERE flag_type_id = $FLAG_TYPE__DDU) AND shipment_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($id);
}

sub get_shipment_documents :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my $qry = "SELECT pl.id,
                      pl.document,
                      pl.file,
                      to_char(pl.date, 'DD-MM-YYYY  HH24:MI') AS date,
                      pl.printer_name AS name
                 FROM shipment_print_log pl
                WHERE pl.shipment_id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my %docs;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $docs{ $$row{id} } = $row;
    }
    return \%docs;
}

sub get_shipment_promotions :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my %data = ();

    # get shipment level promos
    my $qry = "select promotion, value from link_shipment__promotion where shipment_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{promotion} }{shipping} = $row->{value};
    }

    # get item level promos
    $qry = "select shipment_item_id, promotion, unit_price, tax, duty from link_shipment_item__promotion where shipment_item_id in (select id from shipment_item where shipment_id = ?)";
    $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{promotion} }{items}{ $row->{shipment_item_id} } = $row;
    }
    return \%data;
}

sub reset_shipment_item_promotion :Export(:DEFAULT) {
    my ( $dbh, $args ) = @_;

    my $qry = "UPDATE link_shipment_item__promotion SET unit_price = ?, tax = ?, duty = ? WHERE shipment_item_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $args->{unit_price}, $args->{tax}, $args->{duty}, $args->{shipment_item_id} );
    return;
}

sub get_shipment_markdowns :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my %data = ();

    my $qry = "select link.shipment_item_id, pa.percentage
                from link_shipment_item__price_adjustment link, price_adjustment pa
                where link.shipment_item_id in (select id from shipment_item where shipment_id = ?)
                and link.price_adjustment_id = pa.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{shipment_item_id} } = $row->{percentage};
    }
    return \%data;
}

### Subroutine : get_shipment_box_id               ###
# usage        :                                  #
# description  :     returns the next available shipment box id from the database                             #
# parameters   :      nowt                            #
# returns      :       shipment box id                           #

sub get_shipment_box_id :Export(:DEFAULT) {
    my ( $dbh ) = @_;

    my $qry = "SELECT nextval('shipment_box_id_seq')";
    my $sth = $dbh->prepare($qry);
    $sth->execute( );

    my $row = $sth->fetchrow_arrayref();
    return 'C' . $row->[0];
}

sub check_shipping_input_form :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my $qry = "select count(*) from shipment_print_log where shipment_id = ? and document = 'Shipping Input Form'";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my $count = 0;

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $count = $row->[0];
    }
    return $count;
}

sub get_shipment_log :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my $qry = "SELECT   ssl.id,
                        TO_CHAR(ssl.date, 'DD-MM-YY HH24:MI') AS date,
                        ssl.operator_id,
                        ss.status,
                        op.name,
                        d.department
               FROM     shipment_status_log ssl,
                        shipment_status ss,
                        operator op
                            LEFT JOIN department d ON op.department_id = d.id
               WHERE ssl.shipment_id = ?
               AND   ssl.shipment_status_id = ss.id
               AND   ssl.operator_id = op.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my %log;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $log{ $$row{id} } = $row;
    }
    return \%log;
}

sub get_shipment_item_status_log {
    my ( $dbh, $shipment_id ) = @_;

    my $qry = "SELECT   sisl.id,
                        sisl.shipment_item_id,
                        sisl.date,
                        extract(epoch from sisl.date) AS epoch,
                        sisl.operator_id,
                        sis.status,
                        op.name,
                        d.department,
                        v.product_id || '-' || sku_padding(v.size_id) AS sku
               FROM     shipment_item_status_log sisl,
                        shipment_item_status sis,
                        operator op
                            LEFT JOIN department d ON op.department_id = d.id,
                        shipment_item si,
                        super_variant v
               WHERE    sisl.shipment_item_id = si.id
               AND      si.shipment_id = ?
               AND      ( si.variant_id = v.id OR si.voucher_variant_id = v.id )
               AND      sisl.shipment_item_status_id = sis.id
               AND      sisl.operator_id = op.id
               ORDER BY sisl.date,
                        sisl.shipment_item_id,
                        sisl.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    return $sth->fetchall_arrayref({});
}

sub get_shipment_item_container_log {
    my ( $schema, $shipment_id ) = pos_validated_list( \@_,
        { isa => 'XTracker::Schema' },
        { isa => 'Int' },
    );

    return $schema->resultset('Public::ShipmentItemContainerLog')->search(
        { 'shipment_item.shipment_id' => $shipment_id },
        {
            join         => 'shipment_item',
            order_by     => [qw/me.created_at me.shipment_item_id me.id/],
        }
    );
}

=head2 get_shipment_item_log($schema, $shipment_id) : \@log_data

Interleave the data returned by L<get_shipment_item_status_log> and
L<get_shipment_item_container_log>.

=cut

sub get_shipment_item_log :Export(:DEFAULT) {
    my ( $schema, $shipment_id ) = pos_validated_list( \@_,
        { isa => 'XTracker::Schema' },
        { isa => 'Int' },
    );

    my $status_logs = get_shipment_item_status_log(
        $schema->storage->dbh, $shipment_id
    );

    # Get the container logs with the same keys as the status logs
    my $container_logs = [
        map { +{
            id               => $_->id,
            shipment_item_id => $_->shipment_item_id,
            date             => $schema->format_datetime($_->created_at),
            epoch            => $_->created_at->epoch,
            operator_id      => $_->operator_id,
            status           => $_->status_message,
            name             => $_->operator->name,
            department       => $_->operator->department->department,
            sku              => $_->shipment_item->get_sku,
            is_container_log => 1,
        } } get_shipment_item_container_log($schema, $shipment_id)
            ->search(undef, {
                prefetch => {
                    operator => 'department',
                    shipment_item => [ qw/variant voucher_variant/ ],
                },
            })
    ];

    # Interleave the two
    return [
        sort {
            int $a->{epoch} <=> int $b->{epoch}
         || $a->{shipment_item_id} <=> $b->{shipment_item_id}
         || ($a->{is_container_log}//0) <=> ($b->{is_container_log}//0)
         || $a->{id} <=> $b->{id}
        } @{$status_logs||[]}, @{$container_logs||[]}
    ];
}

sub check_shipment_packed :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my $qry = "SELECT shipment_item_status_id FROM shipment_item WHERE shipment_id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my $packed = 0;

    while ( my $item = $sth->fetchrow_hashref() ) {
        if (number_in_list($item->{shipment_item_status_id},
                           $SHIPMENT_ITEM_STATUS__PACKED,
                           $SHIPMENT_ITEM_STATUS__DISPATCHED,
                       ) ) {
            $packed = 1;
        }
    }
    return $packed;
}

### Subroutine : get_shipping_address                   ###
# usage        : get_shipping_address($dbh,$shipment_id)  #
# description  :                                          #
# parameters   :                                          #
# returns      : hashref representing address data        #
sub get_shipping_address :Export(:DEFAULT) {
    my ($dbh, $shipment_id) = @_;
    my ($sql, $sth, $res);

    $sql = q{
        SELECT  s.id as shipment_id,
                oa.address_line_1,
                oa.address_line_2,
                oa.towncity,
                oa.county,
                oa.country,
                oa.postcode,
                c.code as country_code,
                to_char(s.date, 'YYYY-MM-DD HH24:MI:SS.000-00:00') as date
          FROM  shipment s,
                order_address oa,
                country c
         WHERE  s.id = ?
           AND  s.shipment_address_id = oa.id
           AND  oa.country = c.country
    };

    # prepare and execute
    $sth = $dbh->prepare($sql);
    $sth->execute($shipment_id);
    # fetch matching row and cleanup
    $res = $sth->fetchrow_hashref();
    $sth->finish;
    $res->{$_} = decode_db( $res->{$_} ) for (qw(
        address_line_1
        address_line_2
        towncity
        county
        postcode
        country
    ));
    return $res;
}


### Subroutine : is_premier                                  ###
# usage        : if (is_premier($dbh, {country  => ...,        #
#              :                       postcode => ...})) {    #
# description  : Determines if a given address (postcode) is   #
#              : in the premier shipping area                  #
# parameters   : $dbh, $params->{...}                          #
#              :       country                                 #
#              :       postcode                                #
# returns      : true or false                                 #

sub is_premier :Export() {
    my ($dbh, $params) = @_;

    my $is_prem = 0;

    eval {
        ### get shipping options for postcode
        my %shipping_options = get_postcode_shipping_charges($dbh, $params);

        ### check if Same Day (Premier) delivery available
        foreach my $id ( keys %shipping_options ) {
            if ( $shipping_options{$id}{"class"} eq "Same Day" ) {
                $is_prem = 1;
            }
        }
    };

    if ($@) {
        # Invalid postcodes and such can cause an error. In this
        # instance, we probably don't want it to be fatal
        carp $@;
    }
    return $is_prem;
}

=head2 get_address_shipping_charges

    %hash   = get_address_shipping_charges(
        $dbh,
        $channel_id,
        # address hash ref
        {
            country     => 'country',
            postcode    => 'post code',
            state       => 'state',
        },
        # optional other arguments hash ref
        {
            exclude_nominated_day   => 1 or 0,                  # Exclude nominated day charges from results.

            always_keep_sku         => 'shipping_charge-sku',   # Always retain a charge, normally the current SKU.

            customer_facing_only    => 1 or 0,                  # Return only 'is_customer_facing' charges.

            exclude_for_shipping_attributes => {                # A HashRef of Product Shipping Attributes to be
                product_id => {                                 # used in excluding charges from being returned
                    shipping => attributes                      # which can't be used if some attributes are set,
                    ...
                },
                ...
            },
        },
    );

Returns a HASH of Shipping Charges from the 'shipping_charge' table based on the Sales Channel and an Address to Ship to.

=cut

sub get_address_shipping_charges : Export() {
    my ($dbh, $channel_id, $address, $args )    = @_;

    if ( defined $args && ref( $args ) ne 'HASH' ) {
        confess "4th Argument needs to be a HashRef if passed to '" . __PACKAGE__ . "::get_address_shipping_charges'";
    }

    my $exclude_nominated_day   = $args->{exclude_nominated_day} || 0;
    my $always_keep_sku         = $args->{always_keep_sku} || "";
    my $customer_facing_only    = $args->{customer_facing_only} || 0;
    my $exclude_for_shipping_attributes = $args->{exclude_for_shipping_attributes};

    my %id_shipping_charge = (
        get_postcode_shipping_charges(
            $dbh,
            {
                country    => $address->{country},
                postcode   => $address->{postcode},
                channel_id => $channel_id,
            },
        ),
        get_state_shipping_charges(
            $dbh,
            {
                country    => $address->{country},
                state      => $address->{state},
                channel_id => $channel_id,
            },
        ),
        get_country_shipping_charges(
            $dbh,
            {
                country    => $address->{country},
                channel_id => $channel_id,
            },
        ),
    );

    for my $shipping_charge (values %id_shipping_charge) {
        $shipping_charge->{is_nominated_day}
            = !! $shipping_charge->{latest_nominated_dispatch_daytime};
    }

    if($exclude_nominated_day) {
        for my $id (keys %id_shipping_charge) {
            my $shipping_charge = $id_shipping_charge{$id};
            next if(   $always_keep_sku eq $shipping_charge->{sku} );
            next if( ! $shipping_charge->{is_nominated_day} );
            delete $id_shipping_charge{$id};
        }
    }

    if($customer_facing_only) {
        for my $id (keys %id_shipping_charge) {
            next if( $id_shipping_charge{$id}->{is_customer_facing} );
            delete $id_shipping_charge{$id};
        }
    }

    if ( $exclude_for_shipping_attributes ) {
        my $new_charges = XT::Rules::Solve->solve(
            'Shipment::exclude_shipping_charges_on_restrictions' => {
                shipping_charges_ref=> \%id_shipping_charge,
                shipping_attributes => $exclude_for_shipping_attributes,
                always_keep_sku     => $always_keep_sku,
                channel_id          => $channel_id,
            },
        );
        %id_shipping_charge = %{ $new_charges };
    }

    return %id_shipping_charge;
}

### Subroutine : get_postcode_shipping_charges                                  ###
# usage        :                                                                #
# description  : Calculates the postcode level shipping charges for a shipment. #
# parameters   : $dbh, $params->{...}                                           #
#              : country                                                        #
#              : postcode                                                       #
# returns      : hash {id, sku, description, charge, currency_id, currency, flat_rate, class_id, class }                        #

sub get_postcode_shipping_charges :Export() {
    my ($dbh, $params) = @_;

    return unless $params->{postcode};

    my $schema = get_schema_using_dbh($dbh, 'xtracker_schema');
    my $country = $schema->resultset('Public::Country')->find({
        country => $params->{country}
    });
    return unless $country;

    my $token = XTracker::Postcode::Analyser->extract_postcode_matcher({
        country     => $country,
        postcode    => $params->{postcode}
    });

    # Either we do not understand the format of this country's postcodes, or the postcode
    # itself does not match the known format. Either way we won't bother going any further
    return unless $token;

    my $qry = "
SELECT
    sc.id,
    sc.sku,
    sc.description,
    sc.charge,
    sc.currency_id,
    cur.currency,
    sc.flat_rate,
    sc.class_id,
    sc.latest_nominated_dispatch_daytime,
    sc.premier_routing_id,
    sc.is_customer_facing,
    pr.description as premier_routing_description,
    scc.class
FROM
    postcode_shipping_charge psc,
    shipping_charge sc
        LEFT JOIN premier_routing pr on (pr.id = sc.premier_routing_id),
    currency cur,
    shipping_charge_class scc
WHERE
        psc.postcode = ?
    AND psc.country_id = (select id from country where country = ?)
    AND psc.channel_id = ?
    AND psc.shipping_charge_id = sc.id
    AND sc.currency_id = cur.id
    AND sc.class_id = scc.id
    AND sc.is_enabled IS TRUE
";

    my $sth = $dbh->prepare($qry);
    $sth->execute($token, $params->{country}, $params->{channel_id});

    my %charges;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $charges{ $row->{id} } = decode_db($row);
    }
    return %charges;
}


### Subroutine : get_state_shipping_charges                                     ###
# usage        :                                                                #
# description  : Calculates the state level shipping charges for a shipment.    #
# parameters   : $dbh, $params->{...}                                           #
#              : country                                                        #
#              : state                                                          #
# returns      : hash {id, sku, description, charge, currency_id, currency, flat_rate, class_id, class }                        #

sub get_state_shipping_charges :Export() {
    my ($dbh, $params) = @_;

    my $qry = "
SELECT
    sc.id,
    sc.sku,
    sc.description,
    sc.charge,
    sc.currency_id,
    cur.currency,
    sc.flat_rate,
    sc.class_id,
    sc.latest_nominated_dispatch_daytime,
    sc.premier_routing_id,
    sc.is_customer_facing,
    pr.description as premier_routing_description,
    scc.class
FROM
    state_shipping_charge ssc,
    shipping_charge sc
        LEFT JOIN premier_routing pr on (pr.id = sc.premier_routing_id),
    currency cur,
    shipping_charge_class scc
WHERE
        ssc.state = ?
    AND ssc.country_id = (select id from country where country = ?)
    AND ssc.channel_id = ?
    AND ssc.shipping_charge_id = sc.id
    AND sc.currency_id = cur.id
    AND sc.class_id = scc.id
    AND sc.is_enabled IS TRUE
";

    my $sth = $dbh->prepare($qry);
    $sth->execute($params->{state}, $params->{country}, $params->{channel_id});

    my %charges;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $charges{ $row->{id} } = decode_db($row);
    }
    return %charges;
}

### Subroutine : get_country_shipping_charges                                   ###
# usage        :                                                                #
# description  : Calculates the country level shipping charges for a shipment.  #
# parameters   : $dbh, $params->{...}                                           #
#              : country                                                        #
# returns      : hash {id, sku, description, charge, currency_id, currency, flat_rate, class_id, class }                        #

sub get_country_shipping_charges :Export() {
    my ($dbh, $params) = @_;

    my $qry = "
SELECT
    sc.id,
    sc.sku,
    sc.description,
    sc.charge,
    sc.currency_id,
    cur.currency,
    sc.flat_rate,
    sc.class_id,
    sc.latest_nominated_dispatch_daytime,
    sc.premier_routing_id,
    sc.is_customer_facing,
    pr.description as premier_routing_description,
    scc.class
FROM
    country c,
    country_shipping_charge csc,
    shipping_charge sc
        LEFT JOIN premier_routing pr on (pr.id = sc.premier_routing_id),
    currency cur,
    shipping_charge_class scc
WHERE
        c.country = ?
    AND c.id = csc.country_id
    AND csc.channel_id = ?
    AND csc.shipping_charge_id = sc.id
    AND sc.currency_id = cur.id
    AND sc.class_id = scc.id
    AND sc.is_enabled IS TRUE
";

    my $sth = $dbh->prepare($qry);
    $sth->execute($params->{country}, $params->{channel_id});

    my %charges;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $charges{ $row->{id} } = decode_db($row);
    }
    return %charges;
}


### Subroutine : get_shipping_charge_data                                       ###
# usage        :                                                                #
# description  : get data for a specific shipping charge                        #
# parameters   : $dbh, $id                                                      #                                                       #
# returns      : hash {id, sku, description, charge, currency_id, currency, flat_rate, class_id, class }                        #

sub get_shipping_charge_data :Export() {
    my ($dbh, $id) = @_;

    my $qry = "
SELECT
    sc.id,
    sc.sku,
    sc.description,
    sc.charge,
    sc.currency_id,
    cur.currency,
    sc.flat_rate,
    sc.class_id,
    scc.class
FROM
    shipping_charge sc,
    currency cur,
    shipping_charge_class scc
WHERE
        sc.id = ?
    AND sc.currency_id = cur.id
    AND sc.class_id = scc.id
";

    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

    my $row = $sth->fetchrow_hashref();
    return decode_db($row);
}

sub get_similar_shipping_charge_info :Export(:DEFAULT) {
    my ($dbh, $params, $customer_facing_only) = @_;
    $customer_facing_only ||= 0;
    my $country            = $params->{country};
    my $state              = $params->{county};
    my $postcode           = $params->{postcode};
    my $shipping_charge_id = $params->{shipping_charge_id};
    my $shipping_class_id  = $params->{shipping_class_id};
    my $channel_id         = $params->{channel_id};
    my $shipment_obj       = $params->{shipment_obj};

    # get all shipping charges for the address
    my %shipping_charges = get_address_shipping_charges(
        $dbh,
        $channel_id,
        {
            country  => $country,
            postcode => $postcode,
            state    => $state,
        },
        {
            exclude_nominated_day   => 0,
            always_keep_sku         => "",
            customer_facing_only    => $customer_facing_only,
            (
                $shipment_obj
                ? ( exclude_for_shipping_attributes => $shipment_obj->get_item_shipping_attributes )
                : ()
            ),
        },
    );

    my $shipping_data = undef;
    # check if current shipping charge is still available
    if ( $shipping_charges{$shipping_charge_id} ) {
        $shipping_data = $shipping_charges{$shipping_charge_id};
    }
    # current shipping charge NOT available - try and find new charge of the same class
    else {
        if ( defined $shipping_class_id ) {
            foreach my $id (sort keys %shipping_charges) {
                # find a shipping charge with same class as current one
                if ( $shipping_charges{$id}{class_id} == $shipping_class_id ) {
                    $shipping_data = $shipping_charges{$id};
                }
            }
        }

        # still not matched a new shipping charge - return the cheapest available
        if (!$shipping_data) {
            foreach my $id (sort {$shipping_charges{$b}{charge} <=> $shipping_charges{$a}{charge}} (sort keys %shipping_charges)) {
                $shipping_data = $shipping_charges{$id};
            }
        }
    }
    return $shipping_data;
}

### Subroutine : calc_shipping_charges                                          ###
# usage        :                                                                #
# description  : Calculates all levels of shipping charges for a shipment.      #
# parameters   : $dbh, $params->{...}                                           #
#              : shipping_charge_id                             #
#              : shipping_class_id                              #
#              : country                                        #
#              : county/state                                   #
#              : postcode                                       #
#              : item_count                                     #
#              : order_total                                    #
#              : order_currency_id                              #
# returns      : hash {id, sku, description, charge, currency_id, currency, flat_rate, class_id, class }                        #

sub calc_shipping_charges :Export(:DEFAULT) {
    my ($dbh, $params) = @_;
    my $country           = $params->{country};
    my $item_count        = $params->{item_count};
    my $order_total       = $params->{order_total};
    my $order_currency_id = $params->{order_currency_id};
    my $channel_id        = $params->{channel_id};

    my $shipping_data = get_similar_shipping_charge_info($dbh, $params);
    if (!$shipping_data) {
        die "No shipping charge could be found for the address provided, please check and try again.";
    }

    # Convert into the order currency
    $shipping_data->{charge} = $shipping_data->{charge} * get_currency_conversion_rate(
        $dbh,
        $shipping_data->{currency_id},
        $order_currency_id,
    );

    # If the value of the order is over a certain amount, we give free shipping
    # We specify that amount in our local currency, so we need to do a conversion

    # UPDATE: this feature has been disabled on the website
    # my $free_shipping_amt   = config_var('FreeShipping', 'threshold');
    # my $free_shipping_ccy   = config_var('FreeShipping', 'currency');
    #if ($free_shipping_amt) {
    #   if ((get_currency_conversion_rate($dbh, $order_currency_id, $free_shipping_ccy) * $order_total) > $free_shipping_amt) {
    #       $shipping_data->{charge} = 0.00;
    #   }
    #}

    # for non flat rate shipping charges we charge an additional 25% for each extra item
    if ($shipping_data->{flat_rate} == 0) {
        $shipping_data->{charge} += ( ($shipping_data->{charge} * 0.25) * ($item_count - 1) );
    }

    # Apply taxes to the shipping costs, if there are any
    my $tax_info = get_country_tax_info($dbh, $country, $channel_id);
    # added 'IF' to get rid of warnings of undefined values in log
    if ( defined $tax_info && defined $tax_info->{rate} ) {
        $shipping_data->{charge} += $shipping_data->{charge} * $$tax_info{rate};
    }
    return $shipping_data;
}

sub dispatch_shipment :Export(:DEFAULT) {
    my ( $schema, $data, $operator_id ) = @_;

    if ( !$schema || ref( $schema ) !~ m/Schema/ ) {
        croak "Need to pass a DBIC Schema Connection to '" . __PACKAGE__ . "::dispatch_shipment'";
    }

    my $dbh = $schema->storage->dbh;

    # check shipment is correct status for dispatch (processing)
    if ( $data->{shipment_info}{shipment_status_id} == $SHIPMENT_STATUS__PROCESSING ){
        # shipment status update & logging
        update_shipment_status( $dbh, $data->{shipment_info}{id}, $SHIPMENT_STATUS__DISPATCHED, $operator_id );

        # shipment item status update & logging
        foreach my $shipment_item_id ( keys %{ $data->{shipment_items} } ) {
            if ( $data->{shipment_items}{$shipment_item_id}{shipment_item_status_id} == $SHIPMENT_ITEM_STATUS__PACKED ){
                update_shipment_item_status( $dbh, $shipment_item_id, $SHIPMENT_ITEM_STATUS__DISPATCHED );
                log_shipment_item_status( $dbh, $shipment_item_id, $SHIPMENT_ITEM_STATUS__DISPATCHED, $operator_id );
            }
        }

        $data->{shipment_row} ||= $schema->resultset('Public::Shipment')
                                            ->find( $data->{shipment_info}->{id} );

        # send dispatch email for all non-Premier shipments
        if ( $data->{shipment_info}{shipment_type_id} != $SHIPMENT_TYPE__PREMIER ) {
            my $order_obj   = $data->{shipment_row}->order;

            # get shipping email addresses from the config for channel
            my $customer_locale = ( # get the Customer's Locale so as to get the correct Email Addresses
                                    $order_obj
                                    ? $order_obj->customer->locale
                                    : ''
                                );
            my $shipping_email = shipping_email( $data->{channel}{config_section}, {
                schema  => $schema,
                locale  => $customer_locale,
            } );
            my $dispatch_email = dispatch_email( $data->{channel}{config_section}, {
                schema  => $schema,
                locale  => $customer_locale,
            } );

            # workaround for backward compatability with email template
            $data->{shipment}{outward_airway_bill}  = $data->{shipment_info}{outward_airway_bill};
            $data->{shipment}{carrier}              = $data->{shipment_info}{carrier};

            $data->{customercare_email} = customercare_email( $data->{channel}{config_section}, {
                schema  => $schema,
                locale  => $customer_locale,
            } );

            # use a standard placeholder for the Order Number
            $data->{order_number}   = ( $order_obj ? $order_obj->order_nr : '' );
            my $email_info  = get_and_parse_correspondence_template( $schema, $CORRESPONDENCE_TEMPLATES__DISPATCH_ORDER, {
                                                                channel => $data->{shipment_row}->get_channel,
                                                                data    => $data,
                                                                base_rec=> $data->{shipment_row},
                                                        } );

            my $email_sent  = send_customer_email( {
                                            to          => $data->{order_info}{email},
                                            from        => $dispatch_email,
                                            reply_to    => $shipping_email,
                                            subject     => $email_info->{subject},
                                            content     => $email_info->{content},
                                            content_type=> $email_info->{content_type},
                                        } );

            if ($email_sent == 1){
                $data->{shipment_row}->log_correspondence( $CORRESPONDENCE_TEMPLATES__DISPATCH_ORDER, $operator_id );
            }
        }
    }
    return;
}

### Subroutine : get_box_shipment_id         ###
# usage        :  gives the shipment id from a box number                                #
# description  :                                  #
# parameters   :   box id                               #
# returns      :   shipment id                               #

sub get_box_shipment_id :Export(:DEFAULT) {
    my ( $dbh, $box_id ) = @_;

    my $shipment_id = 0;

    my $qry = "SELECT shipment_id FROM shipment_box WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($box_id);

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $shipment_id = $row->[0];
    }
    return $shipment_id;
}


### Subroutine : check_country_paperwork                ###
# usage        :  gives you the number of shipping diocs required for a country  #
# description  :                                  #
# parameters   :   db handle, shipping country                               #
# returns      :   number of proformas, number of returns proformas                               #

sub check_country_paperwork :Export(:DEFAULT) {
    my ($dbh, $country) = @_;

    my $pro    = 4;
    my $retpro = 4;

    my $qry = "SELECT proforma, returns_proforma FROM country WHERE lower(country) = lower(?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute($country);

    while ( my $row = $sth->fetchrow_arrayref ) {
        $pro    = $row->[0];
        $retpro = $row->[1];
    }
    return $pro, $retpro;
}

### Subroutine : get_product_shipping_attributes                ###
# usage        :   #
# description  :                                  #
# parameters   :   db handle, product id                               #
# returns      :   scientific term, packing note, weight, fabric content, country of origin, hs code            #

sub get_product_shipping_attributes :Export(:DEFAULT) {
    my ( $dbh, $prod_id ) = @_;

    # check if the product is a Voucher
    my $schema  = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    my $voucher = $schema->resultset('Voucher::Product')->find( $prod_id );
    if ( defined $voucher ) {
        return  $voucher->shipping_attributes;
    }
    else {
        my $qry = "SELECT
                    sa.scientific_term,
                    sa.packing_note,
                    sa.dangerous_goods_note,
                    sa.weight,
                    sa.fabric_content,
                    sa.fish_wildlife,
                    sa.fish_wildlife_source,
                    sa.is_hazmat,
                    c.country as country_of_origin,
                    hs.hs_code,
                    pt.product_type,
                    st.sub_type,
                    class.classification
                 FROM shipping_attribute sa
                    LEFT JOIN country c
                        ON sa.country_id = c.id,
                    product p
                    LEFT JOIN hs_code hs
                        ON p.hs_code_id = hs.id
                    LEFT JOIN sub_type st
                        ON p.sub_type_id = st.id
                    LEFT JOIN product_type pt
                        ON p.product_type_id = pt.id
                    LEFT JOIN classification class
                        ON p.classification_id = class.id
                WHERE sa.product_id = ?
                    AND sa.product_id = p.id";

        my $sth = $dbh->prepare($qry);
        $sth->execute($prod_id);
        return decode_db($sth->fetchrow_hashref());
    }
}


### Subroutine : check_fish_wildlife_restriction
# usage        :
# description  : returns 1 if shipment contains a fish/wildlife product
# parameters   : shipment id
# returns      : 0/1

sub check_fish_wildlife_restriction :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my $val = 0;

    my $qry = "select 1
                from shipment s, shipment_item si, variant v, shipping_attribute sa
                where s.id = ?
                and s.id = si.shipment_id
                and si.variant_id = v.id
                and v.product_id = sa.product_id
                and sa.fish_wildlife is true";
    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    while ( my $row = $sth->fetchrow_arrayref ) {
        $val    = $row->[0];
    }
    return $val;
}

### Subroutine : get_outer_boxes                      ###
# usage        :                                  #
# description  :  returns hash of outer boxes for packing per channel    #
# parameters   :                                  #
# returns      :                                  #

sub get_outer_boxes :Export(:DEFAULT) {
    my ( $dbh, $channel_id ) = @_;

    my $qry = "SELECT * FROM box WHERE channel_id = ? AND active IS true";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $channel_id );

    my %boxes;

    while ( my $box = $sth->fetchrow_hashref() ) {
        $boxes{ $box->{id} } = $box;
    }
    return \%boxes;
}


### Subroutine : get_inner_boxes                      ###
# usage        :                                  #
# description  :  returns hash of inner boxes for packing per channel   #
# parameters   :                                  #
# returns      :                                  #

sub get_inner_boxes :Export(:DEFAULT) {
    my ( $dbh, $channel_id ) = @_;

    my $qry = "SELECT * FROM inner_box WHERE channel_id = ? AND active IS true";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $channel_id );

    my %boxes;

    while ( my $box = $sth->fetchrow_hashref() ) {
        $boxes{ $box->{sort_order} } = $box;
    }
    return \%boxes;
}


### Subroutine : check_tax_included                      ###
# usage        :  check_tax_included($dbh, $country)                                    #
# description  :  returns 1 if tax should be included in shipment total calculations for country   #
# parameters   :   country                               #
# returns      :  0/1                                #

sub check_tax_included :Export() {
    my ( $dbh, $country ) = @_;

    my $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );

    XT::Rules::Solve->solve(
        'Shipment::tax_included' => {
            country_record => get_country_data( $schema, $country ),
        }
    );
}

### Subroutine : get_shipping_accounts                      ###
# usage        :                                  #
# description  :  get shipping account data (channel_id, carrier and account name as hash keys)   #
# parameters   :   db handle                               #
# returns      :   hash ref                               #

sub get_shipping_accounts :Export() {
    my ( $dbh ) = @_;

    my $qry = "SELECT CASE WHEN c.name IS NOT NULL THEN c.name ELSE 'Unknown' END AS carrier, sa.id, sa.name, sa.channel_id FROM shipping_account sa LEFT JOIN carrier c ON sa.carrier_id = c.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{channel_id} }{ $row->{carrier} }{ $row->{name} } = $row->{id};
    }
    return \%data;
}


### Subroutine : get_country_shipping_account                      ###
# usage        :                                  #
# description  :  get shipping account id for a given country and sales channel   #
# parameters   :   db handle, postcode                               #
# returns      :   integer                             #

sub get_country_shipping_account :Export() {
    my ( $dbh, $country, $channel_id ) = @_;

    my $shipping_account_id;
    my $qry = "SELECT shipping_account_id FROM shipping_account__country WHERE country = ? AND channel_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($country, $channel_id);
    while ( my $row = $sth->fetchrow_hashref() ) {
        $shipping_account_id = $row->{shipping_account_id};
    }
    return $shipping_account_id;
}


### Subroutine : get_shipment_shipping_account                      ###
# usage        :                                                    #
# description  :  returns shipping account id for a shipment        #
# parameters   :  db handle, shipment data and shipment item data   #
# returns      :   shipping_account_id                               #

sub get_shipment_shipping_account :Export() {
    my ( $dbh, $args ) = @_;

    # validate required args
    foreach my $field ( qw(channel_id country item_data shipping_class) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for get_shipment_shipping_account()';
        }
    }

    # get default carrier for DC from config
    my $default_carrier = config_var('DistributionCentre', 'default_carrier');

    # get default ground carrier if shipping class is ground and config value set
    if ($args->{shipping_class} eq 'Ground') {
        my $default_ground_carrier = config_var(
            'DistributionCentre',
            'default_ground_carrier',
        );
        if($default_ground_carrier) {
            $default_carrier = $default_ground_carrier;
        }
    }

    my $channel_carrier_shipping_account_name_id = get_shipping_accounts($dbh);
    my $carrier_shipping_account_name_id
        = $channel_carrier_shipping_account_name_id ->{ $args->{channel_id} };
    my $shipping_account_name_id
        = $carrier_shipping_account_name_id ->{ $default_carrier };

    my $country_specific_shipping_account_id = get_country_shipping_account(
        $dbh,
        $args->{country},
        $args->{channel_id},
    );
    my $unknown_shipping_account_id
        = $carrier_shipping_account_name_id->{Unknown}->{Unknown};

    my $shipping_account_id = 0;
    # premier shipment - no shipping account
    if ( $args->{shipment_type_id} == $SHIPMENT_TYPE__PREMIER ) {
        $shipping_account_id = $unknown_shipping_account_id;
    }
    # domestic shipment - use domestic shipping account for country or default carrier
    elsif ( $args->{shipment_type_id} == $SHIPMENT_TYPE__DOMESTIC ) {
        $shipping_account_id =
               $country_specific_shipping_account_id
            || $shipping_account_name_id->{'Domestic'}
            || 0;
    }
    # international shipments - use international account default carrier
    elsif (
            $args->{shipment_type_id} == $SHIPMENT_TYPE__INTERNATIONAL
         || $args->{shipment_type_id} == $SHIPMENT_TYPE__INTERNATIONAL_DDU
     ) {
        if( $args->{shipping_class} eq 'Ground' ) {
            $shipping_account_id =
                   $country_specific_shipping_account_id
                || $shipping_account_name_id->{'International Road'}
                || $shipping_account_name_id->{'International'};
        }
        else {
            $shipping_account_id =
                   $country_specific_shipping_account_id
                || $shipping_account_name_id->{'International'}
                || $shipping_account_name_id->{'International Road'};
        }
    }
    # not sure what it is - set it to unknown
    else {
        $shipping_account_id = $unknown_shipping_account_id // 0;
    }

    ### TODO: is this obsolete and can be removed?
    # FTBC promotion - special DHL account to be used
    # criteria - 3 or less FTBC products only, International shipments only

    my @ftbc_products   = (29148, 29149, 29150, 29151, 29152);
    my $ftbc_item_count = 0;
    my $item_count      = 0;

    # loop throughh shipment items to check for FTBC prods
    foreach my $item_id ( keys %{ $args->{item_data} } ) {
        # FTBC prod
        if ( grep { /\b$args->{item_data}{$item_id}{'product_id'}\b/ } @ftbc_products ) {
            $ftbc_item_count++;
        }
        # non-FTBC prod
        else {
            $item_count++;
        }
    }

    # does shipment match criteria?
    if (
        ( $args->{shipment_type_id} != $SHIPMENT_TYPE__PREMIER )
        &&
        ( $default_carrier eq 'DHL Express' )
        &&
        ( $ftbc_item_count > 0 && $ftbc_item_count <= 3)
        &&
        ( $item_count == 0 )
        ) {
        $shipping_account_id = $shipping_account_name_id->{'FTBC'};
    }
    return $shipping_account_id;
}


### Subroutine : set_shipment_shipping_account        ###
# usage        :                                  #
# description  :  update shipping_account_id for shipment     #
# parameters   :   db handle, shipment_id, shipping_account_id                              #
# returns      :    nowt                             #

sub set_shipment_shipping_account :Export() {
    my ( $dbh, $shipment_id, $shipping_account_id ) = @_;
    if (not defined $shipping_account_id) {
        carp "shipping_account_id not set!!";
    }

    my $qry = "update shipment set shipping_account_id = ? where id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($shipping_account_id, $shipment_id);
    return;
}


### Subroutine : is_standard_or_active_shipment   ###
# usage        :                                    #
# description  :                                    #
# parameters   :                                    #
# returns      :                                    #

sub is_standard_or_active_shipment :Export() {
    my $shipment = shift;

    # if we've been passed a non hashref - warn and fail
    if ('HASH' ne ref($shipment)) {
        Carp::carp( q{parameter passed to is_standard_or_active_shipment() must be a hash-ref} );
        return;
    }
    # if we don't have 'shipment_class_id' fail
    if (not exists $shipment->{shipment_class_id}) {
        Carp::Carp( q{hash-ref passed to is_standard_or_active_shipment() doesn't contain a shipment_class_id key} );
        return;
    }

    # perform the check ...
    my $result = (
        ($shipment->{shipment_class_id} == $SHIPMENT_CLASS__STANDARD)
        &&
        ($shipment->{shipment_class_id} != $SHIPMENT_CLASS__SAMPLE)
    );
    return $result;
}

sub is_cancelled_item :Export() {
    my $item = shift;

    # if we've been passed a non hashref - warn and fail
    if ('HASH' ne ref($item)) {
        Carp::carp( q{parameter passed to _is_cancelled_item() must be a hash-ref} );
        return;
    }

    # if we don't have 'shipment_class_id' fail
    if (not exists $item->{shipment_item_status_id}) {
        Carp::Carp( q{hash-ref passed to _is_cancelled_item() doesn't contain a shipment_item_status_id key} );
        return;
    }

    my $result = (
        $item->{shipment_item_status_id} == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
        or
        $item->{shipment_item_status_id} == $SHIPMENT_ITEM_STATUS__CANCELLED
    );
    return $result;
}

### Subroutine : get_cancel_putaway_list             ###
# usage        : $list_ref = get_cancel_putaway_list(  #
#                   $database_handle)                  #
# description  : Returns a list of orders that need to #
#                be putaway                            #
# parameters   : Database Handle                       #
# returns      : Returns a pointer to a hash           #

sub get_cancel_putaway_list :Export() {
    my ( $dbh ) = @_;

    my $qry = "SELECT s.id as shipment_id, o.id as order_id, o.order_nr, o.date, o.order_status_id, c.name AS sales_channel
                FROM orders o, link_orders__shipment los, shipment s, channel c
                WHERE o.id = los.orders_id
                AND o.channel_id = c.id
                AND los.shipment_id = s.id
                AND s.id IN (SELECT shipment_id FROM shipment_item WHERE shipment_item_status_id = $SHIPMENT_ITEM_STATUS__CANCEL_PENDING)
                UNION
                SELECT s.id as shipment_id, 1 as order_id, 'Sample Transfer' as order_nr, '2000-01-01' as date, 1 as order_status_id, c.name AS sales_channel
                FROM stock_transfer st, link_stock_transfer__shipment lsts, shipment s, channel c
                WHERE st.id = lsts.stock_transfer_id
                AND st.channel_id = c.id
                AND lsts.shipment_id = s.id
                AND s.id IN (SELECT shipment_id FROM shipment_item WHERE shipment_item_status_id = $SHIPMENT_ITEM_STATUS__CANCEL_PENDING)";
    my $sth = $dbh->prepare($qry);

    # this shaves 20% off previous query
    my $subqry = "SELECT
            si.id,
            v.legacy_sku,
            v.product_id,
            sku_padding(v.size_id) as sku_size,
            cit.description
        FROM
            (SELECT * FROM shipment_item
                WHERE
                    shipment_item_status_id = $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
                    AND shipment_id = ?) si
            JOIN variant v
                ON v.id = si.variant_id
            JOIN cancelled_item ci
                ON ci.shipment_item_id = si.id
            JOIN customer_issue_type cit
                ON cit.id = ci.customer_issue_type_id
    -- Gift Vouchers
    UNION
        SELECT
            si.id,
            '' || v.voucher_product_id || '' as legacy_sku,
            v.voucher_product_id as product_id,
            lpad(CAST(999 AS varchar), 3, '0') as sku_size,
            cit.description
        FROM
            (SELECT * FROM shipment_item
                WHERE
                    shipment_item_status_id = $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
                    AND shipment_id = ?) si
            JOIN voucher.variant v
                ON v.id = si.voucher_variant_id
            JOIN cancelled_item ci
                ON ci.shipment_item_id = si.id
            JOIN customer_issue_type cit
                ON cit.id = ci.customer_issue_type_id
";

    my $substh = $dbh->prepare($subqry);

    $sth->execute();

    my %list;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $list{ $row->{sales_channel} }{ $$row{shipment_id} } = $row;

        $substh->execute($$row{shipment_id},$$row{shipment_id});
        while ( my $subrow = $substh->fetchrow_hashref() ) {
            $list{ $row->{sales_channel} }{ $$row{shipment_id} }{items}{$$subrow{id}} = $subrow;
        }
    }
    return \%list;
}

### Subroutine : check_shipment_restrictions                        ###
# usage        : check_shipment_restrictions( $schema, \%options )  #
# description  :  checks for any restricted products in shipment    #
#                 and sends appropriate emails as required          #
# parameters   :  schema, options                                   #
#                   schema  - Database handle                       #
#                   options - HashRef of options:                   #
#                               shipment_id (required)              #
#                               address_ref: (optional) see subtype #
#                                 'XT::Rules::Type::address_ref' in #
#                                 XT::Rules::Type. Defaults to the  #
#                                 address of shipment.              #
#                               send_email (optional) defaults to   #
#                                 no emails                         #
#                               never_send_email (optional) takes   #
#                                 presedence over everything and    #
#                                 wont send an email                #
# returns      :  HashRef of restricted products, with product_id   #
#                 as the key and an ArayRef of reasons.             #

sub check_shipment_restrictions :Export() {
    my ( $schema, $param )   = @_;

    if ( ref( $schema ) !~ /Schema/ ) {
        croak "Need to pass a 'Schema' object as first argument to '" . __PACKAGE__ . "::check_shipment_restrictions'";
    }

    if (not defined $param->{shipment_id}) {
        croak('Shipment id required to determine restrictions');
    }

    my $dbh = $schema->storage->dbh;

    # get channel info for this shipment's order
    my $channel_id  = get_order_channel_from_shipment( $dbh, $param->{shipment_id} );
    my $channel_info= get_channel( $dbh, $channel_id );

    my $product_ref;

    unless ( defined $param->{address_ref} ) {

        # get shipping country info for shipment
        my $qry = "select oa.county, oa.postcode, oa.country, sr.sub_region, c.code AS country_code
                    from shipment s, order_address oa
                        left join country c on oa.country = c.country
                            left join sub_region sr on c.sub_region_id = sr.id
                    where s.id = ?
                    and s.shipment_address_id = oa.id";

        my $sth = $dbh->prepare($qry);
        $sth->execute($param->{shipment_id});

        $param->{address_ref} = decode_db($sth->fetchrow_hashref());
    }

    # get restriction info for items in shipment
    my $qry = "select   v.product_id,
                        c.country as country_of_origin,
                        sa.fish_wildlife,
                        sa.cites_restricted,
                        sa.is_hazmat,
                        p.designer_id
                from    shipment_item si
                            inner join  variant v on v.id = si.variant_id
                            inner join  shipping_attribute sa on sa.product_id = v.product_id
                            inner join  product p on p.id = v.product_id
                            left join   country c on sa.country_id = c.id
                where   si.shipment_id = ?
                  and   si.shipment_item_status_id IN (
                            $SHIPMENT_ITEM_STATUS__NEW,
                            $SHIPMENT_ITEM_STATUS__SELECTED,
                            $SHIPMENT_ITEM_STATUS__PICKED,
                            $SHIPMENT_ITEM_STATUS__PACKED,
                            $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                            $SHIPMENT_ITEM_STATUS__DISPATCHED,
                            $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                            $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                            $SHIPMENT_ITEM_STATUS__RETURNED
                        )";

    my $sth = $dbh->prepare($qry);
    $sth->execute($param->{shipment_id});

    while ( my $row = $sth->fetchrow_hashref ) {
        my $pid = $row->{product_id};
        my $product = $schema->resultset('Public::Product')->find( $pid );
        $product_ref->{ $pid } = $row;
        $product_ref->{ $pid }{ship_restriction_ids} = $product->get_shipping_restrictions_ids_as_hash();
    }

    my $restrictions = XT::Rules::Solve->solve( 'Shipment::restrictions' => {
        product_ref => $product_ref,
        address_ref => $param->{address_ref},
        channel_id  => $channel_id,
        -schema     => $schema,
    } );

    # If there's nothing worth notifying about, just return straight away.
    return $restrictions
        if $restrictions->{all_silent};

    # decide if an email should be sent or not, based on
    # params passed in and/or whether a notification should
    # be sent for the restrictions found. 'never_send_email'
    # param takes presedence over everything else. 'send_email'
    # means always send an email when there is any restriction
    # unless 'never_send_email' has been passed in.
    my $send_email  = (
        !$param->{never_send_email}
        && ( $param->{send_email} || $restrictions->{notify} )
        ? 1
        : 0
    );

    if ( keys %{ $restrictions->{restricted_products} } && $send_email ) {

        my $restricted_products = $restrictions->{restricted_products};
        my $subject = "Shipment Containing Restricted Products";
        my $msg     = "Shipment Nr: $param->{shipment_id}\n\nRestricted Products:\n";

        foreach my $product_id ( keys %{ $restricted_products } ) {

            # Only use reasons that should be notified about. As the reasons are
            # a HashRef, also pull out just the 'reason' message.
            my @reasons =
                map  { $_->{reason} }
                grep { not $_->{silent} }
                @{ $restricted_products->{ $product_id }{reasons} };

            $msg .= "  $product_id : " . join( ', ', @reasons ) . "\n";
        }

        # send email to Shipping, Customer Care and Fulfilment
        send_email( config_var('Email', 'xtracker_email'), config_var('Email', 'xtracker_email'), config_var('Email_'.$channel_info->{config_section}, 'customercare_email'), $subject, $msg );
        send_email( config_var('Email', 'xtracker_email'), config_var('Email', 'xtracker_email'), config_var('Email_'.$channel_info->{config_section}, 'fulfilment_email'), $subject, $msg );
        send_email( config_var('Email', 'xtracker_email'), config_var('Email', 'xtracker_email'), config_var('Email_'.$channel_info->{config_section}, 'shipping_email'), $subject, $msg );
    }

    return $restrictions;
}

sub create_shipment_hold :Export() {
    my ( $schema, $args ) = @_;

    if ( !$schema || ref( $schema ) !~ /Schema/ ) {
        croak "A DBIC Schema Connection is Required for '" . __PACKAGE__ . "::create_shipment_hold'";
    }

    if ( not defined $args->{shipment_id} ) {
        croak('Shipment id required');
    }

    my $dbh = $schema->storage->dbh;

    # get reason id from reason if required
    if ( $args->{reason} ) {
        # check if sku exists in db
        my $qry = "SELECT id FROM shipment_hold_reason WHERE reason = ?";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $args->{reason} );

        while ( my $row = $sth->fetchrow_arrayref ) {
            $args->{reason_id} = $row->[0];
        }
    }

    # get date from interval if required
    if ( $args->{release_interval} ) {
        # check if sku exists in db
        my $qry = "SELECT current_timestamp + interval '$args->{release_interval}'";
        my $sth = $dbh->prepare($qry);
        $sth->execute();
        my $row = $sth->fetchrow_arrayref;
        $args->{release_date} = $row->[0];
    }

    if ( $args->{release_date} eq '' ) {
        my $qry = "INSERT INTO shipment_hold VALUES (default, ?, ?, ?, ?, current_timestamp(0), null)";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $args->{shipment_id}, $args->{reason_id}, $args->{operator_id}, $args->{comment} );
    }
    else {
        my $qry = "INSERT INTO shipment_hold VALUES (default, ?, ?, ?, ?, current_timestamp(0), ?)";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $args->{shipment_id}, $args->{reason_id}, $args->{operator_id}, $args->{comment}, $args->{release_date} );
    }

    # now log the 'hold reason' and 'comment' so that there is a history of Hold
    # Reasons as the Shipment Hold record itself will be deleted when Released
    $schema->resultset('Public::ShipmentHoldLog')->create( {
        shipment_id             => $args->{shipment_id},
        shipment_hold_reason_id => $args->{reason_id},
        comment                 => $args->{comment},
        operator_id             => $args->{operator_id},
        ( $args->{shipment_status_log_id}
            ? ( shipment_status_log_id  => $args->{shipment_status_log_id} )
            : ()
        )
    } );

    return;
}

sub delete_shipment_hold :Export() {
    my ( $dbh, $shipment_id ) = @_;

    if ( not defined $shipment_id ) {
        croak('No shipment_id defined ro delete_shipment_hold()');
    }

    my $qry = "DELETE FROM shipment_hold WHERE shipment_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);
    return;
}

sub set_shipment_on_hold :Export() {
    my ( $schema, $shipment_id, $params ) = @_;

    if ( !$schema || ref( $schema ) !~ /Schema/ ) {
        croak "A DBIC Schema Connection is Required for '" . __PACKAGE__ . "::set_shipment_on_hold'";
    }

    my $shipment_obj = $schema->resultset('Public::Shipment')->find($shipment_id);

    if ($params->{status_id} == $SHIPMENT_STATUS__HOLD) {
        if ( not $shipment_obj->can_be_put_on_hold ) {
            die 'Shipment not correct status to place on Hold: '
                . $shipment_obj->shipment_status->status;
        }
    }
    elsif ($params->{status_id} == $SHIPMENT_STATUS__FINANCE_HOLD) {
        if ( not $shipment_obj->can_be_put_on_finance_hold ) {
            die 'Shipment not correct status to place on Finance Hold: '
                . $shipment_obj->shipment_status->status;
        }
    }
    elsif (number_in_list($params->{status_id},
                          $SHIPMENT_STATUS__RETURN_HOLD,
                          $SHIPMENT_STATUS__EXCHANGE_HOLD,
                          $SHIPMENT_STATUS__DDU_HOLD,
                          $SHIPMENT_STATUS__PRE_DASH_ORDER_HOLD)) {
        # all right, nothing to check
    }
    else {
        die 'Wrong hold status '. $params->{status_id};
    }

    my $dbh = $schema->storage->dbh;
    update_shipment_status( $dbh, $shipment_id, $params->{status_id}, $params->{operator_id} );

    # current hold table id and reason id
    my $cur_hold_id = 0;
    my $cur_reason_id = 0;

    # shipment release date from form
    my $release_date;
    if ($params->{norelease} == 1) {
        $release_date = '';
    }
    else {
        $release_date = sprintf '%d-%d-%d %d:%d',
            $params->{releaseYear}, $params->{releaseMonth}, $params->{releaseDay},
                $params->{releaseHour}, $params->{releaseMinute};
    }

    # set default hold reason to other
    my $reason_id = $params->{reason} || $SHIPMENT_HOLD_REASON__OTHER;

    # user comment to accompany hold
    my $comment = $params->{comment} || '';

    # check for existing hold against shipment
    my $hold_info  = get_shipment_hold_info( $dbh, $shipment_id );

    if ($hold_info) {
        $cur_hold_id    = $hold_info->{id};
        $cur_reason_id  = $hold_info->{shipment_hold_reason_id};
    }

    # existing hold found - delete it before creating new one
    if ( $cur_hold_id != 0 ) {
        delete_shipment_hold($dbh, $shipment_id);
    }

    # Get the last inserted log for the hold
    my $shipment_status_log = $shipment_obj->shipment_status_logs->search(
        { shipment_status_id => $params->{status_id} },
        { order_by => { -desc => 'id' }, rows => 1 }
    )->single;
    # create shipment hold record
    create_shipment_hold($schema, {
        shipment_id             => $shipment_id,
        reason_id               => $reason_id,
        operator_id             => $params->{operator_id},
        comment                 => $comment,
        release_date            => $release_date,
        shipment_status_log_id  => $shipment_status_log->id,
    });

    # DCS-454
    # work out what business (via the channel) the shipment lives in
    # we then need to use different email addresses for NAP/OUT
    my $shipment_business_id = get_order_business_from_shipment(
        $dbh, $shipment_id
    );

    ## TODO refactor the email sending

    # Hold reason set as stock discrep for the first time - send email to relevant parties
    if (
        $reason_id == $SHIPMENT_HOLD_REASON__STOCK_DISCREPANCY
            && (  !$cur_reason_id
                      || $cur_reason_id != $SHIPMENT_HOLD_REASON__STOCK_DISCREPANCY )
        ) {
        my ($xt_email, $ccare_email, $ful_email, $stock_email);
        my ($business_name, $email_suffix);

        if ($BUSINESS__NAP == $shipment_business_id) {
            $business_name  = 'NET-A-PORTER';
            $email_suffix   = 'NAP';
        } elsif ($BUSINESS__OUTNET == $shipment_business_id) {
            $business_name  = 'theOutnet';
            $email_suffix   = 'OUTNET'
        } elsif ($BUSINESS__MRP == $shipment_business_id) {
            $business_name  = 'Mr. Porter';
            $email_suffix   = 'MRP'
        }
        # unknown business?!?!
        else {
            send_email(
                config_var('Email', 'xtracker_email'),
                config_var('Email', 'xtracker_email'),
                config_var('Email', 'xtracker_email'),
                "UNKNOWN BUSINESS in Stock Discrepancy",
                "Unknown business_id $shipment_business_id for shipment $shipment_id"
            );
        }

        my $msg = "\nStock Discrepancy on ${business_name} Shipment - $shipment_id\n\nComment:\n".$comment."\n\n";

        # loop through defined addresses
        foreach my $email_to (
            config_var('Email_' . $email_suffix, 'customercare_email'),
            config_var('Email_' . $email_suffix, 'fulfilment_email'),
            config_var('Email_' . $email_suffix, 'stockadmin_email'),
        ) {
            send_email(
                config_var('Email', 'xtracker_email'),
                config_var('Email', 'xtracker_email'),
                $email_to,
                "${business_name} Stock Discrepancy",
                $msg
            );
        }
    }

    $shipment_obj->discard_changes->send_hold_update();

    return;
}

### Subroutine : get_shipment_hold_info                   ###
# usage        : get_shipment_hold_info($dbh, $shipment_id) #
# description  : gets all info on the hold for a shipment   #
# parameters   : $dbh, $shipment_id                         #
# returns      : hash ref                                   #

sub get_shipment_hold_info :Export() {
    my ($dbh, $shipment_id) = @_;

    my $qry = "SELECT sh.id, sh.shipment_hold_reason_id, sh.comment, to_char(sh.hold_date, 'DD-MM-YYYY  HH24:MI') as hold_date, to_char(sh.release_date, 'DD-MM-YYYY  HH24:MI') as release_date, to_char(sh.release_date, 'DD') as release_day, to_char(sh.release_date, 'MM') as release_month, to_char(sh.release_date, 'YYYY') as release_year, to_char(sh.release_date, 'HH24') as release_hour, to_char(sh.release_date, 'MI') as release_minute, o.name
                FROM shipment_hold sh, operator o
                WHERE sh.shipment_id = ?
                AND sh.operator_id = o.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my $data = decode_db($sth->fetchrow_hashref());
    return $data;
}

### Subroutine : delete_print_log                              ###
# usage        : delete_print_log($dbh, $id)                     #
# description  : deletes an entry from shipment_print_log table  #
# parameters   : $dbh, $id                                       #
# returns      : Nothing                                         #

sub delete_print_log :Export() {
    my ( $dbh, $id ) = @_;

    if (not defined $id) {
        die 'No row id defined for delete_print_log()';
    }

    my $qry = "DELETE FROM shipment_print_log WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $id );
    return;
}

sub get_shipment_routing_option :Export() {
    my ( $dbh, $shipment_id ) = @_;

    my $qry = "SELECT description, code FROM premier_routing WHERE id = (SELECT premier_routing_id FROM shipment WHERE id = ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my $row = $sth->fetchrow_hashref();
    return decode_db($row) || undef;
}

=head2 set_carrier_automated

  usage        : set_carrier_automated(
                       $dbh,
                       $shipment_id,
                       $state
                   );

  description  : This sets the 'real_time_carrier_booking' (rtcb) field
                 on the 'shipment' table to either TRUE or FALSE. If the
                 setting is FALSE then it will reset the Outbound & Return
                 Airway Bills on the Shipment record to 'none' so that the
                 Shipment will be picked up in a Manifest Request which amongst
                 other things looks for Shipment which don't have those fields
                 completed.

  parameters   : A Database Handler, A Shipment Id, The State to set the
                 field to either TRUE or FALSE.
  returns      : Nothing.

=cut

sub set_carrier_automated :Export(:carrier_automation) {
    my ( $dbh, $shipment_id, $state )   = @_;

    die "No Database Handle"            if (!$dbh);
    die "No Shipment Id"                if (!$shipment_id);
    die "No State to Set"               unless ( defined $state );

    if ( !get_shipment_info( $dbh, $shipment_id ) ) {
        die "No Shipment found for Shipment Id: ".$shipment_id;
    }

    my $upd_awb     = "";

    # if setting field to FALSE then clear AWBs & AV Quality field as well
    if ( !$state ) {
        $upd_awb    =<<UPD_AWB
, outward_airway_bill = 'none',
return_airway_bill = 'none',
av_quality_rating = ''
UPD_AWB
;
    }

    my $sql =<<SQL
UPDATE shipment
    SET real_time_carrier_booking = ?
    $upd_awb
WHERE id = ?
SQL
;
    my $sth = $dbh->prepare($sql);
    $sth->execute( $state, $shipment_id );
    return;
}

### Subroutine : is_carrier_automated                                          ###
# usage        : $boolean = is_carrier_automated(                                #
#                      $dbh,                                                     #
#                      $shipment_id                                              #
#                  );                                                            #
# description  : This gets the current value of the 'real_time_carrier_booking'  #
#                field on the 'shipment' table which is a boolean value.         #
# parameters   : A Database Handler, A Shipment Id.                              #
# returns      : A SCALAR containing the value of the field (TRUE or FALSE).     #

sub is_carrier_automated :Export(:carrier_automation) {
    my ( $dbh, $shipment_id )   = @_;

    die "No Database Handle"            if (!$dbh);
    die "No Shipment Id"                if (!$shipment_id);

    my $schema = get_schema_using_dbh($dbh,'xtracker_schema');
    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);

    return $shipment->is_carrier_automated;
}

### Subroutine : set_shipment_qrt                                      ###
# usage        : set_shipment_qrt(                                       #
#                      $dbh,                                             #
#                      $shipment_id,                                     #
#                      $qrt_value                                        #
#                  );                                                    #
# description  : This sets the 'av_quality_rating' (rtcb) field to a     #
#                value on the 'shipment' table. Can also be used to set  #
#                the field to an empty value.                            #
# parameters   : A Database Handler, A Shipment Id, The Value to set the #
#                field to.                                               #
# returns      : Nothing.                                                #

sub set_shipment_qrt :Export(:carrier_automation) {
    my ( $dbh, $shipment_id, $qrt_value )   = @_;

    die "No Database Handle"            if (!$dbh);
    die "No Shipment Id"                if (!$shipment_id);

    if ( !get_shipment_info( $dbh, $shipment_id ) ) {
        die "No Shipment found for Shipment Id: ".$shipment_id;
    }

    my $sql =<<SQL
UPDATE shipment
    SET av_quality_rating = ?
WHERE id = ?
SQL
;
    my $sth = $dbh->prepare($sql);
    $sth->execute( $qrt_value, $shipment_id );
    return;
}

### Subroutine : get_shipment_qrt                                      ###
# usage        : $scalar = get_shipment_qrt(                             #
#                      $dbh,                                             #
#                      $shipment_id                                      #
#                  );                                                    #
# description  : This gets the current value of the 'av_quality_rating'  #
#                field on the 'shipment' table.                          #
# parameters   : A Database Handler, A Shipment Id.                      #
# returns      : A SCALAR containing the value of the field.             #

sub get_shipment_qrt :Export(:carrier_automation) {
    my ( $dbh, $shipment_id )   = @_;

    die "No Database Handle"            if (!$dbh);
    die "No Shipment Id"                if (!$shipment_id);

    my $retval;

    my $sql =<<SQL
SELECT  av_quality_rating
FROM    shipment
WHERE   id = ?
SQL
;
    my $sth = $dbh->prepare($sql);
    $sth->execute( $shipment_id );

    while ( my $row = $sth->fetchrow_hashref() ) {
        $retval = $row->{av_quality_rating};
    }
    return $retval;
}

### Subroutine : autoable                                                 ###
# usage        : $boolean = autoable(                                       #
#                      $schema,                                             #
#                      {                                                    #
#                         shipment_id => $shipment_id,                      #
#                         mode => 'isit' || 'deduce'                        #
#                         operator_id => $operator_id                       #
#                      }                                                    #
#                  );                                                       #
# description  : This function checks to see if a shipment can be automated #
#                and then if the mode is set to 'deduce' sets the shipments #
#                'rtcb' field accordingly and log's the change if there was #
#                one. An operator id is required if the function is to      #
#                deduce whether the shipment can be automated.              #
# parameters   : A DBiC Schema Handler, An Anonymous HASH containing a      #
#                Shipment Id and a Mode indicating either 'isit' - which    #
#                tests the possibility of the shipment being autoable and   #
#                'deduce' which tests if the shipment can be automated and  #
#                then sets the shipment's 'rtcb' field accordingly and logs #
#                the change if there was one, if the mode is 'deduce' then  #
#                an Operator Id is needed.                                  #
# returns      : A BOOLEAN containing the value of the rtcb field.          #

sub autoable :Export(:carrier_automation) {
    my ( $schema, $args )  = @_;

    die "No Schema Handle"              if ( !$schema );
    die "No Arguments Passed"           if ( !$args );
    die "No Shipment Id Passed"         if ( !$args->{shipment_id} );
    die "No Mode Specified"             if ( !$args->{mode} );
    die "Inproper Mode Specified"       if ( $args->{mode} !~ /(isit|deduce)/ );
    die "No Operator Id Passed"         if ( !$args->{operator_id} );

    if ( !get_shipment_info( $schema->storage->dbh, $args->{shipment_id} ) ) {
        die "No Shipment found for Shipment Id: ".$args->{shipment_id};
    }

    require NAP::Carrier;

    my $retval;
    my $carrier = NAP::Carrier->new( {
                            schema      => $schema,
                            shipment_id => $args->{shipment_id},
                            operator_id => $args->{operator_id},
                        } );

    CASE: {
        if ( $args->{mode} eq "isit" ) {
            $retval = $carrier->is_autoable();
            last CASE;
        }
        if ( $args->{mode} eq "deduce" ) {
            $retval = $carrier->deduce_autoable();
            last CASE;
        }
    };

    return $retval;
}

=head2 process_shipment_for_carrier_automation

  usage        : $boolean = process_shipment_for_carrier_automation( $dbh, $shipment_id, $operator_id );

  description  : This function will attempt to use the NAP::Carrier module to try and process a
                 shipment using the appropriate carrier service. Currently this is only used
                 for UPS.

  parameters   : A Database Handler and a Shipment Id.
  returns      : A BOOLEAN response of either TRUE (1) or FALSE (0).

=cut

sub process_shipment_for_carrier_automation :Export(:carrier_automation) {
    my ( $schema, $shipment_id, $operator_id )     = @_;

    die "No Schema Handle"              if ( !$schema );
    die "No Shipment Id"                if ( !$shipment_id );
    die "No Operator Id"                if ( !$operator_id );

    if ( !get_shipment_info( $schema->storage->dbh, $shipment_id ) ) {
        die "No Shipment found for Shipment Id: ".$shipment_id;
    }

    my $result  = 0;

    require NAP::Carrier;

    my $carrier = NAP::Carrier->new( {
                            schema      => $schema,
                            shipment_id => $shipment_id,
                            operator_id => $operator_id,
                        } );

    $result = $carrier->book_shipment_for_automation();

    # If the attempt to use Carrier Automation fails then the 'rtcb' field
    # on the 'shipment' should be set back to FALSE and this function should
    # return 0 as an indicator of failure, if it succeeds then it should return 1.
    return $result;
}

=head2 check_packing_station

  usage        : $hash_ref = check_packing_station(
                        $handler,
                        $shipment_id,
                        $channel_id
                    );

  description  : This checks to see if an operator needs to set a packing station
                 to pack a shipment. It first checks to see if the shipment is
                 'automated' and then checks to see if the operator has a
                 packing station and if that station is active for the shipment's
                 sales channel. Will return a HASH REF with the following:
                    {
                        ok      => 1 | 0,
                        fail_msg=> ''     # This will be completed if NOT ok and is
                                            the message that should be displayed on the
                                            Packing Overview page
                    }

  parameters   : The xTracker Handler, Shipment Id & Shipment's Sales Channel Id.
  returns      : A HASH Ref containing the above data.

=cut

sub check_packing_station :Export(:carrier_automation) {
    my ( $handler, $ship_id, $channel_id )  = @_;

    die "No Handler Passed"             if ( !$handler );
    die "No Shipment Id Passed"         if ( !$ship_id );
    die "No Sales Channel Id Passed"    if ( !$channel_id );

    die "No DBH Defined in Handler"     if ( !$handler->{dbh} );
    die "No Schema Defined in Handler"  if ( !$handler->{schema} );

    my $retval  = { ok => 1 };

    # are there any packing stations available
    my $ps  = get_packing_stations( $handler->{schema}, $channel_id );
    if ( $ps ) {
        # does the shipment require a packing station
        if ( is_carrier_automated( $handler->{dbh}, $ship_id ) ||
             config_var('Fulfilment', 'requires_packing_station') ) {
            if ( !$handler->{data}{preferences}{packing_station_name} ) {
                $retval->{ok}       = 0;
                $retval->{fail_msg} = "You Need to Set a Packing Station before Packing this Shipment";
            }
            elsif ( !grep { $handler->{data}{preferences}{packing_station_name} eq $_ } @{ $ps } ) {
                $retval->{ok}       = 0;
                $retval->{fail_msg} = "Your Packing Station is Not Valid, You Need to Change it Before Packing this Shipment";
            }
        }
    }
    return $retval;
}

=head2 get_shipment_box_labels

  usage        : $array_ref = get_shipment_box_labels(
                        $dbh,
                        $shipment_id
                    );

  description  : This gets the box label images from the shipment_box table. It returns
                 them in an array of hashes containing both the outward label and the
                 return label. Only records which have something in either field will be
                 returned. The format of the return is as follows:
                    [
                        {
                            box_id          => 1232324,
                            outward_label   => "data",
                            return_label    => "data"
                        }
                    ]

  parameters   : A Database Handle, A Shipment Id.
  returns      : An ARRAY REF of HASHES.

=cut

sub get_shipment_box_labels :Export(:carrier_automation) {
    my ( $dbh, $shipment_id )   = @_;

    die "No Database Handle Passed"     if ( !$dbh );
    die "No Shipment Id Passed"         if ( !$shipment_id );

    if ( !get_shipment_info( $dbh, $shipment_id ) ) {
        die "No Shipment found for Shipment Id: ".$shipment_id;
    }

    my @retval;
    my $boxes   = get_shipment_boxes( $dbh, $shipment_id );

    foreach my $box_id ( sort { $a cmp $b } keys %{ $boxes } ) {
        # if there is data for either the outward or return label then put it on the array
        if ( ( ($boxes->{$box_id}{outward_box_label_image} // '') ne '' ) || ( ($boxes->{$box_id}{return_box_label_image} // '') ne '' ) ) {
            push @retval, {
                    box_id          => $box_id,
                    outward_label   => $boxes->{$box_id}{outward_box_label_image},
                    return_label    => $boxes->{$box_id}{return_box_label_image},
                }
        }
    }
    return \@retval;
}

=head2 get_shipment_id_for_awb

  usage        : $scalar = get_shipment_id_for_awb(
                        $dbh,
                        {
                            'outward'||'return'  => 'an AWB Number',
                            'not_yet_dispatched' => 1,      # optional
                        }
                    );

  description  : This takes in either an Outward or Return AWB and returns back the Shipment Id. It can also take
                 an additional argument 'not_yet_dispatched' to only search shipments which haven't been dispatched
                 yet.

  parameters   : A Database Handle, A HASH containing a key for which type of AWB to search on and the value
                 being what to search for and an optional Not Yet Dispatched flag.
  returns      : A SCALAR containing a Shipment Id.

'

=cut

sub get_shipment_id_for_awb :Export(:carrier_automation) {
    my ( $dbh, $args )      = @_;

    die "No Database Handle Passed"             if ( !$dbh );
    die "No Arguments Passed"                   if ( !$args );
    die "No AWB Type Specified"                 if ( !exists $args->{outward} && !exists $args->{return} );

    my $awb_type        = ( exists $args->{outward} ? 'outward' : 'return' );
    die "No AWB Passed to Search For"           if ( !$args->{ $awb_type } );

    # extra conditions that could be applied
    my $xtra_conds  = "";
    my %conds       = (
            not_yet_dispatched  => " shipment_status_id = $SHIPMENT_STATUS__PROCESSING ",
        );

    my $shipment_id     = 0;

    # get any extra conditions required
    $xtra_conds .= "$conds{$_} AND " for grep { exists $args->{$_} } keys %conds;

    my $sql     =<<SQL
SELECT  id
FROM    shipment
WHERE   $xtra_conds ${awb_type}_airway_bill ILIKE ?
SQL
;
    my $sth = $dbh->prepare( $sql );
    $sth->execute( $args->{ $awb_type } );

    while ( my $rec = $sth->fetchrow_hashref() ) {
        $shipment_id    = $rec->{id};
    }
    return $shipment_id;
}

=pod

=cut

sub mark_items_remaining_in_tote_as_missing :Export(:DEFAULT) {
    my ($schema,$tote,$operator_id) = @_;

    if (!$schema->isa('DBIx::Class::Schema')) {
        $schema = get_schema_using_dbh($schema,'xtracker_schema');
    }

    # we fetch all of these items, because we're going to change the
    # values of the fields we're using to identify them, which will
    # make the RS useless
    my @items = $schema->resultset('Public::ShipmentItem')
        ->search({
            container_id => $tote,
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
        })->all;

    my @ret;

    for my $item (@items) {
        log_shipment_item_status($schema->storage->dbh,
                                 $item->id,
                                 $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                                 $operator_id);
        $item->update({
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
            qc_failure_reason => 'Missing',
        });
        $item->unpick;
        push @ret, $item->shipment_id;
    }
    return uniq @ret;
}

1;
