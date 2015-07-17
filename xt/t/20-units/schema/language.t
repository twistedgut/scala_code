#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use base 'Test::Class';



use Test::XTracker::Data;
use XTracker::Config::Local qw( config_var );

sub startup :Tests(startup) {
    my $self = shift;
    $self->{schema} = Test::XTracker::Data->get_schema();
}

sub test_get_language_from_code :Tests() {
    my $self = shift;

    my @languages = $self->{schema}->resultset('Public::Language')->search()->all;

    foreach my $language (@languages) {
        my $lang_obj = $self->{schema}->resultset('Public::Language')->get_language_from_code($language->code);

        isa_ok($lang_obj, 'XTracker::Schema::Result::Public::Language');
        is($lang_obj->code, $language->code, 'Correct language returend');
    }
}

sub test_get_default_language_preference :Tests() {
    my $self = shift;

    my $lang_from_config = $self->{schema}->resultset('Public::Language')->search({code => lc(config_var('Customer', 'default_language_preference'))})->first;
    my $lang_from_dbix   = $self->{schema}->resultset('Public::Language')->get_default_language_preference();

    is($lang_from_config->code, $lang_from_dbix->code, 'Correct language returned');
}

Test::Class->runtests();

1;
