package Test::XTracker::Data::Email;

# routines to test email content

use strict;
use warnings;

use Test::More; # diag
use Test::XTracker::MessageQueue;

use Test::XTracker::Data;
use XTracker::Config::Local     qw( :DEFAULT customercare_email );
use XTracker::EmailFunctions    qw( localised_email_address );

use Test::Config;

use Carp;


=head2 rma_common_email_tests

 Test::XTracker::Data::Email->rma_common_email_tests;

Carries out common tests on the RMA email content

=cut

sub rma_common_email_tests {
    my ($class, $args) = @_;

    my $content     = $args->{content};
    my $premier     = $args->{premier};
    my $business    = $args->{business};
    my $order       = $args->{order};

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $premier_name = ".* Premier";

    unlike($content, qr/^\n\n/sm, "No double blank lines in email content");

#    note $content;
    if ($premier) {
        like($content, qr/$premier_name/, "$premier_name sig");
    } elsif ($business eq 'out') {
        like($content, qr/\Qwww.theoutnet.com\E/, "Outnet sig");
    } elsif ($business eq 'mrp') {
        like($content, qr/\Qwww.mrporter.com\E/, "MR PORTER sig");
    } else {
        unlike($content, qr/$premier_name/, "No $premier_name sig");
    }

    if ($order) {
        my $salutation = $order->branded_salutation;
        like($content, qr/Dear $salutation,/, "Branded salutation '$salutation' found");
    }
}

=head2 rma_common_email_footer_tail_tests

    Test::XTracker::Data::Email->rma_common_email_footer_tail_tests( {
                                                                content => $content,
                                                                $premier => 1 | 0,
                                                                $business => 'nap' | 'out' | 'mrp' | 'jc',
                                                                shipment => $shipment
                                                        } );

Carries out common tests on the footer of RMA emails, such as:
    * Contact Hours
    * Contact Addresses
    * Sign Off
    * survey link
    * ARMA text

=cut

