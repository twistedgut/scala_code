package XTracker::Database::Product;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use Perl6::Export::Attrs;

use XTracker::Database                  qw( :DEFAULT get_schema_using_dbh );
use Data::Dump 'pp';
use XTracker::Image                     qw( get_images );
use XTracker::Database::Pricing         qw( get_pricing );
use XTracker::Database::Sample          qw( get_sample_stock_qty get_sample_variant_with_stock );
use XTracker::Database::Utilities       qw( results_list results_hash2 last_insert_id is_valid_database_id );
use XTracker::Database::PurchaseOrder   qw( get_product_purchase_orders );
use XTracker::Database::Channel         qw( get_channel );
use XTracker::Database                  qw( :common );
use XTracker::DBEncode                  qw( encode_db decode_db );
use XTracker::Constants                 qw( :all );
use XTracker::Constants::FromDB         qw(
    :flow_status
    :shipment_class
    :variant_type
);
use XTracker::Config::Local             qw( config_var iws_location_name );
use XTracker::Database::StockTransfer qw( create_stock_transfer );
use XT::Domain::PRLs;
use Test::Deep::NoTest;
use Clone 'clone';
use MooseX::Params::Validate;
use MooseX::Types::Common::Numeric qw/PositiveNum/;
use Try::Tiny;

sub new() {
    my ($class, $context, @args) = @_;
    my $new_obj = bless {}, $class;

    return $new_obj;
}


### Subroutine : watch                                        ###
# usage        : watch( $p );                                   #
# description  : Deletes a Comment assigned to a Product        #
# parameters   : dbh => $dbh, type => 'comment_id', id => $id   #
# returns      :                                                #

sub watch :Export() {

    my $p = shift;
    my $operator_id = shift;

    if (!defined $operator_id ) {
        $operator_id = $APPLICATION_OPERATOR_ID;
        warn __PACKAGE__
            ."::watch(): Please define operator_id for call"
            ." - defaulting to 'Application'";
    }

    if ( $p->{type} eq 'product_id' ) {

        my $action;

    if ( $p->{action} == 0 ) {
            $action = 'true';
    }
    else {
            $action = 'false';
    }


        my $qry = qq{
update product set
watch = ?, operator_id = ?
where id = ?
};

        my $sth = $p->{dbh}->prepare( $qry );

        $sth->execute( $action, $operator_id, $p->{id} );

        $sth->finish;

    }
    else {
        croak "undefined type: " . $p->{type};
    }

}


### Subroutine : create_product_comment                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      : unconfirmed                      #

sub create_product_comment :Export() {

    my ( $dbh, $args ) = @_;

    my $qry = qq{
                    INSERT INTO product_comment (
                    comment, operator_id, department_id, created_timestamp, product_id
                    ) VALUES (
                    ?, ?, ?, current_timestamp, ? )
    };

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{comment}, $args->{operator_id}, $args->{department_id}, $args->{product_id} );

    return;

}


### Subroutine : delete_product_comment                       ###
# usage        : delete_product_comment( $p );                  #
# description  : Deletes a Comment assigned to a Product        #
# parameters   : dbh => $dbh, type => 'comment_id', id => $id   #
# returns      :                                                #

sub delete_product_comment :Export() {

    my ( $dbh, $id ) = @_;

    if ( !$id ) {
        die 'No comment id defined for delete_product_comment()';
    }

    my $qry = qq{
                update product_comment set
                deleted = true
                where id = ?
    };

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $id );

    return;
}


### Subroutine : get_product_comments
# usage        : my $comments = get_product_comments( { dbh => $dbh, id => $prod_id, type => 'product_id' } );
# description  : get a ref of all product comments ordered by date created
# parameters   : ro dbh, product id, id type
# returns      : ref of hash of ref of row of product_comments, keyed by comment_id

sub get_product_comments :Export() {

    my ( $dbh, $product_id )  = @_;

    if (!$product_id) {
        croak 'No product_id defined for get_product_comments()';
    }

    my $qry = qq{
                select pc.*, o.name, o.username, d.department,
                       extract( epoch from pc.created_timestamp ) as epoch, to_char( pc.created_timestamp, 'DD-MM-YYYY HH24:MI' ) as timestamp
                from product_comment pc, department d, operator o
                where pc.operator_id = o.id
                and pc.department_id = d.id
                and pc.product_id = ?
                and pc.deleted is false
                order by epoch desc
    };

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $product_id );

    my $data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data->{$row->{epoch}} = $row;
    }

    return $data;
}

### Subroutine : search_product_comments                                            ###
# usage        : $array_ref = search_product_comments(                                #
#                     $dbh, {                                                         #
#                     comment_id => $comment_id,                                      #
#                     product_id => $product_id,                                      #
#                     comment    => $comment,                                         #
#                     user_id    => $user_id                                          #
#                 } );                                                                #
# description  : Get a list of comments which match the parameters passed in.         #
# parameters   : Database Handle, optional parameters follow, Comment Id, Product Id, #
#                Comment Text & User Id.                                              #
# returns      : An Array ref containing the results.                                 #

sub search_product_comments :Export() {
    my ( $dbh, $args )  = @_;

    my %arg_map = (
        comment_id  => ' pc.id = ? ',
        product_id  => ' pc.product_id = ? ',
        comment     => ' pc.comment = ? ',
        user_id     => ' pc.operator_id = ? '
    );

    my $results;
    my $cond        = "AND";
    my @params;


    my $qry =<<QRY
SELECT  pc.*,
        o.username,
        o.name,
        o.department_id,
        d.department
FROM    product_comment pc
            JOIN (
                operator o
                JOIN department d ON o.department_id = d.id
            ) ON pc.operator_id = o.id
WHERE   pc.deleted IS FALSE
QRY
;

    foreach my $arg ( keys %$args ) {
        if ( exists $arg_map{$arg} ) {
            $qry    .= $cond . $arg_map{$arg};
            push @params, $args->{$arg};
            $cond   = "AND";
        }
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute( @params );

    return results_list( $sth );
}

### Subroutine : get_size_id                    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_size_id :Export() {

    my ( $p ) = @_;

    my ( $id, $clause );

    if ( $p->{variant_id} ) {

        $id = $p->{variant_id};

        $clause = qq{ v.id = ? };

    }
    elsif ( $p->{type} eq 'variant_id' and $p->{id} ) {

        $id = $p->{id};

        $clause = qq{ v.id = ? };

    }
    elsif ( $p->{type} eq 'sku' and $p->{id} ) {

        my ( $product_id, $size_id ) = split( /-/, $p->{id} );

        return $size_id;

    }
    elsif ( $p->{type} eq 'legacy_sku' and $p->{id} ) {

        $id = $p->{id};

        $clause = qq{ v.legacy_sku = ? };

    }
    else {
        die "invalid usage of XTracker::Database::Product->get_size_id() [" . $p->{type} . "]";
    }


    my $qry = qq{
select v.size_id
  from variant v,
       product p
 where 1 = 1
   and p.id = v.product_id
   and $clause
};

    my $sth = $p->{dbh}->prepare( $qry );

    $sth->execute( $id );

    my $size_id = $sth->fetchrow;

    return $size_id;

}



### Subroutine : create_product                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_product :Export( :create ) {

    my ( $dbh, $data_ref, $operator_id ) = @_;

    # should the operator_id default to the Application operator?
    if (!defined $operator_id ) {
        $operator_id = $APPLICATION_OPERATOR_ID;
        warn __PACKAGE__
            ."::create_product(): Please define operator_id for call"
            ." - defaulting to 'Application'";
    }

    # var to hold the new product id
    my $product_id;

    # array to hold the insert vars
    my @execute_vars = ();

    # build insert sql
    my $qry = "INSERT INTO product ( id,
                                     world_id,
                                     designer_id,
                                     division_id,
                                     classification_id,
                                     product_type_id,
                                     sub_type_id,
                                     colour_id,
                                     style_number,
                                     season_id,
                                     hs_code_id,
                                     note,
                                     legacy_sku,
                                     colour_filter_id,
                                     payment_term_id,
                                     payment_settlement_discount_id,
                                     payment_deposit_id,
                                     watch,
                                     operator_id,
                                     storage_type_id)
                VALUES (";

    # product id passed to function?
    if ( defined( $data_ref->{product_id} ) ) {
        $qry .= "?";

        # put product id into the insert vars
        push @execute_vars, $data_ref->{product_id};

        # pass the product id to the product id var
        $product_id = $data_ref->{product_id};
    }
    # generate product id
    else {
        $qry .= "default";
    }

    # finish of insert sql
    $qry .= ", ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )";


    # put data into insert vars
    push @execute_vars, (
        $data_ref->{world_id},              $data_ref->{designer_id},
        $data_ref->{division_id},           $data_ref->{classification_id},
        $data_ref->{product_type_id},       $data_ref->{sub_type_id},
        $data_ref->{colour_id},             $data_ref->{style_number},
        $data_ref->{season_id},             $data_ref->{hs_code_id},
        $data_ref->{note},
        $data_ref->{legacy_sku},
        $data_ref->{colour_filter_id},      $data_ref->{payment_term_id},
        $data_ref->{payment_settlement_discount_id},
        $data_ref->{payment_deposit_id},
        $data_ref->{watch},                 $operator_id,
        $data_ref->{storage_type_id}
    );

    # do the insert
    my $sth = $dbh->prepare($qry);
    $sth->execute(@execute_vars);

    # get the product id if not passed to function
    if ( not defined( $data_ref->{product_id} ) ) {
        $product_id = last_insert_id( $dbh, 'product_id_seq' );
    }

    return $product_id;
}

### Subroutine : _create_product_attributes     ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_product_attributes :Export( :create ) {

    my ( $dbh, $product_id, $data_ref, $operator_id ) = @_;

    my $qry = "INSERT INTO product_attribute ( product_id, name, description, long_description, short_description, designer_colour, editors_comments, keywords, designer_colour_code, size_scheme_id, custom_lists, act_id, pre_order, operator_id, runway_look, sample_correct, sample_colour_correct, product_department_id, style_notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
    my $sth = $dbh->prepare($qry);

    $sth->execute(
        $product_id,
        encode_db($data_ref->{name}),
        encode_db($data_ref->{description}),
        encode_db($data_ref->{long_description}),
        encode_db($data_ref->{short_description}),
        encode_db($data_ref->{designer_colour}),
        encode_db($data_ref->{editors_comments}),
        $data_ref->{keywords},
        $data_ref->{designer_colour_code},  $data_ref->{size_scheme_id},
        $data_ref->{custom_lists},          $data_ref->{act_id},
        $data_ref->{pre_order},             $operator_id,
        $data_ref->{runway_look},           $data_ref->{sample_correct},
        $data_ref->{sample_colour_correct}, $data_ref->{product_department_id},
        $data_ref->{style_notes}
    );

    return;
}


### Subroutine : _create_shipping_attributes    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_shipping_attributes :Export( :create ) {

    my ($dbh, $product_id, $data_ref, $operator_id) = @_;

    my $qry = "INSERT INTO shipping_attribute (product_id, scientific_term, country_id, packing_note, weight, fabric_content, fish_wildlife, operator_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
    my $sth          = $dbh->prepare($qry);

    $sth->execute(
        $product_id,                $data_ref->{scientific_term},
        $data_ref->{country_id},    $data_ref->{packing_note},
        $data_ref->{weight},        $data_ref->{fabric_content},
        $data_ref->{fish_wildlife}, $operator_id
    );

    return;
}


