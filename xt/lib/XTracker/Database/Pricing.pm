package XTracker::Database::Pricing;

use strict;
use warnings;
use Carp;

use Perl6::Export::Attrs;
use XTracker::Database      qw( :DEFAULT get_schema_using_dbh );
use XTracker::Utilities     qw( apply_discount );
use XTracker::Database::Utilities;
use XTracker::Database::Currency;
use XTracker::Constants     qw/ $APPLICATION_OPERATOR_ID /;
use XTracker::Config::Local qw( config_var );
use XT::Rules::Solve;

### Subroutine : get_pricing                    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_pricing :Export() {

    my ( $dbh, $prod_id, $type ) = @_;

    my %qry = (
        'purchase' => "select pp.wholesale_price, pp.wholesale_currency_id, pp.original_wholesale, pp.uplift_cost, pp.uk_landed_cost, pp.uplift, pp.trade_discount, c.currency, c.id as currency_id
                              from price_purchase pp, currency c
                              where pp.wholesale_currency_id = c.id
                              and product_id = ?",
        'default' => "select pd.price, c.currency, c.id as currency_id
                              from price_default pd, currency c
                              where pd.currency_id = c.id
                              and product_id = ?",
        'region' => "select pr.price, c.currency,
                                  c.id as currency_id, r.region,
                                  r.id as region_id
                              from price_region pr, region r, currency c
                              where pr.region_id = r.id
                              and pr.currency_id = c.id
                              and pr.product_id = ?",
        'country' => "SELECT pc.price, c.country, r.region, curr.currency,
                                  curr.id as currency_id,
                                  r.id as region_id, c.id as country_id,
                                  1 + ctr.rate as vat_rate
                               FROM price_country pc
                               INNER JOIN country c             ON (pc.country_id   = c.id)
                               INNER JOIN currency curr         ON (pc.currency_id  = curr.id)
                               INNER JOIN sub_region sr         ON (c.sub_region_id = sr.id)
                               INNER JOIN region r              ON (sr.region_id    = r.id)
                               LEFT  JOIN country_tax_rate ctr  ON (ctr.country_id  = c.id)
                               WHERE pc.product_id = ?",
    );

    my $sth = $dbh->prepare( $qry{$type} );
    $sth->execute($prod_id);

    return results_list($sth);
}

### Subroutine : get_markdown                   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_markdown :Export(:legacy) {

    my ( $dbh, $product_id ) = @_;

    my %results = ();

    my $qry = "select pa.id, pa.percentage, to_char(pa.date_start, 'DD-MM-YYYY HH24:MI') as start_date, to_char(pa.date_finish, 'DD-MM-YYYY HH24:MI') as end_date, to_char(pa.date_start, 'YYYYMMDDHH24MI') as date_sort, pa.exported, pac.category, case when pa.exported is true and current_timestamp between pa.date_start and pa.date_finish then 1 else 0 end as current
                from price_adjustment pa, price_adjustment_category pac
               where pa.product_id = ?
               and pa.category_id = pac.id";

    my $sth = $dbh->prepare( $qry );
    $sth->execute($product_id);

    while ( my $row = $sth->fetchrow_hashref ) {
        $results{ $$row{date_sort}.$$row{id} } = $row;
    }

    return \%results;
}


### Subroutine : get_currency                   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_currency  :Export() {

    my ( $dbh ) = @_;

    my $qry = "select id, currency from currency";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    return results_list($sth);
}


