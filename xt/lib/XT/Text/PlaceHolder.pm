package XT::Text::PlaceHolder;

use NAP::policy "tt", qw( class );
with 'XTracker::Role::WithXTLogger';

=head1 NAME

XT::Text::PlaceHolder

=head1 SYNOPSIS

    use XT::Text::PlaceHolder;

    my $ph  = XT::Text::PlaceHolder->new( {
        string  => "This is P[C.DistributionCentre.name] "
                 . "and Customer Care Email Address is: 'P[C.Email.customercare_email:channel]'",
        channel => $channel_obj,
    } );

    $string = $ph->replace;

    # $string will contain:
    # "This is DC1 and Customer Care Email Address is: 'customercare@net-a-porter.com'"

=head1 DESCRIPTION

Will Replace One or more Place Holders of more than one Type found in 'string' with Values.

    $place_holder = XT::Text::PlaceHolder->new( {
        string      => $string_containing_place_holders,

        # required if using the 'SC' or 'LUT' Place Holder,
        # if not passed will use the schema for the 'channel'
        schema      => $schema,

        # required if using the 'SMC' Place Holder
        objects     => [
            # list of DBIC Objects that the
            # 'SMC' Place Holder will use
            $dbic_object_1,
            $dbic_object_2,
            ...
        ],

        # required if the 'channel' option is used if
        # not passed in it will be derived from the first
        # 'channel' or 'get_channel' method it can find from
        # the 'objects' list, if none can be found it will
        # throw an exception
        channel     => $sales_channel_obj,

        # optional
        cache   => \%cache_for_place_holders
        logger  => $log4perl_obj,
    } );

Place Holders should take the form of:

    P[Type.Part1.Part2]
        or
    p[Type.Part1.Part2:list,of,options]

=head2 DIFFERENT TYPES OF PLACE HOLDER

There are four Types of Place Holder:

    * 'C' - Config:

                P[C.ConfigSection.ConfigSetting]
             or P[C.ConfigSection.ConfigSetting:channel]

      This will get a value of the Setting from the Config Section from the Config files.
      By passing the ':channel' option will append the Sales Channel's Config Section to
      the Config Group, therefore allowing you to Channelise the Config Section wanted.

    * 'SC' - System Config:

                P[SC.ConfigGroup.ConfigSetting]
             or P[SC.ConfigGroup.ConfigSetting:channel]

      This will get a value from the System Config tables for the Config Group and the
      Config Setting. By passing the ':channel' option will look for a Config Group
      for the Sales Channel's Id, therefore allowing you to Channelise the System Config
      Group wanted.

    * 'LUT' - Look-Up Table:

                P[LUT.Table::ClassName.column_with_value,column=value],
             or P[LUT.Table::ClassName.column_with_value,column=value:channel]

      This will get the value from a Table in 'column_with_value' WHERE 'column' equals 'value', this allows
      values to come from a Look-up Table such as thresholds. By adding the option ':channel' will also
      check the Table's 'channel_id' field matches the Sales Channel's Id, so if you use this option
      make sure the Table has a 'channel_id' field.

    * 'SMC' - Simple Method Call:

                P[SMC.Class::Name.method_to_call]

      This will get a value by makeing a call to 'method_to_call' on the 'Class::Name' object which MUST be
      one of the objects passed into the 'objects' array.

The comma seperated list of Options that can be placed at the end of Part 2 of a Place Holder can be
one of the following:

    * :channel  - Channelises the Place Holder, see above about what this means to each Place Holder
    * :nocache  - This will mean the Value returned will NOT be Cached

=cut

use MooseX::Types::Moose qw(
    Str
    Object
    ArrayRef
    HashRef
    Maybe
    Undef
);

use XT::Text::PlaceHolder::Type;


=head1 ATTRIBUTES

=cut

=head2 string_to_replace

The String that has Place Holders in it, uses argument 'string' passed to 'new()'.

=cut

has string_to_replace => (
    is      => 'ro',
    isa     => Str|Undef,
    init_arg=> 'string',
);

=head2 place_holders

    $array_ref = $self->place_holders;

