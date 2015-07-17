package XTracker::Database::Customer;

use strict;
use warnings;
use Carp;

use Perl6::Export::Attrs;
use XTracker::Database;
use XTracker::Database::Utilities;
use XTracker::DBEncode qw/ decode_db encode_db /;
use XTracker::Utilities qw(
    format_currency
    number_in_list
    ucfirst_roman_characters
);
use XTracker::Constants::FromDB     qw(
                                        :renumeration_class
                                        :renumeration_status
                                        :renumeration_type
                                        :return_item_status
                                        :return_type
                                        :shipment_class
                                        :shipment_status
                                        :shipment_item_status
                                    );

use DateTime;
use DateTime::Duration;

### Subroutine : create_customer                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_customer :Export(:DEFAULT) {

    my ( $dbh, $data_ref ) = @_;


        # create customer record

        my $qry = "insert into customer ( ";
        if ( $data_ref->{customer_id} ) {
            $qry .= "id, ";
        }

        $qry .= " is_customer_number, title, first_name, last_name, email,
                  category_id, created, modified, telephone_1, telephone_2, telephone_3, group_id, channel_id ";

        if ( $data_ref->{account_urn} ) {
            $qry .= ', account_urn ';
        }

        $qry .= ')';

        if ( $data_ref->{customer_id} ) {
            $qry .=
                "values ( ?, ?, ?, ?, ?, ?, ?, current_timestamp, current_timestamp, ?, ?, ?, default, ?";
        }
        else {
            $qry .=
                "values ( ?, ?, ?, ?, ?, ?, current_timestamp, current_timestamp, ?, ?, ?, default, ?";
        }

        if ( $data_ref->{account_urn} ) {
            $qry .= ', ?';
        }

        $qry .= ' )';

        my $sth = $dbh->prepare($qry);

        my @execute_vars = ();

        if ( $data_ref->{customer_id} ) {
            push @execute_vars, $data_ref->{customer_id};
        }

        push @execute_vars,
            (
            $data_ref->{is_customer_number},
            $data_ref->{title},     $data_ref->{first_name},
            $data_ref->{last_name}, $data_ref->{email},
            $data_ref->{category_id}, $data_ref->{telephone_1},
            $data_ref->{telephone_2},$data_ref->{telephone_3},
            $data_ref->{channel_id}
            );

        if ( $data_ref->{account_urn} ) {
            push @execute_vars, $data_ref->{account_urn};
        }

        $sth->execute(encode_db(@execute_vars));

        if ( !$data_ref->{customer_id} ) {
            $data_ref->{customer_id}
                = last_insert_id( $dbh, 'customer_id_seq' );
        }

        foreach my $address_ref ( @{ $data_ref->{addresses} } ) {
            _create_address( $data_ref->{customer_id}, $address_ref );
        }

       return $data_ref->{customer_id};

}

### Subroutine : update_customer                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub update_customer :Export(:DEFAULT) {

    my ( $dbh, $data_ref ) = @_;

        my $qry = "update customer set ";

        my @updates = ();

        if ( $data_ref->{title} ) {
            push @updates, "title = ?";
        }
        if ( $data_ref->{first_name} ) {
            push @updates, "first_name = ?";
        }
        if ( $data_ref->{last_name} ) {
            push @updates, "last_name = ?";
        }
        if ( $data_ref->{email} ) {
            push @updates, "email = ?";
        }
        #if ( $data_ref->{category_id} ) {
        #    push @updates, "category_id = ?";
        #}
        if ( $data_ref->{telephone_1} ) {
            push @updates, "telephone_1 = ?";
        }
        if ( $data_ref->{telephone_2} ) {
            push @updates, "telephone_2 = ?";
        }
        if ( $data_ref->{telephone_3} ) {
            push @updates, "telephone_3 = ?";
        }

        $qry .= join ", ", @updates;
        $qry .= " where id = ?";

        my @execute_vars = ();

        if ( $data_ref->{title} ) {
            push @execute_vars, $data_ref->{title};
        }
        if ( $data_ref->{first_name} ) {
            push @execute_vars, $data_ref->{first_name};
        }
        if ( $data_ref->{last_name} ) {
            push @execute_vars, $data_ref->{last_name};
        }
        if ( $data_ref->{email} ) {
            push @execute_vars, $data_ref->{email};
        }
        #if ( $data_ref->{category_id} ) {
        #    push @execute_vars, $data_ref->{category_id};
        #}
        if ( $data_ref->{telephone_1} ) {
            push @execute_vars, $data_ref->{telephone_1};
        }
        if ( $data_ref->{telephone_2} ) {
            push @execute_vars, $data_ref->{telephone_2};
        }
        if ( $data_ref->{telephone_3} ) {
            push @execute_vars, $data_ref->{telephone_3};
        }

        my $sth = $dbh->prepare($qry);
        $sth->execute( encode_db(@execute_vars), $data_ref->{customer_id} );

}

