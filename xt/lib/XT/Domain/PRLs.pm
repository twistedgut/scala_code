package XT::Domain::PRLs;

=head1 NAME

XT::Domain::PRLs - PRL-configuration related tasks

=head1 DESCRIPTION

Information about PRLs

=cut

use NAP::policy "tt";

use MooseX::Params::Validate qw/validated_list validated_hash pos_validated_list/;
use Moose::Util::TypeConstraints;
use Clone qw/clone/;
use Carp qw/confess/;
use List::Util qw/first/;

use XTracker::Config::Local qw/config_section_slurp config_var/;
use XTracker::Database 'xtracker_schema';

my $prl_config_hash = config_var('PRL', 'PRLs') // {};
my @prl_configs_param = (
    prl_configs => {
        isa     => 'HashRef',
        default => $prl_config_hash,
    },
);

my @schema_param = (
    schema => {
        isa      => 'DBIx::Class:Schema',
        optional => 1,
    },
);

=head1 SUBROUTINES

All methods accept an optional C<prl_configs> hashref, containing the PRL
configuration data. If this is missing, it defaults to use values from XT's
config instead.


=head2 config_keys : \@config_keys

Return arrayref with the keys from the configuration, or empty
arrayref if there are none.

=cut

sub config_keys {
    return [ sort keys %$prl_config_hash ];
}

=head2 get_prls_for_storage_type_and_stock_status(:storage_type, :stock_status) : \%prl_config_part

For provided storage type and stock status return PRL related part of config
with compatible PRLs.

Storage type and stock status are string as they defined in database ("name" property)
and config file in "storage_types" section.

=cut

sub get_prls_for_storage_type_and_stock_status {
    my ($prl_configs, $storage_type, $stock_status) = validated_list(
        \@_, @prl_configs_param,
        storage_type => { isa => 'Str'},
        stock_status => { isa => 'Str'},
    );

    my @prl_keys =
        # exclude those without provided stock status
        grep {
            my $stock_statuses = $prl_configs->{$_}{storage_types}{$storage_type}{stock_statuses};
            # when "stock_statuses" section contains less than two items,
            # parser treat value as a string rather then array ref,
            # normalize it to always be array ref
            $stock_statuses = [$stock_statuses] unless ref $stock_statuses;
            first { $_ eq $stock_status } @$stock_statuses
        }
        # exclude those without current storage type
        grep { $prl_configs->{$_}{storage_types}{$storage_type} }
        # exclude those without storage type section
        grep { $prl_configs->{$_}{storage_types} }
        # get all PRLs we have
        keys %$prl_configs;

    confess(sprintf 'Two possible PRLs (%s) for storage type %s and stock status %s, stopping',
       join('/',@prl_keys), $storage_type, $stock_status) if @prl_keys > 1;

    my %result;

    # make sure return value is new data structure rather one created from parts
    # of passed PRL configs
    $result{ $_ } = clone( $prl_configs->{$_} ) for @prl_keys;

    return \%result;
}

=head2 get_prls_for_storage_types_and_stock_statuses( :storage_type_and_stock_status_hash ) : \%prl_config_part

Accept information about combinations of storage types and stock statuses in form of hash ref.

    Storage_type => Stock_status => 1

Return config parts for all PRL that could deal with provided storage types and stock statuses.

Note, that all result PRLs are able to coop with passed combination.

=cut

