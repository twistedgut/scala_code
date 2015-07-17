#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use parent 'NAP::Test::Class';
use XTracker::Config::Local qw( config_var );
use XT::Net::CMS::XMLParser;


sub startup : Test(startup => 1) {
    my $self = shift;

    use_ok('XT::Net::CMS::XMLParser');
    $self->{xml_string} = '';
}


sub xml_without_subject : Tests {
    my $self = shift;

    $self->{xml_string} =<<EOF;
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cms>
    <email>
        <entry>
            <key>Text</key>
            <value> <![CDATA[ Template for Plain Text goes here ]]> </value>
        </entry>
        <entry>
            <key>HTML</key>
            <value> <![CDATA[ Template for HTML Version goes here ]]> </value>
        </entry>
    </email>
    <criteria>
        <matched>
            <key>brand</key>
            <value>nap</value>
        </matched>
    </criteria>
</cms>
EOF

    my $expected = {
        is_success => 0
    };
    my $parser = XT::Net::CMS::XMLParser->new({
                xml_string  => $self->{xml_string},
    });
    is_deeply( $parser->parse, $expected, 'Returns Error - when subject is null');
}

sub xml_without_empty_subject : Tests {

    my $self = shift;

    $self->{xml_string} =<<EOF;
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cms>
    <email>
        <entry>
            <key>Text</key>
            <value> <![CDATA[ Template for Plain Text goes here ]]> </value>
        </entry>
        <entry>
            <key>HTML</key>
            <value> <![CDATA[ Template for HTML Version goes here ]]> </value>
        </entry>
    </email>
    <subject></subject>
    <criteria>
        <matched>
            <key>brand</key>
            <value>nap</value>
        </matched>
    </criteria>
</cms>
EOF

    my $expected = {
        is_success => 0,
        subject    => '',
    };
    my $parser = XT::Net::CMS::XMLParser->new({
                xml_string  => $self->{xml_string},
    });
    is_deeply( $parser->parse, $expected, 'Returns Error when subject does not Exists');
}

sub xml_with_text_body : Tests {
    my $self    = shift;
    $self->{xml_string} =<<EOF;
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cms>
    <email>
        <entry>
            <key>TextBody</key>
            <value><![CDATA[ Template for Plain Text goes here ]]></value>
        </entry>
    </email>
    <subject>This is subject</subject>
    <criteria>
        <matched>
            <key>brand</key>
            <value>nap</value>
        </matched>
        <matched>
            <key>language</key>
            <value>de</value>
        </matched>
    </criteria>
</cms>
EOF
   my $expected = {
        is_success  => 1,
        subject     => 'This is subject',
        channel     => 'nap',
        language    => 'de',
        'text'      => ' Template for Plain Text goes here ',
    };
    my $parser = XT::Net::CMS::XMLParser->new({
                xml_string  => $self->{xml_string},
    });

    is_deeply( $parser->parse, $expected, 'Returns Success -  for text only data');

}

sub xml_with_html_body : Tests {
    my $self    = shift;
    $self->{xml_string} =<<EOF;
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cms>
    <email>
        <entry>
            <key>HTMLBody</key>
            <value><![CDATA[ Template for Plain Text goes here ]]></value>
        </entry>
    </email>
    <subject>This is subject</subject>
    <criteria>
        <matched>
            <key>brand</key>
            <value>nap</value>
        </matched>
        <matched>
            <key>language</key>
            <value>de</value>
        </matched>
    </criteria>
</cms>
EOF
   my $expected = {
        is_success  => 1,
        subject     => 'This is subject',
        channel     => 'nap',
        language    => 'de',
        'html'      => ' Template for Plain Text goes here ',
    };
    my $parser = XT::Net::CMS::XMLParser->new({
                xml_string  => $self->{xml_string},
    });

    is_deeply( $parser->parse, $expected, 'Returns Success -  for HTML only data');
}

sub xml_with_invalid_xml : Tests {
    my $self    = shift;

    $self->{xml_string} =<<EOF;
    <email>
        <entry>
            <key>HTMLBody</key>
            <value><![CDATA[ Template for Plain Text goes here ]]></value>
        </entry>
    </email>
    <subject>This is subject</subject>
    <criteria>
        <matched>
            <key>brand</key>
            <value>nap</value>
        </matched>
        <matched>
            <key>language</key>
            <value>de</value>
        </matched>
    </criteria>
</cms>
EOF
    my $expected = {
        is_success  => 0
    };


    my $parser = XT::Net::CMS::XMLParser->new({
                xml_string  => $self->{xml_string},
    });

    is_deeply( $parser->parse, $expected, 'Invalid XML Error while parsing');
}

sub xml_with_valid_data : Tests {
    my $self    = shift;

    $self->{xml_string} =<<EOF;
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cms>
    <email>
        <entry>
            <key>HTMLBody</key>
            <value><![CDATA[ Template for Plain HTML goes here ]]></value>
        </entry>
        <entry>
            <key>TextBody</key>
            <value>Template for Plain Text goes here</value>
        </entry>
    </email>
    <subject>This is subject</subject>
    <criteria>
        <matched>
            <key>brand</key>
            <value>nap</value>
        </matched>
        <matched>
            <key>language</key>
            <value>de</value>
        </matched>
    </criteria>
</cms>
EOF
     my $expected = {
        is_success  => 1,
        subject     => 'This is subject',
        channel     => 'nap',
        language    => 'de',
        'html'      => ' Template for Plain HTML goes here ',
        'text'      => 'Template for Plain Text goes here',
    };

    my $parser = XT::Net::CMS::XMLParser->new({
                xml_string  => $self->{xml_string},
    });

    is_deeply( $parser->parse, $expected, 'Valid XML message');
}

sub xml_with_valid_xml_without_elements : Tests {
    my $self = shift;

    $self->{xml_string} =<<EOF;
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<restful>
    <test>This is test xml</test>
</restful>
EOF
     my $expected = {
        is_success  => 0,
    };

    my $parser = XT::Net::CMS::XMLParser->new({
                xml_string  => $self->{xml_string},
    });

    is_deeply( $parser->parse, $expected, 'Parsed Valid XML');


}

Test::Class->runtests;
