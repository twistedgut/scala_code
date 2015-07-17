package Test::XT::Service::Designer;
use NAP::policy qw( tt test );
use parent 'NAP::Test::Class';

=head1 NAME

Test::XT::Service::Designer

=head1 DESCRIPTION

Test the XT::Service::Designer class.

Extends L<NAP::Test::Class>.

=head1 TESTS

=head2 test_startup

Make sure the following classes can be used ok

    * XTracker::Database
    * XT::Service::Designer
    * XTracker::Config::Local

Get an L<XTracker::Schema> and L<XTracker::Schema::Result::Public::Channel>
objects for use in the tests.

=cut

sub test_startup : Test( startup => no_plan ) {
    my $self = shift;

    use_ok 'Test::XTracker::Data';
    use_ok 'XT::Service::Designer';
    use_ok 'XTracker::Config::Local';

    $self->{channel_nap} = Test::XTracker::Data->channel_for_nap;
    $self->{channel_mrp} = Test::XTracker::Data->channel_for_mrp;

    isa_ok( $self->{channel_nap},
        'XTracker::Schema::Result::Public::Channel',
        'the nap channel' );

    isa_ok( $self->{channel_mrp},
        'XTracker::Schema::Result::Public::Channel',
        'the mrp channel' );

}

=head1 TESTS

=head2 test_instantiation_ok

Make sure that when we call the C<new> method with all the required parameters,
we get an L<XT::Service::Designer> object with all the default attributes.

=cut

sub test_instantiation_ok :Tests {
    my $self = shift;

    my $service = new_ok( 'XT::Service::Designer',
        [ channel => $self->{channel_nap} ],
        'new called with correct parameters' );

    isa_ok( $service->channel,
        'XTracker::Schema::Result::Public::Channel',
        ' .. and channel attribute' );

    is( $service->dataset,
        'live',
        ' .. and dataset attribute defaults to live' );

    isa_ok( $service->service,
        'NAP::Service::Designer::Solr',
        ' .. and service attribute' );

    isa_ok( $service->log,
        'Log::Log4perl::Logger',
        ' .. and log attribute' );

}

=head2 test_instantiation_missing_channel

Make sure that if we call the C<new> method without the required C<channel>
attribute, an exception is thrown.

=cut

sub test_instantiation_missing_channel : Tests {
    my $self = shift;

    throws_ok( sub{ XT::Service::Designer->new },
        qr/Attribute \(channel\) is required at/,
        'Instantiation fails when channel is missing' );

}

=head2 test_service_attribute_fails_for_missing_config

Make sure that if the config option Solr_* -> designer_service_url, in this
case Solr_NAP -> designer_service_url, is not present an exception is raised
when accessing the service attribute.

The reason we test for an exception when using the service attribute and not
at instantiation, is because the attribute is lazy.

=cut

sub test_service_attribute_fails_for_missing_config : Tests {
    my $self = shift;

    my $config_section = $self->{channel_nap}
        ->business
        ->config_section;

    # Set the config data to pretend it wasn't set.
    local $XTracker::Config::Local::config{"Solr_$config_section"}{designer_service_url} = '';

    # This should succeed, as the service attribute is lazy and won't be
    # built yet.
    my $service = new_ok( 'XT::Service::Designer', [
        channel => $self->{channel_nap} ] );

    throws_ok( sub { $service->service },
        qr/Configuration \[Solr_${config_section} -> designer_service_url\] not set/,
        'The service attribute dies when config not provided' );

}

=head2 test_search

Make sure that for all the following scenarios, the search method behaves as
expected:

B<Parameter Tests>

    * The key parameter is undefined.
    * The key parameter is invalid.
    * The value parameter is undefined.
    * The override parameter is invalid.

B<Single Result Tests>

    * We get the correct single record when a single result is expected.
    * We get the correct single record when a single result is expected and
      we use override to change data we're looking for.
    * Both the above also work for another channel.

B<Multiple Result Tets>

    * We get the correct records when multiple results are expected (tested
      for two different channels).

=cut