sub get_prls_for_storage_types_and_stock_statuses {
    my ($prl_configs, $storage_type_and_stock_status_hash) = validated_list(
        \@_, @prl_configs_param,
        storage_type_and_stock_status_hash => { isa => 'HashRef[HashRef[Int]]'},
    );

    # PRLs that are going to be returned as a result
    my %acceptable_prls;

    # counter for each PRL: how many times it appeared during checking
    # different combinations
    my %prl_counter;

    # how many different combinations were provided
    my $number_of_combinations;

    # get config info about all available PRLs
    my $prls = config_var('PRL', 'PRLs');

    foreach my $storage_type (keys %$storage_type_and_stock_status_hash) {
        foreach my $stock_status ( keys %{ $storage_type_and_stock_status_hash->{$storage_type} } ) {

            # get PRLs that could coop with current storage type and stock status
            my $prls_for_current_combination = get_prls_for_storage_type_and_stock_status({
                prl_configs  => $prl_configs,
                storage_type => $storage_type,
                stock_status => $stock_status,
            });

            # count this combination
            $number_of_combinations++;

            # make sure we count each PRL suitable for current combination
            $prl_counter{$_}++ foreach keys %$prls_for_current_combination;

            # keep tracking of all PRLs found
            %acceptable_prls = (
                %acceptable_prls,
                %$prls_for_current_combination
            );
        }
    }

    # as a result we will return only those PRLs that occurred for every combination
    delete $acceptable_prls{ $_ }
        foreach grep { $prl_counter{ $_ } < $number_of_combinations }
             keys %acceptable_prls;

    return \%acceptable_prls;
}

=head2 get_prl_location_names() : $@location_names

Returns an arrayref of location names (C<location.location>) that correspond to
PRLs.

=cut

sub get_prl_location_names {
    my $schema = xtracker_schema;

    my $prl_rs = $schema->resultset('Public::Prl');
    my @prls = $prl_rs->filter_active;
    my @location_names = map  { $_->location->location }
                         grep { defined $_->location_id } @prls;

    return \@location_names;
}

=head2 get_prl(\%columns) : $prl_row

Given a hash of column names and column values, return the PRL row that
matches the given values. Dies if no matching PRL can be found

Note: Uses DBIC's find() method, so this will return no more than one
PRL row. If you want a search that returns multiple PRL rows, then use
get_prls().

=cut

sub get_prl {
    my ($columns) = @_;

    my $schema = xtracker_schema;

    my $prl_rs = $schema->resultset('Public::Prl')->filter_active;

    my $prl = $prl_rs->find($columns);

    confess "Cannot find matching PRL\n" unless $prl;
    return $prl;
}

=head2 get_prls(\%columns) : @prl_rows

Given a hash of column names and column values, return the PRL rows that
match the given values.

Note: Uses DBIC's search() method, so this will return many PRL rows if
they match the criteria. If you want a search that returns a single PRL row,
then use get_prl().

=cut

sub get_prls {
    my ($columns) = @_;

    my $schema = xtracker_schema;

    my $prl_rs = $schema->resultset('Public::Prl')->filter_active;

    return $prl_rs->search($columns);
}

=head2 get_location_from_amq_identifier($amq_identifier) : $location_name

Given an AMQ identifier (config value for PRL: C<amq_identifier>), returns the
corresponding location name (C<location.location>) or undef.

=cut

sub get_location_from_amq_identifier {
    my $prl = get_prl_from_amq_identifier(@_);
    return $prl->location->location;
}

=head2 get_location_from_prl_name($prl_name) : $location_row

Given a PRL's name, return the corresponding location object or undef.

=cut

sub get_location_from_prl_name {
    my $prl = get_prl_from_name(@_);

    return $prl->location;
}

=head2 get_amq_queue_from_prl_name($prl_name) : $amq_queue

Given a PRL's name, return the name of the associated AMQ queue

=cut

sub get_amq_queue_from_prl_name {
    my $prl = get_prl_from_name(@_);

    return $prl->amq_queue;
}

=head2 get_prl_from_amq_name($amq_queue) : $prl_row

Given the name of an AMQ queue, return the associated PRL object.

=cut

sub get_prl_from_amq_queue {
    my ($amq_queue) = validated_list(
        \@_,
        amq_queue => { isa => 'Str'},
    );

    my $prl = get_prl({ amq_queue => $amq_queue });

    return $prl;
}

=head2 get_prl_from_name($prl_name) : $prl_row

