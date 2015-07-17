#!/usr/bin/env perl
use NAP::policy     qw( test );

use Test::XTracker::LoadTestConfig;

=head1 NAME

email_unicode_handling.t

=head1 DESCRIPTION

Tests the 'XTracker::EmailFunctions::send_email' function to make sure that
the emails that are sent which have non ASCII characters in are correctly
encoded when they are sent to the Customer.

This test does this by capturing what gets sent to 'smtp' so as to get as
close to the Customer's end as possible so we can be sure we know what the
email Content, including Subject and To & From addresses, will actually
look like when they are sent.

=cut

use XTracker::Config::Local;
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw( :correspondence_templates );

use utf8;
use Encode qw( encode );


# In order to test the 'send_email' method to find out what the email
# looks like, we need to get what actually gets passed to 'smtp' because
# there are various things happening in 'MIME::Lite' (and below) that
# can change the encoding of the strings and so to know what actually
# will be sent in the email we need to get what actually is coming
# out of the process at the end. To do this we are redfining 'syswrite' so
# that we can capture when it is called by 'MIME::Lite' & store what it's sent
my @lines_sent_to_smtp;
BEGIN {
    no warnings "redefine";
    *CORE::GLOBAL::syswrite = sub {
        my @params = @_;

        # un-pack what was passed in
        my ( $fh, $string, $length, $offset ) = @params;

        # save the string that is going to be written
        # but only those that are from 'MIME::Lite'
        my @caller = caller(1);
        if ( $caller[0] =~ m/MIME::Lite/ ) {
            push @lines_sent_to_smtp, $string;
        }

        # syswrite doesn't like undef's passed to it and
        # also can't take an array of params either because
        # it complains about 'Not enough arguments' passed to
        # it, so need to do the following:
        return (
            !defined $length
            ? CORE::syswrite( $fh, $string )
            : (
                defined $offset
                ? CORE::syswrite( $fh, $string, $length, $offset )
                : CORE::syswrite( $fh, $string, $length )
            )
        );
    };
    use warnings "redefine";
};


# XTracker::EmailFunctions send_email() simply returns 1 without
# actually doing anything if this is set to no which it is in a dev env.
$XTracker::Config::Local::config{Email}{send_email} = 'yes';

# if redirect address is set we always use it, so need to delete it
delete $XTracker::Config::Local::config{Email}{redirect_address};

use_ok( 'XTracker::EmailFunctions', 'send_email' );
can_ok( 'XTracker::EmailFunctions', 'send_email' );


my $tests = {
    ASCII => {
        from    => 'From test <from@net-a-porter.com>',
        to      => 'To nap <to@example.com>',
        replyto => 'ReplyTo nap <replyto@example.com>',
        subject => 'Test ASCII',
        msg     => 'Simple ASCII BODY test',
    },
    Sanskrit => {
        from    => 'From_शक्नो  <from@net-a-porter.com>',
        to      => 'To शक्नोम्यत्तुम्@नोexa <to@net-a-porter.com>',
        subject => 'काचं शक्नोम्यत्तुम् । नोपहिनस्ति माम् ॥',
        msg     => 'काचं शक्नोम्यत्तुम् । BODY नोपहिनस्ति माम् ॥',
        replyto => 'ReplyTo शक्नोम्यत्तुम्@ <replyto@net-a-porter.com>',
    },
    Chinese => {
        from    => 'From 我能 <from@net-a-porter.com>',
        to      => 'To 我能吞 <to@example.com>',
        subject => '我能吞下玻璃而不傷身體。',
        msg     => '我能吞下 BODY 玻璃而不伤身体。',
        replyto => 'ReplyTo 我能吞 <replyto@example.com>',
    },
    French => {
        from    => 'From bénéficiaire <from@net-a-porter.com>',
        to      => 'To bénéficiaire <to@example.fr>',
        subject => "Sujet d'être déçus",
        msg     => "Les naïfs ægithales hâtifs pondant à Noël où il BODY gèle sont sûrs d'être déçus en voyant leurs drôles d'œufs abîmés",
        replyto => 'ReplyTo alterné <replyto@example.fr>',
    },
    German => {
        from    => 'From empfänger <from@net-a-porter.com>',
        to      => 'To empfänger <to@example.com>',
        subject => 'Gegenstand Jagdſchloß',
        msg     => "Im finſteren Jagdſchloß am offenen Felsquellwaſſer BODY patzte der affig-flatterhafte kauzig-höfliche Bäcker über ſeinem verſifften kniffligen C-Xylophon.",
        replyto => 'ReplyTo ablösen <replyto@example.de>',
    },
    Greek => {
        from    => 'From ψυχοφθόρα <from@net-a-porter.com>',
        to      => 'To ψυχοφθόρα <to@example.com>',
        subject => 'ξεσκεπάζω τὴν',
        msg     => "ξεσκεπάζω τὴν ψυχοφθόρα BODY βδελυγμία",
        replyto => 'ReplyTo ψυχοφθόρα <replyto@example.com>',
    },
    Russian => {
        from    => 'From фальшивый <from@net-a-porter.com>',
        to      => 'To фальшивый <to@example.com>',
        subject => 'В чащах юга жил-был цитрус?',
        msg     => "В чащах юга жил-был цитрус? BODY Да, но фальшивый экземпляр! ёъ.",
        replyto => 'ReplyTo фальшивый <replyto@net-a-porter.com',
    },
};

