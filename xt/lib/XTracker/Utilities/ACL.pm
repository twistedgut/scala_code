package XTracker::Utilities::ACL;
use NAP::policy "tt", 'exporter';

use Sub::Exporter   -setup => {
    exports => [ qw(
        filter_acl_roles
        filter_acl_roles_and_get_role_names
        main_nav_option_to_url_path
    ) ],
};

=head1 NAME

XTracker::Utilities::ACL

=head1 DESCRIPTION

Utility functions used for Access Control List (ACL) based
operations, such as those in the 'XT::AccessControls' class.

=cut

use XTracker::Config::Local     qw( config_var );


=head1 METHODS

=head2 filter_acl_roles

    $hash_ref = filter_acl_roles( [
        # array ref of Roles
        app_some_role
        app_can_do_stuff~PROPERTY.value&PROPERTY.value
        ...
    ] );

Will filter the Array Ref. of Roles passed in based on the
settings in the config for the 'ACL' section.

Returns a Hash Ref. of filtered Roles & their properties:

    {
        role_name => {
            BRAND       => 'NAP',
            APP         => 'XTDC1',
            PROPERTY    => 'value'
            ...
        },
        another_role => { },    # if a Role has no properties
        ...
    }

=cut

sub filter_acl_roles {
    my $role_list   = shift;

    die "Must pass in an Array Ref. of Roles to '" . __PACKAGE__ . "::filter_acl_roles'"
                                if ( defined $role_list && !ref( $role_list ) eq 'ARRAY' );

    my %filtered_roles;

    if ( defined $role_list ) {
        # get the options required to parse a Role
        my $parsing_options     = config_var( 'ACL', 'role_parsing' );
        my $prefix              = $parsing_options->{role_prefix};
        my $separator           = $parsing_options->{role_separator};

        # get this DC to use
        my $this_dc             = uc( 'XT' . config_var('DistributionCentre', 'name') );

        my $role_prefix_regex   = qr/^\Q${prefix}\E/i;
        my $role_parts_regex    = qr/^(?<role_name>.*)\Q${separator}\E(?<properties>.*)/i;

        ROLE:
        foreach my $role ( @{ $role_list } ) {
            next ROLE       if ( $role !~ m/${role_prefix_regex}/ );

            my $role_name;
            my $properties   = {};

            if ( $role =~ m/${role_parts_regex}/ ) {
                $role_name  = $+{role_name};

                # get the properties
                $properties = _parse_role_properties( $+{properties} );

                # so far the only property we know about is 'APP', so only
                # want Roles whose APP is for This DC or where there is NO APP
                next ROLE       if ( exists( $properties->{APP} ) && uc( $properties->{APP} ) ne $this_dc );
            }
            else {
                $role_name  = $role;
            }

            $filtered_roles{ $role_name }    = $properties;
        }
    }

    return \%filtered_roles;
}

=head2 filter_acl_roles_and_get_role_names

    $array_ref = filter_acl_roles_and_get_role_names( [
        # array ref of Roles
        app_some_role
        app_can_do_stuff~PROPERTY.value&PROPERTY.value
        ...
    ] );

    the above would return:

    [
        'app_some_role',
        'app_can_do_stuff',
        ...
    ]

Pass in an Array Ref. of Roles and will filter them in the same
way 'filter_acl_roles' does but will return only an Array Ref.
of Role Names.

=cut

sub filter_acl_roles_and_get_role_names {
    my $role_list   = shift;

    die "Must pass in an Array Ref. of Roles to '" . __PACKAGE__ . "::filter_acl_roles_and_get_role_names'"
                                if ( defined $role_list && !ref( $role_list ) eq 'ARRAY' );

    my $filtered_roles = filter_acl_roles( $role_list );

    return [ keys %{ $filtered_roles } ];
}

# private function that will parse the 'properties' for a Role
# that are in the name of the Role after the main separator
sub _parse_role_properties {
    my $property_str    = shift;

    my $parsing_options     = config_var( 'ACL', 'role_parsing' );
    my $separator           = $parsing_options->{property_separator};
    my $key_value_separator = $parsing_options->{property_key_value_separator};

    my %properties;

    if ( $property_str ) {
        my @property_pairs  = split( /\Q${separator}\E/i, $property_str );
        foreach my $property_pair ( @property_pairs ) {
            my ( $property, $value ) = split( /\Q${key_value_separator}\E/i, $property_pair );
            $properties{ $property } = $value;
        }
    }

    return \%properties;
}

=head2 main_nav_option_to_url_path

    $string = main_nav_option_to_url_path( 'Goods In', 'Returns QC' );

    will return:

    '/GoodsIn/ReturnsQC'

Given a Section & Sub-Section for a Main Nav Option it will return the
URL Path for it.

=cut

sub main_nav_option_to_url_path {
    my ( $section, $sub_section )   = @_;

    my $url_path  = ( $section ? "/${section}" : '' );
    $url_path    .= ( $sub_section ? "/${sub_section}" : '' );
    $url_path    =~ s/ //g;

    return $url_path;
}

1;
