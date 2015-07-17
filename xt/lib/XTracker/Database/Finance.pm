package XTracker::Database::Finance;

use strict;
use warnings;

use Perl6::Export::Attrs;
use DateTime::Format::Pg;

use XTracker::Constants::FromDB qw( :order_status :shipment_type :flag );
use XTracker::Config::Local qw( config_var );
use XTracker::Utilities qw/ time_diff_in_english /;
use XTracker::DBEncode qw( decode_db );

use vars qw($r);
use XTracker::Database::Row::CreditCheckOrder;

sub all_flags :Export(:DEFAULT) {

    my $dbh      = shift;
    my $order_id = shift;

    my @flags;

    my $flgqry
        = "SELECT f.flag_type_id, f.description, f.id FROM flag f, order_flag ofl WHERE ofl.orders_id = ? AND ofl.flag_id = f.id GROUP BY f.flag_type_id, f.description, f.id";
    my $flgsth = $dbh->prepare($flgqry);
    $flgsth->execute($order_id);

    while ( my $flgs = $flgsth->fetchrow_arrayref ) {
        my @tmp = ( $flgs->[0], $flgs->[1], $flgs->[2] );

        push( @flags, \@tmp );
    }

    return \@flags;
}

sub watch_flags :Export(:DEFAULT) {

    my $dbh     = shift;
    my $cust_id = shift;

    my %flags;

    my $flgqry = "SELECT f.description FROM flag f, customer_flag cfl WHERE cfl.customer_id = ? AND cfl.flag_id=f.id AND f.flag_type_id=5";
    my $flgsth = $dbh->prepare($flgqry);
    $flgsth->execute($cust_id);

    while ( my $flgs = $flgsth->fetchrow_arrayref ) {
        $flgs->[0] =~ s/ //;
        $flags{ $flgs->[0] } = 1;
    }

    return \%flags;

}


### Subroutine : set_hotlist_value        ###
# usage        :                                  #
# description  :  write hotlist value to db    #
# parameters   :   hotlist_field_id, value                               #
# returns      :    nowt                             #

sub set_hotlist_value :Export(:DEFAULT) {

    my ( $schema, $args ) = @_;

    if ( ref( $schema ) !~ m/Schema/ ) {
        die 'No Schema object passed in for set_hotlist_value()';
    }

    if ( not defined $args->{field_id} ) {
        die 'No field_id defined for set_hotlist_value()';
    }
    if ( !$args->{value} ) {
        die 'No value defined for set_hotlist_value()';
    }
    if ( not defined $args->{channel_id} ) {
        die 'No channel_id defined for set_hotlist_value()';
    }

    my $hotlist_rs  = $schema->resultset('Public::HotlistValue');

    #
    # check to see if the value exists already
    #
    # The Caller should do the Transaction
    #
    my $check   = $hotlist_rs->search( {
        hotlist_field_id    => $args->{field_id},
        channel_id          => $args->{channel_id},
        'LOWER(value)'      => lc( $args->{value} ),
        (
            defined $args->{order_nr} && $args->{order_nr} ne ''
            ? ( 'order_nr'              => $args->{order_nr} )
            : ( "COALESCE(order_nr,'')" => '' )
        ),
    } );
    if ( $check->count() > 0 ) {
        die "DUPLICATE\n";
    }

    # if unique, create it
    return $hotlist_rs->create( {
        hotlist_field_id    => $args->{field_id},
        channel_id          => $args->{channel_id},
        value               => $args->{value},
        order_nr            => $args->{order_nr},
    } );
}

### Subroutine : delete_hotlist_value        ###
# usage        :                                  #
# description  :  remove hotlist value to db    #
# parameters   :   hotlist_value_id                               #
# returns      :    nowt                             #

sub delete_hotlist_value :Export(:DEFAULT) {

    my ( $dbh, $id ) = @_;

    my $qry = "delete from hotlist_value where id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

}

sub get_hotlist :Export(:DEFAULT) {

    my ( $dbh ) = @_;

    my %data;

    my $qry = "select hv.id, ht.type, hf.field, hv.value
                    from hotlist_value hv, hotlist_field hf, hotlist_type ht
                    where hv.hotlist_field_id = hf.id
                    and hf.hotlist_type_id = ht.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

     while ( my $row = $sth->fetchrow_hashref ) {
        $data{ $row->{id} } = $row;
    }

    return \%data;
}