my $smtp_fields = {
    from        => 'From: ',
    replyto     => 'Reply-To: ',
    subject     => 'Subject: ',
    to          => 'To: ',
};

# set this if anything fails, but want to use an explicit
# 'BAIL_OUT' call so a message can be given as to why
my $bail_out_flag = 0;

foreach my $test ( sort keys %{ $tests } ) {
    my $expected = $tests->{$test};

    # clean out what's previously been sent
    @lines_sent_to_smtp = ();

    subtest "$test emails behave as expected" => sub {

        my $sent_ok = send_email(
            $expected->{from},
            $expected->{replyto},
            $expected->{to},
            $expected->{subject},
            $expected->{msg},
            undef,      # type
            undef,      # attachments
            undef       # extra arguments
        );
        cmp_ok( $sent_ok, '==', 1, "email was generated ($test)" );

        if ( $sent_ok ) {
            cmp_ok( scalar( @lines_sent_to_smtp ), '>', 0,
                        "Re-Defined - 'syswrite' function capturing data being sent to 'smtp'" )
                            or diag "ERROR - 'syswrite' didn't capture anything being sent - " .
                                    "possible Error MIME::Lite or Net::Cmd have been changed " .
                                    "to not use 'syswrite' to send data to 'smtp'";
        }

        # remove any 'eol' chars from the strings so as
        # to make the parsing for certain fields easier
        my @no_new_lines;
        foreach my $line ( @lines_sent_to_smtp ) {
            chomp( $line );
            $line =~ s/\r//g;
            push @no_new_lines, $line;
        }
        my $mail_sent = join( "\n", @no_new_lines );

        # left in because any debugging will have you end up using them
        #diag "-----------------------------------";
        #diag $mail_sent;
        #diag "-----------------------------------";

        foreach my $field ( sort keys %{ $smtp_fields } ) {
            next    if ( not $expected->{ $field } );

            my $test_field = $smtp_fields->{ $field };

            if ( $mail_sent =~ m/^${test_field}(?<data>.*)$/m ) {
                # We're going to assume that the two encoding are byte-by-byte equivalent
                # If this changes we will need to use unicode normalisation
                is( $+{data}, encode( 'UTF-8', $expected->{ $field } ), "'${field}' field matched correctly (${test})" );
            }
            else {
                fail( "matched '${test_field}' header in message" );
            }
        }

        # get the BODY of the email and what's expected
        $mail_sent      =~ /\n\n(?<body>.*)/s;
        my $expect_body = encode( 'UTF-8', $expected->{msg} );
        like( $+{body}, qr/\Q${expect_body}\E/, "message body as expected ($test)" );
    } or $bail_out_flag = 1;
}


if ( $bail_out_flag ) {
    diag "----------------------------------------------------------------------------------";
    diag "TEST FAILURE - DON'T IGNORE:";
    diag "    This test checks the 'XTracker::EmailFunctions::send_email' function and";
    diag "    its interaction with 'MIME::Lite'. There is a BUG within 'MIME::Lite' that";
    diag "    causes some parts of the Email to be Encoded when they shouldn't be. If this";
    diag "    test has failed it might be because this BUG has been fixed within MIME::Lite";
    diag "    in which case the change made for CANDO-8505/8509 should be reversed or some";
    diag "    other reason could have caused this test to fail, either way you should not";
    diag "    release any code to Production until this issue has been fixed.";
    diag "----------------------------------------------------------------------------------";

    BAIL_OUT( "DON'T RELEASE IF THIS TEST FAILS ($0) - CUSTOMER EMAILS MIGHT CONTAIN GARBAGE IF NON ASCII CHARACTERS ARE IN THEM" );
}

done_testing();
