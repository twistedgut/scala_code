package XTracker::Schema::ResultSet::Public::PreOrderRefund;
# vim: ts=4 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use XTracker::Constants::FromDB qw( :pre_order_refund_status );

use Moose;
with 'XTracker::Schema::Role::ResultSet::Orderable' => {
         order_by => { id   => 'id',
                       date => 'date'
                     }
     },

     'XTracker::Schema::Role::ResultSet::WithStatus' => {
         column => 'pre_order_refund_status_id',
         statuses => {
                failed => $PRE_ORDER_REFUND_STATUS__FAILED,
               pending => $PRE_ORDER_REFUND_STATUS__PENDING,
             cancelled => $PRE_ORDER_REFUND_STATUS__CANCELLED,
              complete => $PRE_ORDER_REFUND_STATUS__COMPLETE,
         }
     };

=head2 list_for_summary_page

    $array_ref  = $self->list_for_summary_page();

Returns an Array Ref of Hash Ref's for to be displayed on the Pre-Order Summary page.

=cut

sub list_for_summary_page {
    my $self    = shift;

    my @list;
    my @refunds = $self->search( undef, { order_by => 'id' } );

    foreach my $refund ( @refunds ) {
        # First Status Log must be for when Refund was Created
        my $created_log = $refund->pre_order_refund_status_logs->search( undef, { order_by => 'date,id' } )->first;
        # current Status Log
        my $status_log  = $refund->pre_order_refund_status_logs
                                    ->search(
                                        {
                                            pre_order_refund_status_id  => $refund->pre_order_refund_status_id,
                                        },
                                        {
                                            order_by    => 'date DESC',
                                            rows        => 1,
                                        }
                                    )->first;

        my $list    = {
                refund_id       => $refund->id,
                refund_obj      => $refund,
                created_date    => ( $created_log ? $created_log->date->strftime("%F  %H:%M:%S") : '' ),
                status_date     => ( $status_log ? $status_log->date->strftime("%F  %H:%M:%S") : '' ),
                status          => $refund->pre_order_refund_status->status,
                total_value     => sprintf( "%0.2f", $refund->total_value ),
                operator_name   => ( $status_log ? $status_log->operator->name : '' ),
                department      => ( $status_log ? $status_log->operator->department->department : '' ),
            };
        push @list, $list;
    }

    return \@list;
}

=head2 rs_for_active_invoice_page

    $resultset  = $self->rs_for_active_invoice_page();

Returns an Hash Ref's of rows to be displayed on active invoice page.

=cut

sub rs_for_active_invoice_page {
    my $self = shift;

    #$self->result_source->schema->storage->debug(1);
    my $preorder_refund_rs = $self->search(
                                   { 'me.pre_order_refund_status_id' => {
                                        '-in' => [ $PRE_ORDER_REFUND_STATUS__PENDING,
                                                   $PRE_ORDER_REFUND_STATUS__FAILED,
                                                 ]
                                         },
                                    'pre_order_refund_status_logs.pre_order_refund_status_id' => { -ident => 'me.pre_order_refund_status_id' },
                                  },
                                  { join  => [ 'pre_order_refund_items',
                                               'pre_order_refund_status_logs',
                                               'pre_order_refund_status',
                                             ],
                                    '+select' =>[
                                                    'pre_order_refund_items.pre_order_item_id',
                                                    'pre_order_refund_items.unit_price',
                                                    'pre_order_refund_items.tax',
                                                    'pre_order_refund_items.duty',
                                                    'pre_order_refund_status_logs.id',
                                                    'pre_order_refund_status_logs.date',
                                                    { 'age' =>
                                                        { 'date_trunc' => "'day', pre_order_refund_status_logs.date" },
                                                              -as => 'log_date'
                                                    },
                                                    'pre_order_refund_status.status',
                                                ],
                                    '+as'     => [
                                                    'pre_order_item_id',
                                                    'unit_price',
                                                    'tax',
                                                    'duty',
                                                    'refund_status_logs_id',
                                                    'log_date',
                                                    'log_age',
                                                    'status',
                                                ],
                                 });

  return $preorder_refund_rs;

}

1;