### Subroutine : _check_variant                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _check_variant {

    my ( $dbh, $p ) = @_;

    eval {
        die "product_id not passed" unless $p->{product_id};
        die "size_id not passed"    unless $p->{size_id};
        die "type_id not passed"    unless $p->{type_id};
    }; if ( $@ ) { croak $@; }

    my $qry = qq{
select id
  from variant v
 where product_id = ?
   and size_id = ?
   and type_id = ?
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( $p->{product_id}, $p->{size_id}, $p->{type_id} );

    my $row = $sth->fetchrow_hashref();

    return $row->{id};
}


### Subroutine : create_variant                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_variant :Export( :create ) {

    my ( $dbh, $product_id, $data_ref ) = @_;

    # make sure we've got the required data to create a variant
    if (not defined $data_ref->{legacy_sku}) {
        croak('Please provide a legacy_sku for the variant');
    }
    if (not defined $data_ref->{size_id}) {
        croak('Please provide a size_id for the variant');
    }
    if (not defined $data_ref->{designer_size_id}) {
        croak('Please provide a designer_size_id for the variant');
    }

    # default the type_id to 1 (stock) if not defined
    if (not defined $data_ref->{type_id}) {
        $data_ref->{type_id} = 1;
    }

    # check if size already exists
    if ( my $existing_variant_id = _check_variant( $dbh, { 'product_id' => $product_id, 'size_id' => $data_ref->{size_id}, 'type_id' => $data_ref->{type_id} } ) ) {
        return $existing_variant_id;
    }


    # var to hold the new variant id
    my $variant_id;

    # array to hold the insert vars
    my @execute_vars = ();

    # build insert sql
    my $qry = "INSERT INTO variant ( id, product_id, legacy_sku, type_id, size_id, designer_size_id ) VALUES (";

    # product id passed to function?
    if ( defined( $data_ref->{variant_id} ) ) {
        $qry .= "?";

        # put product id into the insert vars
        push @execute_vars, $data_ref->{variant_id};

        # pass the product id to the product id var
        $variant_id = $data_ref->{variant_id};
    }
    # generate product id
    else {
        $qry .= "default";
    }

    # finish of insert sql
    $qry .= ", ?, ?, ?, ?, ? )";


    # put data into insert vars
    push @execute_vars, (
        $product_id,
        $data_ref->{legacy_sku},
        $data_ref->{type_id},
        $data_ref->{size_id},
        $data_ref->{designer_size_id}
    );

    # do the insert
    my $sth = $dbh->prepare($qry);
    $sth->execute(@execute_vars);

    # get the product id if not passed to function
    if ( not defined( $data_ref->{variant_id} ) ) {
        $variant_id = last_insert_id( $dbh, 'variant_id_seq' );
    }

    if ( defined $data_ref->{third_party_sku} ) {

        croak 'Tried to add a third party SKU without providing a business id'
            unless defined $data_ref->{business_id};

        my $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );
        $schema->resultset('Public::ThirdPartySku')->create({
            variant_id      => $variant_id,
            business_id     => $data_ref->{business_id},
            third_party_sku => $data_ref->{third_party_sku},
        });
    }

    return $variant_id;
}



### Subroutine : add_third_party_sku              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub add_third_party_sku :Export( :create ) {

    my ( $dbh, $product_id, $data_ref ) = @_;

    # default the type_id to 1 (stock) if not defined
    if (not defined $data_ref->{type_id}) {
        $data_ref->{type_id} = 1;
    }

    # check if size already exists
    if ( my $variant_id = _check_variant( $dbh, { 'product_id' => $product_id, 'size_id' => $data_ref->{size_id}, 'type_id' => $data_ref->{type_id} } ) ) {

        my $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );

        # if the variant exists but previously wasnt given a thridparty sku, try to add one now if we have the details
        if ( !$schema->resultset('Public::ThirdPartySku')->find({ variant_id => $variant_id }) ) {

            if ( (defined $data_ref->{third_party_sku}) && (defined $data_ref->{business_id}) ) {
                $schema->resultset('Public::ThirdPartySku')->create({
                    variant_id      => $variant_id,
                    business_id     => $data_ref->{business_id},
                    third_party_sku => $data_ref->{third_party_sku},
                });
            }

        }

    }

}

### Subroutine : get_product_data               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_product_data :Export(:DEFAULT) {
    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id};

    die "PID $id is not a valid integer\n" unless is_valid_database_id($id);

    if  ($type eq 'product_id') {
        my ($schema) = get_schema_and_ro_dbh('xtracker_schema');
        my $voucher = $schema->resultset('Voucher::Product')->find($id);
        return get_voucher_data($voucher) if $voucher;
    }

    my %subqry = (
        'product_id'     => ' WHERE p.id = ?',
        'stock_order_id' => ' WHERE p.id = ( select product_id from stock_order where id = ? )',
        'variant_id'     => ' WHERE p.id = ( select product_id from variant where id = ?)',
    );

    my $qry = qq{
         select p.id, w.world, d.designer, di.division, c.classification,
                pt.product_type, st.sub_type, pa.name, p.style_number,
                p.legacy_sku, p.season_id, pa.description, col_f.colour_filter, p.hs_code_id, p.storage_type_id, stype.name as storage_type,
                pa.designer_colour, pa.designer_colour_code, col.colour,
                pm.payment_term, ( pd.deposit_percentage || '%' ) as payment_deposit,
                ( psd.discount_percentage || '%' ) as payment_settlement_discount, ss.id as size_scheme_id, ss.name as size_scheme_name, ss.short_name as size_scheme,
                prd.complete as pricing_complete, o.name as operator_name, o.username, s.season, sa.act, pp.uk_landed_cost, pa.pre_order
           from product p left join price_default prd on ( prd.product_id = p.id ) left join price_purchase pp on ( pp.product_id = p.id ) left join operator o on ( prd.complete_by_operator_id = o.id )
                          left join sub_type st on ( p.sub_type_id = st.id )
                          left join world w on ( p.world_id = w.id )
                          left join hs_code hs on ( p.hs_code_id = hs.id )
                          left join product_type pt on ( p.product_type_id = pt.id )
                          left join division di on ( p.division_id = di.id )
                          left join classification c on ( p.classification_id = c.id )
                          left join designer d on ( p.designer_id = d.id )
                          left join colour col on ( p.colour_id = col.id )
                          left join filter_colour_mapping fcm on ( col.id = fcm.colour_id )
                               join colour_filter col_f on ( fcm.filter_colour_id = col_f.id )
                          left join legacy_attributes la on ( p.id = la.product_id )
                          left join product.storage_type stype ON (p.storage_type_id = stype.id)
                               join season s ON (p.season_id = s.id)
                               join product_attribute pa ON (p.id = pa.product_id)
                          left join size_scheme ss on ( pa.size_scheme_id = ss.id )
                          left join season_act sa on ( pa.act_id = sa.id )
                               join payment_term pm ON (p.payment_term_id = pm.id)
                               join payment_deposit pd ON (p.payment_deposit_id = pd.id)
                               join payment_settlement_discount psd ON (p.payment_settlement_discount_id = psd.id)
                $subqry{$type}
};

    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

    # FIXME - Why are we looping through any number of rows, and just
    # retruning the last one?
    my $data;
    while ( my $row = $sth->fetchrow_hashref() ) {
        $data = $row;
    }

    foreach (qw[name description designer designer_colour]) {
        $data->{$_} = decode_db($data->{$_});
    }

    return $data;
}



### Subroutine : get_variant_product_data                  ###
# usage        : $hash_ptr = get_variant_product_data(       #
#                   $dbh,                                    #
#                   $variant_id)                             #
# description  : Get's a mix of Product and Variant Data     #
#                for a Variant Id, including Size, Designer, #
#                Product Name etc.                           #
# parameters   : A Database Handle and a Variant Id          #
# returns      : A pointer to a Hash containing the data     #

sub get_variant_product_data :Export() {

    my ($dbh, $variant_id)  = @_;

    my $qry = <<QRY
SELECT  v.product_id,
        v.product_id || '-' || sku_padding(size_id) as sku,
        v.legacy_sku,
        pa.name,
        d.designer,
        s.size AS nap_size,
        ss.short_name || ' ' || s2.size AS designer_size
FROM    variant v,
        product p,
        product_attribute pa LEFT JOIN size_scheme ss ON pa.size_scheme_id = ss.id,
        designer d,
        size s,
        size s2
WHERE   v.id                = ?
AND     v.product_id        = p.id
AND     p.id                = pa.product_id
AND     p.designer_id       = d.id
AND     v.size_id           = s.id
AND     v.designer_size_id  = s2.id
QRY
;

    my $sth = $dbh->prepare($qry);
    $sth->execute( $variant_id );

    return decode_db( $sth->fetchrow_hashref() );
}


### Subroutine : get_variant_id                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_variant_id :Export() {

    my ( $dbh, $p ) = @_;

    if ( (exists $p->{type}) && $p->{type} eq 'sku' ) {

        return get_variant_by_sku( $dbh, $p->{id} );

    } elsif (
        (exists $p->{product_id}) and $p->{product_id} and
        (exists $p->{size_id})    and $p->{size_id}
    ) {

        my $type_clause = '';

        if ( (exists $p->{type}) && $p->{type} eq 'sample' ) {
            $type_clause = qq{ and v.type_id = $VARIANT_TYPE__SAMPLE };
        }
        elsif ( (exists $p->{type}) && $p->{type} eq 'stock' ) {
            $type_clause = qq{ and v.type_id = $VARIANT_TYPE__STOCK };
        }

        my $qry = qq{
select v.id
from variant v
where product_id = ?
and size_id = ?
$type_clause
order by v.size_id
};

        my $sth = $dbh->prepare( $qry );

        $sth->execute( $p->{product_id}, $p->{size_id} );

        my $variant_id = $sth->fetchrow;

        return $variant_id;

    }
    else {

        my $clause = {

            'product_id' => 'and v.product_id = ?',

        };
        my $stock_type_clause   = "";

        if ( exists $p->{stock_type} ) {
            if ( $p->{stock_type} eq 'sample' ) {
                $stock_type_clause  = qq{ and v.type_id = $VARIANT_TYPE__SAMPLE };
            }
            elsif ( $p->{stock_type} eq 'stock' ) {
                $stock_type_clause  = qq{ and v.type_id = $VARIANT_TYPE__STOCK };
            }
        }

        my $qry = qq{
select v.id
from variant v
where 1 = 1
$clause->{$p->{type}}
$stock_type_clause
order by v.size_id
};

        my $sth = $dbh->prepare( $qry );

        $sth->execute( $p->{id} );

        my $variant_id = $sth->fetchrow;

        $sth->finish;

        return $variant_id;

    }

}


### Subroutine : get_variant_by_sku             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_variant_by_sku :Export(:DEFAULT) {

    my ( $dbh, $sku ) = @_;

    my %qry = (
        'new' =>
            'select id from super_variant where product_id = ? and size_id = ? and type_id = '.$VARIANT_TYPE__STOCK,
        'old' => 'select id from variant where legacy_sku = ? and type_id = '.$VARIANT_TYPE__STOCK,
    );

    my $sth;

    if ( $sku =~ m/-/ ) {
        my ($product_id, $size_id) = split /-/, $sku;
        $sth = $dbh->prepare( $qry{"new"} );
        $sth->execute($product_id, $size_id);
    }
    else {
        $sth = $dbh->prepare( $qry{"old"} );
        $sth->execute($sku);
    }

    my $variant_id;
    $sth->bind_columns( \$variant_id );
    $sth->fetch();

    return $variant_id;
}