sub test_search : Tests {
    my $self = shift;

    my %tests = (
        # Parameter tests.
        'Undefined key' => {
            attributes => [ channel => $self->{channel_nap} ],
            parameters => [ undef, 'value' ],
            expected   => qr/<key> parameter must not be empty/,
        },
        'Invalid key' => {
            attributes => [ channel => $self->{channel_nap} ],
            parameters => [ '', 'value' ],
            expected   => qr/<key> parameter must not be empty/,
        },
        'Undefined value' => {
            attributes => [ channel => $self->{channel_nap} ],
            parameters => [ 'key', undef ],
            expected   => qr/<value> parameter is required/,
        },
        'Invalid override' => {
            attributes => [ channel => $self->{channel_nap} ],
            parameters => [ 'key', 'value', [] ],
            expected   => qr/<override> parameter must be a hash/,
        },
        # Success tests with a single result.
        'Success with single result (NAP)' => {
            attributes => [ channel => $self->{channel_nap} ],
            parameters => [ 'name_en', 'Designer One (en)' ],
            expected   => [ 'en_nap_1' ],
        },
        'Success with single result and override (NAP)' => {
            attributes => [ channel => $self->{channel_nap} ],
            parameters => [ 'name_en', 'Designer One (en)', { keys => [ 'Designer One (fr)' ] } ],
            expected   => [ 'fr_nap_1' ],
        },
        'Success with single result (MRP)' => {
            attributes => [ channel => $self->{channel_mrp} ],
            parameters => [ 'name_en', 'Designer Two (en)' ],
            expected   => [ 'en_mrp_2' ],
        },
        'Success with single result and override (MRP)' => {
            attributes => [ channel => $self->{channel_mrp} ],
            parameters => [ 'name_en', 'Designer Two (en)', { keys => [ 'Designer Two (fr)' ] } ],
            expected   => [ 'fr_mrp_2' ],
        },
        # Success tests with multiple results.
        'Success with multiple results (NAP)' => {
            attributes => [ channel => $self->{channel_nap} ],
            parameters => [ 'id', '1' ],
            expected   => [ 'en_nap_1', 'fr_nap_1' ],
        },
        'Success with multiple results (MRP)' => {
            attributes => [ channel => $self->{channel_mrp} ],
            parameters => [ 'id', '2' ],
            expected   => [ 'en_mrp_2', 'fr_mrp_2' ],
        },
        # Failure tests.
        'Failure' => {
            attributes  => [ channel => $self->{channel_mrp} ],
            parameters  => [ 'id', '1' ],
            expected    => qr/fetch failed due to error: TEST/,
            service_die => 1,
        },
    );

    while ( my ( $name, $test ) = each %tests ) {

        subtest( $name, sub {

            if ( ref( $test->{expected} ) eq 'ARRAY' ) {

                # If we expect an ARRAY, explode it into the entire data
                # structure for each item in the array and set it to 'bag',
                # as the order in each array doesn't matter.
                $test->{expected} = bag(
                    map { $self->data->{ $_ } }
                    @{ $test->{expected} } );

            }

            $self->with_mocked_service_ok(
                $test,
                'search' );

        } );

    }

}

