package XTracker::Script::Shipment::CheckSLA;

use Moose;

extends 'XTracker::Script';
with map { "XTracker::Script::Feature::$_" } qw(
    SingleInstance
    Schema
    Template
    Logger
);
with 'XTracker::Role::WithAMQMessageFactory';

use XTracker::Config::Local qw(
    config_var
    comp_contact_hours
    customercare_email
);
use XTracker::EmailFunctions qw( get_and_parse_correspondence_template send_customer_email );
use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw(
    :channel
    :business
    :customer_category
    :shipment_type
    :shipment_item_status
    :shipment_status
    :shipping_charge_class
    :shipment_hold_reason
    :note_type
    :correspondence_templates
);
use XTracker::Database::Shipment qw(
    get_shipment_shipping_account
    update_shipment_shipping_charge_id
    set_shipment_shipping_account
    get_address_shipping_charges
);


has breached_sla_rs => (
    is          =>'rw',
    isa         => 'XTracker::Schema::ResultSet::Public::Shipment',
    lazy_build  => 1,
);

# this is required by the role: 'Logger'
sub log4perl_category { return 'CheckSLA'; }


sub invoke {
    ## no critic(ProhibitDeepNests)
    my ($self, %args) = @_;

    my $operator_id = $args{operator_id} // $APPLICATION_OPERATOR_ID;

    my $dry_run        = $args{dryrun};
    my $cutoff         = 0; # number of seconds left at which sla is breached

    $self->logger->info( "START:  Starting CheckSLA script" . ( $dry_run ? " --- DRY RUN ---" : "" ) );


    my $correspondence_template = $self->schema->resultset('Public::CorrespondenceTemplate');

    #populate channel hash
    my $channel_hash = {};
    my @channels = $self->schema->resultset('Public::Channel')->all;
    foreach my $channel ( @channels ) {
       $channel_hash->{$channel->id}->{'business'} =  $channel->business->id;
       $channel_hash->{$channel->id}->{'channel'} =  $channel;
    }

    #populate shipping_charge_class hash
    my $upgrade_class = {};
    my @shipping_charge_class =$self->schema->resultset('Public::ShippingChargeClass')->all;
    foreach my $class ( @shipping_charge_class ) {
        $upgrade_class->{$class->id}{'upgrade'} = $class->upgrade;
    }

    # Main Query - get list of breached SLA shipment as per the conditions specified in query.
    my $shipment_rs = $self->breached_sla_rs;

    my $rec_count = 0;

    $self->logger->info("QUERY DONE, NOW PROCESSING");

    while ( my $shipment = $shipment_rs->next ) {

        my $time_left          = int($shipment->get_column('cutoff_epoch') || 0 );
        my $customer_category  = $shipment->order->customer->category_id;
        my $channel_id         = $shipment->get_column('channel_id');
        my $channel            = $channel_hash->{ $channel_id }->{'channel'};

        if( $time_left < $cutoff &&
            $shipment->shipment_type_id != $SHIPMENT_TYPE__PREMIER &&
            $customer_category != $CUSTOMER_CATEGORY__STAFF &&
            $channel_hash->{ $channel_id }->{'business'}  != $BUSINESS__JC
          ){
            # get shipping options available
            my %shipping_charges    = get_address_shipping_charges(
                $self->dbh,
                $channel_id,
                {
                    country => $shipment->get_column('country'),
                    state   => $shipment->get_column('county'),
                    postcode=> $shipment->get_column('postcode'),
                },
                {
                    exclude_nominated_day   => 1,
                    customer_facing_only    => 1,
                    exclude_for_shipping_attributes => $shipment->get_item_shipping_attributes,
                },
            );

            my $shipping_charge_class_id = $shipment->get_column('shipping_charge_class');

            if($upgrade_class->{$shipping_charge_class_id}->{'upgrade'} ) {

                my %shipment_items;
                for my $item ($shipment->shipment_items->all ) {
                    $shipment_items{ $item->id}{'product_id'} = $item->get_product_id;
                }

                if (!$shipment->can_upgrade_shipment_class) {
                    $shipment->create_related('shipment_notes', {
                        operator_id => $operator_id,
                        note_type_id=> $NOTE_TYPE__SHIPPING,
                        date        => \"now()",
                        note        => "Dispatch SLA Breach: Shipment breached SLA but system unable to upgrade due to restrictions"
                    });
                    next;
                }

                eval {
                    $self->schema->txn_do( sub {

                      CHARGES:
                      foreach my $charge_id (keys %shipping_charges ) {
                        # shipping charge changed?
                        if($shipping_charges{$charge_id}{class_id} == $upgrade_class->{$shipping_charge_class_id}->{'upgrade'} ) {

                            #shipping charge_class before upgrading for logging purpose
                            my $old_charge_class = $shipment->shipping_charge_table->description;

                            # store for logging purposes
                            my $old_charge_id   = $shipment->shipping_charge_id;
                            my $old_account_id  = $shipment->shipping_account_id;

                            #update shipment shipping_charge_id
                            update_shipment_shipping_charge_id( $self->dbh, $shipment->id, $shipping_charges{$charge_id}{id} );

                            #have we switched between shipping accounts?
                            my $shipping_account_id = get_shipment_shipping_account(
                                $self->dbh,
                                {
                                    channel_id          => $channel_id,
                                    shipment_type_id    => $shipment->shipment_type_id,
                                    country             => $shipment->get_column('country'),
                                    postcode            => $shipment->get_column('postcode'),
                                    item_data           => \%shipment_items,
                                    shipping_class      => $shipping_charges{$charge_id}{class},
                                }
                            );

                            #update shipping_account
                            if ( $shipping_account_id != $shipment->shipping_account_id ) {
                               set_shipment_shipping_account( $self->dbh, $shipment->id, $shipping_account_id );
                            }
                            $shipment->discard_changes;

                            # create a change log for the shipment
                            $self->_create_change_log( $shipment, {
                                                        old_charge_id   => $old_charge_id,
                                                        old_account_id  => $old_account_id,
                                                        new_charge_id   => $shipping_charges{$charge_id}{id},
                                                        new_account_id  => $shipping_account_id,
                                                    } );

                            #TODO update shipment_note
                            $shipment->create_related( 'shipment_notes', {
                                                                    operator_id => $operator_id,
                                                                    note_type_id=> $NOTE_TYPE__SHIPPING,
                                                                    date        => \"now()",
                                                                    note        => "Dispatch SLA Breach: Shipment breached SLA so it was upgraded to speedup the delivery as a complimentary gesture.",
                                                                } );

                            #send email and return the email template
                            my $template = $self->_send_email($shipment, $correspondence_template, $dry_run);
                            #TODO update shipment_email_log
                            $shipment->log_correspondence( $template->id, $operator_id )     if ( $template );

                            $self->logger->info("upgraded Shipment ID/ " .$shipment->id. " From $old_charge_class To ".$shipping_charges{$charge_id}{description} ."\n");

                            # shipping_charge_class table should have one record per country
                            # but database has some bad data for norway, switzerland and jersey (might be for more countries)
                            # considering first record and ignoring other
                            last CHARGES;
                        }
                     }
                     $self->schema->txn_rollback        if $dry_run;
                } );
                $rec_count++;       # only count successful processed records
            }; #end of eval
            if ( my $err = $@ ) {
                $self->logger->error( "checkSLA script - error for shipment - ". $shipment->id."\n". $err );
           }

        }; #else { print " no upgrade avilable \n"; }

      } #end of IF block

    }#end of while

    $self->logger->info( "END:  CheckSLA script is complete, Dispatch breached SLA Processed: $rec_count" );
    return;
}