An ArrayRef of all the Place Holders in 'string_to_replace'.

=cut

has place_holders => (
    is          => 'ro',
    isa         => ArrayRef[Str|Undef],
    init_arg    => undef,
    lazy_build  => 1,
    traits      => ['Array'],
    handles     => {
        all_place_holders   => 'elements',
    },
);

=head2 channel

The Sales Channel which is required whenever the 'channel' option is used.

=cut

has channel => (
    is          => 'ro',
    isa         => Maybe['XTracker::Schema::Result::Public::Channel'],
    init_arg    => 'channel',
    required    => 0,
);

=head2 objects

An ArrayRef of Objects that are required for 'SMC' Place Holder Types.

=cut

has objects => (
    is          => 'ro',
    isa         => Maybe[ArrayRef[Object]],
    init_arg    => 'objects',
    required    => 0,
);

=head2 schema

Schema required for 'LUT' & 'SC' Place Holder Types.

=cut

has schema => (
    is          => 'ro',
    isa         => Maybe['XTracker::Schema'],
    init_arg    => 'schema',
    required    => 0,
);


# cache for Place Holders
has _cache => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { return {}; },
    traits  => ['Hash'],
    handles => {
        _add_to_cache   => 'set',
        _get_from_cache => 'get',
        _check_cache    => 'exists',
    },
);


# change the BUILD sub to take in a HASH
# and then assign it to the Method and
# Place Holder caches also handles a logger
sub BUILD {
    my ( $self, $args ) = @_;

    if ( my $cache = delete $args->{cache} ) {
        $self->_cache( $cache //= {} );
    }

    if ( my $logger = delete $args->{logger} ) {
        $self->set_xtlogger( $logger );
    }

    return $self;
}

sub _build_place_holders {
    my $self    = shift;

    my $string  = $self->string_to_replace;

    my @ph;
    while ( $string =~ m/(P\[.*?\])/sg ) {
        # store the place holder
        push @ph, $1;
    }

    return \@ph;
}

=head1 METHODS

=head2 replace

Replaces all the Place Holders in 'string' with their Values.

=cut

sub replace {
    my $self    = shift;

    my $string  = $self->string_to_replace;

    # return empty if nothing to do
    return ''       if ( !defined $string );

    $self->_log_debug( "Replacing Place Holders in string" );

    # store all the placeholders
    # found with their values
    my %place_holders;

    PH:
    foreach my $ph ( $self->all_place_holders ) {
        # no point in getting the same thing more than once
        next PH     if ( exists( $place_holders{ $ph } ) );

        # check if the Place Holder is in the Cache
        if ( $self->_check_cache( $ph ) ) {
            $place_holders{ $ph }   = $self->_get_from_cache( $ph );
            next PH;
        }

        my $type    = XT::Text::PlaceHolder::Type->new( {
            place_holder    => $ph,
            schema          => $self->schema,
            objects         => $self->objects,
            channel         => $self->channel,
        } );

        my $value   = $type->value;
        $place_holders{ $ph } = $value;
        $self->_add_to_cache( $ph => $value )       if ( $type->cache_the_value );
    }

    # replace all occurences of all place holders
    while ( my ( $ph, $value ) = each %place_holders ) {
        $value  //= '';
        $string =~ s/\Q${ph}\E/${value}/sg;
        $self->_log_debug( "Replaced Place Holder: '${ph}' with '${value}'" );
    }

    return $string;
}

#-----------------------------------------------------------------------------

# a helper to do debug logging with
sub _log_debug {
    my ( $self, $msg )  = @_;

    local $Log::Log4perl::caller_depth += 1;

    $self->xtlogger->debug( $self->_log_msg( $msg ) );

    return;
}

# log message with standard Prefix & Suffix
sub _log_msg {
    my ( $self, $msg )  = @_;

    my $string  = $self->string_to_replace;
    my $prefix  = "PlaceHolder using String: '${string}'";

    my @caller  = caller(2);
    my $suffix  = ", for '" . $caller[3] . "'";

    return "${prefix} - ${msg}${suffix}";
}

