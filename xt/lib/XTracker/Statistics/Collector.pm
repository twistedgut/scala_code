package XTracker::Statistics::Collector;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('0.0.1');

use Perl6::Export::Attrs;
use Perl6::Say;

use XTracker::Constants::FromDB qw(
    :shipment_type :shipment_item_status :shipment_status :shipment_item_status
);


# Module implementation here


### Subroutine : on_credit_hold                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub on_credit_hold :Export {

    my ($dbh, $type, $channels) = @_;

    my $qry;
    if ($type eq 'premier') {
        $qry = "SELECT channel_id,COUNT(*)
                FROM orders o
                LEFT OUTER JOIN order_flag oflag ON o.id = oflag.orders_id
                AND oflag.flag_id = 45
                INNER JOIN link_orders__shipment los ON o.id = los.orders_id
                INNER JOIN shipment s ON los.shipment_id = s.id
                AND s.shipment_type_id = $SHIPMENT_TYPE__PREMIER
                WHERE o.order_status_id = 1
                AND oflag.orders_id IS NULL
                GROUP BY channel_id";
    }
    else {
        $qry = "SELECT channel_id,COUNT(*)
                FROM orders o
                LEFT OUTER JOIN order_flag oflag ON o.id = oflag.orders_id
                AND oflag.flag_id = 45
                WHERE o.order_status_id = 1
                AND oflag.orders_id IS NULL
                GROUP BY channel_id";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %results;
    my $total   = 0;
    while ( my @row = $sth->fetchrow_array() ) {
        $total  += $row[1];
        $results{ $channels->{$row[0]}{config_section} }    = $row[1];
    }

    $results{ALL}   = $total;

    return \%results;
}


### Subroutine : on_credit_check                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub on_credit_check :Export {

    my ($dbh, $type, $channels) = @_;

    my $qry;
    if ($type eq 'premier') {
        $qry = "SELECT channel_id,COUNT(*)
                FROM orders o
                LEFT OUTER JOIN order_flag oflag ON o.id = oflag.orders_id
                AND oflag.flag_id = 45
                INNER JOIN link_orders__shipment los ON o.id = los.orders_id
                INNER JOIN shipment s ON los.shipment_id = s.id
                AND s.shipment_type_id = $SHIPMENT_TYPE__PREMIER
                WHERE o.order_status_id = 2
                AND oflag.orders_id IS NULL
                GROUP BY channel_id";
    }
    else {
        $qry = "SELECT channel_id,COUNT(*)
                FROM orders o
                LEFT OUTER JOIN order_flag oflag ON o.id = oflag.orders_id
                AND oflag.flag_id = 45
                WHERE o.order_status_id = 2
                AND oflag.orders_id IS NULL
                GROUP BY channel_id";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %results;
    my $total   = 0;
    while ( my @row = $sth->fetchrow_array() ) {
        $total  += $row[1];
        $results{ $channels->{$row[0]}{config_section} }    = $row[1];
    }

    $results{ALL}   = $total;

    return \%results;
}


### Subroutine : on_preorder_hold               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub on_preorder_hold :Export {

    my ($dbh, $type, $channels) = @_;

    my $premier_sql     = "";

    if ($type eq 'premier') {
        $premier_sql    = " AND s.shipment_type_id = $SHIPMENT_TYPE__PREMIER ";
    }

    my $qry =<<SQL
SELECT  channel_id, SUM(total) AS total FROM (
    SELECT  o.channel_id AS channel_id,
            COUNT(*) as total
    FROM    shipment s, orders o, link_orders__shipment los
    WHERE   s.shipment_status_id IN (1,11)
    AND     s.id IN (SELECT shipment_id FROM shipment_flag WHERE flag_id = 45)
    AND     s.id = los.shipment_id
    AND     o.id = los.orders_id
    $premier_sql
    GROUP BY o.channel_id
    UNION ALL
    SELECT  st.channel_id AS channel_id,
            COUNT(*) as total
    FROM    shipment s, stock_transfer st, link_stock_transfer__shipment lsts
    WHERE   s.shipment_status_id IN (1,11)
    AND     s.id IN (SELECT shipment_id FROM shipment_flag WHERE flag_id = 45)
    AND     s.id = lsts.shipment_id
    AND     st.id = lsts.stock_transfer_id
    $premier_sql
    GROUP BY st.channel_id
) AS preorder
GROUP BY channel_id
SQL
;

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %results;
    my $total   = 0;
    while ( my @row = $sth->fetchrow_array() ) {
        $total  += $row[1];
        $results{ $channels->{$row[0]}{config_section} }    = $row[1];
    }

    $results{ALL}   = $total;

    return \%results;
}