Given the name of a PRL, return the complete PRL object.

=cut

sub get_prl_from_name {
    my ($prl_name) = validated_list(
        \@_,
        prl_name => { isa => 'Str'},
    );

    my $prl = get_prl({ name => $prl_name });

    return $prl;
}

=head2 get_prl_from_amq_identifier($amq_identifier) : $prl_row

=cut

sub get_prl_from_amq_identifier {
    my ($amq_identifier) = validated_list(
        \@_,
        amq_identifier => { isa => 'Str'},
    );

    my $prl = get_prl({ amq_identifier => $amq_identifier });

    return $prl;
}

=head2 with_key_defined($key_to_be_enabled): @prl_names

Return list of PRLs that have provided property name enabled (has TRUE value).

=cut

sub with_key_defined {
    my ($prl_configs, $key_to_be_enabled) = pos_validated_list(
        \@_, values( %{ { @prl_configs_param } } ),
        { isa => 'Str'},
    );

    return grep {
        $prl_configs->{$_}{ $key_to_be_enabled }
    } keys %$prl_configs;
}

=head2 without_post_picking_staging_area() : @prl_names

Return a list of PRL names that have the value post_picking_staging_area
turned off.

=cut

sub without_post_picking_staging_area {
    return map { $_->name } get_prls({
        has_staging_area => 0,
    });
}

=head2 with_post_picking_staging_area() : @prl_names

Return a list of PRL names that have the value post_picking_staging_area
turned on.

=cut

sub with_post_picking_staging_area {
    return map { $_-> name } get_prls({
        has_staging_area => 1,
    });
}

=head2 with_webapp_instances() : @prl_names

Return a list of PRL names that have TRUE value for prl_webapp_url.

=cut

sub with_webapp_instances {
    my ($prl_configs) = validated_list(\@_, @prl_configs_param);

    return with_key_defined($prl_configs, 'prl_webapp_url' );
}

=head2 lookup_config_value

Lookup information about a PRL, from another piece of information in the PRL.
Best illustrated with an example:

  ->lookup_config_value({
    from_key   => 'name',
    from_value => 'Full PRL',
    to         => 'amq_queue',
  });

This means: look up the value of the key "amq_queue" for the PRL where
the key "name" eq "Full PRL".

The PRL config name is available to be search on as the key C<name>.

=cut

sub lookup_config_value {
    my %args = validated_hash(
        \@_, @prl_configs_param,
        from_key   => { isa => 'Str' },
        from_value => { isa => 'Str' },
        to         => { isa => 'Str' },
    );

    my %prl_configs = %{$args{'prl_configs'}};

    # Developer helper sanity check ... at least one PRL has the target key,
    # right?
    my $at_least_one = 0;

    # Short-cut on name
    if ( $args{'from_key'} eq 'name' ) {
        return $prl_configs{ $args{'from_value'} }->{ $args{'to'} };
    }

    my @data = map {{ name => $_, %{ $prl_configs{$_} } }} keys %prl_configs;

    # Brute-force search the others
    foreach my $prl (@data) {
        # If the config has has it in
        if ( exists $prl->{ $args{'from_key'} } ) {
            # Flip the developer sanity check
            $at_least_one++;
            # Is this it?
            return $prl->{ $args{'to'} } if
                $prl->{ $args{'from_key'} } eq $args{'from_value'};
        } else {
            next;
        }
    }

    confess "No PRLs have the config key " . $args{'from_key'}
        unless $at_least_one;
    return;
}

=head2 get_conveyor_destination_id($destination_name) : $destination_id | die

Convert $destination_name (e.g. PackLanes/pack_lane_1) to
$destination_name (e.g. DA.PO01.0000.CCTA01NP02) or die trying.

This is looked up in the config (xtracker_extras_XTDC?.conf) under
PRL/Conveyor/Destinations.

=cut

