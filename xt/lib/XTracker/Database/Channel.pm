package XTracker::Database::Channel;

use strict;
use warnings;

use Perl6::Export::Attrs;
use Plack::App::FakeApache1::Constants qw(:common);
use Carp qw(carp croak);

use XTracker::Constants::FromDB       qw( :business );

=head1 NAME XTracker::Database::Channel
=head1 DESCRIPTION

Methods for returning information from the database related to channels.

=head1 SYNOPSIS

    my $channels_ref = get_channels( $dbh );
    my $channels_ref = get_channels( $dbh );
    my $channel_ref = get_channel( $dbh, $channel_id );
    my $channel_ref = get_channel_details( $dbh, $channel_name );
    my $channel_config_ref = get_channel_config( $dbh );

=head1 METHODS

=head2 get_channels

    # All enabled channels
    my $channels_ref = get_channels( $dbh );
    # All enabled and fulfilment_only channels
    my $channels_ref = get_channels( $dbh , { fulfilment_only => 1 } );
    # All enabled channels that aren't fulfilment_only
    my $channels_ref = get_channels( $dbh , { fulfilment_only => 0 } );

    foreach ( keys %{channels_ref} ) {
        warn $_->{id};
        warn $_->{name};
        warn $_->{business};
    }

Returns a hash containing channel info for all channels.

=cut

sub get_channels :Export() {

    my ( $dbh, $args ) = @_;

    my $wh_clause = '';

    if ( defined($args) && ref($args) eq 'HASH' ) {
        if ( defined($args->{fulfilment_only}) && $args->{fulfilment_only} == 0 ) {
           $wh_clause = 'AND b.fulfilment_only = FALSE ';
        } elsif ( defined($args->{fulfilment_only}) && $args->{fulfilment_only} == 1 ) {
           $wh_clause = 'AND b.fulfilment_only = TRUE ';
        }
    }

    my $qry = "SELECT c.id, c.name, c.business_id, c.distrib_centre_id, c.company_registration_number, c.default_tax_code, b.name as business, b.config_section, b.url, dc.name as dc, b.fulfilment_only
                FROM channel c, business b, distrib_centre dc
                WHERE c.business_id = b.id
                AND c.distrib_centre_id = dc.id
                AND c.is_enabled = TRUE
                $wh_clause";


    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        # set-up 'is_on_*' sales channel flags
        $row->{is_on_nap}       = ( $row->{business_id} == $BUSINESS__NAP ? 1 : 0 );
        $row->{is_on_outnet}    = ( $row->{business_id} == $BUSINESS__OUTNET ? 1 : 0 );
        $row->{is_on_mrp}       = ( $row->{business_id} == $BUSINESS__MRP ? 1 : 0 );

        $data{ $row->{id} } = $row;
    }

    return \%data;

}

=head2 get_web_channels

    my $channels_ref = get_channels( $dbh );

    foreach ( keys %{channels_ref} ) {
        warn $_->{id};
        warn $_->{name};
        warn $_->{business};
    }

Returns a hash containing channel info for all channels that have an
associated web channel (i.e. are not related to a business that is
fulfilment_only).

=cut

sub get_web_channels :Export() {

    my ( $dbh ) = @_;

    my $qry = "SELECT c.id, c.name, c.business_id, c.distrib_centre_id, c.company_registration_number, c.default_tax_code, b.name as business, b.config_section, b.url, dc.name as dc
                FROM channel c, business b, distrib_centre dc
                WHERE c.business_id = b.id
                AND b.fulfilment_only = FALSE
                AND c.distrib_centre_id = dc.id
                AND c.is_enabled = TRUE";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        # set-up 'is_on_*' sales channel flags
        $row->{is_on_nap}       = ( $row->{business_id} == $BUSINESS__NAP ? 1 : 0 );
        $row->{is_on_outnet}    = ( $row->{business_id} == $BUSINESS__OUTNET ? 1 : 0 );
        $row->{is_on_mrp}       = ( $row->{business_id} == $BUSINESS__MRP ? 1 : 0 );

        $data{ $row->{id} } = $row;
    }

    return \%data;

}


=head2 get_channel

    my $channel_ref = get_channel( $dbh, $channel_id );

    warn $channel_ref->{id};
    warn $channel_ref->{name};
    warn $channel_ref->{business};

Returns a single element hash representing the data in the database
for the specified channel.

=cut

sub get_channel :Export() {

    my ( $dbh, $channel_id )    = @_;

    my $qry = "SELECT c.id, c.name, c.business_id, c.distrib_centre_id, c.company_registration_number, c.default_tax_code, b.fulfilment_only, b.name as business, b.config_section, b.url, dc.name as dc, b.email_signoff, b.email_valediction
                FROM channel c, business b, distrib_centre dc
                WHERE c.business_id = b.id
                AND c.distrib_centre_id = dc.id
                AND c.id = ? ";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $channel_id );

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        %data   = %$row;
    }

    return \%data;
}


=head2 get_channel_details

    my $channel_ref = get_channel_details( $dbh, $channel_name );

    warn $channel_ref->{id};
    warn $channel_ref->{name};
    warn $channel_ref->{business};

Returns the same data as L</get_channel> (a single element hash representing the data in the database)
but based on a channel's name rather than its id.

=cut

sub get_channel_details :Export() {

    my ( $dbh, $channel_name ) = @_;

    my $qry = "SELECT c.id, c.company_registration_number, c.default_tax_code, b.fulfilment_only, b.name as business, c.business_id, b.config_section, b.url, dc.name as dc, b.email_signoff, b.email_valediction
                FROM channel c, business b, distrib_centre dc
                WHERE c.business_id = b.id
                AND c.distrib_centre_id = dc.id
                AND c.name = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($channel_name);

    return $sth->fetchrow_hashref();

}

=head2 get_channel_config

    my $channel_config_ref = get_channel_config( $dbh );

    foreach ( keys %{$channel_config_ref} ) {
        warn $_->{name};
        warn $_->{config_section};
    }

Returns a hash containing pairs of channel names and config sections
for every channel.

=cut

sub get_channel_config :Export() {

    my ( $dbh ) = @_;

    my $qry = "SELECT c.name, b.config_section
                FROM channel c, business b
                WHERE c.business_id = b.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{name} } = $row->{config_section};
    }

    return \%data;

}

1;
