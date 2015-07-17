#!/usr/bin/env perl
use NAP::policy "tt",     'test';


use Test::XTracker::Data;
use Test::XT::Data;

use Data::Dumper;
use XTracker::Config::Local         qw( config_var has_cmsservice );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :branding
                                    );

use_ok( 'XTracker::EmailFunctions', qw(
                            get_and_parse_correspondence_template
                        ) );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

my $data    = Test::XT::Data->new_with_traits(
                                traits  => [
                                        'Test::XT::Data::Channel',
                                        'Test::XT::Data::Customer',
                                        'Test::XT::Data::CorrespondenceTemplate',
                                    ],
                            );

note "Testing get_and_parse_correspondence_template method";
#----------------------------------------------------------
_test_method_without_cms_data( $data, 1 );
#----------------------------------------------------------

done_testing();


sub _test_method_without_cms_data {
    my ( $test_data, $oktodo )      = @_;

    SKIP: {
        skip "_test_method_without_cms_data", 1               if ( !$oktodo );

        note "in '_test_method_without_cms_data'";

        my $schema  = $test_data->schema;

        $schema->txn_do( sub {

            my $config  = \%XTracker::Config::Local::config;
            $config->{CMSService_NAP}{use_service}          = 'no';
            $config->{Customer}{default_contact_language}   = 'en';

            my $NAP_channel = Test::XTracker::Data->channel_for_nap();

            # get a new Customer record to be the base object
            my $customer    = $test_data->customer;

            #create new correspodence email template record
            $test_data->subject('Your order - [% order_number %]');
            $test_data->content(
"Dear [% customer_name %],
We're sorry it is taking longer than usual to process your order. I hope this doesn't cause you too much inconvenience.
Kind regards,
[% operator %]"
                );
            my $template = $test_data->template;

            my $data = {
                order_number  => 12345678,
                customer_name => "TEST User",
                operator      => 'XTracker - it god',
            };

            # check when passed a Template Id that
            # doesn't exist an error is thrown
            throws_ok {
                        get_and_parse_correspondence_template( $schema, -1, {
                                'channel'     => $NAP_channel,
                                'data'        => $data,
                                'base_rec'    => $customer,
                            });
                    }
                    qr/Couldn't find Correspondence Template/i,
                    "'get_and_parse_correspondence_template' got 'Couldn't find Template' message when passed an unknown Template Id";

            my $content = get_and_parse_correspondence_template( $schema, $template->id, {
                                'channel'     => $NAP_channel,
                                'data'        => $data,
                                'base_rec'    => $customer,
                            });

            # check everything got parsed and returned correctly
            my $expected = {
                    template_obj=> $template,
                    from_cms    => 0,
                    language    => config_var('Customer','default_contact_language'),
                    instance    => config_var('XTracker','instance'),
                    country     => '',      # wouldn't know what these are when
                    channel     => '',      # using 'correspondence_templates'
                    content_type=> 'text',
                    subject     => 'Your order - ' . $data->{order_number},
                    content     => "Dear ". $data->{customer_name} . ",\n".
"We're sorry it is taking longer than usual to process your order. I hope this doesn't cause you too much inconvenience.
Kind regards,\n" .
$data->{operator},
                };

            is_deeply( $content, $expected, "'get_and_parse_correspondence_template' returns the Expected content" );

            # Check data has locale object
            ok ( exists $data->{locale_obj}, "Data Hash has key 'locale_obj'");
            isa_ok( $data->{locale_obj}, 'NAP::Locale', "sanity check: Locale Object Exists" );


            # now switch the type of email to being 'html' and check for the differnce
            $template->update( { content_type => 'html' } );
            $template->discard_changes;
            $expected->{content_type}   = 'html';

            $content    = get_and_parse_correspondence_template( $schema, $template->id, {
                                'channel'     => $NAP_channel,
                                'data'        => $data,
                                'base_rec'    => $customer,
                            });
            is_deeply( $content, $expected, "'get_and_parse_correspondence_template' returns the Expected content when type is 'html'" );

            # now clear the 'id_for_cms' field and should still work
            $template->update( { id_for_cms => undef } );
            $template->discard_changes;
            $content    = get_and_parse_correspondence_template( $schema, $template->id, {
                                'channel'     => $NAP_channel,
                                'data'        => $data,
                                'base_rec'    => $customer,
                            });
            is_deeply( $content, $expected, "'get_and_parse_correspondence_template' returns the Expected content when 'id_for_cms' field is empty" );


            # rollback changes
            $schema->txn_rollback();
        } );
    };

    return;

}
