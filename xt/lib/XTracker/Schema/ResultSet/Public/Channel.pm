package XTracker::Schema::ResultSet::Public::Channel;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Carp;

use base 'DBIx::Class::ResultSet';

use XTracker::Constants::FromDB qw( :business );
use XTracker::Utilities         qw( strip );

=head1 NAME

XTracker::Schema::ResultSet::Public::Channel

=head1 METHODS

=head2 channel_list

Returns a resultset of all channels ordered by id

=cut

sub channel_list {
    my $self = shift;
    return $self->enabled_channels;
}

sub get_channels_rs {
    return $_[0]->channel_list;
}

=head2 id_display_name() : \%channel_id_display_name

Return hashref with (keys: channel.id, values: display name).

=cut

sub id_display_name {
    my $self = shift;
    return {
        map { $_->id => $_->config_name }
        $self->get_channels_rs->all,
    };
}

=head2 drop_down_options

Returns a resultset of all channels ordered for display in a select drop-down-box.
For now it returns in 'id' order, but in the future it could be in Alphabetical Order
(for example)

=cut

sub drop_down_options {
    my( $class ) = @_;

    return $class->enabled_channels;
}

=head2 fulfilment_only([0|1])

Filter the resultset by the related I<business> row's I<fulfilment_only> field
with the value passed (default is 1).

=cut

sub fulfilment_only {
    my ( $self, $val ) = @_;

    $val //= 1;
    croak "Invalid arg '$val' - must be 0 or 1"
        unless grep { $val == $_ } (0,1);

    return $self->search(
        { 'business.fulfilment_only' => $val },
        { join => 'business' }
    );
}

=head2 enabled([0|1])

Filter the resultset by the I<is_enabled> field with the value passed (default
is 1).

=cut

sub enabled {
    my ($self, $val) = shift;

    $val //= 1;
    croak "Invalid arg '$val' - must be 0 or 1"
        unless grep { $val == $_ } (0,1);

    my $me = $self->current_source_alias;

    return $self->search({ "$me.is_enabled" => $val })
}

=head2 enabled_channels

Returns a resultset of the channels ordered by id. Also prefetches C<business>
and C<distrib_centre> relationships.

=cut

sub enabled_channels {
    my ($self) = shift;

    my $me = $self->current_source_alias;

    return $self->enabled->search_rs(undef, {
        prefetch => [ 'business', 'distrib_centre' ],
        order_by => "$me.id",
    });
}

=head2 channels_enabled( @channel_names )

Returns true if all the channels in @channel_names are enabled. The list of
valid channel names to pass is 'select config_section from business'.

    $schema->resultset('Public::Channel')->channels_enabled( qw( NAP MRP ) );
    # Returns true if NAP and MRP are both enabled.

    $schema->resultset('Public::Channel')->channels_enabled( qw( OUTNET ) );
    # Returns true if OUTNET is enabledenabled.

=cut

sub channels_enabled {
    my $self = shift;
    my @channels = sort @_;

    my @enabled = sort $self
        ->enabled
        ->search(
            {
                'business.config_section' => { '-in' => \@channels },
            },
            {
                'join' => 'business'
            }
        )
        ->get_column( 'business.config_section' )
        ->all;

    SMARTMATCH: {
        use experimental 'smartmatch';
        return ( @channels ~~ @enabled );
    }
}

=head2 get_channels

    # All enabled channels
    my $channels_ref = $channel_rs->get_channels();
    # All enabled and fulfilment_only channels
    my $channels_ref = $channel_rs->get_channels({ fulfilment_only => 1 });
    # All enabled channels that aren't fulfilment_only
    my $channels_ref = $channel_rs->get_channels({ fulfilment_only => 0 });

Returns a hash of channel info for all enabled channels

=head3 NOTE

Seriously, other than the staging_url bit (if necessary this should be done at
row level) this sub should be deprecated.

=cut