### Subroutine : _create_address                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _create_address {

    my ( $dbh, $customer_id, $data_ref ) = @_;

    my @execute_vars = ();

    my $qry = "insert into address
                  ( id, customer_id, address_line_1, address_line_2, address_line_3,
                    towncity, county, postcode, country, address_hash, inserted, type, \"default\", company_name )
               values( default, ?, ?, ?, ?, ?, ?, ?, ?, null, null, ?, 1, null )";

    my $sth = $dbh->prepare($qry);

    push @execute_vars,
        (
        $customer_id,          $data_ref->{line_1},   $data_ref->{line_2},
        $data_ref->{line_3},   $data_ref->{towncity}, $data_ref->{county},
        $data_ref->{postcode}, $data_ref->{country},  $data_ref->{type}
        );

    $sth->execute(encode_db(@execute_vars));

    return last_insert_id( $dbh, 'address_id_seq' );
}

### Subroutine : check_customer                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub check_customer :Export(:DEFAULT) {

    my ( $dbh, $cust_nr, $channel_id ) = @_;

    if (not defined $cust_nr) {
        die 'No customer number defined for check_customer()';
    }

    if (not defined $channel_id) {
        die 'No channel_id defined for check_customer()';
    }

    my $cust_id = 0;

    my $qry = "SELECT id FROM customer WHERE is_customer_number = ? AND channel_id = ? ORDER BY id LIMIT 1";
    my $sth = $dbh->prepare($qry);

    $sth->execute($cust_nr, $channel_id);
    while ( my $rows = $sth->fetchrow_arrayref ) {
        $cust_id = $rows->[0];
    }

    return $cust_id;
}

### Subroutine : get_customer_by_email                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_customer_by_email :Export(:DEFAULT) {

    my ( $dbh, $email ) = @_;

    my $cust_id = 0;

    my $qry = "SELECT id FROM customer WHERE email = ?";
    my $sth = $dbh->prepare($qry);

    $sth->execute(encode_db($email));
    while ( my $rows = $sth->fetchrow_arrayref ) {
        $cust_id = $rows->[0];
    }

    return $cust_id;
}

### Subroutine : get_customer_info              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_customer_info :Export(:DEFAULT) {

    my ( $dbh, $cust_id ) = @_;

    my $qry = "SELECT c.id, c.is_customer_number, c.title, c.first_name, c.last_name, c.email, c.category_id, c.created, c.modified, c.telephone_1, c.telephone_2, c.telephone_3, c.group_id, c.ddu_terms_accepted, c.legacy_comment, c.credit_check, to_char(c.no_marketing_contact, 'DD-MM-YYYY') as no_marketing_contact, cc.category, cc.fast_track, c.no_signature_required, ch.name AS sales_channel
                FROM customer c, customer_category cc, channel ch
                WHERE c.id = ?
                AND c.category_id = cc.id
                AND c.channel_id = ch.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($cust_id);

    my $cust = $sth->fetchrow_hashref();

    foreach (qw[title first_name last_name email]) {
        $cust->{$_} = decode_db($cust->{$_});
    }

    return $cust;

}