sub get_voucher_variant_list {
    my ($dbh, $a, $b )  = @_;

    my $by  = $b->{by} || '';

    my $where = '';
    if ( $by eq 'stock_dc1' ) {
        $where = qq{ and q.status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS };
    }
    elsif ( $by eq 'size_list' ){
        $where = '';
    }
    elsif ( $by eq 'stock_other' ) {
        $where = qq{ and q.status_id != $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS };
    }
    elsif ( $by eq 'sample') {
        return; # vouchers don't have samples
    }

    my $qry = "select v.id,
       v.voucher_product_id as product_id,
       lpad(CAST('999' AS varchar), 3, '0') as size_id,
       'Voucher' as legacy_sku,
       'N/A - Voucher' as size,
        'N/A - Voucher' AS designer_size,
       'Stock' as variant_type,
       q.status_id,
       si.shipment_item_status_id,
       '' as size_prefix,
       ch.name as sales_channel,
       ch.id as channel_id
    from voucher.variant v
       left join quantity q on v.id = q.variant_id
       left join channel ch on q.channel_id = ch.id
       left join location l on l.id = q.location_id
       left join shipment_item si on v.id = si.voucher_variant_id
    where  v.voucher_product_id = ? $where";

    my $sth = $dbh->prepare( $qry );
    $sth->execute($a->{voucher_product_id});

    if ( exists $a->{return} && $a->{return} eq 'List' ) {
        return $sth->fetchall_arrayref( {} );
    }

    return results_hash2($sth, 'id' );
}

sub get_variant_list :Export(:DEFAULT)  {
    my ($dbh, $args_ref, $by_args_ref ) = @_;

    my @params  = @_;

    # this is so we can provide additional fields when we mean to
    my $add_designer_size_id = delete $args_ref->{add_designer_size_id}
        || undef;
    my ($thetype, $and_by)=('','');
    my $type        = $args_ref->{type};
    my $id          = $args_ref->{id};
    my $return      = $args_ref->{return} || 'Hash';
    my $type_id     = $args_ref->{type_id};
    my $location    = $args_ref->{location};
    my $phase       = $args_ref->{iws_rollout_phase} || config_var('IWS', 'rollout_phase');
    my $prl_phase   = $args_ref->{prl_rollout_phase} || config_var('PRL', 'rollout_phase');
    my $exclude_iws = $args_ref->{exclude_iws} || ''; # include IWS unless the caller doesn't want it
    my $exclude_prl = $args_ref->{exclude_prl} || ''; # include PRLs unless the caller doesn't want it
    my $by          = $by_args_ref->{by} || '';

    # decide to return voucher list or not
    if ( ( $type eq 'product_id' || $type eq 'variant_id' ) && !$args_ref->{voucher_product_id} ) {
        my $vouch_prod_id   = is_voucher( $dbh, { type => $type, id => $id } ) || 0;
        $args_ref->{voucher_product_id} = $vouch_prod_id    if ( $vouch_prod_id );
    }
    return get_voucher_variant_list(@params)    if $args_ref->{voucher_product_id};

    my %qry_id = ( 'product_id' => " v.product_id = ? ",
                   'variant_id' => " v.id = ? ",
                 );

    if ($type_id) {
        $thetype = "and v.type_id = $type_id";
    }else{
        $thetype = "";
    }

    my $and_not_in_iws = '';
    my $and_not_in_prl = '';

    if ( $exclude_iws && $phase > 0 ) {
        my $iws_location_name = iws_location_name();
        # not in works where != doesn't, if $iws_location_name is not known to the DB
        $and_not_in_iws = qq{ and (l.id is null or l.id not in ( select id from location where location='$iws_location_name' )) };
    }

    if ( $exclude_prl && $prl_phase > 0 ) {
        my $prl_location_names = XT::Domain::PRLs::get_prl_location_names();

        if ($prl_location_names && @$prl_location_names) {
            my $prl_location_string = "'".join("','",@$prl_location_names)."'";
            $and_not_in_prl = qq{ and l.id not in ( select id from location where location in ($prl_location_string) ) };
        }
    }

    if    ( $by eq 'stock_dc1' or $by eq 'stock_main' ) {
        $and_by = qq{ and ( q.status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS ) and v.type_id = $VARIANT_TYPE__STOCK }
                . $and_not_in_iws
                . $and_not_in_prl;
    }
    elsif ( $by eq 'size_list' ){
        $and_by = qq{ and v.type_id = $VARIANT_TYPE__STOCK } . $and_not_in_iws;
    }
    elsif ( $by eq 'stock_other'   ) {
        $and_by = qq{ and q.status_id not in ($FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                                              $FLOW_STATUS__IN_TRANSIT_FROM_IWS__STOCK_STATUS,
                                              $FLOW_STATUS__IN_TRANSIT_FROM_PRL__STOCK_STATUS)
                      and v.type_id = $VARIANT_TYPE__STOCK }
                  . $and_not_in_iws
                  . $and_not_in_prl;
    }
    elsif ( $by eq 'stock_transit' ) {
        $and_by = qq{ and q.status_id in ($FLOW_STATUS__IN_TRANSIT_FROM_IWS__STOCK_STATUS,
                                          $FLOW_STATUS__IN_TRANSIT_FROM_PRL__STOCK_STATUS)
                    and v.type_id = $VARIANT_TYPE__STOCK };
    }
    elsif ( $by eq 'sample'        ) {
        $and_by = qq{ and v.type_id = $VARIANT_TYPE__SAMPLE };
    }

    my $qry = "
select v.id,
       v.product_id,
       sku_padding(v.size_id) as size_id,
       v.legacy_sku,
       s.size,
       ds.size AS designer_size, "
        . ($add_designer_size_id ?
        'ds.id as designer_size_id, ' : '').
        " vt.type as variant_type,
       q.status_id,
       si.shipment_item_status_id,
       ss.short_name as size_prefix,
       ch.name as sales_channel,
       ch.id as channel_id,
       tps.third_party_sku
  from variant_type vt,
       variant v
       left join quantity q on v.id = q.variant_id
            left join channel ch on q.channel_id = ch.id
       left join third_party_sku tps on v.id = tps.variant_id
       left join location l on l.id = q.location_id
       left join size s on v.size_id = s.id
       left join size ds on v.designer_size_id = ds.id
       left join shipment_item si on v.id = si.variant_id,
       product_attribute pa,
       size_scheme ss
 where $qry_id{$type}
   and v.type_id = vt.id
   and v.product_id = pa.product_id
   and pa.size_scheme_id = ss.id
   $thetype
   $and_by
 group by v.id, v.product_id, v.size_id, v.legacy_sku, s.size, ds.size, vt.type, q.status_id, si.shipment_item_status_id, ss.short_name, ch.name, ch.id, tps.third_party_sku "
        . ($add_designer_size_id ?
        ', ds.id ' : '').

 " order by v.size_id "
        . ($add_designer_size_id ?
        ', ds.id ' : '');


    if ( $location ) {

        $qry = qq/
select v.id,
       v.product_id,
       sku_padding(v.size_id) as size_id,
       v.legacy_sku,
       s.size, ds.size as designer_size,
       coalesce(sois.status, '--') as status,
       vt.type as variant_type,
       q.status_id,
       si.shipment_item_status_id,
       ss.short_name as size_prefix,
       ch.name as sales_channel,
       ch.id as channel_id,
       q.quantity
  from size s,
       size ds,
       variant_type vt,
       quantity q,
       channel ch,
       location l,
       variant v
       left join (stock_order_item soi join stock_order_item_status sois on (soi.status_id = sois.id)) on (soi.variant_id = v.id)
       left join shipment_item si on v.id = si.variant_id,
       product_attribute pa,
       size_scheme ss
 where $qry_id{$type}
   and v.size_id = s.id
   and v.designer_size_id = ds.id
   and v.product_id = pa.product_id
   and pa.size_scheme_id = ss.id
   $thetype
   $and_by
   and v.type_id = vt.id
   and v.id = q.variant_id
   and q.channel_id = ch.id
   and q.location_id = l.id
   and l.location = '$location'
 group by v.id, v.product_id, v.size_id, v.legacy_sku, s.size, ds.size,
       sois.status, vt.type, q.status_id, si.shipment_item_status_id, ss.short_name, ch.name, ch.id,  q.quantity
 order by v.size_id
/;

    }

    my $sth = $dbh->prepare( $qry );
    $sth->execute($id);

    if ($return eq 'List') {
        return $sth->fetchall_arrayref( {} );
    }

    return results_hash2($sth, 'id' );
}



### Subroutine : get_product_shipping_attributes             ###
# usage        :                                               #
# description  :                                               #
# parameters   :                                               #
# returns      :                                               #

sub get_product_shipping_attributes :Export() {

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id  };

    my %subqry = (
        'product_id'     => ' product_id = ?',
        'variant_id'     => ' product_id = ( select product_id from variant where id = ?)',
    );

    my $qry = "SELECT
        sa.scientific_term,
        sa.country_id,
        sa.packing_note,
        sa.dangerous_goods_note,
        to_char(sa.packing_note_date_added, 'DD-MM-YYYY HH24:MI') as packing_note_date_added,
        sa.weight,
        sa.box_id,
        sa.fabric_content,
        c.country,
        hs.hs_code,
        sa.fish_wildlife,
        sa.fish_wildlife_source,
        sa.cites_restricted,
        sa.is_hazmat,
        o.name as operator_name
    FROM shipping_attribute sa
            LEFT JOIN operator o ON sa.packing_note_operator_id = o.id
            LEFT JOIN country c ON sa.country_id = c.id,
         product p
            LEFT JOIN hs_code hs ON p.hs_code_id = hs.id
    WHERE $subqry{$type}
    AND sa.product_id = p.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

    my $data;
    while ( my $row = $sth->fetchrow_hashref() ) { $data = $row; }

    return $data;
}


# return product_id from a piece of data