### Subroutine : set_purchase_price             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_purchase_price :Export {

    my ( $dbh, $product_id, $original_wholesale, $trade_discount, $uplift, $currency_id, $unit_landed_cost, $local_currency_id ) = @_;

    # calculate wholesale price
    my $wholesale_price = $original_wholesale * (1-($trade_discount/100));

    # calculate uplift cost
    my $uplift_cost = $original_wholesale * (1 + ($uplift/100));

    # insert or update?
    my $present = _check_price( $dbh, 'purchase', $product_id );

    # update
    if ($present) {
        my $qry = "UPDATE price_purchase SET wholesale_price = ?, wholesale_currency_id = ?, original_wholesale = ?, uplift_cost = ?, uplift = ?, trade_discount = ? WHERE product_id = ?";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $wholesale_price, $currency_id, $original_wholesale, $uplift_cost, $uplift, $trade_discount, $product_id );
    }
    # insert
    else {
        my $qry = "INSERT INTO price_purchase (product_id, wholesale_price, wholesale_currency_id, original_wholesale, uplift_cost, uk_landed_cost, uplift, trade_discount) VALUES ( ?, ?, ?, ?, ?, 0, ?, ? )";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $product_id, $wholesale_price, $currency_id, $original_wholesale, $uplift_cost, $uplift, $trade_discount );
    }


    # get local currency id via the config if not passed in
    if (!defined $local_currency_id) {
            $local_currency_id = get_local_currency_id($dbh);
        }

    # figure out unit landed cost if we don't already have it.
    unless (defined $unit_landed_cost) {
        # To calculate, ideally use PO season, fall back to product season
        my $qry = "SELECT po.season_id
                  FROM stock_order so, purchase_order po
                  WHERE so.purchase_order_id = po.id
                  AND so.product_id = ?
                  ORDER BY po.date LIMIT 1";
        my $sth = $dbh->prepare($qry);
        $sth->execute($product_id);

        my $season_id;
        if (my $rs = $sth->fetchrow_arrayref) {
            $season_id = $rs->[0];
        } else {
            $qry = "SELECT season_id
                    FROM product
                    WHERE id = ?";
            $sth = $dbh->prepare($qry);
            $sth->execute($product_id);
            $season_id = $sth->fetchrow_arrayref->[0];
        }

        ### calculate landed costs
        $qry = "select ((pp.uplift_cost / pp.original_wholesale) * pp.wholesale_price) * cr.conversion_rate, pp.product_id
                from price_purchase pp, product p, conversion_rate cr
                where pp.product_id = ?
                and pp.product_id = p.id
                and cr.season_id = ?
                and pp.wholesale_currency_id = cr.source_currency
                and cr.destination_currency = ?";
        $sth = $dbh->prepare($qry);
        $sth->execute($product_id, $season_id, $local_currency_id);

        my $row = $sth->fetchrow_arrayref;
        $unit_landed_cost = $row->[0];
    }

    # update unit landed cost
    my $qry = "update price_purchase set uk_landed_cost = ? where product_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $unit_landed_cost, $product_id );

    return;
}

### Subroutine : set_default_price              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_default_price :Export {

    my ( $dbh, $product_id, $price, $currency_id, $operator_id ) = @_;

    if (!defined $operator_id ) {
        $operator_id = $APPLICATION_OPERATOR_ID;

        warn __PACKAGE__
            ."::set_default_price(): Please define operator_id for call"
            ." - defaulting to 'Application'";
    }

    # convert a named currency to an id if passed in
    if ( $currency_id =~ /\w{3}/) {
        $currency_id = get_currency_id($dbh, $currency_id);
    }

    my $qry = '';

    # update if price exists
    if ( _check_price( $dbh, 'default', $product_id ) ) {
        $qry = "UPDATE price_default SET price = ?, currency_id = ?, operator_id = ?  WHERE product_id = ?";
    }
    # or insert
    else {
        $qry = "INSERT INTO price_default (price, currency_id, operator_id, product_id) VALUES ( ?, ?, ?, ? )";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute( $price, $currency_id, $operator_id, $product_id );

    return;
}

### Subroutine : set_region_price               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_region_price :Export() {

    my ( $dbh, $product_id, $price, $currency_id, $region_id,
        $operator_id ) = @_;


    if (!defined $operator_id ) {
        $operator_id = $APPLICATION_OPERATOR_ID;

        warn __PACKAGE__
            ."::set_region_price(): Please define operator_id for call"
            ." - defaulting to 'Application'";
    }

    # convert a named currency to an id if passed in
    if ( $currency_id =~ /\w{3}/) {
        $currency_id = get_currency_id($dbh, $currency_id);
    }

    my $qry;

    # update if price exists
    if ( _check_price( $dbh, 'region', $product_id, $region_id ) ) {
        $qry = "UPDATE price_region
                 SET price = ?,
                 currency_id = ?,
                 operator_id = ?
                 WHERE product_id = ?
                 AND region_id = ?";
    }
    # or insert record
    else {
        $qry = "INSERT INTO price_region (
            price, currency_id, operator_id, product_id, region_id
            ) VALUES ( ?, ?, ?, ?, ? )";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute( $price, $currency_id, $operator_id,
        $product_id, $region_id );

    return;
}

### Subroutine : delete_region_price              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub delete_region_price :Export() {

    my ( $dbh, $product_id, $region_id ) = @_;

    my $qry = "DELETE FROM price_region WHERE product_id = ? AND region_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $product_id, $region_id );

    return;
}

