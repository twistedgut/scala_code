#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 Public::CorrespondenceTemplate

Tests methods on the 'Public::CorrespondenceTemplate' Class.

Currently Tests:

    * in_cms_format - Returns the records data in the same format
                      we get when we request an Email from the CMS

=cut

use Test::XTracker::Data;
use Test::XT::Data;

use XTracker::Config::Local         qw( config_var );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema', 'sanity check on schema' );

my $data    = Test::XT::Data->new_with_traits(
                                traits  => [
                                    'Test::XT::Data::CorrespondenceTemplate',
                                ]
                            );

#----------------- Tests -----------------
_test_in_cms_format( $data, 1 );
#-----------------------------------------

done_testing;

# tests the method 'in_cms_format'
sub _test_in_cms_format {
    my ( $data, $oktodo )       = @_;

    SKIP: {
        skip '_test_in_cms_format', 1       if ( !$oktodo );


        note "TESTING: '_test_in_cms_format'";

        my $schema  = $data->schema;

        $schema->txn_do( sub {
            # set a default language to contact Customers with

            # get a new template
            $data->subject('subject');
            $data->content('content');
            $data->content_type('html');
            my $template    = $data->template;

            my $expect  = {
                    html    => 'content',
                    text    => '',
                    subject => 'subject',
                    language=> config_var('Customer','default_language_preference'),
                    instance=> config_var('XTracker','instance'),
                    country => '',
                    channel => '',
                    from_cms=> 0,
                };

            my $got = $template->in_cms_format();
            is_deeply( $got, $expect, "'in_cms_format' method returned Expected result" );

            # rollback changes
            $schema->txn_rollback();
        } );
    };

    return;
}