sub get_hotlist_values :Export(:DEFAULT) {

    my ( $dbh ) = @_;

    my %data;

    my $qry = "SELECT hv.id, hv.hotlist_field_id, hv.value, hv.order_nr, hf.hotlist_type_id, hf.field, ht.type, ch.name as sales_channel, o.id as order_id
                    FROM hotlist_value hv LEFT JOIN orders o ON hv.order_nr = o.order_nr, hotlist_field hf, hotlist_type ht, channel ch
                    WHERE hv.hotlist_field_id = hf.id
                    AND hf.hotlist_type_id = ht.id
                    AND hv.channel_id = ch.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

     while ( my $row = $sth->fetchrow_hashref ) {
        $data{ $row->{id} } = $row;
    }

    return \%data;
}

sub get_hotlist_fields :Export(:DEFAULT) {

    my ( $dbh ) = @_;

    my %data;

    my $qry = "select * from hotlist_field";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

     while ( my $row = $sth->fetchrow_hashref ) {
        $data{ $row->{id} } = $row->{field};
    }

    return \%data;
}

sub get_credit_hold_orders :Export() {
    my ($schema)    = @_;
    my $dbh         = $schema->storage->dbh;

    # get the High Priority Customer Classes used
    # in determining the priority of each row
    my $hp_customer_classes = $schema->resultset('Public::CustomerClass')->get_finance_high_priority_classes;

    my $package = __PACKAGE__;

    my $qry = "
-- Package: ${package}::get_credit_hold_orders
--
-- For the Finance->Credit Hold page
--
SELECT  o.id,
        o.order_nr,
        TO_CHAR(o.date, 'DD-MM-YYYY  HH24:MI') AS date,
        o.total_value,
        c.currency,
        cust.first_name,
        cust.last_name,
        s.shipment_type_id,
        s.gift,
        ch.name AS sales_channel,
        (
            SELECT  vc.source
            FROM    voucher.code vc
                    JOIN orders.tender ot ON ot.voucher_code_id = vc.id
                                          AND ot.order_id = o.id
            WHERE   vc.source IS NOT NULL
            LIMIT 1
        ) AS source,
        cust.category_id AS customer_category_id,
        ccat.category AS customer_category,
        ccat.customer_class_id,
        cclass.class AS customer_class,
        a.country AS shipment_country
FROM    orders o
            JOIN link_orders__shipment los    ON o.id = los.orders_id
            JOIN customer              cust   ON cust.id = o.customer_id
            JOIN customer_category     ccat   ON ccat.id = cust.category_id
            JOIN customer_class        cclass ON cclass.id = ccat.customer_class_id
            JOIN shipment              s      ON los.shipment_id = s.id
            JOIN order_address         a      ON a.id = s.shipment_address_id
            JOIN channel               ch     ON o.channel_id = ch.id
            JOIN currency              c      ON o.currency_id=c.id
WHERE   o.order_status_id = $ORDER_STATUS__CREDIT_HOLD
";

    my $sth = $dbh->prepare($qry);
    $sth->execute;

    my %order = ();
    while ( my $row = $sth->fetchrow_hashref() ) {
        $row->{$_} = decode_db( $row->{$_} ) for (qw(
            first_name
            last_name
        ));
        my $order_rec = $order{ $row->{sales_channel} }{ $row->{id} } = {};

        $order_rec->{number}        = $row->{order_nr};
        $order_rec->{sales_channel} = $row->{sales_channel};
        $order_rec->{date}          = $row->{date};
        $order_rec->{value}         = sprintf( "%.2f", $row->{total_value} );
        $order_rec->{currency}      = $row->{currency};
        $order_rec->{name}          = $row->{first_name} . ' ' . $row->{last_name};
        $order_rec->{gift}          = $row->{gift};
        $order_rec->{shipment_country} = $row->{shipment_country};

        # customer category information
        $order_rec->{customer_class_id}    = $row->{customer_class_id};
        $order_rec->{customer_category_id} = $row->{customer_category_id};
        $order_rec->{customer_class}       = $row->{customer_class};
        $order_rec->{customer_category}    = $row->{customer_category};

        # get the appropriate Priority for the Order
        $order_rec->{priority} = get_credit_hold_check_priority( $hp_customer_classes, $row );

        # get all order flags
        $order_rec->{flags} = all_flags( $dbh, $row->{id} );

        my @warnings;
        my @categories;
        my @cchecks;
        my $cv2_avs;

        # hash of possible cv2/avs responses
        my %cv2_avs_lookup = ( 'ALL MATCH' => 1, 'SECURITY CODE MATCH' => 1, 'NO DATA MATCHES' => 1, 'DATA NOT CHECKED' => 1 );

        foreach my $flag ( @{ $order_rec->{flags} } ) {

            # customer category flags
            if ( $flag->[0] == 1 ) {
                push( @categories, $flag->[1] );
            }
            # warning flags
            elsif ( $flag->[0] == 2 || $flag->[0] == 5 ) {

                # CV2/AVS responses
                if ( $cv2_avs_lookup{ $flag->[1] } ) {
                    $cv2_avs =  $flag->[1];
                }
                else {

                    if ( $flag->[2] == $FLAG__VIRTUAL_VOUCHER_PAYMENT_FAILURE
                      && $order_rec->{priority} == 0 ) {
                        # if there is a Virtual Voucher flag and current priority is ZERO
                        # set the priority to being 3
                        $order_rec->{priority} = 3;
                    }

                    my $warningImg = $flag->[1];
                    $warningImg =~ s/\s/_/g;

                    if ( -e config_var('SystemPaths','xtdc_base_dir')."/root/static/images/finance_icons/$warningImg.png" ) {
                        push( @warnings,
                                  '<img src="/images/finance_icons/'
                                . $warningImg
                                . '.png" align="left" hspace="4" alt="'
                                . $flag->[1]
                                . '">'
                        );
                    }
                    else {
                        push( @warnings, $flag->[1] . '&nbsp;&nbsp;' );
                    }
                }
            }
            # credit check flags
            elsif ( $flag->[0] == 3 ) {
                push( @cchecks, $flag->[1] );
            }
            # pre-order flag
            elsif ( $flag->[0] == 6 && $flag->[1] eq "Pre-Order" ) {
                $order_rec->{pre_order} = 1;
            }
            # don't care about the rest
            else {

            }
        }

        $order_rec->{cv2_avs}          = $cv2_avs;
        $order_rec->{warningFlags}     = \@warnings;
        $order_rec->{categoryFlags}    = \@categories;
    }

    return \%order;

}