### Subroutine : set_country_price              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_country_price :Export() {

    my ( $dbh, $product_id, $price, $currency_id, $country_code, $operator_id ) = @_;

    if (!defined $operator_id ) {
        $operator_id = $APPLICATION_OPERATOR_ID;

        warn __PACKAGE__
            ."::set_country_price(): Please define operator_id for call"
            ." - defaulting to 'Application'";
    }

    # convert a named currency to an id if passed in
    if ( $currency_id =~ /\w{3}/) {
        $currency_id = get_currency_id($dbh, $currency_id);
    }

    my $qry;

    # update if price exists
    if ( _check_price( $dbh, 'country', $product_id, $country_code ) ) {
        $qry = "UPDATE price_country
                 SET price = ?,
                 currency_id = ?,
                 operator_id = ?
                 WHERE product_id = ?
                 AND country_id = (SELECT id FROM country WHERE code = ?)";
    }
    # or insert record
    else {
        $qry = "INSERT INTO price_country (price, currency_id, operator_id, product_id, country_id) VALUES ( ?, ?, ?, ?, (SELECT id FROM country WHERE code = ?) )";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute( $price, $currency_id, $operator_id, $product_id, $country_code );

    return;
}

### Subroutine : delete_country_price                   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub delete_country_price :Export() {

    my ( $dbh, $product_id, $country_code, $operator_id ) = @_;

    if (!defined $operator_id ) {
        $operator_id = $APPLICATION_OPERATOR_ID;

        warn __PACKAGE__
            ."::delete_country_price(): Please define operator_id for call"
            ." - defaulting to 'Application'";
    }

    my $qry = "DELETE FROM price_country WHERE product_id = ? AND country_id = (SELECT id FROM country WHERE code = ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $product_id, $country_code );

    return;
}

### Subroutine : set_markdown                   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_markdown :Export() {

    my ( $dbh, $args ) = @_;

    # validate required args
    foreach my $field ( qw(product_id start_date category) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for set_markdown()';
        }
    }

    if (!(defined $args->{percentage})) {
        die 'No percentage defined for set_markdown()';
    }

    # do not add if markdown already exists for start date and percentage
    # this is causing purchase orders to fail because products on multiple purchase orders
    # are having their markdowns reinserted and because of the constraint on price_adjustment (product_id,date_end)
    # the purchase orders are failing
    my $chk_qry = "SELECT id FROM price_adjustment WHERE product_id = ? AND date_start = ? AND percentage = ?";
    my $chk_sth = $dbh->prepare( $chk_qry );
    $chk_sth->execute( $args->{product_id}, $args->{start_date}, $args->{percentage} );
    if (! $chk_sth->fetchrow ) {

        # default end date for all markdowns
        # they all need an end date even thought they don't 'end'
        # so current markdowns just needs to an arbitrary time in the future
        my $end_date = '2100-01-01';

        # set end date for any previous markdowns on product
        # to the new markdowns start date so they don't overlap
        my $prev_qry = "SELECT id FROM price_adjustment WHERE product_id = ? AND date_finish = ?";
        my $prev_sth = $dbh->prepare( $prev_qry );
        $prev_sth->execute( $args->{product_id}, $end_date );

        while ( my $row = $prev_sth->fetchrow_hashref ) {
            my $up_qry = "UPDATE price_adjustment SET date_finish = ? WHERE id = ?";
            my $up_sth = $dbh->prepare( $up_qry );
            $up_sth->execute( $args->{start_date}, $row->{id} );
        }

        $args->{percentage} = $args->{percentage} + 0;
        if($args->{percentage})
        {
            # create new markdown record
            my $qry = "INSERT INTO price_adjustment
                             ( product_id, percentage, date_start, date_finish, category_id )
                         VALUES ( ?, ?, ?, ?, (SELECT id FROM price_adjustment_category WHERE category = ?) )";
            my $sth = $dbh->prepare($qry);
            $sth->execute( $args->{product_id}, $args->{percentage}, $args->{start_date}, $end_date, $args->{category} );
        }
    }

    return;
}