sub get_conveyor_destination_id {
    my ($destination_name) = @_;
    my ($group, $name) = split(m|/|, $destination_name);
    $group //= "";
    $name  //= "";

    my $conveyor_config = config_var("PRL", "Conveyor");
    my $destination_id
        = $conveyor_config->{Destinations}->{$group}->{$name}
            or confess("Missing config value (/PRL/Conveyor/Destinations/$destination_name)\n");

    return $destination_id;
}

sub pack_lane_routing_prefix {
    return config_var("PRL", "Conveyor")->{PackLaneMessaging}->{routing_prefix};
}

sub pack_lane_status_prefix {
    return config_var("PRL", "Conveyor")->{PackLaneMessaging}->{status_prefix};
}

sub pack_lane_internal_name_from_status_identifier {
    my ($status_identifier) = shift;
    my $status_prefix = pack_lane_status_prefix;
    my $routing_prefix = pack_lane_routing_prefix;
    my $internal_name = $status_identifier;
    $internal_name =~ s/^\Q$status_prefix\E/$routing_prefix/;
    return $internal_name;
}

sub pack_lane_status_identifier_from_internal_name {
    my ($internal_name) = shift;
    my $status_prefix = pack_lane_status_prefix;
    my $routing_prefix = pack_lane_routing_prefix;
    my $status_identifier = $internal_name;
    $status_identifier =~ s/^\Q$routing_prefix\E/$status_prefix/;
    return $status_identifier;
}

=head2 get_webapp_links: $arrayref_of_hashrefs_with_link_info

Return information about links to related PRL web applications.
Each link has "caption" and "url".

=cut

sub get_webapp_links {
    my ($prl_configs) = validated_list(\@_, @prl_configs_param);

    # handle case when PRL section is missed in config, e.g. Distribution centre
    # does not have PRLs
    return [] unless $prl_configs;

    return [
        map {
            +{
                caption => $_,
                url     => lookup_config_value({
                    prl_configs=> $prl_configs,
                    from_key   => 'name',
                    from_value => $_,
                    to         => 'prl_webapp_url',
                }),
            }
        }

        # make sure provided $prl_configs (if any) is passed further down the line
        with_webapp_instances({prl_configs => $prl_configs})
    ];
}

=head2 get_container_max_weight_for_storage_type($storage_type_name): $weight_value

For provided storage type name it returns container maximum weight in correspondent PRL.

If nothing is configured - returns "0".

=cut

sub get_container_max_weight_for_storage_type {
    my ($prl_configs, $storage_type, $stock_status) = validated_list(
        \@_, @prl_configs_param,
        storage_type => { isa => 'Str'},
        stock_status => { isa => 'Str'},
    );

    my $prls_for_current_combination = get_prls_for_storage_type_and_stock_status({
        prl_configs  => $prl_configs,
        storage_type => $storage_type,
        stock_status => $stock_status,
    });

    return 0 unless keys %$prls_for_current_combination;

    my ($config_part) = values %$prls_for_current_combination;

    return $config_part->{container_max_weight} // 0;
}

=head2 get_all_prls() : @prl_rows

Return all of the configured, active PRLs.

=cut

sub get_all_prls {
    my $schema = xtracker_schema;

    return $schema->resultset('Public::Prl')->filter_active->all;
}

=head2 get_number_of_prls : $number_of_prls

Returns the number of currently active PRLs

=cut

sub get_number_of_prls {
    my $schema = xtracker_schema;

    return $schema->resultset('Public::Prl')->filter_active->count;
}

=head1 MOOSE TYPES

=head2 PRLName

A valid PRLName accoring to the config keys.

=cut

my $PRL_NAMES = config_keys();
my %PRLS = map { $_ => 1 } @$PRL_NAMES;
subtype "PRLName",
    as "Str",
    where { $PRLS{ $_ } },
    message {
        "Unknown PRL ($_). Known PRLs: " . join(", ",
            map { qq{"$_"} } @$PRL_NAMES,
        ) . ".\n",
    };

1;