### Subroutine : search_customers                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub search_customers :Export() {

    my ($dbh, $customer_nr, $first_name, $last_name, $email) = @_;

    my %list = ();

    my $qry = "SELECT * FROM customer WHERE ";
    my @bind_params;

    if ($customer_nr){
        $qry .= "is_customer_number = ? AND ";
        push @bind_params, $customer_nr;
    }

    if ($first_name){
        $qry .= "lower(first_name) = lower(?) AND ";
        push @bind_params, $first_name;
    }

    if ($last_name){
        $qry .= "lower(last_name) = lower(?) AND ";
        push @bind_params, $last_name;
    }

    if ($email){
        $qry .= "lower(email) = lower(?) AND ";
        push @bind_params, $email;
    }

    $qry =~ s/\sAND\s\Z//;

    my $sth = $dbh->prepare($qry);
    $sth->execute(encode_db(@bind_params));

    while ( my $row = $sth->fetchrow_hashref() ) {
        $list{ $$row{id} } = decode_db($row);
    }

    return \%list;

}


### Subroutine : get_customer_ddu_authorised    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_customer_ddu_authorised :Export(:DEFAULT) {

    my ( $dbh, $cust_id ) = @_;

    my $qry = "SELECT ddu_terms_accepted FROM customer WHERE id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($cust_id);

    my $row = $sth->fetchrow_arrayref();

    return $row->[0];
}

### Subroutine : set_customer_ddu_authorised    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_customer_ddu_authorised :Export(:DEFAULT) {

    my ( $dbh, $cust_id ) = @_;

    my $qry = "UPDATE customer SET ddu_terms_accepted = true WHERE id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($cust_id);

}

### Subroutine : get_customer_flag              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_customer_flag :Export(:DEFAULT) {

    my ( $dbh, $cust_id ) = @_;

    my $qry = "SELECT * FROM customer_flag WHERE customer_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($cust_id);

    my %flags;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $flags{ $$row{id} } = $row;
    }

    return \%flags;
}

### Subroutine : set_customer_credit_check      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_customer_credit_check :Export(:DEFAULT) {

    my ( $dbh, $cust_id ) = @_;

    my $qry = "UPDATE customer SET credit_check = current_timestamp WHERE id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($cust_id);

}

### Subroutine : set_marketing_contact_date      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_marketing_contact_date :Export(:DEFAULT) {

    my ( $dbh, $cust_id, $what ) = @_;

    my $qry;

    if ($what eq "2month"){
        $qry = "UPDATE customer SET no_marketing_contact = (current_timestamp + interval '2 months') WHERE id = ?";
    }
    elsif ($what eq "forever"){
        $qry = "UPDATE customer SET no_marketing_contact = '2100-01-01' WHERE id = ?";
    }
    else {
        $qry = "UPDATE customer SET no_marketing_contact = null WHERE id = ?";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute($cust_id);

}

sub get_customer_notes :Export(:DEFAULT) {

    my ( $dbh, $cust_id ) = @_;

    my $qry
        = "SELECT sn.id, to_char(sn.date, 'DD-MM-YY HH24:MI') as date, sn.note, sn.operator_id, nt.description, op.name, d.department FROM customer_note sn, note_type nt, operator op LEFT JOIN department d ON op.department_id = d.id WHERE sn.customer_id = ? AND sn.note_type_id = nt.id AND sn.operator_id = op.id";

    my $sth = $dbh->prepare_cached($qry);
    $sth->execute($cust_id);

    my %notes;

    while ( my $note = $sth->fetchrow_hashref() ) {
        $note->{$_} = decode_db( $note->{$_} ) for (qw( note ));
        $notes{ $$note{id} } = $note;
    }

    return \%notes;

}

### Subroutine : get_customer_categories              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_customer_categories :Export(:DEFAULT) {

    my ( $dbh ) = @_;

    my $qry = "SELECT * FROM customer_category";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{id} } =  $row->{category};
    }

    return \%data;
}

### Subroutine : set_customer_category              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_customer_category :Export(:DEFAULT) {

    my ( $dbh, $customer_id, $category_id ) = @_;

    my $qry = "UPDATE customer SET category_id = ? WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($category_id, $customer_id);

    return;
}


