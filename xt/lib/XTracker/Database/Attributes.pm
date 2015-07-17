package XTracker::Database::Attributes;

use strict;
use warnings;
use Carp;
use Readonly;
use Perl6::Export::Attrs;
use XTracker::Database              qw( get_schema_using_dbh );
use XTracker::Database::Utilities;
use XTracker::Utilities             qw(trim);
use XTracker::Constants             qw( :application );
use XTracker::Config::Local         qw( config_var );

Readonly my $KGS_TO_LBS => 2.2046;

=head1 NAME

XTracker::Database::Attributes

=cut

### Subroutine : get_season_act_atts            ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_season_act_atts :Export(:DEFAULT) {

    my ( $dbh ) = @_;

    my $qry = qq{
select sa.id, sa.act
from season_act sa
order by act
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( );

    return results_list( $sth );
}

### Subroutine : get_product_department_atts            ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_product_department_atts :Export(:DEFAULT) {

    my ( $dbh ) = @_;

    my $qry = qq{
select id, department
from product_department
order by department
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( );

    return results_list( $sth );
}


### Subroutine : get_sample_request_reason      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_sample_request_reason :Export() {

    my ( $dbh ) = @_;

    my $qry = qq{
select srr.id, srr.type as type_id
from stock_transfer_type srr
order by type
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( );

    return results_list( $sth );
}


### Subroutine : get_faulty_atts                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_faulty_atts :Export() {

    my ( $dbh, $p ) = @_;

    my $qry = qq{
select sfr.id, sfr.reason
from stock_faulty_reason sfr
order by id
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( );

    return results_list( $sth );
}


### Subroutine : get_paymentterm_atts           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_paymentterm_atts :Export() {

    my ( $dbh, $p ) = @_;

    my $qry = qq{
select p.id, p.payment_term
from payment_term p
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( );

    return results_list( $sth );
}

### Subroutine : get_paymentdeposit_atts        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_paymentdeposit_atts :Export() {

    my ( $dbh, $p ) = @_;

    my $qry = qq{
select pd.id, pd.deposit_percentage, ( pd.deposit_percentage || '%' ) as payment_deposit
from payment_deposit pd
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( );

    return results_list( $sth );
}

### Subroutine : get_paymentsettlementdiscount_atts     ###
# usage        :                                          #
# description  :                                          #
# parameters   :                                          #
# returns      :                                          #

sub get_paymentsettlementdiscount_atts :Export() {

    my ( $dbh, $p ) = @_;

    my $qry = qq{
select psd.id, (psd.discount_percentage || '%' ) as payment_settlement_discount, psd.discount_percentage
from payment_settlement_discount psd
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( );

    return results_list( $sth );
}

# this is an improved get_size_att with more fields - trying to minimise
# breaking other stuff that may use this - its quick fix SORRY! :(
sub get_size_atts_with_size_scheme :Export(:update) {

    my ( $dbh, $p ) = @_;

    my $qry = qq{
SELECT
    ss.name || ' > ' || s.size as nap_size_label,
    ss.name || ' > ' || ds.size as designer_size_label,
    ss.id as scheme_id,
    s.id as nap_size_id,
    s.size as nap_size,
    ds.id as designer_size_id,
    ds.size as designer_size
FROM
    size_scheme ss
    JOIN size_scheme_variant_size vs
        ON vs.size_scheme_id = ss.id
    JOIN size s
        ON s.id = vs.size_id
    JOIN size ds
        ON ds.id = vs.designer_size_id
ORDER BY
    ss.name, s.id
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( );

    return results_list( $sth );
}

### Subroutine : get_size_schemes                  ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_size_schemes :Export(:update) {

    my ( $dbh, $p ) = @_;

    my $qry = 'select id, name, short_name from size_scheme';
    my $sth = $dbh->prepare( $qry );
    $sth->execute( );

    return results_list( $sth );
}

### Subroutine : set_product_attribute          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_product_attribute  :Export(:update) {

    my ( $dbh, $product_id, $item, $value, $operator_id ) = @_;

    if (!defined $operator_id ) {
        $operator_id = $APPLICATION_OPERATOR_ID;

        warn __PACKAGE__
            ."::set_product_attribute(): Please define operator_id for call"
            ." - defaulting to 'Application'";
    }

    # map named value to ids if required
    if ( $item eq 'season_act' ) {
        $item   = 'act_id';
        $value  = get_id_from_name($dbh, { table => 'season_act', field => 'act', value => $value } );
    }
    if ( $item eq 'product_department' ) {
        $item   = 'product_department_id';
        $value  = get_id_from_name($dbh, { table => 'product_department', field => 'department', value => $value } );
    }
    if ( $item eq 'editorial_approved' || $item eq 'outfit_links' || $item eq 'use_fit_notes' || $item eq 'use_measurements' ) {
        if (not defined $value) {
            $value = 'false';
        }
    }

    if (not defined $product_id) {
        die "No product_id provided for set_product_attribute()\n";
    }
    if (not defined $item) {
        die "No column name provided for set_product_attribute()\n";
    }
    if (not defined $value) {
        die "No value provided for set_product_attribute()\n";
    }

    my $qry = "UPDATE product_attribute SET $item = ?, operator_id = ? WHERE product_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $value, $operator_id, $product_id );

    return;
}


