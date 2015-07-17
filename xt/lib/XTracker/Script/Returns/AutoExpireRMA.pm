package XTracker::Script::Returns::AutoExpireRMA;


use Moose;

extends 'XTracker::Script';
with map { "XTracker::Script::Feature::$_" } qw(
    SingleInstance
    Schema
    Logger
);
with 'XTracker::Role::WithAMQMessageFactory';

use XTracker::Config::Local qw( config_var local_timezone);
use XTracker::Database::Channel qw( get_channel );
use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw(
    :return_item_status
    :return_status
    :return_type
    :renumeration_class
    :renumeration_status
    :note_type
);
use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;
use XT::Domain::Returns;
use Carp;
use DateTime;
use DateTime::Format::DateParse;


has rma_expire_rs => (
    is          =>'rw',
    isa         => 'XTracker::Schema::ResultSet::Public::Return',
    lazy_build  => 1,
);

has auto_expiry_info => (
    is          => 'rw',
    isa         => 'HashRef',
    lazy_build  => 1,
);

has lowest_day => (
    is          => 'rw',
    isa         => 'Int',
    lazy_build  => 1,
);

# this is required by the role: 'Logger'
sub log4perl_category { return 'AutoExpireRMA'; }


sub invoke {
    my ($self, %args) = @_;

    my $dry_run =   $args{dryrun};
    $self->logger->info( "START:  Processing RMA's" . ( $dry_run ? " --- DRY RUN ---" : "" ) );

    # used to Cancel Returns/Return Items
    my $domain = XT::Domain::Returns->new(
                        schema => $self->schema,
                        msg_factory => $self->msg_factory,
                );

    my $operator_id = $args{operator_id} // $APPLICATION_OPERATOR_ID;

    my $rec_count   = 0;

    while( my $return  = $self->rma_expire_rs->next) {

        $self->logger->info("MAIN QUERY DONE, NOW PROCESSING")      if ( !$rec_count );

        my $active_item_count      = $return->return_items->not_cancelled->count();
        my @items                  = $return->return_items->search( { return_item_status_id => $RETURN_ITEM_STATUS__AWAITING_RETURN } )->all;
        my $items_to_cancel        = {};
        my $shipment_items         = {};
        my $skus                   = {};
        my $return_date            = $self->auto_expiry_info->{$return->get_column('channel_id')}->{'return_date'};
        my $exchange_date          = $self->auto_expiry_info->{$return->get_column('channel_id')}->{'exchange_date'};

        # We are doing below as we need DateTime object,get_column() stringifies the value.
        my $return_status_log_date = DateTime::Format::DateParse->parse_datetime( $return->get_column('rsl_date'), 'local' );

        my $flag  = 0;

        foreach my $item ( @items ) {
            my $item_date = $item->is_exchange ? $exchange_date : $return_date;
            # DateTime->compare works the same as '<=>'
            my $cmp       = DateTime->compare( $return_status_log_date, $item_date );

            if($cmp <= 0  ){
                $items_to_cancel->{$item->id} = $item;
                push(@ {$shipment_items->{$return->id}}, $item->shipment_item_id);
                push(@ {$skus->{$return->id}} , $item->shipment_item->get_sku);
                $flag = 1;
            }
        }#end_foreach

        if( $flag ) {
            my $stock_manager = $return->shipment->get_channel->stock_manager;

            # Remember whether IWS knows about shipment now, before we start cancelling shipment items
            my $exchange_shipment = $return->exchange_shipment;
            my $iws_knows = $exchange_shipment && $exchange_shipment->does_iws_know_about_me();

            eval {
                $self->schema->txn_do( sub {
                    my $notes;
                    if( scalar(keys %$items_to_cancel) == $active_item_count ) {
                        #delete return
                        $self->logger->debug( "'Cancel' For Return =" .$return->id."/". $return->rma_number ." return item ids to cancel:". join(',', @{[keys %$items_to_cancel]}) );

                        $domain->cancel({
                               return_id => $return->id,
                               shipment_id => $return->shipment_id,
                               operator_id => $operator_id,
                               send_default_email => 0,
                                stock_manager => $stock_manager,
                         });

                        # add notes
                        $notes = "RMA expired and automatically closed by system.";
                    } else {

                        $self->logger->debug( "'Manual' For Return =" .$return->id."/". $return->rma_number ." return item ids to cancel:". join(',', @{[keys %$items_to_cancel]}) );
                        #remove_items
                        $domain->manual_alteration({
                            return_id => $return->id,
                            shipment_id => $return->shipment_id,
                            operator_id => $operator_id,
                            return_items => { map { $_ => { remove => 1 } } keys(%$items_to_cancel) },
                            send_default_email => 0,
                            stock_manager => $stock_manager,
                        });

                        # remove invoice as well, by finding all Pending Invoices for the Return Items we've cancelled
                        my $invoice_rs = $self->schema->resultset('Public::Renumeration')
                                                           ->search(
                                                                { 'me.renumeration_class_id'            => $RENUMERATION_CLASS__RETURN ,
                                                                  'me.renumeration_status_id'           => $RENUMERATION_STATUS__PENDING,
                                                                  'renumeration_items.shipment_item_id' => {
                                                                                     '-in'    => $shipment_items->{$return->id},
                                                                   },
                                                                  'link_return_renumeration.return_id'  => $return->id,
                                                                  'link_return_renumeration.renumeration_id' => { -ident => 'renumeration_items.renumeration_id'},
                                                                },
                                                                { join  => [ 'renumeration_items',  'link_return_renumeration' ],
                                                                  '+select' => ['renumeration_items.shipment_item_id'],
                                                                  '+as'     => ['shipment_item_id'],

                                                                  distinct => 1,
                                                                }
                                                );

                        my $final_hash = ();
                        while( my $invoice  = $invoice_rs->next ) {

                            #building a hash as follows
                            # '142323' <invoice_id> => {
                            #                           'invoice' => <invoice_obj>,
                            #                           'ret_items => [ <ret_item_obj>, <$ret_item_obj>,...]
                            #                           }
                            # .......
                            $final_hash->{$invoice->id}->{'invoice'} = $invoice;

                            #grep all the return_items who have same shipment_item_id as invoice
                            my @values = grep { $_->shipment_item_id == $invoice->get_column('shipment_item_id') } values( %{$items_to_cancel} );
                            push @{$final_hash->{$invoice->id}->{'ret_item'}}, @values;
                        }

                        # foreach invoice found above, cancel it
                        foreach my $value ( keys %$final_hash) {
                            $final_hash->{$value}->{'invoice'}->remove_return_items_and_cancel( $final_hash->{$value}->{'ret_item'}, $operator_id );
                        }

                        # add notes
                        my $plural  = ( scalar( @{$skus->{$return->id}} ) > 1 ? 's' : '' );
                        $notes = "Returning Item${plural} ".join(', ',@{$skus->{$return->id}})." " . ( $plural ? 'have' : 'has' ) . " been automatically cancelled by the system.";

                   }
                    #  update return_notes
                    $return->create_related( 'return_notes', {
                            operator_id   => $operator_id,
                            note_type_id  => $NOTE_TYPE__RETURNS,
                            date          => \"current_timestamp",
                            note          => $notes,
                    } );

                    if ( $dry_run ) {
                        $stock_manager->rollback;
                        $self->schema->txn_rollback;
                    }
                    else {
                        $stock_manager->commit;
                    }
                } );
                $rec_count++;       # only count successful Returns processed
            }; #end of eval
            if ( my $err = $@ ) {
                $stock_manager->rollback;
                $self->logger->error( "Return: " . $return->id . "/" . $return->rma_number . ", Created: " . $return->creation_date . ":\n" . $err );
            }
            else {
                $domain->send_msgs_for_exchange_items( $exchange_shipment ) if $iws_knows;
            }
        }
    }
    $self->logger->info( "END:  Processing RMA's script is complete, Returns Processed: $rec_count" );

    return;
}


