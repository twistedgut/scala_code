package XTracker::Schema::ResultSet::Public::PreOrderRefundFailedLog;
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


=head2 list_of_failed_log

    $array_ref  = $self->list_of_failed_log();

Returns an Array Ref of Hash Ref's of pre_order_refund_failed log rows to be displayed on a page.

=cut

sub list_of_failed_log {
    my $self    = shift;

    my @list;
    my @logs = $self->order_by_date_id->all;

    foreach my $log ( @logs ) {
        my $list    = {
                log_id          => $log->id,
                date            => $log->date->strftime("%F  %H:%M:%S"),
                message         => $log->failure_message,
                operator_name   => $log->operator->name,
                department      => $log->operator->department->department,
            };
        push @list, $list;
    }

    return \@list;
}

1;