### Subroutine : add_customer_flag                              ###
# usage        : add_customer_flag($dbh, $customer_id, $flag_id)  #
# description  : adds a flag against a customer record            #
# parameters   : dbh, customer_id, flag_id                        #
# returns      :                                                  #

sub add_customer_flag :Export() {

    my ( $dbh, $customer_id, $flag_id ) = @_;

    my $qry = "INSERT INTO customer_flag VALUES (default, ?, ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $flag_id, $customer_id );

    # try to match others customers to the account provided
    # so we can flag them all
    my $alt_customers = match_customer($dbh, $customer_id);

    foreach my $alt_customer_id (@$alt_customers) {
        $sth->execute( $flag_id, $alt_customer_id );
    }

    return;
}

### Subroutine : delete_customer_flag                              ###
# usage        : delete_customer_flag($dbh, $customer_id, $flag_id)  #
# description  : deletes a flag against a customer record            #
# parameters   : dbh, customer_id, flag_id                           #
# returns      :                                                     #

sub delete_customer_flag :Export() {

    my ( $dbh, $customer_id, $flag_id ) = @_;

    my $qry = "DELETE FROM customer_flag WHERE flag_id = ? AND customer_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $flag_id, $customer_id );

    # try to match others customers to the account provided
    # so we can delete flag from them all
    my $alt_customers = match_customer($dbh, $customer_id);

    foreach my $alt_customer_id (@$alt_customers) {
        $sth->execute( $flag_id, $alt_customer_id );
    }

    return;
}


### Subroutine : match_customer                                    ###
# usage        : match_customer($dbh, $customer_id)                  #
# description  : tries to match customer accounts across all sales   #
#                channels using email address then name & address    #
# parameters   : dbh, customer_id                                    #
# returns      : array ref                                           #

sub match_customer :Export() {

    my ( $dbh, $customer_id ) = @_;

    my @customers;

    # first try a match on email address
    my $qry = "SELECT id FROM customer WHERE id != ? AND email != '' AND LOWER(email) = (SELECT LOWER(email) FROM customer WHERE id = ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $customer_id, $customer_id );

    while ( my $row = $sth->fetchrow_arrayref() ) {
        push @customers, $row->[0];
    }

    return \@customers;
}

=head2 get_customer_from_pws

Get customer data from the website db

=cut

sub get_customer_from_pws :Export {
    my ( $dbh_web, $customer_nr ) = @_;

    # Force Data out of MySQL to be in UTF8
    $dbh_web->do( "SET NAMES 'utf8';" );

    my $qry = 'SELECT id, email, first_name, last_name, global_id FROM customer WHERE id = ?';
    my $sth = $dbh_web->prepare($qry);
    $sth->execute( $customer_nr );

    my $customer_ref = $sth->fetchrow_hashref;
    return decode_db($customer_ref);
}

=head2 get_customer_from_pws_by_email

Get customer data from the website db using the email field.

=cut

sub get_customer_from_pws_by_email :Export {
    my ( $dbh_web, $email ) = @_;

    # Force Data out of MySQL to be in UTF8
    $dbh_web->do( "SET NAMES 'utf8';" );

    my $qry = 'SELECT id, email, first_name, last_name, global_id FROM customer WHERE email = ?';
    my $sth = $dbh_web->prepare($qry);
    $sth->execute( encode_db($email) );

    my $customer_ref = $sth->fetchrow_hashref;
    return decode_db($customer_ref);
}

=head2 get_customer_value

    $hash_ref   = get_customer_value(
                        $dbh,
                        $dbic_customer
                    );

Calculate the customer's value on the specified channel for the
past 12 months.

This returns a HASH keyed by Sales Channel Id, showing all of
the components of the Customer's Value which are: Spend,
UNIT Return Rate & Number of Orders. Also the date period
the calculation is for is also present.

    '1' => {
        period => {
            fancy => 'from 2010-01-01 to 2010-12-31 inclusive',
            start_date => '2010-01-01',
            end_date => '2010-12-31'
        },
        'spend'             => [ (see 'get_cv_spend') ],
        'return_rate'       => { (see 'get_cv_return_rate') },
        'number_of_orders'  => (see 'get_cv_order_count'),
    }