sub _build_auto_expiry_info {
    my $self = shift;

    my $expiry_info = ();
    my $auto_expiry_day;

    #get all channels
    my @channels= $self->schema->resultset('Public::Channel')->search->all;

    foreach my $channel ( @channels ) {

        my $config_section  = $channel->business->config_section;

        # get auto_expire days for return and exchange from config
        my $return_days            = config_var('Returns_'.$config_section, 'auto_expire_return_days');
        my $exchange_days          = config_var('Returns_'.$config_section, 'auto_expire_exchange_days');

        # populate hash
        $expiry_info->{$channel->id}->{'return_days'}    = $return_days;
        $expiry_info->{$channel->id}->{'exchange_days'}  = $exchange_days;
        $expiry_info->{$channel->id}->{'return_date'}    = DateTime->now(time_zone => "local")->subtract( days => $return_days );
        $expiry_info->{$channel->id}->{'exchange_date'}  = DateTime->now(time_zone => "local")->subtract( days => $exchange_days );

        my $day = $return_days < $exchange_days ? $return_days : $exchange_days;

        #find the lowest day of all
        if (!(defined $auto_expiry_day) || $auto_expiry_day > $day) {
            $auto_expiry_day = $day;
        }
    }

    $self->lowest_day($auto_expiry_day);

    return $expiry_info;
}