=head2 set_shipping_attributes

Updates shipping attribute details for a PID

=cut

sub set_shipping_attribute :Export(:update) {

    my ( $dbh, $product_id, $item, $value, $operator_id ) = @_;

    my $field = ($item eq 'country' || $item eq 'box') ? $item . '_id' : $item;
    $field = $field eq 'origin_country_id' ? 'country_id' : $field;

    if (!defined $operator_id ) {
        $operator_id = $APPLICATION_OPERATOR_ID;
        warn __PACKAGE__
            ."::set_shipping_attribute(): Please define operator_id for call"
            ." - defaulting to 'Application'";
    }

    # convert weight from kgs if required
    if ( $field eq 'weight_kgs' ) {
        $field   = 'weight';

        my $local_weight_unit = config_var('Units', 'weight');

        if ( $local_weight_unit eq 'kgs' ) {
            # no conversion required on source value in kgs
        }
        elsif ( $local_weight_unit eq 'lbs' ){
           $value = $value * $KGS_TO_LBS;
        }
        else {
            die "Unexpect DC unit of weight: $local_weight_unit, unable to convert from kgs\n";
        }
    }

    my $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    my $shipping_attribute = $schema->resultset('Public::ShippingAttribute')
                                ->find({ product_id => $product_id });

    # It looks like we have a voucher...
    return unless $shipping_attribute;

    if ($item eq 'packing_note') {
        $shipping_attribute->update({ packing_note             => $value,
                                      packing_note_operator_id => $operator_id,
                                      packing_note_date_added  => $schema->db_now() });
    } else {
        $shipping_attribute->update({ $field      => $value,
                                      operator_id => $operator_id });
    }

    return;
}


