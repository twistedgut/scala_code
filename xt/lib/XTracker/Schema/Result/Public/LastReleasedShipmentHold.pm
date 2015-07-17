package XTracker::Schema::Result::Public::LastReleasedShipmentHold;
use NAP::policy;

use base qw/DBIx::Class::Core/;

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table('last_released_shipment_hold');
__PACKAGE__->result_source_instance->is_virtual(1);
__PACKAGE__->result_source_instance->view_definition(
<<EOQ
SELECT me.release_date, me.held_long_enough, allow_new_sla_on_release
    FROM (
        SELECT
            ssl.date,
            ss.status,
            (CASE WHEN (ssl.date + ? * INTERVAL '1 MINUTE') <= (LEAD(ssl.date,1) OVER (ORDER BY ssl.date)) THEN TRUE ELSE FALSE END) AS held_long_enough,
            LEAD(ssl.date,1) OVER(ORDER BY ssl.date) as release_date,
            shr.allow_new_sla_on_release,
            ssl.shipment_status_id
    FROM shipment_status_log ssl
        JOIN shipment_status ss ON ssl.shipment_status_id=ss.id
        LEFT JOIN shipment_hold_log shl ON ssl.id=shl.shipment_status_log_id
        LEFT JOIN shipment_hold_reason shr ON shl.shipment_hold_reason_id = shr.id
        WHERE ssl.shipment_id = ? order by date DESC
    ) me
WHERE me.shipment_status_id = (SELECT id FROM shipment_status WHERE status = 'Hold')
AND me.release_date IS NOT NULL
EOQ
);

__PACKAGE__->add_columns(
  'release_date' => {
    data_type => 'timestamp with time zone',
  },
  'held_long_enough' => {
    data_type => 'boolean',
  },
  'allow_new_sla_on_release' => {
    data_type => 'boolean',
  },
);