### Subroutine : _check_price                   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _check_price {

    my ( $dbh, $type, $product_id, $type_value ) = @_;

    my $qry = "";
    my $sth = "";

    if ( $type eq 'purchase' ) {
        $qry = "select count(*) from price_purchase where product_id = ?";
        $sth = $dbh->prepare($qry);
        $sth->execute($product_id);
    }
    elsif ( $type eq 'default' ) {
        $qry = "select count(*) from price_default where product_id = ?";
        $sth = $dbh->prepare($qry);
        $sth->execute($product_id);
    }
    elsif ( $type eq 'region' ) {
        $qry = "select count(*) from price_region where product_id = ? and region_id = ?";
        $sth = $dbh->prepare($qry);
        $sth->execute($product_id, $type_value);
    }
    elsif ( $type eq 'country' ) {
        $qry = "select count(*) from price_country where product_id = ? and country_id = (SELECT id FROM country WHERE code = ?)";
        $sth = $dbh->prepare($qry);
        $sth->execute($product_id, $type_value);
    }
    else {
        $qry = "select count(*)
                from price_$type
                where " . $type . "_id = ? and
                product_id = ?";

        $sth = $dbh->prepare($qry);
        $sth->execute( $type_value, $product_id );
    }

    my $count;
    $sth->bind_columns( \$count );
    $sth->fetch();

    return $count;
}