### Subroutine : on_ddu_hold                    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub on_ddu_hold :Export {

    my ($dbh, $type, $channels) = @_;

    my $premier_sql = "";

    if ($type eq 'premier') {
        $premier_sql    = " AND s.shipment_type_id = $SHIPMENT_TYPE__PREMIER";
    }

    my $qry =<<SQL
SELECT  channel_id, SUM(total) AS total FROM (
    SELECT  o.channel_id AS channel_id, COUNT(*) AS total
    FROM    shipment s, orders o, link_orders__shipment los
    WHERE   s.shipment_status_id = 9
    AND     s.id = los.shipment_id
    AND     o.id = los.orders_id
    $premier_sql
    GROUP BY o.channel_id
    UNION ALL
    SELECT  st.channel_id AS channel_id, COUNT(*) AS total
    FROM    shipment s, stock_transfer st, link_stock_transfer__shipment lsts
    WHERE   s.shipment_status_id = 9
    AND     s.id = lsts.shipment_id
    AND     st.id = lsts.stock_transfer_id
    $premier_sql
    GROUP BY st.channel_id
) AS dduhold
GROUP BY channel_id
SQL
;


    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %results;
    my $total   = 0;
    while ( my @row = $sth->fetchrow_array() ) {
        $total  += $row[1];
        $results{ $channels->{$row[0]}{config_section} }    = $row[1];
    }

    $results{ALL}   = $total;

    return \%results;
}


### Subroutine : shipment_status                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub shipment_status :Export {
    my ($dbh, $status, $type, $channels)    = @_;
    # this is a mapping of shipment status name to shipment item status id
    # for picking out the shipments that have a shipment item status with the
    # lowest shipment_item_id - yes it's using the id's integer to indicate
    # progress through the workflow
    my %shpmnt_status_id = (
        selection => $SHIPMENT_ITEM_STATUS__NEW,
        picking   => $SHIPMENT_ITEM_STATUS__SELECTED,
        packing   => $SHIPMENT_ITEM_STATUS__PICKED,
    );

    my $premier_sql     = "";

    if ($type eq 'premier') {
        $premier_sql    = " AND s.shipment_type_id = $SHIPMENT_TYPE__PREMIER";
    }

    my $exclude_nominated_day_not_due = "
    AND (
        s.nominated_earliest_selection_time IS NULL
        OR s.nominated_earliest_selection_time < CURRENT_TIMESTAMP
    )
    ";

    my $qry =<<SQL
SELECT  channel_id, SUM(total) AS total FROM (
    SELECT  o.channel_id AS channel_id, COUNT(*) AS total
    FROM    shipment s, orders o, link_orders__shipment los
    WHERE   s.shipment_status_id = $SHIPMENT_STATUS__PROCESSING
    AND     s.id = los.shipment_id
    AND     o.id = los.orders_id
    AND     s.id IN ( SELECT    shipment_id
                      FROM      shipment_item
                      WHERE shipment_id = s.id
                      GROUP BY shipment_id
                      HAVING MIN( shipment_item_status_id ) = ? )
    $exclude_nominated_day_not_due
    $premier_sql
    GROUP BY o.channel_id
    UNION ALL
    SELECT  st.channel_id AS channel_id, COUNT(*) AS total
    FROM    shipment s, stock_transfer st, link_stock_transfer__shipment lsts
    WHERE   s.shipment_status_id = $SHIPMENT_STATUS__PROCESSING
    AND     s.id = lsts.shipment_id
    AND     st.id = lsts.stock_transfer_id
    AND     s.id IN ( SELECT    shipment_id
                      FROM      shipment_item
                      WHERE shipment_id = s.id
                      GROUP BY shipment_id
                      HAVING MIN( shipment_item_status_id ) = ? )
    $premier_sql
    GROUP BY st.channel_id
) AS shipstatus
GROUP BY channel_id
SQL
;

    my $sth = $dbh->prepare($qry);
    $sth->execute( $shpmnt_status_id{$status}, $shpmnt_status_id{$status} );

    my %results;
    my $total   = 0;
    while ( my @row = $sth->fetchrow_array() ) {
        $total  += $row[1];
        $results{ $channels->{$row[0]}{config_section} }    = $row[1];
    }

    $results{ALL}   = $total;

    return \%results;
}