sub get_channels {
    my ( $self, $args ) = @_;

    my $list = $self->enabled_channels;

    if (defined $args && ref($args) eq 'HASH') {
        $list = $list->search_rs($args);
    }

    my %channels;
    while ( my $row = $list->next ) {
        $channels{$row->id} = {
            id                                 => $row->id,
            name                               => $row->name,
            business_id                        => $row->business_id,
            distrib_centre_id                  => $row->distrib_centre_id,
            company_registration_number        => $row->company_registration_number,
            default_tax_code                   => $row->default_tax_code,
            business                           => $row->business->name,
            config_section                     => $row->business->config_section,
            url                                => $row->business->url,
            staging_url                        => $row->business->url,
            dc                                 => $row->distrib_centre->name,
            fulfilment_only                    => $row->business->fulfilment_only,
            is_on_nap                          => $row->is_on_nap || 0,
            is_on_outnet                       => $row->is_on_outnet || 0,
            is_on_mrp                          => $row->is_on_mrp || 0,
            has_nominated_day_shipping_charges => $row->has_nominated_day_shipping_charges || 0,
            web_name                           => $row->web_name,
            carrier_automation_state           => $row->carrier_automation_state,
        };

        $channels{$row->id}{staging_url} =~ s/^[^.]*\./staging\./;
    }
    return \%channels;
}

=head2 enabled_channels_with_public_website

    Return channels that are enabled and have a public website but are not
    fulfilment only in a custom hash.

    $schema->resultset('Public::Channel')->enabled_channels_with_public_website;

=cut

sub enabled_channels_with_public_website {
    my($self) = @_;
    return $self->get_channels({
        fulfilment_only     => 0,
        is_enabled          => 1,
        has_public_website  => 1,
    });
}

=head2 get_channels_for_action

    $result_set = $self->get_channels_for_action( $action_string );

This will Return a ResultSet limiting the Sales Channels that could be returned by only including
those for the Action passed in. The Action is checked against the 'ChannelsForAction' DB System
Config Section and then only those Channels will be returned.

If the Action passed does not exist in the Config or is empty, undef or absent then All Channels
will be returned.


First introduced for CANDO-443.

=cut

sub get_channels_for_action {
    my ( $self, $action )   = @_;

    $action = strip( $action );

    return $self        if ( !$action );        # nothing to restrict to

    my $schema  = $self->result_source->schema;

    # find the Config Sections to use to restrict the
    # Sales Channels returned to and be Case Insensitive
    my $sections    = $schema->resultset('SystemConfig::ConfigGroupSetting')
                            ->config_var( 'ChannelsForAction', { 'ILIKE' => $action } );
    return $self        if ( !$sections );      # nothing found to restrict to

    # force $sections into an Array Ref.
    $sections   = ( ref( $sections ) ? $sections : [ $sections ] );

    return $self->search(
                    {
                        'business.config_section'   => {
                                                'IN'    => $sections,
                                            },
                    },
                    {
                        join    => 'business',
                    }
                );
}

=head2 get_channel( $channel_id )

Returns a hashref of channel info for a given C<$channel_id>.

=head3 NOTE

This sub should be deprecated, as DBIC offers are more consistent object
approach to retrieve the same data.

=cut

sub get_channel {
    my ($rs, $channel_id) = @_;

    my $row = $rs->find( $channel_id, { prefetch => [ 'business', 'distrib_centre' ] } );

    my %channel;
    if ( defined $row ) {
        $channel{id}                          = $row->id;
        $channel{name}                        = $row->name;
        $channel{business_id}                 = $row->business_id;
        $channel{distrib_centre_id}           = $row->distrib_centre_id;
        $channel{company_registration_number} = $row->company_registration_number,
        $channel{default_tax_code}            = $row->default_tax_code,
        $channel{business}                    = $row->business->name;
        $channel{config_section}              = $row->business->config_section;
        $channel{url}                         = $row->business->url;
        $channel{staging_url}                 = $channel{url};
        $channel{staging_url}                 =~ s/^[^.]*\./staging\./;
        $channel{dc}                          = $row->distrib_centre->name;
    }

    return \%channel;
}