sub get_credit_check_orders :Export() {
    my ($schema)    = @_;
    my $dbh         = $schema->storage->dbh;

    # get the High Priority Customer Classes used
    # in determining the priority of each row
    my $hp_customer_classes = $schema->resultset('Public::CustomerClass')->get_finance_high_priority_classes;

    # get a map of Language Ids to Languages and the Default
    my $languages   = $schema->resultset('Public::Language')
                                ->get_all_languages_and_default;

    # Note: Now that the query and the resultset are moved into the
    # XTracker::Database::Row::CreditCheckOrder class, a lot more
    # refactoring could be made here. TBD.
    my %order = ();
    XTracker::Database::Row::CreditCheckOrder->each_row({
    schema       => $schema,
    each_sub     => sub {
        my $row = shift;
        my $order_rec = $order{ $row->{sales_channel} }{ $row->{id} } = {};

        $order_rec->{number}        = $row->{order_nr};
        $order_rec->{sales_channel} = $row->{sales_channel};
        $order_rec->{age}           = $row->{age};

        if ( $order_rec->{age} eq "00:00:00" ) {
            $order_rec->{age} = "Today";
        }

        $order_rec->{nominated_dispatch_time}
            ||= $row->{nominated_dispatch_time};
        $order_rec->{nominated_earliest_selection_time}
            ||= $row->{nominated_earliest_selection_time};
        $order_rec->{nominated_credit_check_urgency}
            ||= $row->nominated_credit_check_urgency;

        $order_rec->{nominated_dispatch_in} ||= time_diff_in_english(
            $row->{nominated_dispatch_time},
        );

        $order_rec->{date}     = $row->{date};
        $order_rec->{value}    = sprintf( "%.2f", $row->{total_value} );
        $order_rec->{currency} = $row->{currency};
        $order_rec->{name}     = $row->{first_name} . ' ' . $row->{last_name};
        $order_rec->{gift}     = $row->{gift};
        $order_rec->{shipment_country} = $row->{shipment_country};

        # customer category information
        $order_rec->{customer_class_id}    = $row->{customer_class_id};
        $order_rec->{customer_category_id} = $row->{customer_category_id};
        $order_rec->{customer_class}       = $row->{customer_class};
        $order_rec->{customer_category}    = $row->{customer_category};

        # Customer Preferred Language
        $order_rec->{cpl}   = $languages->{ $row->{language_preference_id} || 'default' };

        $order_rec->{flags}    = all_flags( $dbh, $row->{id} );

        # get the appropriate Priority for the Order
        $order_rec->{priority} = get_credit_hold_check_priority( $hp_customer_classes, $row );

        my @warnings;
        my @categories;
        my @cchecks;
        my $cv2_avs;

        # hash of possible cv2/avs responses
        my %cv2_avs_lookup = ( 'ALL MATCH' => 1, 'SECURITY CODE MATCH' => 1, 'NO DATA MATCHES' => 1, 'DATA NOT CHECKED' => 1 );

        foreach my $flag ( @{ $order_rec->{flags} } ) {

            # customer category flags
            if ( $flag->[0] == 1 ) {
                push( @categories, $flag->[1] );
            }
            # warning flags
            elsif ( $flag->[0] == 2 || $flag->[0] == 5 ) {

                # CV2/AVS responses
                if ( $cv2_avs_lookup{ $flag->[1] } ) {
                    $cv2_avs =  $flag->[1];
                }
                else {

                    my $warningImg = $flag->[1];
                    $warningImg =~ s/\s/_/g;

                    if ( -e config_var('SystemPaths','xtdc_base_dir')."/root/static/images/finance_icons/$warningImg.png" ) {
                        push( @warnings,
                                  '<img src="/images/finance_icons/'
                                . $warningImg
                                . '.png" width="16" height="16" style="display:inline" alt="'
                                . $flag->[1]
                                . '">'
                        );
                    }
                    else {
                        push( @warnings, $flag->[1] . '&nbsp;&nbsp;' );
                    }
                }
            }
            # credit check flags
            elsif ( $flag->[0] == 3 ) {
                push( @cchecks, $flag->[1] );
            }
            # pre-order flag
            elsif ( $flag->[0] == 6 && $flag->[1] eq "Pre-Order" ) {
                $order_rec->{pre_order} = 1;
            }
            # don't care about the rest
            else {

            }
        }

        my $namecheck       = "-";
        my $addrcheck       = "-";
        my $possiblefraud   = "-";

        if ( @cchecks > 0 ) {
            foreach my $ccheck (@cchecks) {
                if ( $ccheck eq "Address OK" ) {
                    $addrcheck = "<img src=\"/images/icons/tick.png\">";
                }
                elsif ( $ccheck eq "Address Wrong" ) {
                    $addrcheck = "<img src=\"/images/icons/cross.png\">";
                }
                elsif ( $ccheck eq "Name OK" ) {
                    $namecheck = "<img src=\"/images/icons/tick.png\">";
                }
                elsif ( $ccheck eq "Name Wrong" ) {
                    $namecheck = "<img src=\"/images/icons/cross.png\">";
                }
                elsif ( $ccheck eq "Possible Fraud" ) {
                    $possiblefraud = "<img src=\"/images/icons/exclamation.png\">";
                }
            }
        }

        $order_rec->{namecheck}        = $namecheck;
        $order_rec->{addrcheck}        = $addrcheck;
        $order_rec->{possiblefraud}    = $possiblefraud;
        $order_rec->{cv2_avs}          = $cv2_avs;
        $order_rec->{warningFlags}     = \@warnings;
        $order_rec->{categoryFlags}    = \@categories;
    }});

    return \%order;

}