### Subroutine : get_product_id                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_product_id :Export(:DEFAULT) {

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id};
    $id =~ s/^p-//i;

    my %qry = (
        # delivery_id, stock_order and process_group will return a voucher_product_id
        'delivery_id' => 'SELECT CASE WHEN so.product_id IS NULL THEN so.voucher_product_id ELSE so.product_id END AS product_id
                            FROM delivery_item di
                            JOIN link_delivery_item__stock_order_item link ON link.delivery_item_id = di.id
                            JOIN stock_order_item soi ON soi.id = link.stock_order_item_id
                            JOIN stock_order so ON soi.stock_order_id = so.id
                            WHERE di.delivery_id = ?
                         LIMIT 1',
        'stock_order'   => 'select CASE WHEN product_id IS NULL THEN
                voucher_product_id ELSE product_id END AS product_id from stock_order where id = ?',
        'process_group' => 'select CASE WHEN product_id IS NULL THEN
                voucher_product_id ELSE product_id END AS product_id from stock_order where id =
                                        ( select stock_order_id
                                          from stock_order_item where id =
                                            ( select stock_order_item_id
                                              from link_delivery_item__stock_order_item
                                              where delivery_item_id =
                                                 ( select delivery_item_id
                                                   from stock_process where
                                                   group_id = ? limit 1 )))',
        'return_process_group' => 'select product_id from variant where id =
                                        ( select variant_id
                                          from return_item where id =
                                            ( select return_item_id
                                              from link_delivery_item__return_item
                                              where delivery_item_id =
                                                 ( select delivery_item_id
                                                   from stock_process where
                                                   group_id = ? limit 1 )))',
        'sample_process_group' => 'select product_id from variant where id =
                                        ( select variant_id
                                          from shipment_item where id =
                                            ( select shipment_item_id
                                              from link_delivery_item__shipment_item
                                              where delivery_item_id =
                                                 ( select delivery_item_id
                                                   from stock_process where
                                                   group_id = ? limit 1 )))',
        'quarantine_process_group' => 'select product_id from variant where id =
                                        ( select variant_id
                                          from quarantine_process where id =
                                            ( select quarantine_process_id
                                              from link_delivery_item__quarantine_process
                                              where delivery_item_id =
                                                 ( select delivery_item_id
                                                   from stock_process where
                                                   group_id = ? limit 1 )))',
        'variant_id'    => 'SELECT CASE
                                WHEN (SELECT product_id FROM variant WHERE id = ?) IS NULL
                                    THEN (SELECT voucher_product_id FROM voucher.variant WHERE id =  ?)
                                ELSE (SELECT product_id FROM variant WHERE id = ?)
                                END AS product_id;',
        'legacy_sku'    => 'select product_id from variant where legacy_sku = ?',

    );

    my @param = ($id);
    push @param ,$id,$id if $type eq 'variant_id';
    my $sth = $dbh->prepare( $qry{$type} );
    $sth->execute(@param);

    my $product_id;
    $sth->bind_columns( \$product_id );
    $sth->fetch();

    return $product_id;
}

# see if a variant_id / product_id is refering to a voucher
#
sub is_voucher {
    my ($dbh, $a) = @_;

    my $sql;
    if($a->{type} eq 'variant_id') {
        $sql = 'select voucher_product_id from voucher.variant where id = ?';
    }
    elsif($a->{type} eq 'product_id') {
        $sql = 'select id from voucher.product where id = ?';
    }
    else {
        die "invalid type parameter '$a->{type}'";
    }

     my $sth = $dbh->prepare( $sql);
    $sth->execute($a->{id});

    my $id;
    $sth->bind_columns( \$id );
    $sth->fetch;
    return $id;
}



# searchs names and keywords only
sub simple_product_search {
    my ($dbh, $input) = @_;
    my $args = clone($input);
    my $pid = delete $args->{product_id};
    my $keyword = delete $args->{keywords};
    delete $args->{page};

    my $expected = {
        discount    => "all",
        live        => "all",
        location    => "all",
        stockvendor => "all",
        visible     => "all",
    };

    return unless eq_deeply($args,$expected) and ($pid || $keyword);

    my @args;
    my $product_claus = '';
    my $v_product_claus = '';
    my $kw_claus = '';
    my $v_kw_claus = '';

    if ($pid) {
        $product_claus = 'p.id = ?';
        $v_product_claus = 'vp.id = ?';
    }

    if ($keyword) {
        $kw_claus = ' and ' if $product_claus;
        $kw_claus .= ' (name ilike ? or description ilike ?) ';

        $v_kw_claus = ' and ' if $product_claus;
        # another easy optimisation. if (str !~ Gift Voucher) { strip out entire half of union }
        $v_kw_claus .= " (vp.name ilike ? or 'Gift Voucher' ilike ?) ";

        $keyword = "%$keyword%";
    }

    my $query = "
        (
            SELECT
                p.id,
                pa.name,
                se.season,
                act.act,
                dept.department,
                d.designer,
                pt.product_type,
                pa.description,
                pa.designer_colour,
                pa.designer_colour_code,
                c.colour,
                p.style_number,
                p.legacy_sku,
                bool_or(pc.live) as live
            FROM product p
            join product_channel pc on (p.id = pc.product_id)
            join season se on(p.season_id = se.id)
            join designer d on (p.designer_id = d.id)
            join product_type pt on ( p.product_type_id = pt.id )
            join colour c on (p.colour_id = c.id )
            left join product_attribute pa on ( p.id = pa.product_id )
            join season_act act on (pa.act_id = act.id)
            join product_department dept on (pa.product_department_id = dept.id)
            join variant v on (v.product_id = p.id)
            join variant_type vt on (v.type_id = vt.id)
            WHERE
                $product_claus $kw_claus
            GROUP BY
                p.id,
                pa.name,
                se.season,
                act.act,
                dept.department,
                d.designer,
                pt.product_type,
                pa.description,
                pa.designer_colour,
                pa.designer_colour_code,
                c.colour,
                p.style_number,
                p.legacy_sku,
                pc.live
        )
        UNION ALL
        (
        SELECT vp.id,
            vp.name,
            'Continuity' as season,
            'Unknown' as act,
            'Unknown' as department,
            'Unknown' as designer,
            'Unknown' as product_type,
            'Gift Voucher' as description,
            'N/A' as designer_colour,
            'N/A' as designer_colour_code,
            'N/A' as colour,
            'Gift Voucher' as style_number,
            '9999' as legacy_sku,
            case when
                vp.upload_date is not null
                then true
                else false
            end as live
        FROM
        voucher.product vp
        WHERE
        $v_product_claus $v_kw_claus)
        limit 2500
   ";

    my $sth = $dbh->prepare($query);
    $sth->execute(grep { defined } ($pid, $keyword, $keyword, $pid, $keyword, $keyword));

    return results_list($sth);
}

sub search_product :Export( :search ) {
    my ( $dbh, $args_ref ) = @_;

    my $r = simple_product_search($dbh, $args_ref);
    return $r if $r;

    my @from = (
        'FROM product p',
        'LEFT JOIN product_attribute pa ON ( p.id = pa.product_id )',
        'JOIN colour c ON ( p.colour_id = c.id )',
        'JOIN designer d ON ( p.designer_id = d.id )',
        'JOIN product_channel pc ON ( p.id = pc.product_id )',
        'JOIN product_department dept ON ( pa.product_department_id = dept.id )',
        'JOIN product_type pt ON ( p.product_type_id = pt.id )',
        'JOIN season_act act ON ( pa.act_id = act.id )',
        'JOIN season se ON ( p.season_id = se.id )',
        'JOIN variant v ON ( v.product_id = p.id )',
        'JOIN variant_type vt ON ( v.type_id = vt.id )',
    );

    croak 'No location defined' unless defined $args_ref->{location};

    # This horrible cascading elsif builds the location-dependent part of the
    # 'from' and 'where' clauses for the query
    my @where;
    if ( $args_ref->{location} =~ m{^(?:inventory|alllocated)$} ) {
        push @from, 'JOIN quantity q ON ( v.id = q.variant_id )';
    }
    elsif ( $args_ref->{location} eq 'all' ) {
        push @from, 'LEFT JOIN quantity q ON ( v.id = q.variant_id )';
    }
    elsif ( $args_ref->{location} eq 'dc1stock' ) {
        push @from, 'JOIN quantity q ON ( v.id = q.variant_id )';
        push @where,
            'q.status_id IN ( '
          . ( join q{, },
                $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
                $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
                $FLOW_STATUS__REMOVED_QUARANTINE__STOCK_STATUS,
                $FLOW_STATUS__SAMPLE__STOCK_STATUS,
                $FLOW_STATUS__QUARANTINE__STOCK_STATUS )
          . q{ )},
            "vt.id = $VARIANT_TYPE__STOCK";
    }
    elsif ( $args_ref->{location} =~m/^dc.$/ ) {
        push @from, 'JOIN quantity q ON ( v.id = q.variant_id )';
        push @where, "q.status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS";
    }
    elsif ( $args_ref->{location} eq 'transfer' ) {
        push @from,
            'JOIN quantity q ON ( v.id = q.variant_id )',
            'JOIN shipment_item si ON ( v.id = si.variant_id )',
            'JOIN shipment sh ON ( si.shipment_id = sh.id )';

        push @where,
            'q.status_id IN ( '
          . ( join q{, },
              $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
              $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
              $FLOW_STATUS__REMOVED_QUARANTINE__STOCK_STATUS )
          . q{ )},
            "sh.shipment_class_id = $SHIPMENT_CLASS__TRANSFER_SHIPMENT";
    }
    elsif ( $args_ref->{location} =~ m{\A
        sample
        (?:_
            (?:room|room_press|editorial|faulty|gift|press|styling|upload_[12])
        )? # optionally end with '_$string'
    \z}xms ) {
        push @from, 'JOIN quantity q ON ( v.id = q.variant_id )';

        my %location_map = (
            sample_room       => 'Sample Room',
            sample_room_press => 'Press Samples',
            sample_editorial  => 'Editorial',
            sample_faulty     => 'Faulty',
            sample_gift       => 'Gift',
            sample_press      => 'Press',
            sample_styling    => 'Styling',
            sample_upload_1   => 'Upload 1',
            sample_upload_2   => 'Upload 2',
        );
        push @where, (
            $args_ref->{location} eq 'sample'
          ? "q.status_id IN ( $FLOW_STATUS__SAMPLE__STOCK_STATUS, $FLOW_STATUS__CREATIVE__STOCK_STATUS )"
          : "q.location_id IN ( SELECT id FROM location WHERE location = '$location_map{$args_ref->{location}}' )"
        );
    }
    elsif ( $args_ref->{location} =~ m{\A(dead|rtv_workstation|rtv_process)\z}xms ) {
        push @from, 'JOIN quantity q ON ( q.variant_id = v.id )';

        my %location_status_map = (
            dead            => $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS,
            rtv_workstation => $FLOW_STATUS__RTV_WORKSTATION__STOCK_STATUS,
            rtv_process     => $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
        );
        push @where, "q.status_id = $location_status_map{$args_ref->{location}}";
    }
    else {
        croak "Unrecognised location $args_ref->{location}";
    }

    push @from, 'JOIN shipping_attribute sa ON ( p.id = sa.product_id )'
        if $args_ref->{fabric};

    # Here we build the location-independent 'where' part of the query
    my %arg_map = (
        stockvendor => {
            all => '1 = 1',
            stock => "vt.id = $VARIANT_TYPE__STOCK",
            vendor => "vt.id = $VARIANT_TYPE__SAMPLE",
        },
        discount => {
            all => '1 = 1',
            discount => 'p.payment_settlement_discount_id != 0',
            notdiscount => 'p.payment_settlement_discount_id = 0',
        },
        live => {
            all => '1 = 1',
            live => 'pc.live = true',
            notlive => 'pc.live = false',
        },
        visible => {
            all => '1 = 1',
            visible => 'pc.visible = true',
            notvisible => 'pc.visible = false',
        },
    );

    push @where, map { $arg_map{$_}{$args_ref->{$_}} }
        grep { exists $args_ref->{$_} } keys %arg_map;

    my %where_clause_map = (
        binds => {
            'product_id'     => 'p.id = ?',
            'season'         => 'p.season_id = ?',
            'classification' => 'p.classification_id = ?',
            'product_type'   => 'p.product_type_id = ?',
            'sub_type'       => 'p.sub_type_id = ?',
            'designer'       => 'p.designer_id = ?',
            'act'            => 'pa.act_id = ?',
            'department'     => 'pa.product_department_id = ?',
            'colour'         => 'p.colour_id = ?',
            'colour_filter'  => 'p.colour_filter_id = ?',
            'channel_id'     => 'pc.channel_id = ?',
        },
    );
    $where_clause_map{no_binds}{style_ref} = "LOWER(p.style_number) LIKE LOWER('%$args_ref->{style_ref}%')"
        if (defined $args_ref->{style_ref});
    $where_clause_map{no_binds}{fabric} = "LOWER(sa.fabric_content) LIKE LOWER('%$args_ref->{fabric}%')"
        if (defined $args_ref->{fabric});
    $where_clause_map{no_binds}{keywords} = "LOWER(pa.keywords) LIKE LOWER ('%$args_ref->{keywords}%')"
        if (defined $args_ref->{keywords});

    my @param;
    foreach my $key ( keys %$args_ref ) {
        # Populate @where for params that require binds and that don't
        for my $param_type ( qw{binds no_binds} ) {
            push @where, $where_clause_map{$param_type}{$key}
                if grep { m{^$key$} } keys %{$where_clause_map{$param_type}};
        }
        # Only populate @param for keys that require binds
        push @param, $args_ref->{$key}
            if grep { m{^$key$} } keys %{$where_clause_map{binds}};
    }

    my $select
        = "SELECT DISTINCT ON (p.id) p.id, pa.name, se.season, act.act, dept.department, d.designer, pt.product_type, pa.description, pa.designer_colour, pa.designer_colour_code, c.colour, p.style_number, MAX( CAST(pc.live AS integer)) AS live, q.quantity";
    my $group_by
        = "GROUP BY p.id, pa.name, se.season, act.act, dept.department, d.designer, pt.product_type, pa.description, pa.designer_colour, pa.designer_colour_code, c.colour, p.style_number, q.quantity";
    my $order_by = "ORDER BY p.id, q.quantity";
    # limit to 5001 to keep make Glynn smile
    my $limit = "LIMIT 5001";

    my $qry = join qq{ },
        $select,
        ( join qq{ }, @from ),
        ( @where ? 'WHERE ' . join qq{ AND }, @where : q{} ),
        $group_by,
        $order_by,
        $limit;

    my $sth = $dbh->prepare($qry);
    $sth->execute( @param );
    my $results_list = results_list($sth);

    # fix encoding for some columns...
    for my $column_name (qw( designer )) {
        $_->{$column_name} = decode_db( $_->{$column_name} ) for @$results_list;
    }
    return $results_list;
}

