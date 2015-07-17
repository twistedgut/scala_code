package Test::XT::Net::CMS::Wrapper;
use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

use Test::XTracker::Mock::REST::Client;
use XTracker::Config::Local qw( config_var );
use Test::XTracker::Data::CMS;
use REST::Client;
use XT::Net::CMS::Wrapper;

=head1 CLASS METHODS

=head1 METHODS

=cut

sub startup : Test(startup) {
    my $self = shift;
    $self->SUPER::startup;
    $self->{schema}         = Test::XTracker::Data->get_schema();
    $self->{channel}        = Test::XTracker::Data->channel_for_nap();
    $self->{setup_mock_obj} = Test::XTracker::Mock::REST::Client->new();
    $self->{mock}           = $self->{setup_mock_obj}->setup_mock;
    my $config  = \%XTracker::Config::Local::config;
    $config->{CMSService_NAP}{use_service}  = 'yes';
}

sub setup: Test(setup) {
    my $self = shift;
    $self->SUPER::setup;

}

sub get_class_instance {
    my ($self, $args)  = @_;

    my $wrapper_obj = XT::Net::CMS::Wrapper->new({
        channel => $self->{channel},
        %$args,
    });
}

sub test_get_method_with_empty_data : Tests() {
    my $self = shift;
    my $data = { cms => { } };
    my $xml = Test::XTracker::Data::CMS->create_cms_correspondence_template_data($data);
    $self->{setup_mock_obj}->set_responseContent($xml);

    my $cms_obj = $self->get_class_instance({
        language_pref_code => '',
        cms_template_id => '',
    });

     ok(!defined $cms_obj->get() ,"Empty Data - Returns undef" );
}

sub test_default_get_method : Tests() {
    my $self = shift;


    my $xml = Test::XTracker::Data::CMS->create_cms_correspondence_template_data();
    $self->{setup_mock_obj}->set_responseContent($xml);

    my $cms_obj = $self->get_class_instance({
        language_pref_code => '',
        cms_template_id => '',
    });

    my $expected = {
        'is_success' => 1,
        'country'  => 'UK',
        'language' => 'zh',
        'html'     => "Template for HTML Version goes here \x{2603}",
        'subject'  => 'You Order subject line',
        'text'     => "Template for Plain Text goes here \x{2603}",
        'channel'  => 'nap',
        'instance' => 'AM'
     };

    is_deeply ($cms_obj->get(), $expected, "CMS default data is returned correctly" );
}

=head2 test_get_method_with_invalid_language

Test that when XT::Net::CMS::Wrapper is initiated with a language that is
not supported for the channel the language is replaced with the default.

=cut

sub test_get_method_with_invalid_language : Tests() {
    my $self = shift;

    my $xml = Test::XTracker::Data::CMS->create_cms_correspondence_template_data( );
    $self->{setup_mock_obj}->set_responseContent($xml);

    # Enable CMS access for JC channel
    my $old_cms_setting = $XTracker::Config::Local::config{CMSService_JC}->{use_service};
    local $XTracker::Config::Local::config{CMSService_JC}->{use_service} = 'yes';

    my $wrapper_obj = XT::Net::CMS::Wrapper->new({
        channel => Test::XTracker::Data->channel_for_jc,    # We'll use JC channel as they do not support ZH
        language_pref_code  => 'zh',
        cms_template_id => '',
    });

    cmp_ok( $wrapper_obj->language_pref_code,
            'eq',
            'zh',
            'language_pref_code attribute is ZH'
          );


    # We call get ob the wrapper object but we don't care about the result.
    my $result = $wrapper_obj->get();

    # Now test that the language_pref_code attribute on the CMS Wrapper object
    # is the default language and not ZH
    cmp_ok( $wrapper_obj->language_pref_code,
            'eq',
            $self->schema->resultset('Public::Language')->get_default_language_preference->code,
            'language_pref_code attribute is now default and not ZH'
          );

    # Reset the config value to original
    $XTracker::Config::Local::config{CMSService_JC}->{use_service} = $old_cms_setting;
}

sub test_get_method_with_invalid_data : Tests() {
    my $self = shift;

    my $data = {
        cms =>  {
            message_entry => [
                {
                    key => 'html',
                    value => <<HTML
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=iso-8859-1">
<table id="order-main" border="0" cellpadding="0" cellspacing="0" style="font-family:Arial, Helvetica, sans-serif; font-size:14px; font-weight:bold;" width="740">
<tr>
    <!-- did not close td -->
    <td> NET-A-PORTER GROUP LTD Registered Office:<br />
</tr>
</table>
HTML
                 }
            ],
        }
    };

    my $xml = Test::XTracker::Data::CMS->create_cms_correspondence_template_data($data);
    $self->{setup_mock_obj}->set_responseContent($xml);

    my $cms_obj = $self->get_class_instance({
        language_pref_code => '',
        cms_template_id => '',
    });

    ok(!$cms_obj->get() ,"Returns undef" );
}