The I<fancy> values are generally expected to be shown to the user;
the I<value> values are there in case something needs the raw info.

=cut

sub get_customer_value :Export {
    my ( $dbh, $customer ) = @_;

    my $channel = $customer->channel;

    # set-up date period of 1 year from yesterday
    my $schema      = XTracker::Database::xtracker_schema();
    my $now         = $schema->db_now;
    my $yesterday   = $now - DateTime::Duration->new( days => 1 );
    # 1 year back plus 1 day, should be 12 month period
    my $duration    = DateTime::Duration->new( years => 1 ) - DateTime::Duration->new( days => 1 );

    # start at the beginning of the day and end at the end of the day
    my $start_date  = ( $yesterday - $duration )->set( hour => 0, minute => 0, second => 0 );
    my $end_date    = $yesterday->set( hour => 23, minute => 59, second => 59 );

    my $retval  = {
                    $channel->id => {
                        sales_channel   => $channel->name,
                        customer_id     => $customer->id,
                        period  => {
                            fancy => "last 12 months (from ".$start_date->dmy('-')." to ".$end_date->dmy('-')." inclusive)",
                            start_date => $start_date->ymd('-'),
                            end_date => $end_date->ymd('-'),
                        },
                        spend           => get_cv_spend( $dbh, $customer, $start_date, $end_date ),
                        return_rate     => get_cv_return_rate( $dbh, $customer, $start_date, $end_date ),
                        number_of_orders=> get_cv_order_count( $dbh, $customer, $start_date, $end_date ),
                    }
                 };

    return $retval;
}

=head2 get_cv_spend

Used as part of the 'Customer Value'.

    $hash_ref   = get_cv_spend(
                            $dbh,
                            $dbic_customer,
                            $start_date,
                            $end_date
                        );

Calculate the customer's spend on a specified channel, for
the specified period.

This is returned in the form of an array ref containing keys that
are currency codes, whose values are hashes containing the keys
'gross' and 'net', with the corresponding monetary values from XT for
the date period, rounded to the nearest unit of currency:

So, for customer ID 34567 on channel 1, the returned hash might be:

      [
           { gross => { value => 12345, fancy => "12,345.00" },
             returns => { value => 1234,  fancy => "1,234.00" },
             net   => { value => 5678,  fancy => "5,678.00" },
             currency => 'GBP',
             html_entity => '&pounds;',
           },
           { gross => { value => 212345, fancy => "212,345.00" },
             returns => { value => 2345.33,  fancy => "2,345.33" },
             net   => { value => 95678,  fancy => "95,678.00" },
             currency => 'EUR',
             html_entity => '&euros;',
           },
      ]

=cut