### Subroutine : get_sku                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_sku :Export(:DEFAULT) {

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id};

    my %qry = ( 'variant_id' => 'select legacy_sku from variant where id = ?',
                'product_id' => 'select legacy_sku from product where id = ?',
              );

    my $sth = $dbh->prepare( $qry{$type} );
    $sth->execute( $id );

    my $sku = "";
    $sth->bind_columns( \$sku );
    $sth->fetch();

    if( $sku eq "" ){
        croak "Could not find legacy sku";
    }

    return $sku;
}


### Subroutine : product_present                                    ###
# usage        :                                                      #
# description  : return true if it's live, staging or fulfilment_only #
# parameters   :                                                      #
# returns      :                                                      #

sub product_present :Export() {

    my ( $dbh, $args_ref ) = @_;

    my $type        = $args_ref->{type};
    my $id          = $args_ref->{id};
    my $channel_id  = $args_ref->{channel_id};
    my $environment = defined $args_ref->{environment} ? $args_ref->{environment} : 'live';

    if ( $environment !~ m{^live|staging$} ) {
        croak "Invalid environment specified for product_present() : $environment.";
    }

    if ( not defined $channel_id ) {
        croak "No channel_id defined for product_present()";
    }

    # It's regarded as present if it's a fulfilment_only product.
    my $schema  = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    my $channel = $schema->resultset('Public::Channel')->find($channel_id);
    return unless $channel;
    return 1 if $channel->business->fulfilment_only;

    my %qry = ( 'variant_id' => 'select live, staging from product_channel where channel_id = ? and product_id = ( select product_id from variant where id = ? )',
                'product_id' => 'select live, staging from product_channel where channel_id = ? and product_id = ?',
              );

    my $sth = $dbh->prepare( $qry{$type} );
    $sth->execute( $channel_id, $id );

    my ($live, $staging);
    $sth->bind_columns( \($live, $staging) );
    $sth->fetch();

    # if didn't get back either Live or Staging
    # see if the product is a Voucher
    if ( !defined $live && !defined $staging ) {
        my $voucher;
        if ( $type eq 'product_id' ) {
            $voucher    = $schema->resultset('Voucher::Product')
                                    ->search( { id => $id, channel_id => $channel_id } )
                                    ->first;
        }
        if ( $type eq 'variant_id' ) {
            my $variant = $schema->resultset('Voucher::Variant')
                                    ->search(
                                        {
                                            'me.id' => $id,
                                            'product.channel_id' => $channel_id,
                                        },
                                        {
                                            join => 'product',
                                        } )->first;
            $voucher    = $variant->product     if ( defined $variant );
        }
        # if a Voucher was found
        if ( defined $voucher ) {
            my $tmp = $voucher->live;
            $live   = ( defined $tmp ? $tmp : 0 );
            $staging= 0;        # don't know about staging yet
        }
    }

    my $retval  = ($environment eq 'live')      ?   $live
                : ($environment eq 'staging')   ?   $staging
                :                                   undef
                ;

    return $retval;

}

### Subroutine : get_fcp_sku                       ###
# usage        :                                     #
# description  :                                     #
# parameters   : type [ variant_id ], id             #
# returns      : scalar fcp sku (product_id-size_id) #

sub get_fcp_sku :Export {

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id};

    my %qry = ( 'variant_id' => q{ select product_id || '-' ||
        sku_padding(size_id) as sku
        from variant where id = ? },
        'product_id' => q{ select product_id || '-' || sku_padding(size_id) as sku
                                   from variant where id = ( select min(id) from variant where product_id = ? ) },
            'product_id' => q{ select product_id || '-' || sku_padding(size_id) as sku
                                   from variant where id = ( select min(id) from variant where product_id = ? ) },
              );

    my $sth = $dbh->prepare_cached( $qry{$type} );          # use 'prepare_cached' for faster acces on subsequent calls
    $sth->execute( $id );

    my $sku = undef;
    $sth->bind_columns( \$sku );
    $sth->fetch();
    $sth->finish();

    # if no SKU found check to see if it is a Voucher
    if ( !defined $sku ) {
        my $schema  = get_schema_using_dbh( $dbh, 'xtracker_schema' );
        my $voucher;
        if ( $type eq 'product_id' ) {
            $voucher    = $schema->resultset('Voucher::Product')->find( $id );
        }
        if ( $type eq 'variant_id' ) {
            # can set the same variable as the method '->sku' is available
            # for both Voucher::Product & Voucher::Variant
            $voucher    = $schema->resultset('Voucher::Variant')->find( $id );
        }
        # if a Voucher was found
        if ( defined $voucher ) {
            $sku    = $voucher->sku;
        }
    }

    # if still no SKU then die
    if( !defined $sku ){
        croak "Could not find build fcp sku";
    }

    return $sku;
}



### Subroutine : create_sample_variant          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_sample_variant :Export() {

    my ( $dbh, $p ) = @_;

    my $var_ref = get_variant_details( $dbh, $p->{variant_id} );

    my $sample_ref = { size_id => $var_ref->{size_id}, designer_size_id => $var_ref->{designer_size_id}, legacy_sku => "s".$var_ref->{legacy_sku}, type_id => 3, size_id_old => $var_ref->{size_id_old} };

    my $id = create_variant( $dbh, $var_ref->{product_id}, $sample_ref );

    return $id;
}


### Subroutine : get_variant_details            ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_variant_details :Export() {

    my ( $dbh, $variant_id ) = @_;

    my $qry = qq{
select v.id, v.product_id, v.size_id, v.designer_size_id, v.legacy_sku, v.product_id || '-' || sku_padding(v.size_id) as sku, v.type_id, v.size_id_old, s.size as nap_size, s2.size as designer_size
from variant v, size s, size s2
where v.id = ?
and v.size_id = s.id
and v.designer_size_id = s2.id
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( $variant_id );

    return $sth->fetchrow_hashref();
}

=pod get_variant_id_by_type

Given a Variant ID, get matching Variant ID of another Variant type.

my $variant_id = get_variant_id_by_type( $dbh, { variant_id => $p->{variant_id}, from => 'Sample', to => 'Stock' } );

=cut

### Subroutine : get_variant_id_by_type         ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_variant_id_by_type :Export() {

    my ( $dbh, $p ) = @_;

    my $from_qry = qq{
 select product_id, size_id
   from variant v,
        variant_type vt
  where v.id = ?
    and vt.type = ?
    and v.type_id = vt.id
};

    my $from_sth = $dbh->prepare( $from_qry );

    $from_sth->execute( $p->{variant_id}, $p->{from_type} );

    my $from_variant = $from_sth->fetchrow_hashref();

    my $to_qry = qq{
 select v.id as variant_id
   from variant v,
        variant_type vt
  where product_id = ?
    and size_id = ?
    and v.type_id = vt.id
    and vt.type = ?
};

    my $to_sth = $dbh->prepare( $to_qry );

    $to_sth->execute( $from_variant->{product_id}, $from_variant->{size_id}, $p->{to_type} );

    my $to_variant = $to_sth->fetchrow_hashref();

    return $to_variant->{variant_id};

}




### Subroutine : get_variant_type               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_variant_type :Export() {

    my ( $dbh, $p ) = @_;

    my $qry = qq{
select vt.type
  from variant v, variant_type vt
 where v.id = ?
   and v.type_id = vt.id
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( $p->{id} );

    my $row = $sth->fetchrow_hashref( );

    return $row->{type};

}


sub check_product_preorder_status :Export() {

    my ( $dbh, $args ) = @_;

    my %qry = (
        'variant' => 'select pa.pre_order from product_attribute pa, variant v where v.id = ? and v.product_id = pa.product_id',
        'product' => 'select pre_order from product_attribute where product_id = ?',
    );

    my $sth = $dbh->prepare( $qry{ $args->{'type'} } );
    $sth->execute( $args->{'id'} );

    my $row = $sth->fetchrow_arrayref( );

    return $row->[0];

}


