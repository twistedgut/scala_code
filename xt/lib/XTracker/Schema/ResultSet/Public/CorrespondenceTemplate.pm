package XTracker::Schema::ResultSet::Public::CorrespondenceTemplate;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head2 find_by_name

Return a C<XTracker::Schema::Result::Public::CorrespondenceTemplate> record
given an specific order of prefered template names

=cut

sub find_by_name {
    my($self,$names) = @_;
    $names = [ $names ] if (ref($names) ne 'ARRAY');

    foreach my $name (@{$names}) {
        # ensure ordering is reliable - couldn't think of better than desc id
        # with the theory its more recent so more useful - might need changing
        my $set = $self->search({ name => $name },{ order_by => 'me.id DESC' });
        if ($set && $set->count > 0) {
            return $set->first;
        }
    }

    return;
}


sub get_templates_by_department {
    my $self = shift;

    my @templates = $self->search(
        undef,
        {
            '+select' => [
                'department.department',
                'me.id',
                'me.name'
             ],
            '+as' => [
                'department',
                'id',
                'name'
            ],
            join => 'department',
        })->all;

    my %list = ();
    foreach my $template ( @templates ) {
       my $tt =  $template->get_most_recent_log_entry;
        my %data;
        if( $tt ) {
            %data = (
                date => $tt->last_modified,
                operator => $tt->operator->name,
            );
        }
        my $department    = $template->get_column('department') // 'Unknown';
        my $id            = $template->get_column('id');
        my $name          = $template->get_column('name');
        my $row = {
            id => $id,
            name => $name,
            department => $department,
            %data,
        };
        $list {$department}{$id} = $row;

    }


    return \%list;
}

1;
