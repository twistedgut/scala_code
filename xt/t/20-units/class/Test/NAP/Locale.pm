package Test::NAP::Locale;

use NAP::policy "tt", qw( test );

use parent 'NAP::Test::Class';

use NAP::Locale;
use POSIX;
use Encode;

use XTracker::Config::Local qw( config_var );
use Test::XTracker::Data::Locale qw( get_locale_object );
use Test::XTracker::Data;

sub setup : Test(setup) {
    my $self = shift;
    $self->{old_locale} = config_var('Locale', 'default_locale') ?
        config_var('Locale', 'default_locale')
        : ( $ENV{LANG} ? $ENV{LANG} : 'C' );

    my $loc = POSIX::setlocale(LC_ALL, $self->{old_locale});
    $self->{old_conv} = POSIX::localeconv();
    $self->{default_locales} = {
        de  => 'de_DE',
        fr  => 'fr_FR',
        en  => 'en_US',
        zh  => 'zh_CN',
    };
    $self->schema->txn_begin;
}

sub teardown : Test(teardown) {
    my $self = shift;

    $self->schema->txn_rollback;
}

sub base_locale_class : Tests {
    my $self = shift;
    for my $locale (qw/de_DE de fr_FR fr zh_CN zh/) {
        my $setloc = POSIX::setlocale(LC_ALL, $locale);

        note("Locale is $locale");
        if ( ! $setloc ) {
            note($self->{default_locales}->{$locale});
            $setloc = POSIX::setlocale(LC_ALL, $self->{default_locales}->{$locale});
        }

        die "Cannot call setlocale to " . $locale unless $setloc;
        my $tloc = POSIX::localeconv();

        my $loc = Test::XTracker::Data::Locale->get_locale_object($locale);
        ok($loc, "Locale object initiated to locale : " . $loc->locale);

        ok($loc->old_locale, "Old locale setting defined : " . $loc->old_locale);

        is_deeply($loc->localeconv, $tloc, "$locale localeconv set");

        my ($language) = split(/_/, $locale);
        ok($language eq $loc->language, "Language is set correctly to $language");

        # Set POSIX locale back to default once we have the data we need
        $setloc = POSIX::setlocale(LC_ALL, $self->{old_locale});

        # Test Autoload behaviour
        my $same_returned = $loc->really_unknown_method("UNKNOWN");
        ok("UNKNOWN" eq $same_returned, "Unknown method returns input unchanged");
    }

    my $new_old_locale = config_var('Locale', 'default_locale') ?
        config_var('Locale', 'default_locale')
        : ( $ENV{LANG} ? $ENV{LANG} : 'C' );

    ok($self->{old_locale} eq $new_old_locale, 'Perl locale is what it was when we started');
}

sub verify_old_locale : Tests {
    my $self = shift;
    my $loc = POSIX::setlocale(LC_ALL, $self->{old_locale});
    my $conv = POSIX::localeconv();

    is_deeply($conv, $self->{old_conv}, "localeconv data is as expected");
}

sub test_unsupported_language : Tests() {
    my $self = shift;

    my $channel = Test::XTracker::Data->channel_for_jc;

    my $config_group = $self->schema->resultset('SystemConfig::ConfigGroup')->search( {
        name        => 'Language',
        active      => 1,
        channel_id  => $channel->id,
    } )->first;

    my $setting = $config_group->create_related( 'config_group_settings', {
        active      => 1,
        setting     => 'ZZ',
        value       => 'Off',
    } );

    isa_ok( $setting, 'XTracker::Schema::Result::SystemConfig::ConfigGroupSetting',
                'I have a config setting record' );

    my $locale_obj = Test::XTracker::Data::Locale->get_locale_object('zz', $channel);
    isa_ok( $locale_obj, 'NAP::Locale', 'I get default when I request a NAP::Locale with ZZ');
    cmp_ok( $locale_obj->language,
            'eq',
            $self->schema->resultset('Public::Language')->get_default_language_preference->code,
            'The language is the default'
          );
}
