package XT::Order::Role::Parser::IntegrationServiceJSON::OrderDataMapping;
use NAP::policy "tt", 'role';

sub _order_data_key_mapping {
    # originally copied from the mapping used by JimmyChoo
    # some may be surplus to requirement
    # the only change I made was customer_ip --> cust_ip
    return {
        'o_id'                  => 'order_nr',
          'cust_id'             => 'customer_nr',
          'channel'             => 'channel',
          'customer_ip'         => 'ip_address',
          'placed_by'           => 'placed_by',
          'order_date'          => 'order_date',
          'shipping_method'     => 'shipping_sku',
          'source_app_name'     => 'source_app_name',
          'source_app_version'  => 'source_app_version',
          'language'            => 'language_preference',
    };
}