sub test_get_method_html_with_cdata :Tests() {
    my $self = shift;

    my $data = {
        cms =>  {
            field_subject => 'this is subject',
            message_entry => [
                {
                    key => 'html',
                    value => <<HTML
<![CDATA[<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=iso-8859-1">
<table id="order-main" border="0" cellpadding="0" cellspacing="0" style="font-family:Arial, Helvetica, sans-serif; font-size:14px; font-weight:bold;" width="740">
<tr>
    <!-- did not close td -->
    <td> NET-A-PORTER GROUP LTD Registered Office:<br />
</tr>
</table>]]>
HTML
                 }
            ],
        }
    };

    my $expected =  {
          'subject'    => 'this is subject',
          'is_success'  => 1,
          'language'    => 'en',
          'html' => <<HTML
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=iso-8859-1">
<table id="order-main" border="0" cellpadding="0" cellspacing="0" style="font-family:Arial, Helvetica, sans-serif; font-size:14px; font-weight:bold;" width="740">
<tr>
    <!-- did not close td -->
    <td> NET-A-PORTER GROUP LTD Registered Office:<br />
</tr>
</table>
HTML
        };

    my $xml = Test::XTracker::Data::CMS->create_cms_correspondence_template_data($data);
    $self->{setup_mock_obj}->set_responseContent($xml);
    my $cms_obj = $self->get_class_instance({
        language_pref_code => 'en',
        cms_template_id => '',
    });

    is_deeply ($cms_obj->get(), $expected, "HTML data with CDATA returned correctly" );
}


sub test_get_method_with_html: Tests() {
    my $self = shift;

    my $data = {
        'cms' => {
            'matched_criteria' => [
                {
                    'value' => 'nap',
                    'key' => 'brand'
                },
            ],
            'field_subject' => 'You Order subject line',
            'message_entry' => [
                {
                    'value' => '<![CDATA[Template for HTML Version goes here]]>',
                    'key' => 'HTML'
                }
            ],
        }
     };


    my $xml = Test::XTracker::Data::CMS->create_cms_correspondence_template_data($data);

    $self->{setup_mock_obj}->set_responseContent($xml);

    my $cms_obj = $self->get_class_instance({
        language_pref_code => 'fr',
        cms_template_id => '',
    });

    my $expected = {
        'html'     => 'Template for HTML Version goes here',
        'subject'  => 'You Order subject line',
        'channel'  => 'nap',
         is_success => 1,
        language    => 'fr'
     };


    is_deeply ($cms_obj->get(), $expected, "CMS data with HTML only is returned correctly" );
}

sub test_get_method_with_text: Tests() {
    my $self = shift;

    my $data = {
        'cms' => {
            'matched_criteria' => [
                {
                    'value' => 'nap',
                    'key' => 'brand'
                },
                {
                    key => 'channel',
                    value => 'AM',
                }
            ],
            'field_subject' => 'You Order subject line',
            'message_entry' => [
                {
                    'value' => 'Template for Text Version goes here',
                    'key' => 'Text',
                }
            ],
        }
     };


    my $xml = Test::XTracker::Data::CMS->create_cms_correspondence_template_data($data);

    $self->{setup_mock_obj}->set_responseContent($xml);

    my $cms_obj = $self->get_class_instance({
        language_pref_code => '',
        cms_template_id => '',
    });

    my $expected = {
        'text'     => 'Template for Text Version goes here',
        'subject'  => 'You Order subject line',
        'channel'  => 'nap',
        'instance'  => 'AM',
        is_success => 1,
        language    => ''
     };

    is_deeply ($cms_obj->get(), $expected, "CMS data with  Text only is returned correctly" );
}


sub test_get_method_with_bad_template_data: Tests() {
    my $self = shift;

    # TT template has ELSEIF  which should fail during parsing.
    my $data = {
        cms =>  {
            field_subject => 'this is subject',
            message_entry => [
                {
                    key => 'html',
                    value => <<HTML

[\% IF refund_type == 'card' \%]

As soon as we receive and process your return, we will refund your card. Please note that card refunds can take up to 10 days to show on your statement due to varying processing times between card issuers. [\%   ELSEIF refund_type == 'store_credit' \%]

As soon as we receive and process your return, we will issue your NET-A-PORTER store credit.
[\% END #IF STORE CREDIT \%]
HTML
                 }
            ],
        }
    };

    my $xml = Test::XTracker::Data::CMS->create_cms_correspondence_template_data($data);

    $self->{setup_mock_obj}->set_responseContent($xml);

    my $cms_obj = $self->get_class_instance({
        language_pref_code => '',
        cms_template_id => '',
    });


    ok(!$cms_obj->get() ,"Template with bad data - Returns undef" );

}

sub test_get_method_with_valid_template_data: Tests() {
    my $self = shift;

    my $data = {
        cms =>  {
            field_subject => 'this is subject',
            message_entry => [
                {
                    key => 'html',
                    value => <<HTML

[\% IF refund_type == 'card' \%]

As soon as we receive and process your return, we will refund your card. Please note that card refunds can take up to 10 days to show on your statement due to varying processing times between card issuers. [\%   ELSIF refund_type == 'store_credit' \%]

As soon as we receive and process your return, we will issue your NET-A-PORTER store credit.
[\% END #IF STORE CREDIT \%]
HTML
                 }
            ],
        }
    };

    my $xml = Test::XTracker::Data::CMS->create_cms_correspondence_template_data($data);

    $self->{setup_mock_obj}->set_responseContent($xml);

    my $cms_obj = $self->get_class_instance({
        language_pref_code => '',
        cms_template_id => '',
    });

    my $expected = {
        'language' => '',
        'html' => '
[% IF refund_type == \'card\' %]

As soon as we receive and process your return, we will refund your card. Please note that card refunds can take up to 10 days to show on your statement due to varying processing times between card issuers. [%   ELSIF refund_type == \'store_credit\' %]

As soon as we receive and process your return, we will issue your NET-A-PORTER store credit.
[% END #IF STORE CREDIT %]
',
          'subject' => 'this is subject',
          'is_success' => 1
        };

     is_deeply ($cms_obj->get(), $expected, "Valid Template returns ccorrectly" );

}