### Subroutine : airwaybill_status              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub airwaybill_status :Export {

    my ($dbh, $type, $channels) = @_;

    my $premier_sql     = "";
    if ($type eq 'premier') {
        $premier_sql    = " AND s.shipment_type_id = $SHIPMENT_TYPE__PREMIER";
    }

    my $qry  =<<SQL
SELECT  channel_id, SUM(total) AS total FROM (
    SELECT  o.channel_id AS channel_id, COUNT(s.id) AS total
    FROM    shipment s, orders o, link_orders__shipment los
    WHERE   s.shipment_status_id = 2
    AND     s.shipment_type_id != 2
    AND     s.id = los.shipment_id
    AND     o.id = los.orders_id
    AND     (s.outward_airway_bill = 'none' OR s.return_airway_bill = 'none')
    AND     s.id IN ( SELECT shipment_id FROM shipment_item WHERE shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKED )
    $premier_sql
    GROUP BY o.channel_id
    UNION ALL
    SELECT  st.channel_id AS channel_id, COUNT(s.id) AS total
    FROM    shipment s, stock_transfer st, link_stock_transfer__shipment lsts
    WHERE   s.shipment_status_id = 2
    AND     s.shipment_type_id != 2
    AND     s.id = lsts.shipment_id
    AND     st.id = lsts.stock_transfer_id
    AND     (s.outward_airway_bill = 'none' OR s.return_airway_bill = 'none')
    AND     s.id IN ( SELECT shipment_id FROM shipment_item WHERE shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKED )
    $premier_sql
    GROUP BY st.channel_id
) AS airwaystatus
GROUP BY channel_id
SQL
;


    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %results;
    my $total   = 0;
    while ( my @row = $sth->fetchrow_array() ) {
        $total  += $row[1];
        $results{ $channels->{$row[0]}{config_section} }    = $row[1];
    }

    $results{ALL}   = $total;

    return \%results;
}


### Subroutine : dispatch_status                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub dispatch_status :Export {

    my ($dbh, $type, $channels) = @_;

    my $premier_sql     = "";

    if ($type eq 'premier') {
        $premier_sql    = " AND shipment_type_id = $SHIPMENT_TYPE__PREMIER";
    }

    my $qry  =<<SQL
SELECT  channel_id, SUM(total) AS total FROM (
    SELECT  o.channel_id AS channel_id, COUNT(s.id) AS total
    FROM    shipment s, orders o, link_orders__shipment los
    WHERE   s.shipment_status_id = 2
    AND     s.shipment_type_id != 2
    AND     s.id = los.shipment_id
    AND     o.id = los.orders_id
    AND     (s.outward_airway_bill != 'none' OR s.return_airway_bill != 'none')
    AND     s.id IN ( SELECT shipment_id FROM shipment_item WHERE shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKED )
    $premier_sql
    GROUP BY o.channel_id
    UNION ALL
    SELECT  st.channel_id AS channel_id, COUNT(s.id) AS total
    FROM    shipment s, stock_transfer st, link_stock_transfer__shipment lsts
    WHERE   s.shipment_status_id = 2
    AND     s.shipment_type_id != 2
    AND     s.id = lsts.shipment_id
    AND     st.id = lsts.stock_transfer_id
    AND     (s.outward_airway_bill != 'none' OR s.return_airway_bill != 'none')
    AND     s.id IN ( SELECT shipment_id FROM shipment_item WHERE shipment_item_status_id = $SHIPMENT_ITEM_STATUS__PACKED )
    $premier_sql
    GROUP BY st.channel_id
) AS dispatchstatus
GROUP BY channel_id
SQL
;


    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %results;
    my $total   = 0;
    while ( my @row = $sth->fetchrow_array() ) {
        $total  += $row[1];
        $results{ $channels->{$row[0]}{config_section} }    = $row[1];
    }

    $results{ALL}   = $total;

    return \%results;
}