=head2 test_get_restricted_countries_by_designer_id : Tests {

Make sure that for all the following scenarios, the
get_restricted_countries_by_designer_id method behaves as expected:

B<Parameter Tests>

    * The parameter is undefined.
    * The parameter is an empty string.
    * The parameter is not numeric.

B<Single Result Tests>

    * When there is only on match for the ID, we get just the data from that
      record.

B<Multiple Result Tets>

    * When there are multiple matches for an ID (i.e. various languages), we
      get back a unique list of country codes for all the records.

=cut

sub test_get_restricted_countries_by_designer_id : Tests {
    my $self = shift;

    my %tests = (
        # Parameter tests.
        'Undefined ID' => {
            attributes  => [ channel => $self->{channel_nap} ],
            parameters => [ undef ],
            expected   => qr/<id> parameter must be numeric/,
        },
        'Empty ID' => {
            attributes  => [ channel => $self->{channel_nap} ],
            parameters => [ '' ],
            expected   => qr/<id> parameter must be numeric/,
        },
        'Non Numeric ID' => {
            attributes  => [ channel => $self->{channel_nap} ],
            parameters => [ 'TEST' ],
            expected   => qr/<id> parameter must be numeric/,
        },
        # Success with a single result.
        'Single Result From Search' => {
            attributes  => [ channel => $self->{channel_nap} ],
            parameters => [ 3 ],
            expected   => [ 'FR', 'DE' ],
        },
        # Success with multiple results.
        'Multiple Results From Search' => {
            attributes  => [ channel => $self->{channel_nap} ],
            parameters => [ 1 ],
            expected   => [ 'AU', 'NZ', 'DE' ],
        },

    );

    while ( my ( $name, $test ) = each %tests ) {

        subtest( $name, sub {

            if ( ref( $test->{expected} ) eq 'ARRAY' ) {

                # Use 'bag' as the order in each array doesn't matter.
                $test->{expected} = bag(
                    @{ $test->{expected} } );

            }

            $self->with_mocked_service_ok(
                $test,
                'get_restricted_countries_by_designer_id' );

        } );

    }

}

=head1 METHODS

=head2 data

Provides named data for use in the tests.

=cut

sub data {
    my $self = shift;

    my $nap_id = $self->{channel_nap}->id;
    my $mrp_id = $self->{channel_mrp}->id;

    return {
        en_nap_1 => {
            'restricted_countries'              => [ 'AU', 'DE' ],
            'id'                                => '1',
            'status'                            => 'Visible',
            'name_en'                           => 'Designer One (en)',
            'designer_name_en_for_spellcheck'   => 'Designer One (en)',
            'sort_string'                       => 'Designer One (en)',
            'urlKey'                            => 'Designer One (en)',
            'language'                          => 'en',
            'channel_id'                        => $nap_id,
            'key'                               => "en-$nap_id-1",
        },
        fr_nap_1 => {
            'restricted_countries'              => [ 'NZ', 'DE' ],
            'id'                                => '1',
            'status'                            => 'Visible',
            'name_en'                           => 'Designer One (fr)',
            'designer_name_en_for_spellcheck'   => 'Designer One (fr)',
            'sort_string'                       => 'Designer One (fr)',
            'urlKey'                            => 'Designer One (fr)',
            'language'                          => 'fr',
            'channel_id'                        => $nap_id,
            'key'                               => "fr-$nap_id-1",
        },
        en_mrp_2 => {
            'restricted_countries'              => [ 'AU' ],
            'id'                                => '2',
            'status'                            => 'Visible',
            'name_en'                           => 'Designer Two (en)',
            'designer_name_en_for_spellcheck'   => 'Designer Two (en)',
            'sort_string'                       => 'Designer Two (en)',
            'urlKey'                            => 'Designer Two (en)',
            'language'                          => 'en',
            'channel_id'                        => $mrp_id,
            'key'                               => "en-$mrp_id-2",
        },
        fr_mrp_2 => {
            'restricted_countries'              => [ 'NZ' ],
            'id'                                => '2',
            'status'                            => 'Visible',
            'name_en'                           => 'Designer Two (fr)',
            'designer_name_en_for_spellcheck'   => 'Designer Two (fr)',
            'sort_string'                       => 'Designer Two (fr)',
            'urlKey'                            => 'Designer Two (fr)',
            'language'                          => 'fr',
            'channel_id'                        => $mrp_id,
            'key'                               => "fr-$mrp_id-2",
        },
        de_nap_2 => {
            'restricted_countries'              => [ 'FR', 'DE' ],
            'id'                                => '3',
            'status'                            => 'Visible',
            'name_en'                           => 'Designer Three (de)',
            'designer_name_en_for_spellcheck'   => 'Designer Three (de)',
            'sort_string'                       => 'Designer Three (de)',
            'urlKey'                            => 'Designer Three (de)',
            'language'                          => 'de',
            'channel_id'                        => $mrp_id,
            'key'                               => "de-$mrp_id-2",
        },
    };

}

=head2 with_mocked_service_ok( \%test, $method )

Mock the L<NAP::Service::Designer::Solr>C<::fetch> method to either die if
the C<%test> requires, or return matches from the data returned by the C<data>
method based on the C<key_fields> and C<keys> passed to C<fetch>.

Then test the following:

    * We can instantiate a new L<XT::Service::Designer> instance using the
      C<parameters> key in <%test>.
    * If the C<expected> key in C<%test> is a RegEx, make sure an exception
      matching this is thrown, when calling C<$method>.
    * If the C<expected> key in C<%test> is an ArrayRef, make sure the result
      of calling C<$method> returns the same data as given in C<expected>. This
      uses cmp_deeply, so C<expected> can contain any supported functions.

=cut

sub with_mocked_service_ok {
    my ($self,  $test, $method ) = @_;

    # Mock the method.

    no warnings 'redefine', 'once'; ## no critic(ProhibitNoWarnings)
    local *NAP::Service::Designer::Solr::fetch = sub {
        my $this = shift;
        my ( %args ) = @_;

        die 'TEST'
            if $test->{service_die};

        # At present we only support a single key/value pair, so they'll
        # always be the first items in the arrays.
        my $key   = $args{key_fields}->[0];
        my $value = $args{keys}->[0];

        # Simulate the fetch method by searching the data for matches based
        # on the given key/value.
        return [ grep { $_->{ $key } eq $value } values %{ $self->data } ];

    };
    use warnings 'redefine', 'once';

    # Do the test.

    my @parameters =
        @{ $test->{parameters} };

    my $service = new_ok( 'XT::Service::Designer',
        $test->{attributes},
        'the service' );

    if ( ref( $test->{expected} ) eq 'Regexp' ) {
    # A regular expression indicates that the method should fail
    # and the excpetion match the given expression.

        throws_ok( sub { $service->$method( @parameters ) },
            $test->{expected},
            "the $method method dies as expected" );

    } else {
    # Otherwise just compare what we get back.

        cmp_deeply( $service->$method( @parameters ),
            $test->{expected},
            'the result is as expected' );

    }

}

