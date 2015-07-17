package XT::Text::PlaceHolder::Type;

use NAP::policy "tt",     'class';

=head1 XT::Text::PlaceHolder::Type

Base Class for all the different types of Place Holder, by instantiating
this Class the correct Class Type will be returned.

=cut

use Module::Pluggable::Object;

use MooseX::Types::Moose qw(
    Str
    Bool
    Object
    ArrayRef
    HashRef
    RegexpRef
    Undef
);


=head1 ATTRIBUTES

=cut

# used to find the appropriate Type Class to use
has _plugin_search_path => (
    is      => 'ro',
    isa     => ArrayRef,
    default => sub {
        return [
            __PACKAGE__
        ];
    },
    required => 1,
);

=head2 place_holder

Holds the string with the Place Holder in it.

=cut

has place_holder => (
    is      => 'ro',
    isa     => Str,
    required=> 1,
);

=head2 schema

=cut

has schema => (
    is          => 'ro',
    isa         => 'XTracker::Schema',
    required    => 0,
    lazy        => 1,
    builder     => '_build_schema',
);

=head2 channel

=cut

has channel => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Channel',
    required    => 0,
    lazy_build  => 1,
);

=head2 objects

=cut

has objects => (
    is          => 'ro',
    isa         => ArrayRef[Object],
    init_arg    => 'objects',
    required    => 0,
    traits      => ['Array'],
    handles     => {
        all_objects     => 'elements',
    },
);

=head2 logger

Used for logging, will be built when needed but can also be passed to 'new()'.

=cut

has logger  => (
    is          => 'ro',
    isa         => 'Log::Log4perl::Logger',
    init_arg    => 'logger',
    lazy_build  => 1,
);

=head2 ph_split_pattern

The RegEx Pattern that Splits up 'place_holder' to
get each of its parts:

    P[Type.Part1.Part2:Options]

=cut

has ph_split_pattern => (
    is      => 'ro',
    isa     => RegexpRef,
    default => sub {
        return qr/P\[(?<type>\w+)\.(?<part1>.*)\.(?<part2>.*?)(:(?<options>.*))?\]/;
    },
);

#
# the place holder will be split up into the following:
#

has _type => (
    is      => 'rw',
    isa     => Str,
);

has _part1 => (
    is      => 'rw',
    isa     => Str,
);

has _part2 => (
    is      => 'rw',
    isa     => Str,
);

has _options => (
    is      => 'rw',
    isa     => HashRef,
    traits  => ['Hash'],
    handles => {
        _has_option => 'exists',
    },
);

# set this to TRUE if the 'channel' option is used
has _is_channelised => (
    is      => 'rw',
    isa     => Bool,
    lazy_build => 1,
);

=head2 cache_the_value

Boolean to tell the caller whether to Cache the Resulting Value or NOT. Is set
to TRUE by default, using the 'nocache' option will set this to FALSE.

=cut

has cache_the_value => (
    is      => 'rw',
    isa     => Bool,
    init_arg=> undef,
    default => 1,
);


# remove from the Arguments any
# 'undefined' values for Attributes
around BUILDARGS => sub {
    my ( $orig, $class, $args ) = @_;

    my @args_to_delete  = grep {
        exists( $args->{ $_ } )
        &&
        !defined $args->{ $_ }
    } keys %{ $args };
    delete $args->{ $_ }    foreach ( @args_to_delete );

    return $class->$orig( $args );
};

# used to figure out which Class should actually be
# instantiated based on the Type of the Place Holder
sub BUILD {
    my ( $self, $args ) = @_;

    my $class   = ref( $self );
    if ( __PACKAGE__ eq $class ) {
        my $finder  = Module::Pluggable::Object->new(
            search_path => $self->_plugin_search_path,
            require     => 1,
            inner       => 0,
        );

        # split 'place_holder' to get its Type
        $self->_split_up_ph;

        # build the Class name suffix for the Type of Place Holder
        my $type_class  = "::Type::" . $self->_type;

        my @type = grep { m/${type_class}$/ } $finder->plugins;
        if ( !@type ) {
            $self->_log_croak( "Couldn't Find Place Holder Class Type '${type_class}' when building" );
        }
        elsif ( @type > 1 ) {
            $self->_log_croak( "Found more than one Class for Place Holder Type '${type_class}' when building" );
        }

        # Re-Bless $self so that it is now the Plugin's Class, BUILD & BUILDARGS
        # won't be called but Attributes will be populated with contents of %{ $args }
        $type[0]->meta->rebless_instance( $self, %{ $args } );
        $self->BUILD( $args );      # call the BUILD on the new object, to cleanup anything that needs it

        # set some attributes based on the 'options' passed
        $self->_set_options;

        # using the Attributes on the Child Classes:
        # 'part1_split_pattern' & 'part2_split_pattern'
        # split up the two parts of the Place Holder
        $self->_split_up_parts;
    }

    return $self;
};