sub get_price_audit_log :Export() {

    my ($dbh, $argref) = @_;


    # make sure we've got the required args
    if (not defined $argref->{product_id}) {
        croak('Please provide a product_id for get_price_audit_log()');
    }

    my %data            = ();   # hash to hold results


    # price default
    if ( !$argref->{type} || $argref->{type} eq 'price_default' ) {

        my $qry = "SELECT ap.id, TO_CHAR( ap.dtm, 'DD/MM/YY') AS date, TO_CHAR( ap.dtm, 'HH24:MI') AS time,
                    CASE WHEN ap.field_name = 'currency_id' THEN 'Currency' WHEN ap.field_name = 'price' THEN 'Price' ELSE 'Unknown' END AS field_name,
                    CASE WHEN field_name = 'currency_id' THEN cur_pre.currency else ap.value_pre END AS value_pre,
                    CASE WHEN field_name = 'currency_id' THEN cur_post.currency else ap.value_post END AS value_post, op.name
                    FROM audit.product ap
                        LEFT JOIN operator op ON ap.operator_id = op.id
                        LEFT JOIN currency cur_pre ON ap.value_pre = CAST(cur_pre.id AS TEXT)
                        LEFT JOIN currency cur_post ON ap.value_post = CAST(cur_post.id AS TEXT)
                    WHERE ap.product_id = ?
                    AND ap.comment like 'Price default%'
                    AND ap.field_name in ('price', 'currency_id')";

        my $sth = $dbh->prepare($qry);
        $sth->execute($argref->{product_id});

        while ( my $row = $sth->fetchrow_hashref() ) {
            $data{ 'price_default' }{ $row->{id} } = $row;
        }
    }

    # price region
    if ( !$argref->{type} || $argref->{type} eq 'price_region' ) {

        my $qry = "SELECT ap.id, TO_CHAR( ap.dtm, 'DD/MM/YY') AS date, TO_CHAR( ap.dtm, 'HH24:MI') AS time,
                    CASE WHEN ap.field_name = 'currency_id' THEN 'Currency' WHEN ap.field_name = 'price' THEN 'Price' WHEN ap.field_name = 'region_id' THEN 'Region' ELSE 'Unknown' END AS field_name,
                    CASE WHEN ap.value_pre IS NULL THEN 'Added' WHEN field_name = 'currency_id' THEN cur_pre.currency WHEN field_name = 'region_id' THEN r_pre.region ELSE ap.value_pre END AS value_pre,
                    CASE WHEN ap.value_post IS NULL THEN 'Deleted' WHEN field_name = 'currency_id' THEN cur_post.currency WHEN field_name = 'region_id' THEN r_post.region ELSE ap.value_post END AS value_post,
                    op.name, r.region
                    FROM audit.product ap
                        LEFT JOIN operator op ON ap.operator_id = op.id
                        LEFT JOIN currency cur_pre ON ap.value_pre = CAST(cur_pre.id AS TEXT)
                        LEFT JOIN currency cur_post ON ap.value_post = CAST(cur_post.id AS TEXT)
                        LEFT JOIN region r_pre ON ap.value_pre = CAST(r_pre.id AS TEXT)
                        LEFT JOIN region r_post ON ap.value_post = CAST(r_post.id AS TEXT)
                        LEFT JOIN price_region pr ON ap.table_id = pr.id
                        LEFT JOIN region r ON pr.region_id = r.id
                    WHERE ap.product_id = ?
                    AND ap.comment like 'Price region%'
                    AND ap.field_name in ('region_id', 'price', 'currency_id')";

        my $sth = $dbh->prepare($qry);
        $sth->execute($argref->{product_id});

        while ( my $row = $sth->fetchrow_hashref() ) {
            $data{ 'price_region' }{ $row->{id} } = $row;
        }
    }

    # price country
    if ( !$argref->{type} || $argref->{type} eq 'price_country' ) {

        my $qry = "SELECT ap.id, TO_CHAR( ap.dtm, 'DD/MM/YY') AS date, TO_CHAR( ap.dtm, 'HH24:MI') AS time,
                    CASE WHEN ap.field_name = 'currency_id' THEN 'Currency' WHEN ap.field_name = 'price' THEN 'Price' WHEN ap.field_name = 'country_id' THEN 'Country' ELSE 'Unknown' END AS field_name,
                    CASE WHEN ap.value_pre IS NULL THEN 'Added' WHEN field_name = 'currency_id' THEN cur_pre.currency WHEN field_name = 'country_id' THEN c_pre.country ELSE ap.value_pre END AS value_pre,
                    CASE WHEN ap.value_post IS NULL THEN 'Deleted' WHEN field_name = 'currency_id' THEN cur_post.currency WHEN field_name = 'country_id' THEN c_post.country ELSE ap.value_post END AS value_post,
                    op.name, c.country
                    FROM audit.product ap
                        LEFT JOIN operator op ON ap.operator_id = op.id
                        LEFT JOIN currency cur_pre ON ap.value_pre = CAST(cur_pre.id AS TEXT)
                        LEFT JOIN currency cur_post ON ap.value_post = CAST(cur_post.id AS TEXT)
                        LEFT JOIN country c_pre ON ap.value_pre = CAST(c_pre.id AS TEXT)
                        LEFT JOIN country c_post ON ap.value_post = CAST(c_post.id AS TEXT)
                        LEFT JOIN price_country pc ON ap.table_id = pc.id
                        LEFT JOIN country c ON pc.country_id = c.id
                    WHERE ap.product_id = ?
                    AND ap.comment like 'Price country%'
                    AND ap.field_name in ('country_id', 'price', 'currency_id')";

        my $sth = $dbh->prepare($qry);
        $sth->execute($argref->{product_id});

        while ( my $row = $sth->fetchrow_hashref() ) {
            $data{ 'price_country' }{ $row->{id} } = $row;
        }
    }

    return \%data;


}

### Subroutine : get_product_channel_info                         ###
# usage        : get_product_channel_info($dbh, $product_id)        #
# description  : returns a flag to indicate if product has been transferred    #
#                and a hash of all the channel info for a given product id    #
# parameters   : $dbh, $product_id                                  #
# returns      : integer, hash ref                                           #

sub get_product_channel_info :Export() {

    my ( $dbh, $product_id ) = @_;

    my %data = ();
    my $transfer = 0;

    my $qry = qq{
               select pc.channel_id, pc.live, pc.staging, pc.visible, pc.disable_update, pc.cancelled, to_char( pc.arrival_date, 'DD-MM-YYYY' ) as arrival_date, to_char( pc.upload_date, 'DD-MM-YYYY' ) as upload_date, pc.transfer_status_id, to_char( pc.transfer_date, 'DD-MM-YYYY' ) as transfer_date, ch.name as channel_name, b.url as web_url, pcts.status as transfer_status, b.config_section as config_section
                   from product_channel pc, channel ch, business b, product_channel_transfer_status pcts
                   where pc.product_id = ?
                   and pc.channel_id = ch.id
                   and pc.transfer_status_id = pcts.id
                   and ch.business_id = b.id
    };

    my $sth = $dbh->prepare($qry);
    $sth->execute( $product_id );

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{channel_name} } = $row;

        if ( $row->{transfer_status_id} == 4 ) {
            $transfer = 1;
        }
    }

    return $transfer, \%data;
}

=head2 get_product_summary

B<Description>

Same as L<get_product_summary>, but instead of messing with C<$handler>
it gets all necessary arguments as explicit list if parameters and returns
data structure (HASH ref).

B<Parameters>

=over

=item schema

=item product_id

=back

B<Returns>

HASH ref with all data needed for presenting Product summary on web page.

=cut

sub get_product_summary :Export() {
    my ( $schema, $product_id ) = @_;

    # validate and saved passed  parameters
    croak 'Missing schema parameter' unless defined $schema;
    croak 'Missing product_id parameter' unless defined $product_id;

    my $dbh = $schema->storage->dbh;

    # data structure that is going to be returned
    my %results;

    my $product = get_product_data( $dbh, { type => 'product_id', id => $product_id} );

    $results{product} = $product;

    # its NOT a voucher
    if (not $product->{voucher}) {
        # default price
        my @default_selling_prices      = get_pricing( $dbh, $product_id, 'default' );
        $results{default_selling_price} = $default_selling_prices[0][0]{price};
        $results{default_currency}      = $default_selling_prices[0][0]{currency};

        # get all channel data for product
        ($results{channel_transfer}, $results{channel_info}) =
            get_product_channel_info($dbh, $product_id);

        # work out 'active' channel
        my $product_row = $schema->resultset('Public::Product')->find($product_id);
        my $active_channel;
        $active_channel = $product_row->get_current_channel_name() if $product_row;
        $results{active_channel} = $results{channel_info}{ $active_channel };


        # work out if product has ever been live for images
        my $been_live = 0;
        # consider replacing it with "first" from List::Utils
        foreach my $channel_id ( keys %{$results{channel_info}} ) {
            if ( $results{channel_info}{$channel_id}{live} ) {
                $been_live = 1;
                last;
            }
        }

        $results{comments} = get_product_comments( $dbh, $product_id );
        $results{images}   = get_images({
            product_id => $product_id,
            live       => $been_live,
            schema     => $schema,
        });
        $results{purchase_orders} = get_product_purchase_orders( $dbh, $product_id );

    } else {

        # it IS a voucher
        my $voucher = $product->{voucher};

        $results{voucher}                               = 1;
        $results{default_selling_price}                 = $voucher->value;
        $results{default_currency}                      = $voucher->currency->currency;
        $results{channel_info}{$voucher->channel->name} = get_voucher_channel($voucher);

        $results{images} = get_images({
            product_id => $product_id,
            live       => $results{channel_info}{$voucher->channel->name}{live},
            schema     => $schema,
        });

        $results{active_channel} = $results{channel_info}{$voucher->channel->name};

       # get po's
        map {
            $results{purchase_orders}{$_->purchase_order->id}{purchase_order_number}
                = $_->purchase_order->purchase_order_number;
            $results{purchase_orders}{$_->purchase_order->id}{purchase_order_id}
                = $_->purchase_order->id;
        } $schema->resultset('Public::StockOrder')
            ->search({voucher_product_id=>$voucher->id});
    }

    return \%results;
}

sub get_voucher_channel {
    my ($voucher) = @_;
    my $arrival_date = $voucher->arrival_date;
    my $upload_date = $voucher->upload_date;
    return {
        channel_id => $voucher->channel_id,
        live => $voucher->live,
        visible => $voucher->visible,
        arrival_date => $arrival_date ? $arrival_date->dmy('-') : undef,
        cancelled => 0,
        upload_date => $upload_date ? $upload_date->dmy('-') : undef,
        channel_name => $voucher->channel->name,
        web_url => $voucher->channel->business->url,
        transfer_status => 'None',
    };
}

sub get_voucher_data {
    my ($voucher) = @_;
    return {
        id => $voucher->id,
        designer => 'Gift Voucher',
        season => 'N/A',
        colour => 'N/A',
        style_number => 'N/A',
        division => 'N/A',
        product_type => 'Gift Voucher',
        description => 'Gift Voucher',
        sub_type => '',
        size_scheme_name => 'Unsized',
        season => 'Unknown',
        season_id => 0,
        name => $voucher->name,
        operator_name => $voucher->operator->name,
        voucher => $voucher,
        storage_type_id => $voucher->storage_type_id,
        storage_type => $voucher->storage_type->name,
    };
}

=head2 get_products_info_for_upload
    usage       : $hash_ptr = get_products_info_for_upload(
                                $dbh,
                                $pid_arr_ref
                  );
    description : This gets details needed for an upload which currently
                  consists of product name, channel id, live  & upload date.
    parameters  : Database Handle, Array Ref to a List of PIDs.
    returns     : A Pointer to a HASH with the Product Id as the key.
=cut

sub get_products_info_for_upload :Export() {
    my ( $dbh, $pids )  = @_;

    my $in_clause   = join( ',', map { '?' } @{$pids} );

    my $qry =<<QRY
SELECT  pa.product_id,
        pa.name,
        get_product_channel_id(pa.product_id) AS channel_id,
        pc.upload_date,
        pc.live
FROM    product_attribute pa,
        product_channel pc
WHERE   pa.product_id IN ($in_clause)
AND     pa.product_id = pc.product_id
AND     pc.channel_id = get_product_channel_id(pa.product_id)
QRY
    ;

    my $sth = $dbh->prepare($qry);
    $sth->execute( @{$pids} );
    my $return_hashref = decode_db( $sth->fetchall_hashref('product_id') );
    return $return_hashref;
}


### Subroutine : get_recent_uploads                                        ###
# usage        : get_recent_uploads($dbh, $channel_id)                       #
# description  : returns first 25 uploads ordered by descending upload date  #
#                for a given sales channel                                   #
# parameters   : db handle, channel id                                       #
# returns      : array ref                                                   #

