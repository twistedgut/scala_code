package NAP::Carrier::UPS::Config;
use NAP::policy "tt", 'class';

use XTracker::Config::Local;

=head1 NAME

NAP::Carrier::UPS::Config

=head1 DESCRIPTION

Provides configuration layer for NAP::Carrier::UPS

=cut

has username => (
    is          => 'rw',
    isa         => 'Str',
    init_arg    => 'user_name',
);

has password => (
    is  => 'rw',
    isa => 'Str',
);

has xml_access_key => (
    is  => 'rw',
    isa => 'Str',
);

has base_url => (
    is      => 'rw',
    isa     => 'Str',
    default => 'https://wwwcie.ups.com/ups.app/xml',
);

has av_service => (
    is      => 'rw',
    isa     => 'Str',
    default => '/AV',
);

has shipconfirm_service => (
    is      => 'rw',
    isa     => 'Str',
    default => '/ShipConfirm',
);

has shipaccept_service => (
    is      => 'rw',
    isa     => 'Str',
    default => '/ShipAccept',
);

has quality_rating_threshold => (
    is      => 'rw',
    isa     => 'Num',
    default => '0.98',
);

has max_retry_wait_time => (
    is      => 'rw',
    isa     => 'Int',
    default => '5',
);

has max_retries => (
    is      => 'rw',
    isa     => 'Int',
    default => '3',
);

has fail_warnings => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
);

around BUILDARGS => sub {
    my ($orig, $class, $args) = @_;

    # get the failure error codes into a more descriptive array
    if ( exists $args->{ fail_warning_errcode } ) {
        $args->{ fail_warnings } = (
            ref( $args->{ fail_warning_errcode } ) eq "ARRAY"
                ? $args->{ fail_warning_errcode }
                : [ $args->{ fail_warning_errcode } ]
        );

        # get rid of the key just to clean everything up
        delete $args->{ fail_warning_errcode };
    }

    return $class->$orig($args);
};

=head1 METHODS

=head2 new_for_business

Constructor that will create a config object for a given business

param - $business : A DBIC Business result object

return - $config : Config object for the above business
=cut
sub new_for_business {
    my ($class, $business) = @_;
    return $class->_create_from_config_section($business->config_section());
}

=head2 new_for_unknown_business

Constructor that will create a config object if either we do not know what business
the config will be used for, or if it is for no specific business

return - $config : Config object
=cut
sub new_for_unknown_business {
    my ($class) = @_;
    # Use the NAP settings when we don't have a specific business
    return $class->_create_from_config_section('NAP');
}

sub _create_from_config_section {
    my ($class, $config_section) = @_;
    my $blob = config_section_exists(qq{UPS_API_Integration_${config_section}});
    return $class->new($blob);
}