### Subroutine : set_product                    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_product :Export(:update) {

    my ( $dbh, $product_id, $item, $value, $operator_id ) = @_;

    if (!defined $operator_id ) {
        $operator_id = $APPLICATION_OPERATOR_ID;

        warn __PACKAGE__
            ."::set_product(): Please define operator_id for call"
            ." - defaulting to 'Application'";
    }

    # map named value to ids if required
    if ( $item eq 'classification' ) {
        $item   = 'classification_id';
        $value  = get_id_from_name($dbh, { table => 'classification', field => 'classification', value => $value } );
    }
    if ( $item eq 'colour' ) {
        $item   = 'colour_id';
        $value  = get_id_from_name($dbh, { table => 'colour', field => 'colour', value => $value } );
    }
    if ( $item eq 'designer' ) {
        $item   = 'designer_id';
        $value  = get_id_from_name($dbh, { table => 'designer', field => 'designer', value => $value } );
    }
    if ( $item eq 'division' ) {
        $item   = 'division_id';
        $value  = get_id_from_name($dbh, { table => 'division', field => 'division', value => $value } );
    }
    if ( $item eq 'product_type' ) {
        $item   = 'product_type_id';
        $value  = get_id_from_name($dbh, { table => 'product_type', field => 'product_type', value => $value } );
    }
    if ( $item eq 'sub_type' ) {
        $item   = 'sub_type_id';
        $value  = get_id_from_name($dbh, { table => 'sub_type', field => 'sub_type', value => $value } );
    }
    if ( $item eq 'season' ) {
        $item   = 'season_id';
        $value  = get_id_from_name($dbh, { table => 'season', field => 'season', value => $value } );
    }
    if ( $item eq 'world' ) {
        $item   = 'world_id';
        $value  = get_id_from_name($dbh, { table => 'world', field => 'world', value => $value } );
    }
    if ( $item eq 'hs_code' ) {
        $item   = 'hs_code_id';
        $value  = get_id_from_name($dbh, { table => 'hs_code', field => 'hs_code', value => $value } );
    }

    if (not defined $product_id) {
        die "No product_id provided for set_product()\n";
    }
    if (not defined $item) {
        die "No column name provided for set_product()\n";
    }

    my $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    my $product = $schema->resultset('Public::Product')->find( $product_id );

    unless ($product) {
        warn __PACKAGE__
            . "::set_product(): Failed to find product for id ($product_id)";
        return undef;
    }

    $product->update({ $item       => $value,
                       operator_id => $operator_id });
}


### Subroutine : set_variant                    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_variant :Export(:update) {

    my ( $dbh, $variant_id, $item, $value ) = @_;

    croak 'No variant_id supplied.' unless $variant_id =~ m/^\d+$/;

    my $qry = "update variant set $item = ? where id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $value, $variant_id );
}

### Subroutine : set_classification_attribute   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_classification_attribute :Export(:update) {

    my ( $dbh, $product_id, $item, $value, $operator_id ) = @_;

    my $field = $item . '_id';

    if (!defined $operator_id ) {
        $operator_id = $APPLICATION_OPERATOR_ID;

        warn __PACKAGE__
            ."::set_classification_attribute(): Please define operator_id for call"
            ." - defaulting to 'Application'";
    }

    #TODO: check input data

    my $qry = "update product set $field = ?, operator_id = ? where id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $value, $operator_id, $product_id );

    return;
}

### Subroutine : delete_recommended_product     ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub delete_recommended_product :Export() {

    my ( $dbh, $product_id, $rec_product_id, $recommended_product_type_id ) = @_;

    my $qry = "delete from recommended_product where product_id = ? and recommended_product_id = ? and type_id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $product_id, $rec_product_id, $recommended_product_type_id );

    return;
}

### Subroutine : get_shipping_attributes        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_shipping_attributes :Export() {

    my ( $dbh, $prod_id ) = @_;

    my $qry = "select sa.scientific_term, sa.packing_note,
                      to_char(sa.packing_note_date_added, 'DD-MM-YYYY HH24:MI') as packing_note_date_added,
                      sa.weight, b.box, c.country, sa.fabric_content,
                      hs.hs_code, sa.country_id, sa.legacy_countryoforigin, sa.fish_wildlife,
                      sa.fish_wildlife_source, sa.cites_restricted, sa.dangerous_goods_note, o.name as operator_name
               from shipping_attribute sa
                    left join country c on ( sa.country_id = c.id )
                    left join box b on ( sa.box_id = b.id )
                    left join operator o on ( sa.packing_note_operator_id = o.id ),
                    product p left join hs_code hs on ( p.hs_code_id = hs.id )
               where p.id = sa.product_id
               and p.id  = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($prod_id);

    return results_list($sth);
}

### Subroutine : get_designer_atts              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_designer_atts :Export(:DEFAULT) {

    my ($dbh) = @_;

    my $qry = "select sku_padding(id) as id , designer from designer order by designer asc";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    return results_list($sth);
}