sub rma_common_email_footer_tail_tests {
    my ( $class, $args )    = @_;

    my $content     = $args->{content};
    my $premier     = $args->{premier} || 0;
    my $business    = $args->{business};
    my $shipment    = $args->{shipment};
    my $skip_survey = $args->{survey} || 0;
    my $dc          = config_var( 'DistributionCentre', 'name' );
    my $instance    = config_var( 'XTracker', 'instance' );
    my $channel     = $shipment->order->channel;

    my $config_section  = ( $premier ? 'Premier_' : '' ) . uc $business;
    my $signee          = Test::Config->value( $config_section => 'signee' );
    my $contact_addr    = $premier
                          ? config_var( 'Email_' . $channel->business->config_section, 'premier_email' )
                          : customercare_email( $channel->business->config_section );
    $contact_addr       = localised_email_address(
        Test::XTracker::Data->get_schema,
        $shipment->order->customer->locale,
        $contact_addr,
    );
    my $contact_hours   = Test::Config->value( $config_section => 'contact_hours' );
    my $contact_phone   = Test::Config->value( $config_section => 'contact_phone' );

    my $survey_link;

    if ( $ENV{'HARNESS_VERBOSE'} ) {
        # show the content for visual checks
        diag "=================================";
        diag $content;
        diag "---------------------------------";
    }

    #CANDO-436 check  survey on both NAP sites: DC1 = survey is removed
    #                                  DC2 = survey is still there
    ## The Survey has now been removed from DC2 so No point in checking anything
    # !!! DC3: IF THIS IS RE-ENABLED, USE XT::Rules !!!
    #if ( $business eq 'nap' && !( $skip_survey )) {
    #    if( $dc eq 'DC2') {
    #        my $start_point = 'Please click on the link to take part in our short survey';
    #        $survey_link    = "http://www.snapsurveys.com";
    #        like( $content, qr/$start_point.*$survey_link.*/s, "Survey Link is correct");
    #    } else {
    #        $survey_link    = 'Please click on the link to take part in our short survey http://www.snapsurveys.com';
    #        unlike( $content, qr/.*$survey_link.*/s, "No Survey Link");
    #    }
    #}

    #CANDO-436: Check for ARMA text
    if ( $business =~ /^(nap|mrp|out)$/  && ( $dc eq 'DC2') && $shipment->is_domestic ) {
        my $account_no;
        $account_no = "X27W90" if $business eq 'mrp';
        $account_no = "X248F0" if $business eq 'nap';
        $account_no = "X2480W" if $business eq 'out';


        my $start_point = <<EOF;
1. Book your free collection with UPS before your RMA number expires on \.* by calling 1800 823 7459 and quoting our account number $account_no. Alternatively drop your shipment off at your local UPS store or at any UPS facility.
2. Complete and sign a copy of the returns proforma invoice enclosed with your order and include it with your return.
3. Then attach the UPS label on the outside of the box and leave your package open until the driver has checked the contents.
EOF

        if( $content =~ /"Book you free collection with UPS before"/ ) {
            like( $content, qr/.*$start_point.*/s, "ARMA text is correct");
        }
    }

    # check the email address and contact hours
    # at the bottom of the email

    CASE: {
        # work out the Email Address to check for
        $contact_addr   =~ m/(?<address>.*)\@(?<domain>.*)/;
        my $address     = $+{address};
        my $domain      = $+{domain};
        $address        =~ s/\..*//;        # if there is a '.suffix' in the address, then optionally check for it
        $address        =~ s/${instance}$//i;   # if the instance is at the end of the address then git rid of that too
        my $match_addr  = qr/${address}(\..*)*\@${domain}/;

        if ( $business eq 'nap' ) {
            my $start_point = '(Kind|Best) regards,\r?\n?\r?\n';

            like( $content, qr/$start_point.*${signee}\r?\n(www\.net-a-porter\.com)?/s, "Signee & Web-Site Address correct" );
            like( $content, qr/$start_point.*(For assistance)? $contact_hours/s, "Contact Hours correct" );
            like( $content, qr/$start_point.*or email $match_addr/s, "Contact email address correct" );

            last CASE;
        }
        if ( $business eq 'out' ) {
            my $start_point = '((Kind|Best) regards|Sincerely),\r?\n\r?\n';

            like( $content, qr/$start_point.*${signee}\r?\nwww\.theoutnet\.com/s, "Signee & Web-Site Address correct" );
            like( $content, qr/$start_point.*$contact_hours/s, "Contact Hours correct" );
            like( $content, qr/$start_point.*or email $match_addr/s, "Contact email address correct" );

            last CASE;
        }
        if ( $business eq 'mrp' ) {
            my $start_point = 'Yours sincerely,\r?\n\r?\n';

            like( $content, qr[$start_point.*${signee}\r?\n(http://)?www\.mrporter\.com]s, "Signee & Web-Site Address correct" );
            like( $content, qr/$start_point.*For assistance email $match_addr/s, "Contact email address correct" );
            like( $content, qr/$start_point.*For assistance.* or call .*${contact_hours}\./s, "Contact Hours correct" );
            like( $content, qr/$start_point.*For assistance.* or call ${contact_phone}.*/s, "Contact Phone correct" )   if $premier;


            last CASE;
        }
        if ( $business eq 'jc' ) {
            my $start_point = 'Best wishes,\r?\n\r?\n';

            $signee .= ' Team';

            like( $content, qr/$start_point.*${signee}\r?\nwww\.jimmychoo\.com/s, "Signee & Web-Site Address correct" );
            like( $content, qr/$start_point.*For assistance $contact_hours/s, "Contact Hours correct" );
            like( $content, qr/$start_point.*or email $match_addr/s, "Contact email address correct" );

            last CASE;
        }
    };

    return;
}

=head2 get_active_mq_producer

 my $domain = Test::XTracker::Data::Email->get_active_mq_producer;

Gets the Returns Domain

=cut

sub get_active_mq_producer {
    my ($class) = @_;

    my $schema = Test::XTracker::Data->get_schema;

    my $domain = XT::Domain::Returns->new(
        schema => $schema,
        msg_factory => Test::XTracker::MessageQueue->new({
            schema => $schema,
        }),
    );
    ok($domain,  "Created Returns domain");
    return $domain;
}

=head2 create_localised_email_for_config_setting

    $localised_email_address_obj = Test::XTracker::Data::Email->create_localised_email_for_config_setting( $channel, $email_config_setting, $locale );

For a given Sales Channel and a particular Email config setting create a localised version for the given Locale in the 'localised_email_address'
table. This will either create a new record or give back an existing one. Call 'cleanup_localise_email_address' to remove any Email Addresses created.

This calls 'create_localised_email_address' to actually get/create the email address.

=cut

# store any localised email addresses created so that
# can be removed by calling 'cleanup_localise_email_address'
my @localised_email_recs_created;

sub create_localised_email_for_config_setting {
    my ( $self, $channel, $email_config_setting, $locale )  = @_;

    my $config_section  = $channel->business->config_section;

    my $email_address   = config_var( "Email_${config_section}", $email_config_setting );

    return $self->create_localised_email_address( $email_address, $locale );
}

=head2 create_localised_email_address

    $localised_email_address_obj = Test::XTracker::Data::Email->create_localised_email_address( $email_address, $locale );

Will create a localised version of the given Email Address for the Locale. If one already exists in
the 'localised_email_address' table then that record will be returned else a new one with the Locale
as a prefix will be created.

Call 'cleanup_localise_email_address' to remove any Email Addresses created.

=cut

sub create_localised_email_address {
    my ( $self, $email_address, $locale )   = @_;

    my $schema  = Test::XTracker::Data->get_schema;

    my $local_email_rs  = $schema->resultset('Public::LocalisedEmailAddress');

    $email_address  = lc( $email_address );
    my $rec = $local_email_rs->search( {
        'LOWER(email_address)'  => $email_address,
        locale                  => $locale,
    } )->first;

    if ( !$rec ) {
        # not found an address so create one
        $rec    = $local_email_rs->create( {
            email_address   => $email_address,
            locale          => $locale,
            localised_email_address => "${locale}.${email_address}",
        } );
        push @localised_email_recs_created, $rec->discard_changes;
    }

    return $rec;
}

=head2 cleanup_localised_email_addresses

    Test::XTracker::Data::Email->cleanup_localised_email_addresses;

Removes any Localised Email Addresses created by 'create_localised_email_for_config_setting'.

=cut

sub cleanup_localised_email_addresses {
    my $self    = shift;

    while ( my $rec = pop @localised_email_recs_created ) {
        $rec->discard_changes->delete;
    }

    return;
}

=head2 overwrite_correspondence_template_content

    $template_rec = __PACKAGE__->overwrite_correspondence_template_content( {
        raw_text      => "...",                 # just put this raw text in the template,
                                                # this will go ahead of any 'placeholders'
            and/or
        placeholders  => { ... },               # placeholders that will be used to update the content

        template_id   => $CORRESPONDENCE_TEMPLATE__??? # Id of the Template to use
            or
        template_name => 'Return Received',     # name of Template in 'correspondence_templates' table
        department_id => 1,                     # together with 'template_name' gets the template
                                                # this is optional as 'undef' is an acceptable department id
        # optional, indicate how the original content should be changed
        type_of_change => 'prepend' | 'append' | 'overwrite' (default)
    } );

This will overwrite a Correspondence Template with Content provided in the 'placeholders' key. This will
be used to produce content with labels and placeholders which when the TT document is parsed will get
replaced with data that you can test has been produced, see below for a 'placeholders' example:

'placeholders' example:
    {
        # label_in_document => 'placeholder.data',
        new_payment_data => 'payment.payment_type',
        new_address_data => 'address.country',
        new_name_data    => 'new_name',
    }

would produce content that looks like this:

new_payment_data:[% payment.payment_type +%]
new_address_data:[% address.country +%]
new_name_data:[% new_name +%]

=cut

# stores original content for the templates
my @_original_content;

sub overwrite_correspondence_template_content {
    my ( $self, $args ) = @_;

    my $schema = Test::XTracker::Data->get_schema;

    my $template_name   = $args->{template_name};
    my $department_id   = $args->{department_id};     # this being 'undef' is fine
    my $template_id     = $args->{template_id};
    my $type_of_change  = lc( $args->{type_of_change} || 'overwrite' );
    my $placeholders    = $args->{placeholders};
    my $raw_text        = $args->{raw_text} // '';

    my $template_rs = $schema->resultset('Public::CorrespondenceTemplate');
    my $template;
    if ( $template_id ) {
        $template = $template_rs->find( $template_id );
        croak "Couldn't find Template Id: '${template_id}'"         if ( !$template );
    }
    else {
        $template = $template_rs->find( {
            name          => $template_name,
            department_id => $department_id,
        } );
        croak "Couldn't find Template: '${template_name}' for Department Id: '" . ( $department_id // 'undef' ) . "'"
                            if ( !$template );
    }

    my $content = $raw_text;
    while ( my ( $label, $placeholder ) = each %{ $placeholders } ) {
        $content .= <<CONTENT
${label}:[% ${placeholder} +%]
CONTENT
;
    }

    my $orig_content = $template->content;
    push @_original_content, {
        template_id => $template->id,
        content     => $orig_content,
    };

    # set-up the different types of change
    my %types_of_change = (
        overwrite => sub { return $content },
        prepend   => sub { return $content . "\n" . $orig_content },
        append    => sub { return $orig_content . "\n" . $content },
    );

    # update the content according to what type of change has been asked for
    $template->discard_changes->update( { content => $types_of_change{ $type_of_change }->() } );

    return $template;
}

=head2 restore_correspondence_template_content

    __PACKAGE__->restore_correspondence_template_content();
            or
    __PACKAGE__->restore_correspondence_template_content( { restore_what => 'last' } );

By default will restore ALL content that has been overwritten using the
'overwrite_correspondence_template_content' method since the last time
this method was called.

If you specify the argument "restore_what => 'last'" then only the most recent content
will be restored.

=cut

sub restore_correspondence_template_content {
    my ( $self, $args ) = @_;

    return  if ( !@_original_content );

    my $restore_what = $args->{restore_what} // '';

    my $schema = Test::XTracker::Data->get_schema;

    # either do the most recent or restore ALL (default)
    my $counter = ( lc( $restore_what ) eq 'last' ? 1 : scalar( @_original_content ) );

    TEMPLATE:
    foreach ( 1..$counter ) {
        my $template = pop @_original_content;
        last TEMPLATE   if ( !$template);

        my $rec      = $schema->resultset('Public::CorrespondenceTemplate')->find( $template->{template_id} );
        $rec->update( { content => $template->{content} } );
    }

    return;
}

1;