sub get_recent_uploads :Export() {

    my ($dbh, $channel_id) = @_;

    my $qry = "SELECT to_char(upload_date, 'DD-MM-YYYY')
    FROM product_channel
    WHERE channel_id = ?
    AND upload_date IS NOT NULL
    GROUP BY upload_date
    ORDER BY upload_date DESC LIMIT 25";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $channel_id );

    my @uploads = ();
    while( my $row = $sth->fetchrow_arrayref() ){
        push @uploads, $row->[0];
    }

    return \@uploads;
}



sub set_product_cancelled :Export() {

    my ($dbh, $argref) = @_;

    # make sure we've got the required args
    if (not defined $argref->{product_id}) {
        croak('Please provide a product_id for set_product_cancelled()');
    }
    if (not defined $argref->{channel_id}) {
        croak('Please provide a channel_id for set_product_cancelled()');
    }

    # check if all stock orders are cancelled for product/channel
    my $cancelled       = 0;
    my $not_cancelled   = 0;

    my $qry = "SELECT so.cancel
    FROM stock_order so, purchase_order po
    WHERE so.product_id = ?
    AND so.purchase_order_id = po.id
    AND po.channel_id = ?";
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $argref->{product_id}, $argref->{channel_id} );

    while ( my $row = $sth->fetchrow_arrayref() ) {
        if ( $row->[0] == 1) {
            $cancelled++;
        }
        else {
            $not_cancelled++;
        }
    }

    # product is "cancelled" - update flag in product_channel table
    if ( $cancelled > 0 && $not_cancelled == 0 ) {
        my $up_qry = "UPDATE product_channel SET cancelled = true WHERE product_id = ? AND channel_id = ?";
        my $up_sth = $dbh->prepare($up_qry);
        $up_sth->execute($argref->{product_id}, $argref->{channel_id});
    }
    else {
        my $up_qry = "UPDATE product_channel SET cancelled = false WHERE product_id = ? AND channel_id = ?";
        my $up_sth = $dbh->prepare($up_qry);
        $up_sth->execute($argref->{product_id}, $argref->{channel_id});
    }

    return;
}


### Subroutine : create_product_channel #
# usage        : #
# description  : #
# parameters   : #
# returns      : #

sub create_product_channel :Export() {

    my ( $dbh, $args )  = @_;

    # validate required args
    foreach my $field ( qw(product_id channel_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for create_product_channel()';
        }
    }

    my $qry = qq{ INSERT INTO product_channel (product_id, channel_id) VALUES (?, ?) };
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{product_id}, $args->{channel_id} );
    my $product_channel_id = last_insert_id($dbh, 'product_channel_id_seq');

    # create stock summary for product and channel
    create_product_stock_summary(
        $dbh,
        {
            product_id      => $args->{product_id},
            ordered         => 0,
            delivered       => 0,
            main_stock      => 0,
            sample_stock    => 0,
            sample_request  => 0,
            reserved        => 0,
            pre_pick        => 0,
            cancel_pending  => 0,
            last_updated    => undef,
            arrival_date    => undef,
            channel_id      => $args->{channel_id},
        }
    );

    return $product_channel_id;
}


### Subroutine : set_product_channel #
# usage        : #
# description  : #
# parameters   : #
# returns      : #

sub set_product_channel :Export() {

    my ( $dbh, $args ) = @_;

    # default op id to application user if not defined
    if (!defined $args->{operator_id} ) {
        $args->{operator_id} = 1;
    }

    # validate required args
    foreach my $field ( qw(product_id channel_id field_name operator_id) ) {
        if ( $field eq 'field_name' && ( $args->{'field_name'} eq 'visible' || $args->{'field_name'} eq 'disableupdate' ) && !$args->{'value'}) {
            $args->{'value'} = 'false';
        }
        if (!$args->{$field}) {
            die 'No '.$field.' defined for set_product_channel()';
        }
    }

    # workaround for leagcy field name
    if ( $args->{field_name} eq 'disableupdate' ) {
        $args->{field_name} = 'disable_update';
    }

    my $qry = "UPDATE product_channel SET $args->{field_name} = ? WHERE product_id = ? AND channel_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $args->{value}, $args->{product_id}, $args->{channel_id} );
}


### Subroutine : create_product_stock_summary #
# usage        : #
# description  : #
# parameters   : #
# returns      : #

sub create_product_stock_summary :Export() {

    my ( $dbh, $args )  = @_;

    # validate required args
    foreach my $field ( qw(product_id channel_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for create_product_stock_summary()';
        }
    }

    my $qry = qq{ INSERT INTO product.stock_summary (product_id, ordered, delivered, main_stock, sample_stock, sample_request, reserved, pre_pick, cancel_pending, last_updated, arrival_date, channel_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) };
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{product_id}, $args->{ordered}, $args->{delivered}, $args->{main_stock}, $args->{sample_stock}, $args->{sample_request}, $args->{reserved}, $args->{pre_pick}, $args->{cancel_pending}, $args->{last_updated}, $args->{arrival_date}, $args->{channel_id} );

    return;
}

# DCS-847
### Subroutine : create_new_channel_navigation_attributes                             #
# usage        : create_new_channel_navigation_attributes(                            #
#                       $dbh,                                                         #
#                       $args - { product_id, from_channel_id, to_channel_id,         #
#                                 navigation_categories - {                           #
#                                        classification, product_type, sub_type       #
#                                   }                                                 #
#                             }                                                       #
#                  );                                                                 #
# description  : This is used by the Receive::Product::ChannelTransfer JQ worker to   #
#                populate the product's new channel's navigation classification.      #
#                It first removes any current classification (including Hierarchy)    #
#                attributes that may be present for the new channel and then if the   #
#                $args->{navigation_categories} is present populates the new ones     #
#                (doesn't create new Hierarchy attribs.) with the values in this hash #
#                ptr. If it can't find an attribute for the new channel it replaces   #
#                it with 'Unknown'.                                                   #
# parameters   : Database Handler, HASH Ptr containing Product Id, From Channel Id,   #
#                To Channel Id, Navigation Categories HASH Ptr containing the new     #
#                NAV Level Attributes.                                                #
# returns      : Nothing.                                                             #

sub create_new_channel_navigation_attributes :Export() {

    my ( $dbh, $args )  = @_;

    # translation table for mapping the keys in the payload
    # to the actual names in the database
    my %translation_map = (
        sub_type        => 'Sub-Type',
        product_type    => 'Product Type',
        classification  => 'Classification'
    );

    # validate required args
    foreach my $field ( qw(product_id from_channel_id to_channel_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for create_new_channel_navigation_attributes()';
        }
    }

    # Delete any current classifications the
    # product has for the new channel in the attribute_value table.
    # Found that there were already attribute_value's for products
    # for The Outnet even though there was no Outnet Row in product_channel table.
    my $del_qry = "DELETE FROM product.attribute_value
    WHERE id IN (
    SELECT av.id
    FROM product.attribute a, product.attribute_value av, product.attribute_type at
    WHERE av.product_id = ?
    AND av.attribute_id = a.id
    AND a.channel_id = ?
    AND a.attribute_type_id = at.id
    AND at.name IN ('Classification', 'Product Type', 'Sub-Type', 'Hierarchy')
    )";
    my $del_sth = $dbh->prepare($del_qry);
    $del_sth->execute( $args->{product_id}, $args->{to_channel_id} );

    if ( !defined $args->{navigation_categories} ) {
        warn __PACKAGE__
        ."::create_new_channel_navigation_attributes(): No Navigational Classification Received";
        return;
    }

    # get the nav categories using the translation table
    my %nav_cats    = ( map { ( $translation_map{$_} => $args->{navigation_categories}{$_} ) } keys %{ $args->{navigation_categories} } );

    # get the attribute id's for each level of navigation: Classification, Product Type & Sub-Type
    my %attr_type_ids;
    my $in_mask = join( ',', map { '?' } keys %nav_cats );
    my $qry     = "SELECT *
    FROM product.attribute_type
    WHERE name IN ($in_mask)";
    my $sth     = $dbh->prepare($qry);
    $sth->execute( keys %nav_cats );
    while ( my $row = $sth->fetchrow_hashref() ) {
        $attr_type_ids{ $row->{name} }  = $row->{id};
    }

    # prepare cursor to get the attribute for the new channel
    $qry        = "SELECT id FROM product.attribute WHERE name = ? AND channel_id = ? AND attribute_type_id = ?";
    my $get_sth = $dbh->prepare( $qry );

    # prepare cursor to insert the new attribute for the product
    $qry        = "INSERT INTO product.attribute_value (product_id, attribute_id) VALUES (?, ?)";
    my $ins_sth = $dbh->prepare( $qry );

    foreach my $nav_category ( keys %nav_cats ) {

        # get attr on destination channel for each category
        my $new_attr_id;

        # get the attribute for the category for the new channel
        $get_sth->execute( $nav_cats{$nav_category}, $args->{to_channel_id}, $attr_type_ids{$nav_category} );
        while ( my $get_row = $get_sth->fetchrow_hashref() ) {
            $new_attr_id = $get_row->{id};
        }

        if ( !$new_attr_id ) {
            warn "Couldn't find Attrribute for new Channel.".
            " Channel Id: $args->{to_channel_id},".
            " PID: $args->{product_id},".
            " Attribute: $nav_cats{$nav_category},".
            " NAV Category: $nav_category.";

            $get_sth->execute( 'Unknown', $args->{to_channel_id}, $attr_type_ids{$nav_category} );
            while ( my $get_row = $get_sth->fetchrow_hashref() ) {
                $new_attr_id = $get_row->{id};
            }

        }

        # set attribute on dest channel
        $ins_sth->execute( $args->{product_id}, $new_attr_id );
    }

    return;
}


### Subroutine : set_upload_date #
# usage        : #
# description  : #
# parameters   : #
# returns      : #

sub set_upload_date :Export() {

    my ( $dbh, $args )  = @_;

    # validate required args
    foreach my $field ( qw(product_id channel_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for set_upload_date()';
        }
    }

    my $qry = qq{ UPDATE product_channel SET upload_date = ? WHERE product_id = ? AND channel_id = ? };
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{date}, $args->{product_id}, $args->{channel_id} );

    return;
}


### Subroutine : request_product_sample                    ###
# usage        : request_product_sample($dbh, $prod_id, $channel_id) #
# description  : Creates sample requests for all product $prod_id on channel $channel_id #
# parameters   : $dbh - a db handle                 #
#              : $prod_id - int                     #
#              : $channel_id - int                  #
# returns      : -                                  #

