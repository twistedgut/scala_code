#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::XTracker::Data;
use XTracker::Constants qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw( :authorisation_level );

my $schema = Test::XTracker::Data->get_schema;
isa_ok($schema, 'XTracker::Schema',"Schema Created");

# ---------- Run Tests ----------
test_is_subs( $schema, 1 );
# -------------------------------

done_testing;

#TODO: sub test_initials {}
#TODO: sub test_customer_ref {}
#TODO: sub test send_message {}
#TODO: sub test_check_if_has_role {}

sub test_is_subs {
    my ( $schema, $oktodo ) = @_;

    # Find or Create Authorisation Section.

    my $section = $schema->resultset('Public::AuthorisationSection')->find_or_create( {
        section     => 'TEST',
    } );

    isa_ok( $section, 'XTracker::Schema::Result::Public::AuthorisationSection' );

    # Find or Create Authorisation Sub-Section.

    my $sub_section = $section->sub_section->find_or_create( {
        sub_section => 'SUB-TEST',
        'ord'       => 1,
    } );

    isa_ok( $sub_section, 'XTracker::Schema::Result::Public::AuthorisationSubSection' );

    # Get the Application Oparator.

    my $operator = $schema->resultset('Public::Operator')->find( $APPLICATION_OPERATOR_ID );

    isa_ok( $operator, 'XTracker::Schema::Result::Public::Operator' );

    # Create the Operator Authorisation.

    my $permission = $operator->permissions->find_or_create( {
        authorisation_sub_section_id    => $sub_section->id,
        authorisation_level_id          => $AUTHORISATION_LEVEL__READ_ONLY,
    } );

    isa_ok( $permission, 'XTracker::Schema::Result::Public::OperatorAuthorisation' );

    # Determine tests to run and expected results of methods.
    my $tests = {
        $AUTHORISATION_LEVEL__READ_ONLY => {
            is_read_only    => 1,
            is_operator     => 0,
            is_manager      => 0,
        },
        $AUTHORISATION_LEVEL__OPERATOR => {
            is_read_only    => 1,
            is_operator     => 1,
            is_manager      => 0,
        },
        $AUTHORISATION_LEVEL__MANAGER => {
            is_read_only    => 1,
            is_operator     => 1,
            is_manager      => 1,
        },
    };

    # Run the tests.
    while ( my ( $auth_level, $methods ) = each %$tests ) {

        while ( my ( $method_name, $method_expected ) = each %$methods ) {

            $permission->update( { authorisation_level_id => $auth_level } );

            is(
                $operator->$method_name( 'TEST', 'SUB-TEST' ),
                $method_expected,
                "Operator sub '$method_name' returned correct value ($method_expected) for '" . $permission->auth_level->description . "'"
            );

        }

    }

    # Check the method returns zero if we specify incorrect section and sub-section.
    $permission->update( { authorisation_level_id => $AUTHORISATION_LEVEL__MANAGER } );
    is( $operator->is_manager( 'SUB-TEST', 'TEST' ), 0, 'Incorrect Section/Sub-Subsection' );

    # Delete the data from the database.
    $permission->delete;
    $sub_section->delete;
    $section->delete;

}