sub _build_breached_sla_rs {
    my $self = shift;

    my $sub_query = $self->schema->resultset('Public::ShipmentItem')
                                         ->search(
                                            { shipment_item_status_id => {
                                                 '-in' =>  [ $SHIPMENT_ITEM_STATUS__NEW,
                                                             $SHIPMENT_ITEM_STATUS__SELECTED,
                                                             $SHIPMENT_ITEM_STATUS__PICKED,
                                                             $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                                                            ]}
                                            },
                                            { alias => 'subquery_shipment_item' }
                                         );


    my $delayed_shipment_rs = $self->schema->resultset('Public::Shipment')
                                            ->search(
                                                {
                                                    'link_orders__shipments.shipment_id' => { '!=' => undef },
                                                    'me.shipment_status_id' => { '-in' => [ $SHIPMENT_STATUS__PROCESSING, $SHIPMENT_STATUS__HOLD ] },
                                                    'me.id'                => { '-in' => $sub_query->search(
                                                                                                        { 'subquery_shipment_item.shipment_id' => { -ident => 'me.id' } },
                                                                                                    )->get_column('shipment_id')->as_query },
                                                    'shipping_charge_class.id' => { '-in' => [ $SHIPPING_CHARGE_CLASS__GROUND, $SHIPPING_CHARGE_CLASS__AIR] },
                                                    'shipment_holds.shipment_hold_reason_id' => [ {'-not_in' => [$SHIPMENT_HOLD_REASON__CUSTOMER_ON_HOLIDAY,
                                                                                            $SHIPMENT_HOLD_REASON__CUSTOMER_REQUEST,
                                                                                            $SHIPMENT_HOLD_REASON__INCOMPLETE_ADDRESS,
                                                                                            $SHIPMENT_HOLD_REASON__ORDER_PLACED_ON_INCORRECT_WEBSITE,
                                                                                            $SHIPMENT_HOLD_REASON__PREPAID_ORDER,
                                                                                            $SHIPMENT_HOLD_REASON__UNABLE_TO_MAKE_CONTACT_TO_ORGANISE_A_DELIVERY_TIME,
                                                                                            $SHIPMENT_HOLD_REASON__ACCEPTANCE_OF_CHARGES,
                                                                                            $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS,
                                                                                           ]
                                                                                 },
                                                                                {
                                                                                    '=' => undef,
                                                                                },
                                                                                ],
                                                },
                                                { join  => [
                                                             {'shipping_charge_table' => 'shipping_charge_class'},
                                                             {'link_orders__shipments' => { 'orders' =>'channel' }},
                                                             'shipment_address',
                                                             'shipping_account',
                                                             'shipment_holds',
                                                          ],
                                                    '+select' => [
                                                                  { to_char => 'me.date, \'DD-MM-YYYY HH24:MI\''},
                                                                  'shipment_address.country',
                                                                  'shipment_address.county',
                                                                  'shipment_address.postcode',
                                                                  'shipment_address.id',
                                                                  'channel.id',
                                                                  'channel.name',
                                                                  'shipping_charge_class.id',
                                                                  { 'to_char'    => 'me.date, \'YYYYMMDDHH24MI\''},
                                                                  { "date_trunc" => "'second', (me.sla_cutoff - current_timestamp)" },
                                                                  { "extract"    => "epoch from (me.sla_cutoff - current_timestamp)" },
                                                                 ],
                                                    '+as'     => [
                                                                  'date',
                                                                  'country',
                                                                  'county',
                                                                  'postcode',
                                                                  'orders_id',
                                                                  'channel_id',
                                                                  'sales_channel',
                                                                  'shipping_charge_class',
                                                                  'datesort',
                                                                  'cutoff',
                                                                  'cutoff_epoch'
                                                                 ],
                                                }

                                            );

        # Following SQL is produced  from above step
         # SELECT me.*,
         # TO_CHAR( me.date, 'DD-MM-YYYY HH24:MI' ),
         # shipment_address.country,
         # shipment_address.id,
         # channel.id,
         # channel.name,
         # shipping_charge_class.class,
         # TO_CHAR( me.date, 'YYYYMMDDHH24MI' ),
         # DATE_TRUNC( 'second', (me.sla_cutoff - current_timestamp) ),
         # EXTRACT( epoch from (me.sla_cutoff - current_timestamp) )
         #
         # FROM shipment me
         # JOIN public.shipping_charge shipping_charge_table ON shipping_charge_table.id = me.shipping_charge_id
         # JOIN public.shipping_charge_class shipping_charge_class ON shipping_charge_class.id = shipping_charge_table.class_id
         # LEFT JOIN link_orders__shipment link_orders__shipments ON link_orders__shipments.shipment_id = me.id
         # LEFT JOIN orders orders ON orders.id = link_orders__shipments.orders_id
         # LEFT JOIN channel channel ON channel.id = orders.channel_id
         # JOIN order_address shipment_address ON shipment_address.id = me.shipment_address_id
         # JOIN shipping_account shipping_account ON shipping_account.id = me.shipping_account_id
         # LEFT JOIN shipment_hold shipment_holds ON shipment_holds.shipment_id = me.id
         # WHERE ( (
         #
         # link_orders__shipments.shipment_id IS NOT NULL
         # AND me.id IN (
         #        SELECT subquery_shipment_item.shipment_id
         #        FROM shipment_item subquery_shipment_item
         #        WHERE ( ( subquery_shipment_item.shipment_id = me.id
         #             AND shipment_item_status_id IN ( 1,2,3,13 ) ) ) )
         # AND me.shipment_status_id IN ( 2,3 )
         # AND ( shipment_holds.shipment_hold_reason_id NOT IN ( 4,5,6,12,10,8,2) OR shipment_holds.shipment_hold_reason_id IS NULL )
         # AND shipping_charge_class.id IN ( 2,3 ) ) )
         #

    return $delayed_shipment_rs;
}