### Subroutine : order_total              ###
# usage        :                            #
# description  :                            #
# parameters   :                            #
# returns      :                            #

sub order_total :Export {

    my ( $dbh, $start_date, $end_date, $currency, $channels )   = @_;

    my $qry =<<QRY
SELECT  channel_id,
        COUNT(*),
        SUM(total_value)
FROM    orders
WHERE   date BETWEEN ? AND ?
AND     currency_id = ( SELECT id FROM currency WHERE currency = ? )
GROUP BY channel_id
QRY
;

    my $sth = $dbh->prepare($qry);
    $sth->execute($start_date, $end_date, $currency );

    my %order_count;
    my %total_value;

    my $total_count = 0;
    my $total_value = 0;

    while ( my @row = $sth->fetchrow_array() ) {
        $total_count    += $row[1];
        $total_value    += $row[2];

        $order_count{ $channels->{$row[0]}{config_section} }    = $row[1];
        $total_value{ $channels->{$row[0]}{config_section} }    = $row[2];
    }

    $order_count{ALL}   = $total_count;
    $total_value{ALL}   = $total_value;

    return \%order_count,\%total_value;
}

### Subroutine : ranged_order_total       ###
# usage        :                            #
# description  :                            #
# parameters   :                            #
# returns      :                            #

sub ranged_order_total :Export {

    my ( $dbh, $start_date, $end_date, $date_type, $channels )  = @_;

    my %truncate_date   = ( 'day'   => 'day',
                            'month' => 'month' );

    my $qry =<<QRY
SELECT  channel_id,
        COUNT(*) AS order_count,
        DATE_TRUNC( '$truncate_date{$date_type}', date ) AS date
FROM    orders
WHERE   date BETWEEN ? AND ?
GROUP BY    channel_id,
            DATE_TRUNC( '$truncate_date{$date_type}', date )
QRY
;
    my $sth = $dbh->prepare($qry);
    $sth->execute($start_date,$end_date);

    my %orders  = ();
    my $total   = 0;

    while( my $row = $sth->fetchrow_hashref() ) {

        my $chann_conf  = $channels->{ $row->{channel_id} }{config_section};

        $row->{date}    =~ s/20\d{2}-//xmsg;
        $row->{date}    =~ s/\s00:00:00//xmsg;

        $orders{ $row->{date} }{$chann_conf}    = $row->{order_count};

        if ( exists $orders{ $row->{date} }{'ALL'} ) {
            $orders{ $row->{date} }{'ALL'}      += $row->{order_count};
        }
        else {
            $orders{ $row->{date} }{'ALL'}      = $row->{order_count};
        }
    }

    return \%orders;
}


### Subroutine : dispatch_total              #
# usage        :                             #
# description  :                             #
# parameters   :                             #
# returns      :                             #

sub dispatch_total :Export {

    my ( $dbh, $start_date, $end_date, $channels )  = @_;

    my $qry =<<QRY
SELECT  o.channel_id,
        COUNT(*) AS total
FROM    shipment_status_log ssl,
        link_orders__shipment los,
        orders o
WHERE   ssl.shipment_status_id = 4
AND     ssl.date BETWEEN ? AND ?
AND     ssl.shipment_id = los.shipment_id
AND     o.id = los.orders_id
GROUP BY o.channel_id
QRY
;

    my $sth = $dbh->prepare($qry);
    $sth->execute( $start_date, $end_date );

    my %results;
    my $total   = 0;
    while ( my @row = $sth->fetchrow_array() ) {
        $total  += $row[1];
        $results{ $channels->{$row[0]}{config_section} }    = $row[1];
    }

    $results{ALL}   = $total;

    return \%results;
}




1; # Magic true value required at end of module
__END__

=head1 NAME

XTracker::Statistics::Collector - [One line description of module's purpose here]


=head1 VERSION

This document describes XTracker::Statistics::Collector version 0.0.1


=head1 SYNOPSIS

    use XTracker::Statistics::Collector;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.


=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.

XTracker::Statistics::Collector requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-xtracker-statistics-collecter@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Matthew Ryall  C<< <matt.ryall@net-a-porter.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Matthew Ryall C<< <matt.ryall@net-a-porter.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