=head2 get_credit_hold_check_priority

    $priority   = get_credit_hold_check_priority(
                            \%high_priority_customer_classes,
                            \%credit_hold_or_check_row
                        );

This will return the priority level for a order that is either on Credit Hold or Credit Check.
This function is primary used within the 'get_credit_hold_orders' & 'get_credit_check_orders'
functions, where the priority is used to determine how to highlight a row if needed.

=cut

sub get_credit_hold_check_priority :Export() {
    my ( $hp_customer_classes, $row )   = @_;

    if ( !defined $hp_customer_classes || ref($hp_customer_classes) ne 'HASH' ) {
        die "Invalid High Priority Customer Classes passed to 'get_credit_hold_check_priority', must be a HASH";
    }
    if ( !defined $row || !ref($row) ) {
        die "Invalid Row data passed to 'get_credit_hold_check_priority'";
    }

    # by default there is no priority
    my $priority    = 0;

    CASE: {
        # flag Premier orders as priority
        if ( $row->{shipment_type_id} == $SHIPMENT_TYPE__PREMIER ) {
            $priority   = 1;
            last CASE;
        }

        # check if the voucher code source starts with 'AMEX' and is case insensitive
        if ( defined $row->{source} && $row->{source} =~ m/^AMEX/i ) {
            $priority   = 2;
            last CASE;
        }

        #
        # WARNING: Priority 3 is reserved for Virtual Voucher Payment Failures
        #          in 'get_credit_hold_orders' function
        #

        # look for high priority customers
        if ( exists( $hp_customer_classes->{ $row->{customer_class_id} } ) ) {
            $priority   = 4;
            last CASE;
        }

        # non-premier nominated day shipments
        if ($row->{nominated_dispatch_time}) {
            $priority   = 5;
            last CASE;
        }
    };

    return $priority;
}

