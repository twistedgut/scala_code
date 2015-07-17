package Test::XTracker::Schema::ResultSet::Public::CountrySubdivision;
use NAP::policy "tt", "test", "class";

BEGIN {
    extends 'NAP::Test::Class';
}

use JSON;
sub test_setup : Test( setup => 0 ) {
    my $self = shift;

    note 'Starting the transaction';
    $self->schema->txn_begin;

}

sub test_get_country_subdivision_with_group : Tests {
    my ($self) = @_;

    # get country_id
    my $italy_obj = $self->schema->resultset('Public::Country')->find_by_name('Italy');
    my $peru_obj = $self->schema->resultset('Public::Country')->find_by_name('Peru');


    # Create records in country_subdivision_group table
    my $grp1 = $self->schema->resultset('Public::CountrySubdivisionGroup')->create({ name => 'Group1'});
    my $grp2 = $self->schema->resultset('Public::CountrySubdivisionGroup')->create({ name => 'Group2'});

    # Insert records into country_subdivision table
    $self->schema->resultset('Public::CountrySubdivision')->create(
        {
            country_id => $italy_obj->id,
            name  => 'test_New York',
            country_subdivision_group_id => $grp1->id,
        }
    );
    $self->schema->resultset('Public::CountrySubdivision')->create(
        {
            country_id => $italy_obj->id,
            name  => 'test_Manhattan',
            iso => 'TT',
            country_subdivision_group_id => $grp1->id,
        }
    );
    $self->schema->resultset('Public::CountrySubdivision')->create(
        {

            country_id => $peru_obj->id,
            name  => 'test_London',
        }
    );

    my $result =  $self->schema->resultset('Public::CountrySubdivision')->get_country_subdivision_with_group;

    # Build expected result set
    my $expected1 = {
        'Group1' => [
            methods( name => 'test_Manhattan' ),
            methods( name => 'test_New York' ),
        ],
    };
    my $expected2 = {
        none => [ methods(name => 'test_London' ) ],
    };

    cmp_deeply( $result->{$italy_obj->country}, $expected1, "Data with more than one country subdivision grp is returned correctly" );
    cmp_deeply( $result->{$peru_obj->country}, $expected2, "Data with No Group subdivision name is returned correctly" );
}
sub test_json_data : Test {
    my $self =  shift;

    my $pak_obj = $self->schema->resultset('Public::Country')->find_by_name('Pakistan');
    my $grp   = $self->schema->resultset('Public::CountrySubdivisionGroup')->create({ name => 'TestGroup'});

    $XTracker::Config::Local::config{countries_with_districts_for_ui}{country} = 'Pakistan';


    $self->schema->resultset('Public::CountrySubdivision')->create(
        {
            country_id => $pak_obj->id,
            name  => 'test_Manhattan',
            country_subdivision_group_id => $grp->id,
        }
    );

    $self->schema->resultset('Public::CountrySubdivision')->create(
        {
            country_id => $pak_obj->id,
            name  => 'test_XYZ',
            iso => 'ISO',
            country_subdivision_group_id => $grp->id,
        }
    );

    my $expected = {
        'TestGroup' => [
            { 'test_Manhattan' => 'test_Manhattan'},
            { 'ISO' => 'ISO - test_XYZ' },
         ]
    };


    my $json_result = $self->schema->resultset('Public::CountrySubdivision')->json_country_subdivision_for_ui();
    my $result = decode_json $json_result;
    is_deeply($result->{$pak_obj->country}, $expected, "Json data is as expected");

}


sub test_teardown : Test( teardown => 0 ) {
    my $self = shift;

    note 'Rolling back the transaction';
    $self->schema->txn_rollback;
}
