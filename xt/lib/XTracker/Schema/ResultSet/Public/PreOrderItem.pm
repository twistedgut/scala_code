package XTracker::Schema::ResultSet::Public::PreOrderItem;
# vim: ts=4 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use XTracker::Constants::FromDB         qw( :pre_order_item_status );

use Moose;
with 'XTracker::Schema::Role::ResultSet::Orderable' => {
         order_by => { id => 'id' }
     },

     'XTracker::Schema::Role::ResultSet::Summable' => {
         sums => {
             total_value          => [ qw( unit_price tax duty ) ],
             total_original_value => [ qw(
                original_unit_price
                original_tax
                original_duty
             ) ],
         }
     },

     'XTracker::Schema::Role::ResultSet::WithStatus' => {
         column => 'pre_order_item_status_id',
         statuses => {
                     selected => $PRE_ORDER_ITEM_STATUS__SELECTED,
                    confirmed => $PRE_ORDER_ITEM_STATUS__CONFIRMED,
                    complete  => $PRE_ORDER_ITEM_STATUS__COMPLETE,
                    cancelled => $PRE_ORDER_ITEM_STATUS__CANCELLED,
                     exported => $PRE_ORDER_ITEM_STATUS__EXPORTED,
             payment_declined => $PRE_ORDER_ITEM_STATUS__PAYMENT_DECLINED,
         },
         update_with => 'update_status'
     };

=head2 available_to_cancel

    $result_set = $self->available_to_cancel;

This will return a Result Set for Pre-Order Items that can be Cancelled.

Oddly enough, these are also the items that can have their tax rate adjusted.

=cut

sub available_to_cancel {
    my $self    = shift;

    return $self->search(
                    {
                        pre_order_item_status_id => {
                                                        'NOT IN' => [
                                                                $PRE_ORDER_ITEM_STATUS__CANCELLED,
                                                                $PRE_ORDER_ITEM_STATUS__EXPORTED,
                                                            ],
                                                    },
                    }
                );
}

=head2 not_notifiable

This will return a Result Set for Pre-Order Items that cannot be
notified to the web app.

=cut

sub not_notifiable {
    return shift->search( {
        pre_order_item_status_id => {
            IN => [
                    $PRE_ORDER_ITEM_STATUS__SELECTED,
                    $PRE_ORDER_ITEM_STATUS__CONFIRMED,
                    $PRE_ORDER_ITEM_STATUS__PAYMENT_DECLINED,
            ]
        }
    } );
}

sub are_all_confirmable {
    my $self = shift;

    foreach my $item ($self->all) {
        unless ( $item->is_confirmable ) {
            return 0;
        }
    }

    return 1;
}

=head2 status_log_for_summary_page

    $array_ref  = $self->status_log_for_summary_page();

Returns an Array Ref of Hash Ref's for to be displayed on the Pre-Order Summary page.

=cut

sub status_log_for_summary_page {
    my $self    = shift;

    my @list;
    my @logs    = $self->search_related('pre_order_item_status_logs')
                            ->search( undef,
                                {
                                    order_by    => [ qw(
                                                        pre_order_item_status_logs.date
                                                        pre_order_item_status_logs.pre_order_item_id
                                                        pre_order_item_status_logs.id
                                                    ) ],
                                    alias       => 'pre_order_item_status_logs',
                                }
                            )->all;

    foreach my $log ( @logs ) {
        my $list    = {
                log_id          => $log->id,
                item_obj        => $log->pre_order_item,
                status_date     => $log->date->strftime("%F @ %H:%M:%S"),
                status          => $log->pre_order_item_status->status,
                operator_name   => $log->operator->name,
                department      => $log->operator->department->department,
            };
        push @list, $list;
    }

    return \@list;
}

=head2 order_by_sku

Will order by product_id and size_id

=cut

sub order_by_sku {
    my $self = shift;

    return $self->search( {},
        { join     => 'variant',
          order_by => 'variant.product_id, variant.size_id, me.id',
        }
    );

}

=head2 all_are_exported

Will return positively if all PreOrderItems in the Result Set have a status
of 'Exported'

=cut

sub all_are_exported {
    my $self = shift;

    # flag to indicate if any records have
    # been processed as if there hasn't been
    # then this method should return FALSE
    my $any_recs_processed = 0;

    foreach my $item ( $self->all ) {
        $any_recs_processed = 1;
        unless ( $item->is_exported ) {
            return 0;
        }
    }

    return $any_recs_processed;
}

=head2 some_are_exported

Will return positively if at least one PreOrderItem in the Result Set has a
status of 'Exported'

=cut

sub some_are_exported {
    my $self = shift;

    foreach my $item ($self->all) {
        if ( $item->is_exported ) {
            return 1;
        }
    }

    return 0;
}


sub get_consolidated_items_for_display {
    my $self = shift;

    my $grp_by_variant =  $self->search( {},
        {
          select    => [ 'pre_order_id','variant_id','pre_order_item_status_id',{ count => 'variant_id', -as => 'count' }],
          group_by  => ['variant_id', 'pre_order_item_status_id','pre_order_id','variant.product_id','variant.size_id'],
          join      => ['variant'],
          order_by  => ['variant.product_id','variant.size_id']

        }
    );

    return [ $grp_by_variant->all ];
}

1;