sub get_invalid_payment_list :Export() {

    my ($schema) = @_;
    my ($dbh)    = $schema->storage->dbh;

    # get the High Priority Customer Classes used
    # in determining the priority of each row
    my $hp_customer_classes = $schema->resultset('Public::CustomerClass')->get_finance_high_priority_classes;

    my $qry  = "SELECT o.id, o.order_nr, c.first_name, c.last_name, to_char(o.date, 'DD-MM-YY HH24:MI') as date, ch.name as sales_channel,
                c.category_id AS customer_category_id,
                ccat.category AS customer_category,
                ccat.customer_class_id,
                cclass.class AS customer_class,
                s.shipment_type_id,
                to_char( (
                    SELECT  MAX(date_changed)
                    FROM    orders.payment op
                            JOIN orders.log_payment_valid_change opl ON opl.payment_id = op.id
                    WHERE   op.orders_id = o.id
                    AND     opl.new_state = FALSE
                ), 'DD-MM-YY HH24:MI') valid_log_date
                FROM link_orders__shipment los,
                channel ch,
                shipment s
                JOIN order_address a ON a.id = s.shipment_address_id,
                orders o
                JOIN customer c ON c.id = o.customer_id
                JOIN customer_category ccat ON ccat.id = c.category_id
                JOIN customer_class cclass ON cclass.id = ccat.customer_class_id
                WHERE o.id in (select orders_id from orders.payment where valid = false)
                AND o.channel_id = ch.id
                AND o.customer_id = c.id
                AND o.id = los.orders_id
                AND los.shipment_id = s.id
                AND o.order_status_id != $ORDER_STATUS__CANCELLED";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $row->{$_} = decode_db( $row->{$_} ) for (qw(
            first_name
            last_name
        ));

        $data{ $row->{sales_channel} } { $row->{id} }{number}         = $row->{order_nr};
        $data{ $row->{sales_channel} } { $row->{id} }{sales_channel}  = $row->{sales_channel};
        $data{ $row->{sales_channel} } { $row->{id} }{name}           = $row->{first_name} . ' ' . $row->{last_name};
        $data{ $row->{sales_channel} } { $row->{id} }{date}           = $row->{date};
        $data{ $row->{sales_channel} } { $row->{id} }{valid_log_date} = $row->{valid_log_date};

        # customer category information
        $data{ $row->{sales_channel} }{ $row->{id} }{customer_class_id}    = $row->{customer_class_id};
        $data{ $row->{sales_channel} }{ $row->{id} }{customer_category_id} = $row->{customer_category_id};
        $data{ $row->{sales_channel} }{ $row->{id} }{customer_class}       = $row->{customer_class};
        $data{ $row->{sales_channel} }{ $row->{id} }{customer_category}    = $row->{customer_category};

        # get the appropriate Priority for the Order
        $data{ $row->{sales_channel} }{ $row->{id} }{priority} = get_credit_hold_check_priority( $hp_customer_classes, $row );
    }

    return \%data;
}

sub get_finance_icons :Export() {
    my ($dbh) = @_;

    my %icons = ();

    my $qry = "SELECT description FROM flag where flag_type_id in (2,5)";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {

        my $icon_img = $row->{description};
        $icon_img =~ s/\s/_/g;

        if ( -e config_var('SystemPaths','xtdc_base_dir')."/root/static/images/finance_icons/$icon_img.png" ) {
            $icons{ $row->{description} } = '<img src="/images/finance_icons/'.$icon_img.'.png">';
        }
    }
    return \%icons;
}


### Subroutine : get_credit_hold_thresholds        ###
# usage        :                                  #
# description  : need to create XTracker::Schema::Result::Public::CreditHoldThreshold     #
# parameters   :                                  #
# returns      :                                 #

sub get_credit_hold_thresholds :Export() {

    my ( $dbh ) = @_;

    my %data;

    my $qry = "SELECT channel_id, name, value FROM credit_hold_threshold";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

     while ( my $row = $sth->fetchrow_hashref ) {
        $data{ $row->{channel_id} }{ $row->{name} } = $row->{value};
    }

    return \%data;
}

1;