### Subroutine : get_product_selling_price      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_product_selling_price :Export() {

    my ( $dbh, $args ) = @_;

    # set up vars
    my $price       = 0;
    my $currency_id = 0;
    my $tax         = 0;
    my $duty        = 0;
    my $markdown    = 0;
    my $duty_rate   = 0;
    my $tax_rate    = 0;
    my $rrp         = 0;
    my $xt_instance = config_var('XTracker', 'instance');

    # duty calculation rules
    my $duty_threshold = 0;
    my $duty_product_percentage = 100;
    my $duty_fixed_rate = 0;

    # tax calculation rules
    my $tax_threshold = 0;
    my $tax_custom_modifier = 0;

    # get conversion rate from order currency to local rate - all duty rule values in local currency
    my $conversion_rate_local = get_conversion_rate_from_local($dbh, $args->{order_currency_id});

    my $qry = "select pc.price, pc.currency_id, pr.price, pr.currency_id, pd.price, pd.currency_id
                from product p
                left join price_country pc on p.id = pc.product_id and pc.country_id = (select id from country where country = ?)
                left join price_region pr on p.id = pr.product_id and pr.region_id = (select sbr.region_id from sub_region sbr, country c where c.country = ? and c.sub_region_id = sbr.id)
                left join price_default pd on p.id = pd.product_id
               where p.id = ?";

    my $sth = $dbh->prepare( $qry );
    $sth->execute($args->{country}, $args->{country}, $args->{product_id});

    while ( my $row = $sth->fetchrow_arrayref ) {

        # country price set
        if ( $row->[0] ){
            $price = $row->[0];
            $currency_id = $row->[1];
            $rrp = 1;
        }
        # regional price set - exclude UK, Jersey and Guernsey from European Region
        elsif ( $row->[2] && $args->{country} ne "United Kingdom" && $args->{country} ne "Guernsey" && $args->{country} ne "Jersey" ){
            $price = $row->[2];
            $currency_id = $row->[3];
            $rrp = 1;
        }
        # using default price for product
        else {
            $price = $row->[4];
            $currency_id = $row->[5];
        }
    }

    # if couldn't get a price check to see
    # if the product is a Gift Voucher
    if ( !defined $price || $price == 0 ) {
        my $schema  = get_schema_using_dbh( $dbh, 'xtracker_schema' );

        my $voucher = $schema->resultset('Voucher::Product')->find( $args->{product_id} );
        # found a voucher so just do this and return
        if ( defined $voucher ) {
            $price          = $voucher->value;
            $tax            = 0;
            $duty           = 0;
            $currency_id    = $voucher->currency_id;

            if ( $args->{order_currency_id} != $currency_id ) {
                # get conversion rate for product season
                $qry = "
                    SELECT conversion_rate
                    FROM season_conversion_rate
                    WHERE season_id = ?
                    AND source_currency_id = ?
                    AND destination_currency_id = ?
                ";

                $sth = $dbh->prepare($qry);
                $sth->execute( $voucher->season_id, $currency_id, $args->{order_currency_id} );

                my $conv_rate   = 1;

                while ( my $item = $sth->fetchrow_hashref() ) {
                    $conv_rate = $item->{conversion_rate};
                }

                $price  = $price * $conv_rate;
            }

            return ( $price, $tax, $duty );
        }
    }

    # get any markdowns on product
    $qry = "select percentage
                from price_adjustment
                where product_id = ?
                and date_start < current_timestamp
                and exported = true
                order by date_start desc limit 1";

    $sth = $dbh->prepare( $qry );
    $sth->execute($args->{product_id});

    while ( my $row = $sth->fetchrow_arrayref ) {
        $markdown = $row->[0];
    }

    # get duty rate
    $qry = "select cdr.rate
                from country_duty_rate cdr, product p
                where p.id = ?
                and p.hs_code_id = cdr.hs_code_id
                and cdr.country_id = (select id from country where country = ?)";

    $sth = $dbh->prepare( $qry );
    $sth->execute($args->{product_id}, $args->{country});

    while ( my $row = $sth->fetchrow_arrayref ) {
        $duty_rate = $row->[0];
    }

    # get duty rules for country
    $qry = "select dr.rule, drv.value
                from duty_rule dr, duty_rule_value drv
                where drv.country_id = (select id from country where country = ?)
                and drv.duty_rule_id = dr.id";
    $sth = $dbh->prepare( $qry );
    $sth->execute($args->{country});

    while ( my $row = $sth->fetchrow_hashref ) {
        if ($row->{rule} eq "Product Percentage") {
            $duty_product_percentage = $row->{value};
        }

        if ($row->{rule} eq "Order Threshold") {
            $duty_threshold = $row->{value} * $conversion_rate_local;
        }

        if ($row->{rule} eq "Fixed Rate") {
            $duty_fixed_rate = $row->{value} * $conversion_rate_local;
        }
    }

    $duty_product_percentage = $duty_product_percentage / 100;

    # get sales tax rate
    $qry = "select rate
                from country_tax_rate
                where country_id = (select id from country where country = ?)";

    $sth = $dbh->prepare( $qry );
    $sth->execute($args->{country});

    while ( my $row = $sth->fetchrow_arrayref ) {
        $tax_rate = $row->[0];
    }

    # get tax rules for country
    $qry = "select tr.rule, trv.value
                from tax_rule tr, tax_rule_value trv
                where trv.country_id = (select id from country where country = ?)
                and trv.tax_rule_id = tr.id";
    $sth = $dbh->prepare( $qry );
    $sth->execute($args->{country});

    while ( my $row = $sth->fetchrow_hashref ) {
        if ($row->{rule} eq "Order Threshold") {
            $tax_threshold = $row->{value} * $conversion_rate_local;
        }

        if ( $row->{rule} eq 'Custom Modifier' ) {
            $tax_custom_modifier = $row->{value} / 100;
        }

    }

    # product specific tax rates
    $qry = "select pttr.rate
                from product_type_tax_rate pttr, product p
                where p.id = ?
                and p.product_type_id = pttr.product_type_id
                and pttr.country_id = (select id from country where country = ?)";

    $sth = $dbh->prepare( $qry );
    $sth->execute($args->{product_id}, $args->{country});

    while ( my $row = $sth->fetchrow_arrayref ) {
        $tax_rate = $row->[0];
    }

    # workaround for NY tax until Vertex is integrated
    my $vertext_workaround = XT::Rules::Solve->solve(
        'Database::Pricing::product_selling_price::vertext_workaround' => {
            country => $args->{country},
            county  => $args->{county}
        }
    );

    if ( $vertext_workaround ) {
        $tax_rate = 0.04375;
    }

    # calculate price

    # currency conversion if required
    if ($args->{order_currency_id} != $currency_id){

        # get conversion rate for product season
        $qry = "
            SELECT conversion_rate
            FROM season_conversion_rate
            WHERE season_id = (SELECT season_id FROM product WHERE id = ?)
            AND source_currency_id = ?
            AND destination_currency_id = ?
        ";

        $sth = $dbh->prepare($qry);
        $sth->execute($args->{product_id}, $currency_id, $args->{order_currency_id});

        my $conv_rate = 1;

        while ( my $item = $sth->fetchrow_hashref() ) {
            $conv_rate = $item->{conversion_rate};
        }

        $price = $price * $conv_rate;
    }

    # markdown - if applicable
    if ($markdown > 0){
        $price = $price * ((100 - $markdown) / 100);
    }

    # customer discount - if applicable
    if ($args->{customer_id} || $args->{pre_order_discount} ){

        # Pre-Order Discount takes presedence as it could be different everytime
        if ( $args->{pre_order_discount} ) {
            $price = apply_discount( $price, $args->{pre_order_discount} );
        }
        else {
            $qry = "
                select cat.discount
                from customer c, customer_category cat
                where c.id = ?
                and c.category_id = cat.id
            ";
            $sth = $dbh->prepare($qry);
            $sth->execute($args->{customer_id});

            my $discount = 1;

            while ( my $item = $sth->fetchrow_hashref() ) {
                $discount = (100 - $$item{discount}) / 100;
            }

            $price = $price * $discount;
        }
    }

    # duties

    # check for duty threshold on order value
    if ($args->{order_total} >= $duty_threshold) {

        ### check for a fixed rate duty
        if ($duty_fixed_rate){
            $duty = $duty_fixed_rate;
        }
        else {
            $duty = ($price * $duty_product_percentage) * $duty_rate;
        }
    }


    # tax

    # check for tax threshold on order value
    if ( $args->{order_total} >= $tax_threshold ) {

        # If Custom Modifier is non zero (we found an entry in the table).
        if ( $tax_custom_modifier != 0 ) {

            $tax = ( $price + $duty ) / $tax_custom_modifier * $tax_rate;

        } else {

            $tax = ( $price + $duty ) * $tax_rate;

        }

    }


    # if UK system and price is an RRP then tax and duty need to be taken off rather than added on
    my $product_selling_price = config_var( 'Pricing', 'ProductSellingPrice' );
    if ($product_selling_price->{remove_vat} && $rrp == 1){

        # check for tax threshold on order value
        if ($args->{order_total} >= $tax_threshold) {
            my $less_tax = $price / (1 + $tax_rate);
            $tax = $price - $less_tax;

            $price = $less_tax;
        }

        # check for duty threshold on order value
        if ($args->{order_total} >= $duty_threshold) {

            # check for a fixed rate duty
            if ($duty_fixed_rate){
                $price = $price - $duty_fixed_rate;
            }
            else {
                my $less_duty = $price / (1 + ( $duty_product_percentage * $duty_rate ));
                $duty = $price - $less_duty;
                $price = $less_duty;
            }
        }
    }

    return $price, $tax, $duty;
}