sub request_product_sample :Export() {

    my ($dbh, $product_id, $channel_id) = @_;

    my $schema  = get_schema_using_dbh( $dbh, 'xtracker_schema' );

    # get channel info
    my $channel_ref = get_channel($dbh, $channel_id);

    # see which Sales Channels want to use the Stock Check
    # method of finding a variant and then see if the Sales
    # Channel requested is one of them and set a flag to use later.
    my $stock_check_channels= config_var( 'SampleRequests', 'use_stockcheck_for_channel' );
    $stock_check_channels   = ( ref( $stock_check_channels ) eq "ARRAY" ? $stock_check_channels : [ $stock_check_channels ] );
    my $use_stock_check     = ( ( grep { $_ eq $channel_ref->{config_section} } @{ $stock_check_channels } ) ? 1 : 0 );

    # set-up a HASH of variants to be indexed by size
    # and an array of variant sizes
    my %variants;
    my @variant_sizes;

    my $sample_prod_type_sizes;
    my $sample_prod_class_sizes;

    my $variant_rs  = $schema->resultset('Public::Variant')->search({
        'me.product_id' => $product_id,
    },{
        join            => 'product',
        order_by        => 'me.size_id DESC',
    });

    # Get the (unique) size scheme ID for the product
    my $size_scheme = $schema->resultset('Public::ProductAttribute')->search({
        product_id      => $product_id,
    })->first->size_scheme;
    my $size_scheme_id;
    if ($size_scheme) {
        $size_scheme_id = $size_scheme->id;
    }

    my $smallest_size_vid   = 0;
    my $ideal_size_vid      = 0;
    my $variant_id          = 0;

    while ( my $variant = $variant_rs->next ) {

        $smallest_size_vid  = $variant->id;

        # get the sample product type/classification default sizes
        # for the product, only need to get it once
        if ( !defined $sample_prod_type_sizes ) {
            $sample_prod_type_sizes = $variant->product->product_type->sample_product_type_default_sizes;
            $sample_prod_class_sizes= $variant->product->classification->sample_classification_default_sizes;
        }

        $variants{ $variant->size_id }  = $variant->id;
        unshift @variant_sizes, $variant->size_id;
    }

    # Check if we can find an ideal sample size from
    # the 'sample_size_scheme_default_size' table
    # for the sales channel

    if ($size_scheme_id) {
        my $sssds = $schema->resultset('Public::SampleSizeSchemeDefaultSize')->search({
            size_scheme_id  => $size_scheme_id,
            channel_id      => $channel_id,
        })->first;

        if ($sssds && grep { $_ == $sssds->size_id } keys %variants) {
            $ideal_size_vid = $variants{ $sssds->size_id };
        }
    }

    # check to see if we can find an ideal sample size
    # from the 'sample_product_type_default_size' table
    # for the Sales Channel
    if ( !$ideal_size_vid ) {
        my @sample_prodtype_sizes   = $sample_prod_type_sizes->search( { 'me.channel_id' => $channel_id } )->all;
        foreach my $size ( @variant_sizes ) {
            if ( grep { $_->size_id == $size } @sample_prodtype_sizes ) {
                $ideal_size_vid = $variants{ $size };
                last;
            }
        }
   }

    # if we didn't find an ideal size by product type,
    # now try by the product's classification
    if ( !$ideal_size_vid ) {
        my @sample_class_sizes  = $sample_prod_class_sizes->search( { 'me.channel_id' => $channel_id } )->all;
        foreach my $size ( @variant_sizes ) {
            if ( grep { $_->size_id == $size } @sample_class_sizes ) {
                $ideal_size_vid = $variants{ $size };
                last;
            }
        }
    }

    # if we still haven't found an ideal size
    # then for NAP use the smallest size,
    # for OUTNET use the middle size
    if ( !$ideal_size_vid ) {
        if ( $channel_ref->{config_section} eq "OUTNET" ) {
            my $idx = int( (scalar @variant_sizes) / 2 );
            $ideal_size_vid = $variants{ $variant_sizes[ $idx ] };
        }
        else {
            $ideal_size_vid = $smallest_size_vid;
        }
    }

    # if we can use the stock check method of getting
    # the best variant for this Sales Channel, then do so.
    if ( $use_stock_check ) {
        $variant_id = get_sample_variant_with_stock( $dbh, $product_id, \%variants, \@variant_sizes, $ideal_size_vid, $channel_ref );
    }
    else {
        $variant_id = $ideal_size_vid;
    }

    # check for existing sample units or stock transfers for
    # this variant before creating transfer
    my $sample_stock    = get_sample_stock_qty( $dbh, { type => 'variant', id => $variant_id, channel_id => $channel_id } );
    if ( !defined $sample_stock
        || !exists $sample_stock->{ $variant_id }
        || $sample_stock->{ $variant_id } <= 0 ) {

        # create the stock transfer if no current requests pending
        create_stock_transfer(
            $dbh,
            8,          # stock transfer type of 'Upload'
            1,          # stock transfer status of 'Requested'
            $variant_id,
            $channel_id
        );
    }

    return;
}



### Subroutine : set_product_nav_attribute #
# usage        : #
# description  : #
# parameters   : #
# returns      : #

sub set_product_nav_attribute :Export() {

    my ( $dbh, $args )  = @_;

    # validate required args
    foreach my $field ( qw(product_id channel_id attributes operator_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for set_product_nav_attribute()';
        }
    }

    # map attribute types passed in to name in db
    my %type_mapping = (
        navigation_classification   => 'Classification',
        navigation_product_type     => 'Product Type',
        navigation_sub_type         => 'Sub-Type',
    );

    foreach my $attribute_type (keys %{ $args->{attributes} }){
        if ( !$type_mapping{ $attribute_type } ) {
            die 'Unexpected attribute type: '. $attribute_type ;
        }
    }

    # first, delete all linkages between product and nav hierarchy
    my $qry = "UPDATE product.attribute_value av
    SET deleted = true
    FROM product.attribute a
    JOIN product.attribute_type at ON a.attribute_type_id = at.id
    WHERE av.product_id = ?
    AND a.id = av.attribute_id
    AND a.channel_id = ?
    AND at.name IN ('Classification', 'Product Type', 'Sub-Type')";
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{product_id}, $args->{channel_id} );

    # now for each attribute, undelete from attribute_value or insert.
    foreach my $attribute_type (keys %{ $args->{attributes} }){
        my $val = $args->{attributes}->{$attribute_type};
        # ignore if undefined.
        next unless $val;
        my $field = $type_mapping{ $attribute_type };

        $qry = "SELECT a.id FROM product.attribute a
        JOIN product.attribute_type at ON a.attribute_type_id = at.id
        WHERE at.name = ?
        AND a.name = ?
        AND a.channel_id = ?";
        $sth = $dbh->prepare( $qry );
        $sth->execute( $field, encode_db($val), $args->{channel_id} );
        my $row = $sth->fetchrow_hashref();
        if ( !$row->{id} ) {
            warn 'Could not find attribute: '.$val.' of type: '.$field.' on channel: '.$args->{channel_id};

            $sth->execute( $field, 'Unknown', $args->{channel_id} );
            $row = $sth->fetchrow_hashref();
            if ( !$row->{id} ) {
               die 'Could not find attribute: '.$val.' of type: '.$field.' on channel: '.$args->{channel_id};
            }
        }

        my $attribute_id = $row->{id};

        $sth = $dbh->prepare("UPDATE product.attribute_value SET deleted = false WHERE product_id = ? AND attribute_id = ?");
        my $rows_affected = $sth->execute($args->{product_id}, $attribute_id);
        if ($rows_affected > 1){
            die "Should only have updated one row. We've got bad data somewhere";
        } elsif ( $rows_affected eq "0E0" ){
            # insert instead
            $sth = $dbh->prepare( "INSERT INTO product.attribute_value (product_id, attribute_id) VALUES ( ?, ? )" );
            $sth->execute( $args->{product_id}, $attribute_id );
        }

    }

    return;
}



### Subroutine : set_product_hierarchy_attributes #
# usage        : #
# description  : #
# parameters   : #
# returns      : #

sub set_product_hierarchy_attributes :Export() {

    my ( $dbh, $args )  = @_;

    # validate required args
    foreach my $field ( qw(product_id channel_id operator_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for set_product_hierarchy_attributes()';
        }
    }

    # first set all current hierarchy atts to deleted
    my $qry = "UPDATE product.attribute_value av
    SET deleted = true
    FROM product.attribute a
    JOIN product.attribute_type at ON a.attribute_type_id = at.id
    WHERE av.product_id = ?
    AND a.id = av.attribute_id
    AND a.channel_id = ?
    AND at.name = 'Hierarchy'";
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{product_id}, $args->{channel_id} );

    # now loop over attributes passed and assign to product
    if ( $args->{values} ){

        foreach my $attribute_name ( @{ $args->{values} } ){

            # get id for attribute
            my $qry = "SELECT a.id FROM product.attribute a
            JOIN product.attribute_type at ON a.attribute_type_id = at.id
            WHERE at.name = 'Hierarchy'
            AND a.name = ?
            AND a.channel_id = ?";
            my $sth = $dbh->prepare( $qry );
            $sth->execute( $attribute_name, $args->{channel_id} );
            my $row = $sth->fetchrow_hashref();
            my $attribute_id = $row->{id};

            if ( !$attribute_id ) {
                # Ignore this error - can carry on since XT can longer be kept in sync
                warn 'Could not find attribute: '.$attribute_name.' of type: Hierarchy on channel: '.$args->{channel_id};
            } else {

                # undelete from attribute_value or insert
                $qry = "SELECT id FROM product.attribute_value
                WHERE product_id = ?
                AND attribute_id = ?";
                $sth = $dbh->prepare( $qry );
                $sth->execute( $args->{product_id}, $attribute_id );
                $row = $sth->fetchrow_hashref();
                my $attribute_value_id = $row->{id};

                # insert
                if ( !$attribute_value_id ) {
                    $sth = $dbh->prepare( "INSERT INTO product.attribute_value (product_id, attribute_id) VALUES ( ?, ? )" );
                    $sth->execute( $args->{product_id}, $attribute_id );
                }
                # update
                else {
                    $sth = $dbh->prepare("UPDATE product.attribute_value SET deleted = false WHERE id = ?");
                    $sth->execute($attribute_value_id);
                }

            }
        }
    }

    return;
}



### Subroutine : set_product_standardised_sizes #
# usage        : #
# description  : #
# parameters   : #
# returns      : #

sub set_product_standardised_sizes :Export() {

    my ( $dbh, $pid )  = @_;

    if ( !$pid ) {
        die 'No product_id defined for set_product_standardised_sizes()';
    }

    my $qry = "UPDATE variant SET std_size_id = (
    SELECT std_size_id FROM std_size_mapping, product_attribute
    WHERE variant.designer_size_id = std_size_mapping.size_id
    AND variant.product_id = product_attribute.product_id
    AND std_size_mapping.size_scheme_id = product_attribute.size_scheme_id
    LIMIT 1
    )
    WHERE product_id = ?";
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $pid );

    return;
}

### Subroutine : validate_product_weight #
# usage        :
#               use XTracker::Database::Product qw(validate_product_weight);
#
#               eval {
#                   validate_product_weight( product_weight => $new_weight_value );
#               };
#               if ($@) {
#                   warn( "Passed weight is not valid. Error: $@" );
#               }
# description  : Performs validation of product's weight and in case of failure
#                throws an exception as string.
# parameters   : product_weight
# returns      : 1 if ok
# exception    : String with error message if passed value is invalid product weight.

sub validate_product_weight :Export() {
    my $args = \@_;
    my $product_weight;
    try {
        ($product_weight) = validated_list($args,
            product_weight  => { isa => PositiveNum },
            # MooseX::Params::Validate uses caller_cv as a cache key
            # for the compiled validation constraints. 'try' takes a
            # coderef, that in this case is a garbage-collectable
            # anonymous sub that closes over some variables; since
            # it's a closure, it gets re-allocated every time. A new
            # sub (anonymous or not) created after this one is called
            # may well end up at the same memory address, thus
            # colliding in the MX:P:V cache; let's provide a hand-made
            # key to make sure we never collide
            MX_PARAMS_VALIDATE_CACHE_KEY => __FILE__.__LINE__,
        );
    } catch {
        die "Product weight should be a positive number\n";
    };

    if (sprintf("%.3f", $product_weight) == 0) {
        die "Product weight should not equal or round to zero\n";
    }

    return 1;
}

1;

__END__
