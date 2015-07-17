package XTracker::Schema::ResultSet::Public::ReturnEmailLog;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head2 in_created_order

    $return_email_log->in_created_order;

Return the logs in the order they were created.

=cut

sub in_created_order {
    my $self    = shift;

    my $alias   = $self->current_source_alias;
    return $self->search( {}, {
                        order_by    => "${alias}.date, ${alias}.id",
                    } );
}

=head2 formatted_for_page

    my $array_ref   = $return_email_log->formatted_for_page();

This returns the Return Email Logs formatted for displaying on Pages such as the Order View & Return Details page.

It will return an Array Ref of Hash refs containing the following:

    [
        {
            id          => $id,
            log_obj     => DBIC Record,
            rma_number  => RMA Number,
            operator    => Operator Name,
            template    => Correspondence Template Name,
            date        => 'DD-MM-YYYY  HH:MM',
        },
        ...
    ]

It will return 'undef' if there are no records found.

=cut

sub formatted_for_page {
    my $self    = shift;

    my @logs    = $self->in_created_order->all;
    return      if ( !@logs );

    my @rows;
    foreach my $log ( @logs ) {
        push @rows, {
                id          => $log->id,
                log_obj     => $log,
                rma_number  => $log->return->rma_number,
                operator    => $log->operator->name,
                template    => $log->correspondence_template->name,
                date        => $log->date->format_cldr('dd-MM-yyyy  HH:mm'),
            };
    }

    return \@rows;
}


1;
