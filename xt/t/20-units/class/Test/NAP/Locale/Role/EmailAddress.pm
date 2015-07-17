package Test::NAP::Locale::Role::EmailAddress;

use NAP::policy "tt", qw( test );
use feature 'unicode_strings';

use parent 'NAP::Test::Class';

use NAP::Locale;
use Test::XTracker::Data::Locale;

# this is done once, when the test starts
sub startup : Test(startup) {
    my $self = shift;
    $self->SUPER::startup;

    # need to use this schema because
    # rollbacks don't work otherwise
    # and I can't figure out why!
    $self->{schema} = Test::XTracker::Data->get_schema;
}

# this is done before every test
sub setup : Test(setup) {
    my $self = shift;
    $self->SUPER::setup;

    $self->schema->txn_begin;
}

# this is done after every test
sub teardown : Test(teardown) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
}

sub test_email_address : Tests {
    my $self    = shift;

    # create some Test Data
    my $rs  = $self->schema->resultset('Public::LocalisedEmailAddress');
    $rs->search->delete;
    my @test_data   = (
        {
            email_address           => 'test_address.1@net-a-porter.com',
            locale                  => 'fr_FR',
            localised_email_address => 'test_address.1.fr_FR@net-a-porter.com'
        },
        {
            email_address           => 'test_address.1@net-a-porter.com',
            locale                  => 'de_DE',
            localised_email_address => 'test_address.1.de_DE@net-a-porter.com'
        },
    );
    $rs->create( $_ )           foreach ( @test_data );

    # get a German Locale, which we have a Localised Email Address for
    my $locale  = Test::XTracker::Data::Locale->get_locale_object('de');

    my $got = $locale->email_address();
    is( $got, "", "When passed with an 'undef' email address, got Empty string back" );

    $got = $locale->email_address('');
    is( $got, "", "When passed with an Empty email address, got Empty string back" );

    $got    = $locale->email_address('test_address.2@net-a-porter.com');
    is( $got, 'test_address.2@net-a-porter.com', "When asking for an Email Address that has NO Localisations at all, got what was passed in, back" );

    $got    = $locale->email_address('test_address.1@net-a-porter.com');
    is( $got, 'test_address.1.de_DE@net-a-porter.com', "Wanted a Localised Email Address and got a Localised Email Address" );

    # get an Chinese Locale, which we don't have a Localised Email Address for
    $locale = Test::XTracker::Data::Locale->get_locale_object('zn');
    $got    = $locale->email_address('test_address.1@net-a-porter.com');
    is( $got, 'test_address.1@net-a-porter.com', "When asking for an Email Address that doesn't have MY Locale, got what was passed in, back" );
}

#-------------------------------------------------------------