sub get_cv_spend :Export {
    my ( $dbh, $customer, $start_timestamp, $end_timestamp )    = @_;

    my @spend;

    my ( $customer_id, $channel_id )    = ( $customer->id, $customer->channel_id );

    my $qry = qq{
                 SELECT cu2.currency,
                        cg.html_entity,
                        gross,
                        returns,
                        gross - returns AS net
                   FROM (
                     SELECT x.currency_id,
                            SUM(gross_sum)
                              + COALESCE(SUM(rdebit.shipping), 0)
                              + COALESCE(SUM(rdebit.gift_voucher), 0)
                             AS gross,
                            SUM(returns_sum)
                              + COALESCE(SUM(rrefund.shipping), 0)
                             AS returns
                       FROM (
                         SELECT cu.id AS currency_id,
                                COALESCE(SUM(ri.unit_price + ri.tax + ri.duty), 0) AS gross_sum,
                                0    AS returns_sum,
                                r.id AS debit_renumeration_id,
                                NULL AS refund_renumeration_id
                           FROM renumeration r
                           JOIN renumeration_item ri
                             ON ri.renumeration_id=r.id
                            AND r.renumeration_status_id = $RENUMERATION_STATUS__COMPLETED
                            AND r.renumeration_class_id  = $RENUMERATION_CLASS__ORDER
                            AND r.renumeration_type_id   = $RENUMERATION_TYPE__CARD_DEBIT
                           JOIN currency cu
                             ON r.currency_id=cu.id
                           JOIN shipment s
                             ON r.shipment_id=s.id
                           JOIN link_orders__shipment los
                             ON s.id=los.shipment_id
                           JOIN orders o
                             ON los.orders_id=o.id
                            AND o.channel_id = ?
                            AND o.date BETWEEN ? AND ?
                           JOIN customer c
                             ON o.customer_id=c.id
                            AND c.id = ?
                          GROUP BY cu.id,
                                    r.id
                     UNION
                         SELECT cu.id AS currency_id,
                                0 AS gross_sum,
                                COALESCE(SUM(ri.unit_price + ri.tax + ri.duty),0) AS returns_sum,
                                NULL AS debit_renumeration_id,
                                r.id AS refund_renumeration_id
                           FROM renumeration r
                           JOIN renumeration_item ri
                             ON ri.renumeration_id=r.id
                            AND r.renumeration_status_id=$RENUMERATION_STATUS__COMPLETED
                            AND r.renumeration_class_id= $RENUMERATION_CLASS__RETURN
                            AND r.renumeration_type_id IN ( $RENUMERATION_TYPE__CARD_REFUND,
                                                            $RENUMERATION_TYPE__STORE_CREDIT )
                           JOIN currency cu
                             ON r.currency_id=cu.id
                           JOIN shipment s
                             ON r.shipment_id=s.id
                           JOIN link_orders__shipment los
                             ON s.id=los.shipment_id
                           JOIN orders o
                             ON los.orders_id=o.id
                            AND o.channel_id = ?
                            AND o.date BETWEEN ? AND ?
                           JOIN customer c
                             ON o.customer_id=c.id
                            AND c.id= ?
                          GROUP BY cu.id,
                                    r.id
                     ) x
                     LEFT JOIN renumeration rdebit
                       ON rdebit.id  = x.debit_renumeration_id
                     LEFT JOIN renumeration rrefund
                       ON rrefund.id = x.refund_renumeration_id
                     GROUP BY x.currency_id
                 ) y
                 JOIN currency cu2
                   ON y.currency_id = cu2.id
                 JOIN link_currency__currency_glyph lcg
                   ON lcg.currency_id=cu2.id
                 JOIN currency_glyph cg
                   ON lcg.currency_glyph_id=cg.id
                 ORDER BY currency
                     ;
    };

    my $sth = $dbh->prepare($qry);

    $sth->execute( $channel_id, $start_timestamp, $end_timestamp, $customer_id,
                   $channel_id, $start_timestamp, $end_timestamp, $customer_id );

    while ( my $rec = $sth->fetchrow_hashref() ) {
        push @spend, {
                        gross   => {
                            value       => sprintf("%0.3f",$rec->{gross}),
                            formatted   => format_currency($rec->{gross}, 2, 1)
                        },
                        returns => {
                            value       => sprintf("%0.3f",$rec->{returns}),
                            formatted   => format_currency($rec->{returns}, 2, 1)
                        },
                        net     => {
                            value       => sprintf("%0.3f",$rec->{net}),
                            formatted   => format_currency($rec->{net}, 2, 1)
                        },
                        currency    => $rec->{currency},
                        html_entity => $rec->{html_entity}
               };
    }

    return \@spend;
}

=head2 get_cv_return_rate

Used as part of the 'Customer Value'.

    $hash_ref   = get_cv_return_rate(
                            $dbh,
                            $dbic_customer,
                            $start_date,
                            $end_date
                        );

This returns the Unit Return Rate for a given Customer over a specfied period. It only
countr items that are at the following Status: Packed, Dispatched, Return Pending,
Return Received, Returned. It then gives the percentage unit return rate counting items
that are Packed, Dispathed or Return Pending as items bought and items that are Return
Received or Returned as items returned.