=head2 get_channel_details( $channel_name )

Returns a hash of channel info for a C<$channel_name>.

=head3 NOTE

This sub should be deprecated, as DBIC offers are more consistent object
approach to retrieve the same data.

=cut

sub get_channel_details {
    my ($rs, $channel_name) = @_;

    my $list = $rs->search(
        { 'me.name' => $channel_name },
        { prefetch => [ 'business', 'distrib_centre' ] }
    );

    my %details;
    while ( my $row = $list->next ) {
        $details{id}                          = $row->id;
        $details{company_registration_number} = $row->company_registration_number,
        $details{default_tax_code}            = $row->default_tax_code,
        $details{business}                    = $row->business->name;
        $details{config_section}              = $row->business->config_section;
        $details{url}                         = $row->business->url;
        $details{dc}                          = $row->distrib_centre->name;
    }
    return \%details;
}


=head2 get_channel_config

Returns a hash with channel name as key and config name as value.

=head3 NOTE

This sub should be deprecated, as DBIC offers are more consistent object
approach to retrieve the same data.

=cut

sub get_channel_config {
    my $rs = shift;

    my $list = $rs->search( undef, {
        order_by => 'me.name ASC',
        prefetch => [ 'business' ]
    });
    my %config;
    while ( my $row = $list->next ) {
        $config{ $row->name } = $row->business->config_section;
    }
    return \%config;
}

=head2 find_by_web_name

Finds channel by its web name

=cut

sub find_by_web_name {
    my $self = shift;
    my $web_name = shift;

    return $self->search({web_name => $web_name})->first;
}

=head2 find_by_pws_name

Finds channel by its PWS name

=cut

sub find_by_pws_name {
    my $self = shift;
    my $web_name = shift;

    # PWS uses 'OUT' but xTracker uses 'OUTNET'
    $web_name =~ s/OUT/OUTNET/;

    return $self->find_by_web_name($web_name);
}

=head2 find_by_name

Finds channel by its name

=cut

sub find_by_name {
    my ($self, $name, $args) = @_;
    $args //= {};
    my $ignore_case = $args->{ignore_case} // 0;

    return $self->search({
        ($ignore_case ? 'upper(name)' : 'name') => ($ignore_case ? uc($name) : $name),
    })->first;
}

=head2 net_a_porter

Get a channel object for NET-A-PORTER.

    my $channel = $schema->resultset('Public::Channel')->net_a_porter;

=cut

sub net_a_porter {
    my $self = shift;

    return $self->find( { business_id => $BUSINESS__NAP } );

}


=head2 the_outnet

Get a channel object for THE OUTNET.

    my $channel = $schema->resultset('Public::Channel')->the_outnet;

=cut

sub the_outnet {
    my $self = shift;

    return $self->find( { business_id => $BUSINESS__OUTNET } );

}

=head2 mr_porter

Get a channel object for MR PORTER.

    my $channel = $schema->resultset('Public::Channel')->mr_porter;

=cut

sub mr_porter {
    my $self = shift;

    return $self->find( { business_id => $BUSINESS__MRP } );

}

=head2 jimmy_choo

Get a channel object for JIMMY CHOO.

    my $channel = $schema->resultset('Public::Channel')->jimmy_choo;

=cut

sub jimmy_choo {
    my $self = shift;

    return $self->find( { business_id => $BUSINESS__JC } );


}

=head2 get_carrier_automation_states

Returns a hash with channel id as key and carrier automation state as value.

=cut

sub get_carrier_automation_states {
    my $self = shift;

    my %states = map { $_->id => $_->carrier_automation_state } $self->enabled_channels->all;
    return \%states;
}

1;
