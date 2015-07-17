package XTracker::Script::Sync::FraudHotlist;

use NAP::policy "tt", 'class';
extends 'XT::Common::Script';

with map { "XTracker::Script::Feature::$_" } qw(
    SingleInstance
    Schema
    Logger
);
with 'XTracker::Role::WithAMQMessageFactory';
sub log4perl_category { return 'Script_Sync' }

use DateTime;

use XTracker::Config::Local             qw( config_var );


=head1 NAME

    XTracker::Script::Sync::FraudHotlist

=head1 SYNOPSIS

    XTracker::Script::Sync::FraudHotlist->invoke();

=head1 DESCRIPTION

=cut

=head1 ATTRIBUTES

=cut

has verbose => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has dryrun => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has this_dc => (
    is      => 'rw',
    isa     => 'Str',
    required=> 1,
    init_arg=> undef,
    default => sub {
        return config_var('DistributionCentre', 'name');
    },
);

# restrict how many records are sent
# to an AMQ message at a time, if ZERO
# then have no restriction
has max_msg_per_batch => (
    is      => 'rw',
    isa     => 'Int',
    required=> 1,
    default => 0,
    init_arg => 'batch',
);

has hotlist_rs => (
    is      => 'rw',
    isa     => 'XTracker::Schema::ResultSet::Public::HotlistValue',
    lazy_build => 1,
    init_arg => undef,
);


=head1 METHODS

=cut

sub _build_hotlist_rs {
    my $self    = shift;

    return $self->schema->resultset('Public::HotlistValue')->search(
        { },
        {
            # 'prefetch' so that the DB isn't hit with requests
            # to these tables for every hotlist record processed
            prefetch => [ 'hotlist_field', { channel => 'business' } ],
            order_by => 'me.id',
        }
    );
}

=over 4

=item B<invoke>

Script entry point

=back

=cut

sub invoke {
    my ( $self )        = @_;

    $self->log_info("Script Started");

    my $rs  = $self->hotlist_rs;

    # if no limit on records per message has been specified
    # then set it to the total number of records to copy
    my $total_todo  = $rs->count();
    $self->max_msg_per_batch( $total_todo )     if ( !$self->max_msg_per_batch );

    $self->log_info( "Records per AMQ Message: " . $self->max_msg_per_batch );

    my @payload;

    my $counter     = 0;
    my $recs_per_msg= 0;

    while ( my $rec = $rs->next ) {
        if ( $counter == 0 ) {
            # for useful infomation log when
            # the first record gets processed
            $self->log_info("Processing FIRST Record");
        }

        push @payload, $rec->format_for_sync('add');

        $counter++;
        $recs_per_msg++;
        if ( $recs_per_msg >= $self->max_msg_per_batch || $counter >= $total_todo ) {
            $self->msg_factory->transform_and_send( 'XT::DC::Messaging::Producer::Sync::FraudHotlist', \@payload )     if ( !$self->dryrun );
            $self->log_info( "Created AMQ Message containing: ${recs_per_msg} records" );
            $recs_per_msg   = 0;
            @payload        = ();
        }
    }

    $self->log_info( "Hotlist Copied: ${counter}" );

    return;
}

1;