It returns a Hash Ref with the following:
    {
        total_items     => 12,
        items_bought    => 7,
        items_returned  => 5,
        unit_return_rate=> '41.67%',
    }

=cut

sub get_cv_return_rate :Export {
    my ( $dbh, $customer, $start_timestamp, $end_timestamp )    = @_;

    my ( $customer_id, $channel_id )    = ( $customer->id, $customer->channel_id );

    my $total   = 0;
    my $bought  = 0;
    my $returned= 0;

    my $qry = qq{
SELECT  si.shipment_item_status_id AS item_status_id,
        ri.return_type_id AS return_type_id,
        COUNT(*) AS item_count
FROM    shipment_item si
        LEFT JOIN return_item ri
                    ON ri.shipment_item_id = si.id
        JOIN shipment s
                    ON s.id = si.shipment_id
                    AND s.shipment_status_id IN (
                                                    $SHIPMENT_STATUS__PROCESSING,
                                                    $SHIPMENT_STATUS__DISPATCHED
                                                )
                    AND s.shipment_class_id IN (
                                                    $SHIPMENT_CLASS__STANDARD,
                                                    $SHIPMENT_CLASS__RE_DASH_SHIPMENT,
                                                    $SHIPMENT_CLASS__REPLACEMENT
                                               )
        JOIN link_orders__shipment los
                    ON los.shipment_id = s.id
        JOIN orders o
                    ON o.id = los.orders_id
                    AND o.channel_id = ?
                    AND o.date BETWEEN ? AND ?
        JOIN customer c
                    ON c.id = o.customer_id
                    AND c.id = ?
WHERE   si.shipment_item_status_id IN (
                                        $SHIPMENT_ITEM_STATUS__PACKED,
                                        $SHIPMENT_ITEM_STATUS__DISPATCHED,
                                        $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                                        $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                                        $SHIPMENT_ITEM_STATUS__RETURNED
                                    )
GROUP BY    item_status_id,
            return_type_id
    };

    my $sth = $dbh->prepare($qry);

    $sth->execute( $channel_id, $start_timestamp, $end_timestamp, $customer_id );

    while ( my $row = $sth->fetchrow_hashref() ) {
        $total  += $row->{item_count};

        # if the Return is an Exchange then don't count it as being returned, regardless of the item's status
        if ( defined $row->{return_type_id} && $row->{return_type_id} == $RETURN_TYPE__EXCHANGE ) {
            $bought += $row->{item_count};
            next;
        }

        # if the status of the item is a 'Return' one then count it as a return, else it's bought
        if ( number_in_list( $row->{item_status_id}, (
                                                    $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                                                    $SHIPMENT_ITEM_STATUS__RETURNED,
                                                ) ) ) {
            $returned   += $row->{item_count};
        }
        else {
            $bought += $row->{item_count};
        }
    }

    my %return_rate = (
            total_items     => $total,
            items_bought    => $bought,
            items_returned  => $returned,
            # work out unit return rate percentage and allow for potential divide by zero error
            unit_return_rate=> ( $total ? sprintf( "%0.2f%%", ( ( $returned / $total ) * 100 ) ) : '0.00%' ),
        );

    return \%return_rate;
}

=head2 get_cv_order_count

Used as part of the 'Customer Value'.

    $integer = get_cv_order_count(
                            $dbh,
                            $dbic_customer,
                            $start_date,
                            $end_date
                        );

This gets the total number of orders for the given date period for a Customer.

=cut

