package XTracker::Database::Row::CreditCheckOrder;
use NAP::policy "tt";
use parent 'XTracker::Database::Row';

use DateTime::Format::Pg;
use Carp;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB     qw( :order_status );

sub query_sql { "
-- Package: XTracker::Database::Row::CreditCheckOrder
--
-- For the Finance->Credit Check page
--
SELECT  o.id,
        o.order_nr,
        TO_CHAR(o.date, 'DD-MM-YYYY  HH24:MI') AS date,
        AGE(DATE_TRUNC('day',o.date)) AS age,
        o.total_value,
        c.currency,
        cust.first_name,
        cust.last_name,
        s.shipment_type_id,
        s.gift,
        s.nominated_dispatch_time as nominated_dispatch_time,
        s.nominated_earliest_selection_time
            as nominated_earliest_selection_time,
        ch.name AS sales_channel,
        ch.timezone,
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
        custattr.language_preference_id,
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
            LEFT JOIN customer_attribute custattr  ON custattr.customer_id = cust.id
WHERE   o.order_status_id = $ORDER_STATUS__CREDIT_CHECK
" }

#TODO: Should really be shipments with shipment_status is earlier
#than "dispatched"


sub inflated_columns {
    return {
        nominated_dispatch_time           => "DateTime",
        nominated_earliest_selection_time => "DateTime",
    };
}

=head2 nominated_credit_check_urgency : 0 | 1

The urgency indicates that it's closing in on the Selection
Time. Currently the values are:

  0: Not urgent
  1: Urgent (within 4h of Selection)

It is possible we might want this in the future:

  2: Very urgent (past selection)

=cut

sub nominated_credit_check_urgency {
    my $self = shift;
    $self->{nominated_earliest_selection_time} or return 0;

    my $urgency_window_minutes = config_var(
        "NominatedDay",
        "credit_check_urgency_window_before_selection_time__minutes",
    );

    my $urgency_start_time = DateTime->now->add(
        minutes => $urgency_window_minutes,
    );

    return ( $self->{nominated_earliest_selection_time}->epoch <= $urgency_start_time->epoch ) + 0;
}
