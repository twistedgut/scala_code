#!/usr/bin/env perl
# vim: ts=8 sts=4 et sw=4 sr sta
use NAP::policy "tt",     'test';

=head2 CANDO-2198: Checks Language Welcome Packs

This will test that the the Language Welcome Packs have been set-up on the
correct Channels and for the correct Languages.

=cut

use Test::XTracker::Data;

use XTracker::Config::Local         qw( config_var );
use XTracker::Constants::FromDB     qw( :promotion_class );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', 'Sanity Check' );

my @all_channels = $schema->resultset('Public::Channel')->enabled_channels->all;

my %tests = (
    NAP => {
        languages   => {
            en  => 'en',
            fr  => 'fr',
            de  => 'de',
            zh  => 'zh',
        },
        # settings to exclude when importing
        # all the settings for the config group
        exclude_settings => [ qw(
            exclude_on_product_type
        ) ],
    },
    OUTNET => {
        languages   => {},
    },
    MRP => {
        languages   => {
            DEFAULT => config_var( 'Customer', 'default_language_preference' ),
        },
    },
    JC => {
        languages   => {},
    },
);

foreach my $channel ( @all_channels ) {
    note "Testing: " . $channel->name;

    my $config_section  = $channel->business->config_section;
    my $test            = $tests{ $config_section };

    note "check Languages assigned to Welcome Packs";
    my $promo_rs = $channel->search_related( 'promotion_types',
        {
            'me.name'           => { ILIKE => 'Welcome Pack %' },
            promotion_class_id  => $PROMOTION_CLASS__FREE_GIFT,
        },
    );
    my @got = $promo_rs->search_related('language__promotion_types')
        ->search_related('language')->all;

    my @languages   = sort values %{ $test->{languages} };
    cmp_ok( @got, '==', @languages,
            "Got Expected Number of Language Welcome Packs: " . scalar( @languages ) ) or do {
                note p @languages;
                note $_->code
                    for @got;
            };

    if ( @got ) {
        my @got_languages = sort map { $_->code } @got;
        is_deeply( \@got_languages, \@languages, "and the Languages are as Expected" );

        foreach my $language ( @got ) {
            my $lang_desc    = $language->description;
            my @promos = $promo_rs->search({
                'language.id' => $language->id,
            },{
                join => { 'language__promotion_types' => 'language' },
            })->all;

            for my $promo (@promos) {
                my $name = $promo->name;
                $name =~ s/^Welcome Pack - //;        # remove the Welcome Pack prefix
                like( $lang_desc, qr/${name}/i, "The Language '${lang_desc}' assigned to the Promotion '$name' matches" );
            }
        }
    }

    note "check Languages defined in the System Config for the Sales Channel";
    @got = sort map { $_->get_column('language_code_setting') }
                        $channel->search_related( 'config_groups',
        {
            'me.name'   => 'Welcome_Pack',
            'me.id'     => { '=' => \'config_group_settings.config_group_id' },
            'config_group_settings.setting' => { 'NOT IN' => $test->{exclude_settings} // [] },
        },
        {
            '+select'   => [ qw( config_group_settings.setting ) ],
            '+as'       => [ qw( language_code_setting ) ],
            join        => 'config_group_settings',
        }
    )->all;
    is_deeply( \@got, [ sort keys %{ $test->{languages} } ],
                        "Languages defined under the 'Welcome_Pack' group are as expected" );
}

done_testing;

