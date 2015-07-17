package XTracker::Schema::ResultSet::Public::PreOrderRefundStatusLog;
# vim: ts=4 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Moose;
with 'XTracker::Schema::Role::ResultSet::Orderable' => {
         order_by => {      id => 'id',
                          date => 'date',
                       date_id => [ qw( date id ) ]
                     }
     };


=head2 status_log_for_summary_page

    $array_ref  = $self->status_log_for_summary_page();

Returns an Array Ref of Hash Ref's for to be displayed on the Pre-Order Refund Summary page.

=cut

sub status_log_for_summary_page {
    my $self    = shift;

    my @list;
    my @logs = $self->order_by_date_id->all;

    foreach my $log ( @logs ) {
        my $list    = {
                log_id          => $log->id,
                status_date     => $log->date->strftime("%F  %H:%M:%S"),
                status          => $log->pre_order_refund_status->status,
                operator_name   => $log->operator->name,
                department      => $log->operator->department->department,
            };
        push @list, $list;
    }

    return \@list;
}

1;