sub get_cv_order_count :Export {
    my ( $dbh, $customer, $start_timestamp, $end_timestamp )    = @_;

    my ( $customer_id, $channel_id )    = ( $customer->id, $customer->channel_id );

    my $order_count = 0;

    my $qry = qq{
SELECT  COUNT(DISTINCT o.id) AS order_count
FROM    orders o
        JOIN link_orders__shipment los
                    ON los.orders_id = o.id
        JOIN shipment s
                    ON s.id = los.shipment_id
                    AND s.shipment_status_id IN (
                                               $SHIPMENT_STATUS__PROCESSING,
                                               $SHIPMENT_STATUS__DISPATCHED
                                            )
                    AND s.shipment_class_id IN (
                                                $SHIPMENT_CLASS__STANDARD,
                                                $SHIPMENT_CLASS__RE_DASH_SHIPMENT,
                                                $SHIPMENT_CLASS__REPLACEMENT
                                            )
                    AND EXISTS (
                        SELECT  1
                        FROM    shipment_item si
                        WHERE   si.shipment_id = s.id
                        AND     si.shipment_item_status_id IN (
                                    $SHIPMENT_ITEM_STATUS__PACKED,
                                    $SHIPMENT_ITEM_STATUS__DISPATCHED,
                                    $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                                    $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                                    $SHIPMENT_ITEM_STATUS__RETURNED
                                )
                    )
WHERE   o.customer_id = ?
AND     o.channel_id = ?
AND     o.date BETWEEN ? AND ?
    };

    my $sth = $dbh->prepare($qry);

    $sth->execute( $customer_id, $channel_id, $start_timestamp, $end_timestamp );

    while ( my $row = $sth->fetchrow_hashref() ) {
        $order_count    = $row->{order_count};
    }

    return $order_count;
}

=head2 get_order_address_customer_name

Given an OrderAddress object, a Customer object, and optionally a
Flag, return a hash containing C<first_name>, C<last_name>, C<title>
that represents the best available version of the customer's name.

If the Flag is set (which is the default when it is not provided),
canonicalize the presentation of the C<first_name> value that is
returned to be capitalized.

Also, if the Customer object is undef, immediately fall back to the
OrderAddress's details (this protects callers from having to cope with
situations where there is no Customer object, which can happen on
things like stock transfer shipments -- otherwise, we'd force the
caller to invent a bogus Customer object just for our benefit).

This exists to handle the situation where we want the name details on
an order address, which might be an invoice or shipping address, but
we also want the customer's title if we can get it.

So, we case-blind compare the first and last names on the order
address object to those on the customer object, and iff they're the
same, we return those along with the customer title, since we know
it matches that on the address.

Otherwise, we just return the first and last names from the address
and an empty title, because we don't have a reasonable way to guess
what it should be otherwise.


=cut

sub get_order_address_customer_name :Export(:DEFAULT) {
    my $order_address = shift;
    my $customer      = shift;
    my $fix_first_name= shift // 1;

    croak "Order Address required, but not provided"
      unless $order_address && ref( $order_address ) =~ qr/Public::OrderAddress$/;

    my ($c_first_name, $c_last_name);

    if ( $customer ) {
        croak "Customer provided, but not actually a Customer object"
            unless ref( $customer ) =~ qr/Public::Customer$/;

        $c_first_name = $customer->first_name || '';
        $c_last_name  = $customer->last_name  || '';
    }
    else {
        $c_first_name = $c_last_name = '';
    }

    my $o_first_name = $order_address->first_name || '';
    my $o_last_name  = $order_address->last_name  || '';

    if ( lc($o_first_name) eq lc($c_first_name)
      && lc($o_last_name)  eq lc($c_last_name)) {
        return { title      => $customer->title,
                 first_name => ( $fix_first_name ? ucfirst_roman_characters($c_first_name) : $c_first_name ),
                 last_name  => $c_last_name };
    }
    else {
        return { title      => undef, # because we actually don't know, rather than because it's empty
                 first_name => ( $fix_first_name ? ucfirst_roman_characters($o_first_name) : $o_first_name ),
                 last_name  => $o_last_name };
    }
}

=head2 check_or_create_customer

Given a hashref containing at least the keys is_customer_number and channel_id
return the id for the customer record

=cut

sub check_or_create_customer :Export(:DEFAULT) {
    my ( $dbh, $args ) = @_;

    foreach my $required ( qw( is_customer_number channel_id ) ) {
        die "$required field missing" unless exists( $args->{$required} )
                                             && $args->{$required};
    }

    my $id = check_customer($dbh,
                            $args->{is_customer_number},
                            $args->{channel_id}
                           );

    return $id ? $id : create_customer($dbh, $args);
}

1;
