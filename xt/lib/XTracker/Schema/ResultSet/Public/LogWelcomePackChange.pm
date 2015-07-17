package XTracker::Schema::ResultSet::Public::LogWelcomePackChange;
# vim: ts=8 sts=4 et sw=4 sr sta
use NAP::policy "tt";
use base 'DBIx::Class::ResultSet';

use Moose;
with 'XTracker::Schema::Role::ResultSet::Orderable' => {
    order_by => {
        id      => 'id',
        date    => 'date',
        date_id => [ qw( date id ) ]
     }
};

use XTracker::Constants::FromDB     qw( :welcome_pack_change );


=head2 get_config_setting_changes

    $result_set = $self->get_config_setting_changes;

Returns a ResultSet of 'Config Setting' changes.

=cut

sub get_config_setting_changes {
    my $self    = shift;

    return $self->_get_rs_for_changes(
        $WELCOME_PACK_CHANGE__CONFIG_SETTING,
    );
}

=head2 get_config_group_changes

    $result_set = $self->get_config_group_changes;

Returns a ResultSet of 'Config Group' changes.

=cut

sub get_config_group_changes {
    my $self    = shift;

    return $self->_get_rs_for_changes(
        $WELCOME_PACK_CHANGE__CONFIG_GROUP,
    );
}

=head2 get_config_changes

    $result_set = $self->get_config_changes;

Returns a ResultSet for both 'Config Setting' & 'Config Group' changes.

=cut

sub get_config_changes {
    my $self    = shift;

    return $self->_get_rs_for_changes(
        $WELCOME_PACK_CHANGE__CONFIG_GROUP,
        $WELCOME_PACK_CHANGE__CONFIG_SETTING,
    );
}

=head2 for_page

    $array_ref  = $self->for_page;

Returns an Array Ref. of Log Records for displaying on a page.

=cut

sub for_page {
    my $self    = shift;

    my @rows;

    my @recs    = $self->all;
    foreach my $rec ( @recs ) {
        my $channel = $rec->channel;
        push @rows, {
            log             => $rec,
            channel         => $channel // '',
            config_section  => ( $channel ? $channel->business->config_section : '' ),
            affected        => $rec->affected // '',
            date            => $rec->date->ymd('-'),
            time            => $rec->date->hms(':'),
            description     => $rec->description // '',
            value           => $rec->change_value // '',
        };
    }

    return \@rows;
}


# retun a ResultSet for the supplied list of 'changes'
sub _get_rs_for_changes {
    my ( $self, @change_ids )   = @_;

    my $value   = (
        @change_ids > 1
        ? { IN => [ @change_ids ] }
        : $change_ids[0]
    );

    return $self->search( {
        welcome_pack_change_id  => $value,
    } );
}

1;