### Subroutine : get_classification_atts        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_classification_atts :Export(:DEFAULT) {

    my ($dbh) = @_;

    my $qry = "select lpad(CAST(id AS varchar), 2, '0') as id, classification from classification";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    return results_list($sth);
}


### Subroutine : get_product_type_atts          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_product_type_atts :Export(:DEFAULT) {

    my ($dbh) = @_;

    #my $qry = "select id, product_type from product_type order by product_type asc";
    my $qry = "select lpad(CAST(id AS varchar), 3, '0') as id, product_type from product_type order by product_type asc";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    return results_list($sth);
}


### Subroutine : get_sub_type_atts              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_sub_type_atts :Export(:DEFAULT) {

    my ($dbh) = @_;

    my $qry = "select lpad(CAST(id AS varchar), 3, '0') as id, sub_type from sub_type order by sub_type asc";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    return results_list($sth);
}

### Subroutine : get_season_atts                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_season_atts :Export(:DEFAULT) {

    my ($dbh) = @_;

    my $qry = q[
        SELECT  lpad(CAST(id AS varchar), 3, '0') as id,
                season
        FROM    season
        ORDER BY
            season_year DESC,
            season_code ASC
    ];

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    return results_list($sth);
}


### Subroutine : get_colour_filter_atts                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_colour_filter_atts :Export() {

    my ($dbh) = @_;

    #my $qry = "select lpad(CAST(id AS varchar), 3, '0') as id, colour_filter from colour_filter order by colour_filter asc";
    my $qry = "select id, colour_filter from colour_filter order by colour_filter asc";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    return results_list($sth);
}


### Subroutine : get_colour_atts                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_colour_atts :Export(:DEFAULT) {

    my ($dbh) = @_;

    #my $qry = "select id, colour_filter from colour_filter order by colour_filter asc";
    #my $qry = "select lpad(CAST(id AS varchar), 3, '0') as id, colour_filter from colour_filter order by colour_filter asc";
    my $qry = "select id, colour from colour order by colour asc";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    return results_list($sth);
}

### Subroutine : get_locations                  ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_locations :Export(:DEFAULT) {
    my ($schema, $type_id, $table) = @_;

    die "hard deprecation - get_locations can't operate on arbitrary tables ($table)" if defined $table;

    if (! $schema->isa('DBIx::Class::Schema')) {
        $schema=get_schema_using_dbh($schema,'xtracker_schema');
    }

    my $locs=$schema->resultset('Public::Location')->search({
        ( defined $type_id ? ( type_id => $type_id ) : () )
    });
    require DBIx::Class::ResultClass::HashRefInflator;
    $locs->result_class('DBIx::Class::ResultClass::HashRefInflator');

    return [$locs->all];
}


### Subroutine : get_countries                  ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_countries :Export(:DEFAULT) {

    my ( $dbh ) = @_;

    #my $qry = qq{
    #    select c.id, c.country, cdr.hs_code
    #    from country c, country_duty_rate cdr
    #};

    my $qry = q{ select c.id, c.country from country c order by country asc };

    my $sth = $dbh->prepare( $qry );
    $sth->execute( );

    return results_list( $sth );
}


### Subroutine : get_country_by_id              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_country_by_id :Export {

    my ( $dbh, $id ) = @_;

    my $qry = "select country from country where id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $id );

    my $country = undef;
    $sth->bind_columns( \$country );
    $sth->fetch();

    return $country;
}


### Subroutine : get_id_from_name        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_id_from_name :Export() {

    my ($dbh, $args) = @_;

    # validate required fields
    foreach my $field ( qw(table field) ) {
        if (not defined $args->{$field}) {
            die "No $field defined for get_id_from_name()\n";
        }
        else {
            if ( $args->{$field} !~ m/^[\w\s\-\_\&\(\.\)]+$/) {
                die "Unrecognised format for field: '$field' value: '$args->{$field}'\n";
            }
        }
    }

    my $qry = "select id from $args->{table} where $args->{field} = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $args->{value} );

    my $row = $sth->fetchrow_hashref();

    return $row->{id};
}