### Subroutine : get_buy_conversion_rates     ###
# usage        :                                  #
# description  :   gets a hash of all buy conversion rates                               #
# parameters   :                                  #
# returns      :                                  #

sub get_buy_conversion_rates :Export {

    my ( $dbh ) = @_;

    my %rates = ();

    my $qry = "select season_id, source_currency, destination_currency, conversion_rate from conversion_rate";
    my $sth = $dbh->prepare( $qry );
    $sth->execute();

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $rates{$row->[0]}{$row->[1]}{$row->[2]} = $row->[3];
    }

    return \%rates;
}


### Subroutine : complete_pricing                         ###
# usage        : complete_pricing( $p );                    #
# description  : Sets status of product price to complete.  #
# parameters   : $dbh, $product_id, $operator_id            #
# returns      : from $sth                                  #

sub complete_pricing :Export {

    my ( $dbh, $args ) = @_;

    if (!defined $args->{product_id} ) {
        die 'No product id defined for complete_pricing()';
    }

    if (!defined $args->{operator_id} ) {
        $args->{operator_id} = $APPLICATION_OPERATOR_ID;

        warn __PACKAGE__
            ."::complete_pricing(): Please define operator_id for call"
            ." - defaulting to 'Application'";
    }

    my $qry = qq{
            UPDATE price_default SET
                   complete = true,
                   complete_by_operator_id = ?,
                   operator_id = ?
             WHERE product_id = ?
               AND complete = false
    };

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{operator_id}, $args->{operator_id}, $args->{product_id} );
    $sth->finish;

    return;
}




sub get_discounts :Export() {

    my $params = shift;

    my ( $bind, @bound );

    my $dataref = $params->{id_ref};

    my @data = ( @$dataref );

    foreach my $item ( @data ) {

        my $product_id = $item->{product_id};

        $bind  .= ' ?,';
        push @bound, $product_id;

    }

    chop $bind;

    my $qry = qq{
select id, product_id, percentage, date_start
from price_adjustment
where product_id in ( $bind )
};

    my $sth = $params->{dbh}->prepare( $qry );

    $sth->execute( @bound );

    my $discounts;

    while ( my $row = $sth->fetchrow_hashref( ) ) {

        my $discounts_ref = $discounts->{$row->{product_id}} || [ ];
        my @discounts = @$discounts_ref;
        push @discounts, $row;
        $discounts_ref = \@discounts;
        $discounts->{$row->{product_id}} = $discounts_ref;

    }

    return $discounts;

}

1;


__END__