sub _send_email {
    my $self        = shift;
    my $shipment    = shift;
    my $correspondence_template  = shift;
    my $dry_run     = shift;

    my $b_name          = $shipment->get_channel->business->config_section;
    my $email           = $shipment->email;
    my $subject         = $b_name. " order update - ".$shipment->order->order_nr;
    my $template_name   = "Dispatch-SLA-Breach-$b_name";
    my $salutation      = $shipment->branded_salutation;

    my $template        =   $correspondence_template->find({ name => $template_name, department_id => undef });

    my $success = 0;
    my $email_data = {
        branded_salutation => $salutation,
        contact_hours      => comp_contact_hours( $b_name ),
        customercare_email => customercare_email ( $b_name ),
        order_number       => $shipment->order->order_nr,
        brand_name         => $b_name
    };

    my $email_info = get_and_parse_correspondence_template( $self->schema, $template->id, {
        channel     => $shipment->order->channel,
        data        => $email_data,
        base_rec    => $shipment,
    } );

    my $from_email  = customercare_email( $b_name, {
            schema  => $self->schema,
            locale  => $shipment->order->customer->locale,
    } );
    if( $email_info ) {

        eval {
            $success = send_customer_email( {
                to           => $email,
                from         => $from_email,
                reply_to     => $from_email,
                subject      => $email_info->{subject},
                content      => $email_info->{content},
                content_type => $email_info->{content_type}
            } ) unless $dry_run;

        };
        if ( my $err = $@ ) {
            $self->logger->error( "Check SLA script failed to send email due to error for shipment - ".$shipment->id. " - ". $err );
        }

    }

    return ( $success ? $template : undef );
}

sub _create_change_log {
    my ( $self, $shipment, $args )  = @_;

    my $qry =<<SQL
INSERT INTO shipment_shipping_charge_change_log (
                                                 shipment_id,
                                                 old_shipping_charge_id,
                                                 old_shipping_account_id,
                                                 new_shipping_charge_id,
                                                 new_shipping_account_id,
                                                 operator_id
                                             ) VALUES ( ?, ?, ?, ?, ?, ? );
SQL
;
    my $ins_qry = $self->dbh->prepare( $qry );
    $ins_qry->execute(
                    $shipment->id,
                    $args->{old_charge_id},
                    $args->{old_account_id},
                    $args->{new_charge_id},
                    $args->{new_account_id},
                    $APPLICATION_OPERATOR_ID,
                );
}

__PACKAGE__->meta->make_immutable;

1;