### Subroutine : set_shipping_restriction        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_shipping_restriction :Export() {

    my ($dbh, $args) = @_;

    my $restriction_id = undef;

    # validate required fields
    foreach my $field ( qw(product_id restriction) ) {
        if (not defined $args->{$field}) {
            die "No $field defined for set_shipping_restriction()\n";
        }
    }

    # get id for restriction provided
    my $qry = "select id from ship_restriction where title = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $args->{restriction} );
    $sth->bind_columns( \$restriction_id );
    $sth->fetch();

    if ( not defined $restriction_id ) {
        die "Could not find a restriction matching: $args->{restriction}\n";
    }

    # insert product restriction, but only if it isn't already defined.
    my $t_product_id = undef;
    $qry = "SELECT product_id FROM link_product__ship_restriction WHERE product_id = ? AND ship_restriction_id = ?";
    $sth = $dbh->prepare($qry);
    $sth->execute( $args->{product_id}, $restriction_id );
    $sth->bind_columns( \$t_product_id );
    $sth->fetch();

    if (not defined $t_product_id ) {
        # make sure we only try to insert record if product exists in the DC
        $qry = "INSERT INTO link_product__ship_restriction (product_id, ship_restriction_id) SELECT id, $restriction_id FROM product WHERE id = ?";
        $sth = $dbh->prepare($qry);
        $sth->execute( $args->{product_id} );
    }

    # check if legacy fields need to be set for CITES and Fish & Wildlife
    # may be able to remove these fields once migrated over to new
    # restriction table
    if ( $args->{restriction} eq 'CITES' ) {
        my $qry = "UPDATE shipping_attribute SET cites_restricted = true WHERE product_id = ?";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $args->{product_id} );
    }
    if ( $args->{restriction} eq 'Fish & Wildlife' ) {
        my $qry = "UPDATE shipping_attribute SET fish_wildlife = true WHERE product_id = ?";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $args->{product_id} );
    }
    if ( $args->{restriction} eq 'Hazmat' ) {
        my $qry = "UPDATE shipping_attribute SET is_hazmat = true WHERE product_id = ?";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $args->{product_id} );
    }

    return;
}


### Subroutine : remove_shipping_restriction        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub remove_shipping_restriction :Export() {

    my ($dbh, $args) = @_;

    my $restriction_id = undef;

    # validate required fields
    foreach my $field ( qw(product_id restriction) ) {
        if (not defined $args->{$field}) {
            die "No $field defined for remove_shipping_restriction()\n";
        }
    }

    # get id for restriction provided
    my $qry = "select id from ship_restriction where title = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $args->{restriction} );
    $sth->bind_columns( \$restriction_id );
    $sth->fetch();

    if ( not defined $restriction_id ) {
        die "Could not find a restriction matching: $args->{restriction}\n";
    }

    $qry = "DELETE FROM link_product__ship_restriction WHERE product_id = ? AND ship_restriction_id = ?";
    $sth = $dbh->prepare($qry);
    $sth->execute( $args->{product_id}, $restriction_id );

    # check if legacy fields need to be unset for CITES and Fish & Wildlife
    # may be able to remove these fields once migrated over to new
    # restriction table
    if ( $args->{restriction} eq 'CITES' ) {
        my $qry = "UPDATE shipping_attribute SET cites_restricted = false WHERE product_id = ?";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $args->{product_id} );
    }
    if ( $args->{restriction} eq 'Fish & Wildlife' ) {
        my $qry = "UPDATE shipping_attribute SET fish_wildlife = false WHERE product_id = ?";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $args->{product_id} );
    }
    if ( $args->{restriction} eq 'Hazmat' ) {
        my $qry = "UPDATE shipping_attribute SET is_hazmat = false WHERE product_id = ?";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $args->{product_id} );
    }

    return;
}


1;

__END__