=head1 METHODS

All methods are Private.

=cut

# split up the Place Holder into its different Parts
sub _split_up_ph {
    my $self    = shift;

    $self->_log_debug("Splitting Up Place Holder");

    $self->place_holder =~ $self->ph_split_pattern;
    $self->_type( $+{type} );
    $self->_part1( $+{part1} );
    $self->_part2( $+{part2} );
    $self->_options( {
        map { $_ => 1 } split( /,/, $+{options} // '' )
    } );

    return;
}

# set some attributes based on the 'options' for the Place Holder
sub _set_options {
    my $self    = shift;

    $self->_log_debug("Setting Options for Place Holder");

    # try and get a Sales Channel if the
    # 'channel' option has been used
    if ( $self->_is_channelised ) {
        $self->channel;
    }

    if ( $self->_has_option('nocache') ) {
        $self->cache_the_value( 0 );
    }

    return;
}

# this will be called on the Child Class after it
# has been instantaited and requires that the Child Class
# has the following two RegEx Attributes:
#       part1_split_pattern
#       part2_split_pattern
sub _split_up_parts {
    my $self    = shift;

    $self->_log_debug("Splitting Up Parts 1 & 2 of the Place Holder");

    foreach my $n ( 1..2 ) {
        my $part    = "_part${n}";
        my $pattern = "part${n}_split_pattern";

        if ( $self->$part =~ $self->$pattern ) {
            while ( my ( $key, $value ) = each %+ ) {
                $self->$key( $value );
                $self->_log_debug( "Part ${n} - '${key}': '" . ( $value // 'undef' ) . "'" );
            }
        }
        else {
            $self->_log_croak( "Couldn't Split Part ${n}, pattern didn't match: '" . $self->$pattern . "'" );
        }
    }

    return;
}

# make sure the value returned is a SCALAR
sub _check_value {
    my ( $self, $value )    = @_;

    if ( ref( $value ) ) {
        $self->_log_croak( "Value found for Place Holder is not a simple Scalar it is of type: '" . ref( $value ) . "'" );
    }

    $self->_log_debug( "Value Returned: '" . ( defined $value ? $value : 'undef' ) . "'" );

    return $value;
}

#-----------------------------------------------------------------------------

sub _build_logger {
    my $self    = shift;
    require XTracker::Logfile;
    return XTracker::Logfile::xt_logger();
}

sub _build__is_channelised {
    my $self    = shift;
    return ( $self->_has_option('channel') ? 1 : 0 );
}

# go through each of the 'objects' and call
# method 'channel' or 'get_channel' if available
sub _build_channel {
    my $self    = shift;

    if ( !$self->objects ) {
        $self->_log_croak( "Can't derive Sales Channel without a list of Objects" );
    }

    my $channel;

    OBJECT:
    foreach my $object ( $self->all_objects ) {
        # go through all Objects in the 'objects' list looking
        # for either a 'channel' or 'get_channel' method
        if ( $object->can('channel') ) {
            $channel    = $object->channel;
            last OBJECT;
        }
        if ( $object->can('get_channel') ) {
            $channel    = $object->get_channel;
            last OBJECT;
        }
    }

    if ( !$channel ) {
        $self->_log_croak( "Couldn't derive Sales Channel from list of Objects" );
    }

    return $channel;
}

# use the Schema for the 'channel'
sub _build_schema {
    my $self    = shift;
    return  if ( !$self->_is_channelised );
    return $self->channel->result_source->schema;
}


# do logging this way to get the standard
# prefix & suffix for every entry

sub _log_debug {
    my ( $self, $msg )  = @_;

    local $Log::Log4perl::caller_depth += 1;

    $self->logger->debug( $self->_log_msg( $msg ) );
    return;
}

sub _log_croak {
    my ( $self, $msg )  = @_;

    local $Log::Log4perl::caller_depth += 1;

    $self->logger->logcroak( $self->_log_msg( $msg ) );
    return;
}

# get a standard prefix & suffix for every Log entry
sub _log_msg {
    my ( $self, $msg )  = @_;

    my @caller  = caller(2);
    my $function= $caller[3];

    return "PH: '" . $self->place_holder . "' - " .
           $msg .
           ", for '${function}'";
}