sub _build_rma_expire_rs {
    my $self = shift;

    # get the lowest day to search on
    my $no_of_days = $self->lowest_day;

    $self->logger->debug("Lowest Day Used for main Query: $no_of_days");

    # build the subquery
    my $return_item_rs = $self->schema->resultset('Public::ReturnItem')
                                         ->search(
                                            { return_item_status_id =>  $RETURN_ITEM_STATUS__AWAITING_RETURN },
                                            { alias => 'subquery_return_item' }
                                         );
    # need this because Some Return's have the Same Status Logged more than Once
    # this should gives us the most recent which should have the latest Date
    my $return_status_log_rs    = $self->schema->resultset('Public::ReturnStatusLog')
                                        ->search(
                                            { },
                                            {
                                                alias => 'subquery_return_status_log',
                                                select => 'MAX(subquery_return_status_log.id)',
                                                as => 'id',
                                            }
                                        );

    my $return_rs = $self->schema->resultset('Public::Return')
                                   ->search(
                                       {
                                         'return_status_logs.date'  => {
                                                 '<='  => \"current_timestamp - INTERVAL \'$no_of_days\' DAY",
                                                },
                                         'me.return_status_id'      => { -ident => 'return_status_logs.return_status_id'},
                                         'me.id'                    => {
                                              '-in'    => $return_item_rs->search->get_column('return_id')->as_query,
                                               },
                                         'link_orders__shipment.orders_id' => { '!=' => undef },
                                         'return_status_logs.id' => {
                                                '=' => $return_status_log_rs->search(
                                                                    {
                                                                        'subquery_return_status_log.return_id' => { '=' => { -ident => 'me.id' } },
                                                                        'subquery_return_status_log.return_status_id' => { '=' => { -ident => 'me.return_status_id' } },
                                                                    },
                                                                )->get_column('id')->as_query,
                                            },
                                      },
                                      { join  => [ 'return_status_logs', { 'shipment' => {'link_orders__shipment' => 'orders'} }, ],
                                        '+select' => ['return_status_logs.date','orders.channel_id'],
                                        '+as'     => ['rsl_date','channel_id'],
                                      }
                                    );

    # Following SQL is produced  from above step
    #    SELECT me.*, return_status_logs.date, orders.channel_id
    #    FROM return me
    #        LEFT JOIN return_status_log return_status_logs ON return_status_logs.return_id = me.id
    #        JOIN shipment shipment ON shipment.id = me.shipment_id
    #        LEFT JOIN link_orders__shipment link_orders__shipment ON link_orders__shipment.shipment_id = shipment.id
    #        LEFT JOIN orders orders ON orders.id = link_orders__shipment.orders_id
    #    WHERE ( ( link_orders__shipment.orders_id IS NOT NULL
    #    AND me.id IN (
    #            SELECT subquery_return_item.return_id
    #            FROM return_item subquery_return_item
    #            WHERE ( return_item_status_id = 1 )
    #        )
    #    AND me.return_status_id = return_status_logs.return_status_id
    #    AND return_status_logs.date <= current_timestamp - INTERVAL '45' DAY
    #    AND return_status_logs.id = (
    #            SELECT MAX(subquery_return_status_log.id)
    #            FROM return_status_log subquery_return_status_log
    #            WHERE ( ( subquery_return_status_log.return_id = me.id
    #            AND subquery_return_status_log.return_status_id = me.return_status_id ) )
    #        )
    #    ))

    return $return_rs;
}

sub _build_lowest_day {
    my $self    = shift;

    # required to find the lowest day
    $self->auto_expiry_info;

    return $self->lowest_day;
}

1;
