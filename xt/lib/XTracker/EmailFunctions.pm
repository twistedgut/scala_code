package XTracker::EmailFunctions;

use strict;
use warnings;

use Carp;
use Perl6::Export::Attrs;

use XTracker::Config::Local;
use XTracker::XTemplate ();
use XTracker::Constants::FromDB qw( :correspondence_templates );

use XT::Net::CMS::Wrapper;
use XTracker::DBEncode qw( decode_db decode_it encode_it );

use NAP::Locale;

use Mail::Sendmail;
use MIME::Lite;
use Carp;

use Scalar::Util qw(blessed);

use vars qw($dbh);

### Subroutine : list_templates                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub list_templates :Export(:DEFAULT) {

    my ( $dbh, $department ) = @_;

    my $qry;
    my $sth;

    if ($department) {
        $qry
            = "SELECT * FROM correspondence_templates WHERE department_id = ? ORDER BY name";
        $sth = $dbh->prepare($qry);
        $sth->execute($department);
    }
    else {
        $qry = "SELECT * FROM correspondence_templates ORDER BY name";
        $sth = $dbh->prepare($qry);
        $sth->execute();
    }

    my %templates;

    while ( my $row = $sth->fetchrow_hashref() ) {

        my $key = $$row{id};

        if ($$row{ordering}){ $key = $$row{ordering}; }

        $templates{ $key } = $row;
    }

    return \%templates;
}

### Subroutine : get_email_template             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_email_template :Export(:DEFAULT) {

    my ( $dbh, $template_id, $data, $strict ) = @_;

    my $qry = "SELECT * FROM correspondence_templates WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($template_id);
    my $info = decode_db($sth->fetchrow_hashref);

    my $template = XTracker::XTemplate->template( {
        PRE_CHOMP  => '0',
        POST_CHOMP => '0',
        STRICT => $strict,
    } );
    $template->process( \$$info{content}, {%$data, template_type => 'email'}, \$$info{email_msg} );

    # The TT rendered email is UTF-8 encoded. We need to decode it as we're
    # not finished processing it (and encoding happens at send_email and within TT)

    $$info{content} = decode_it( $$info{email_msg} );

    return $info;
}

=head2 get_and_parse_correspondence_template

    $hash_ref   = get_and_parse_correspondence_template( $schema, $CORRESPONDENCE_TEMPLATES__ID, {
                                    channel     => channel_row,
                                    data        => template data used when parsing the template

                                    base_rec    => This is what you are emailing about such as the
                                                   Return or Shipment and it is used to get the Customer
                                                   object which can then get the Customer's Language preference

                                    # optional TT options
                                    strict      => 1 or 0, defualts to off
                                    pre_chomp   => 1 or 0, defualts to off
                                    post_chomp  => 1 or 0, defualts to off
                                } );

This will get a Template from the CMS first and if that fails then the 'correspondence_templates' table.

It will return a Hash Ref. which amongst other things contains the parsed Subject & Content along with the type
of the content either 'html' or 'text'.

returns:
    {
        template_obj    => 'Public::CorrespondenceTemplate' object
        from_cms        => boolean,             # TRUE if content came from CMS, FALSE if from 'correspondence_templates'
        language        => 'en',                # language the content is in
        country         => 'GB',                # country returned from the CMS, empty if from 'correspondence_templates'
        instance        => 'INTL', 'AM' etc.
        channel         => 'nap',               # channel returned from the CMS, empty if from 'correspondence_templates'
        content_type    => 'text' or 'html'     # used to know what sort of email to send
        subject         => 'TT Processed Subject for the email',
        content         => 'TT Processed Content for the email',
    }

=cut

sub get_and_parse_correspondence_template :Export(:DEFAULT) {
    my ( $schema, $template_id, $args )     = @_;

    # check the parameters passed in
    my $msg = "'" . __PACKAGE__ . "::get_and_parse_correspondence_template' function";
    croak "No Argument Hash Ref passed into ${msg}"             if ( !$args || !ref( $args ) );
    foreach my $param ( qw( channel base_rec ) ) {
        croak "No '${param}' argument passed into ${msg}"       if ( !$args->{ $param } || !ref( $args->{ $param } ) );
    }
    croak "No 'template_id' passed into ${msg}"                 if ( !$template_id );

    my $data_for_template   = $args->{data} // {};
    my $base_rec            = delete $args->{base_rec};

    # optional options for TT Parser
    my $post_chomp  = delete $args->{post_chomp} // 0;
    my $pre_chomp   = delete $args->{pre_chomp} // 0;
    my $strict      = delete $args->{strict} // 0;

    # get the cms id for given template
    my $correspondence_template = $schema->resultset('Public::CorrespondenceTemplate')
                                            ->find( $template_id );
    if ( !$correspondence_template ) {
        croak "Couldn't find Correspondence Template for Id: '" . $template_id . "'";
    }

    # get the Customer from the base object
    # to get the Language preference
    my $customer        = $base_rec->next_in_hierarchy_from_class( 'Customer', 'Customer', { stop_if_me => 1 } );

    if ($customer) {
        $args->{language_pref_code} = $customer->get_language_preference->{language}->code;
    }
    else {
        $args->{language_pref_code} = $schema->resultset('Public::Language')->get_default_language_preference->code;
    }

    my $cms_info;
    # instantiate CMS object if there is a CMS Id
    # allocated to the Correspondence Template
    if ( $correspondence_template->id_for_cms ) {
        $args->{cms_template_id}= $correspondence_template->id_for_cms;
        my $cms_obj             = XT::Net::CMS::Wrapper->new( $args );
        $cms_info               = $cms_obj->get();
    }

    if ( !$cms_info ) {
        # then use the template from database
        $cms_info   = $correspondence_template->in_cms_format();
    }

    # work out what to parse html or text,
    # always choose html over text if available
    my $html            = delete $cms_info->{html};
    my $text            = delete $cms_info->{text};
    my ( $body, $type ) = (
                    $html
                    ? ( $html, 'html' )
                    : ( $text, 'text' )
                  );

    # get a TT parser
    my $tt_parser   = XTracker::XTemplate->template( {
            PRE_CHOMP   => $pre_chomp,
            POST_CHOMP  => $post_chomp,
            STRICT      => $strict,
        } );

    # CANDO-1851: instantiate Locale class
    my $locale;
    if ( $customer ) {
        $locale = NAP::Locale->new(
            # use the language from the template that we've actually got and
            # not the language that we asked for as they might not be the same
            locale      => $cms_info->{language},
            customer    => $customer,
        )
    }

    if ( $locale ) {
        # CANDO-2024
        # We have a template in the target language so localise the data too
        # This must be done BEFORE adding the locale object to the data
        $data_for_template = $locale->localise_product_data( $data_for_template );

        $data_for_template->{'locale_obj'}  = $locale;
    }

    # parse the content of the template
    my $content;
    $tt_parser->process( \$body, { %{ $data_for_template }, template_type => 'email' }, \$content );

    # now parse the subject of the template
    my $subject;
    $tt_parser->process( \$cms_info->{subject}, { %{ $data_for_template }, template_type => 'email_subject' }, \$subject );

    $cms_info->{template_obj}   = $correspondence_template;
    $cms_info->{content_type}   = $type;
    $cms_info->{content}        = decode_it($content); # This is not the app boundary so UTF-8 decode
    $cms_info->{subject}        = decode_it($subject);

    return $cms_info;
}

### Subroutine : send_email                     ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub send_email :Export(:DEFAULT) {
    my ( $from, $replyto, $to, $subject, $msg, $type, $attachments, $email_args ) = @_;
    my $sent = 0;

    unless ( $to && $msg ) {
        carp "Email to address or content not provided";
        return 0;
    }

    if ($to eq 'Not set in LDAP') {
        warn "'To' email address invalid - ($to)";
        return 0;
    }

    # magically make the From: look nicer
    if (defined $from and $from eq config_var('Email', 'xtracker_email')) {
        $from =
            'XT-'
            . config_var('DistributionCentre','name')
            . ' <'
            . config_var('Email', 'xtracker_email')
            . '>'
        ;
    }

    # We need to encode the outgoing email to UTF8.
    # This covers all outgoing emails. encode_it decodes first so we will
    # never get double encoded output.

    # CANDO-8505: removed '$subject' from being encoded as there is a BUG in
    #             MIME::Lite that encodes it again. FYI: the Body ($msg) is
    #             left alone by MIME::Lite so still needs to be encoded here.
    # CANDO-8509: Also removed '$from', '$replyto' & '$to'
    #             from being encoded for the same reason
    foreach my $thing ( \$msg ) {
        $$thing = encode_it($$thing);
    }

    my %mail = (
        "To"       => $to,
        "From"     => $from,
        "Bcc"      => $from,
        "Reply-To" => $replyto,
        "Subject"  => $subject,
        "Message"  => $msg
    );

    my $do_send = config_var('Email', 'send_email');

    # die if no config setting for emails found
    if (not defined $do_send) {
        die "No email settings found in config file";
    }

    # if "send_email=no" return without sending email
    if ($do_send ne 'yes') {
        #warn "send_email=no: $subject\n";
        return 1;
    }

    # If asked to don't 'Bcc' the email
    if ( delete $email_args->{no_bcc} ) {
        delete $mail{Bcc};
    }


    # For debugging purposes, we need to be able to redirect emails
    my $redirect_address = config_var('Email', 'redirect_address');
    if ($redirect_address) {
        $mail{'X-XTracker-Originally-To'} = $to;
        $mail{'To'}                       = $redirect_address;
        # make sure we aren't Bcc-ing anyone
        $mail{'X-XTracker-Originally-Bcc'} = delete $mail{Bcc} // "NOT_SET";
    }

    ## MIME::Lite
    my $lite;

    # html messages
    if ( $type && ( lc($type) eq "html" ) ) {
        $lite = MIME::Lite->new(
            %mail,
            Type        => 'multipart/mixed',
        );
        $lite->attach(
            Type => 'text/html',
            Data => $msg,
        );
    }
    # plain text messages
    else {
        if ( !defined $attachments ) {
            $lite = MIME::Lite->new(
                %mail,
                Type    => 'text/plain',
                Data    => $msg,
            );
        }
        else {
            $lite = MIME::Lite->new(
                %mail,
                Type        => 'multipart/mixed',
            );
            $lite->attach(
                Type => 'text/plain',
                Data => $msg,
            );
        }
    }

    # attach any attachments
    if (defined $attachments) {
        if ( ref($attachments) eq "HASH" ) {
            if ( $attachments->{type} && $attachments->{filename} ) {
                $lite->attach(
                        Type        => $attachments->{type},
                        Path        => $attachments->{filename},
                        Disposition => 'attachment',
                    );
            }
        }
        elsif ( ref($attachments) eq "ARRAY" ) {
            foreach my $attach ( @$attachments ) {
                if ( $attach->{type} && $attach->{filename} ) {
                    $lite->attach(
                            Type        => $attach->{type},
                            Path        => $attach->{filename},
                            Disposition => 'attachment',
                        );
                }
            }
        }
        else {
            carp 'send_email() : $attachments must be ArrayRef or HashRef';
        }
    }

    $lite->attr( 'content-type.charset' => 'UTF-8' );

    # send the message
    my $status = $lite->send('smtp', 'localhost');
    return $status;

    ## Mail::Sendmail
#    if ( lc($type) eq "html" ) {
#        $mail{"Content-Type"} = 'text/html; charset="utf-8"';
#    }
#
#    if (sendmail(%mail)) {
#       $sent = 1;
#    }
#    else{
#       $sent = $Mail::Sendmail::error;
#    }
#
#    return $sent;
}

=head2 send_customer_email

    $booleam    = send_customer_email( {
                                # these map to the parameters of 'send_email'
                                to              => $to_email_address,
                                from            => $from_email_address,
                                reply_to        => $reply_to_email_address defaults to $from_email_address,
                                subject         => $subject_of_the_email,
                                content         => $content_of_the_email,
                                content_type    => 'text' or 'html' (defaults to 'text'),
                                attachments     => { } or [ ] of attachments,

                                # all of these will go in the 'email_args' parameter of 'send_email'
                                another         => argument,
                                ...
                        } );

This is a wrapper around then 'send_email' function to send out Customer emails.

It returns the same as 'send_email'.

=cut

sub send_customer_email :Export(:DEFAULT) {
    my $args        = shift;

    if ( !$args || !ref( $args ) eq 'HASH' ) {
        croak "No Argument HASH passed to '" . __PACKAGE__ . "::send_customer_email'";
    }

    # check the vital arguments are present in $args
    foreach my $arg ( qw(
                        to
                        from
                        subject
                        content
                    ) ) {
        croak "Argument '${arg}' missing or not defined for '" . __PACKAGE__ . "::send_customer_email'"
                                    if ( !exists( $args->{ $arg } ) || !$args->{ $arg } );
    }

    my $to              = delete $args->{to};
    my $from            = delete $args->{from};
    my $reply_to        = delete $args->{reply_to} || $from;
    my $subject         = delete $args->{subject};
    my $content         = delete $args->{content};
    my $content_type    = delete $args->{content_type} || 'text';
    my $attachments     = delete $args->{attachments};

    return send_email(
                        $from,
                        $reply_to,
                        $to,
                        $subject,
                        $content,
                        $content_type,
                        $attachments,
                        $args
                    );
}

### Subroutine : log_order_email                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub log_order_email :Export(:DEFAULT) {

    my ( $dbh, $order_id, $template_id, $operator_id ) = @_;

    my $qry = "INSERT INTO order_email_log VALUES (default, ?, ?, ?, current_timestamp)";
    my $sth = $dbh->prepare($qry);
    $sth->execute($order_id, $template_id, $operator_id);

}


### Subroutine : log_shipment_email             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub log_shipment_email :Export(:DEFAULT) {

    my ( $dbh, $shipment_id, $template_id, $operator_id ) = @_;

    my $qry = "INSERT INTO shipment_email_log VALUES (default, ?, ?, ?, current_timestamp)";
    my $sth = $dbh->prepare($qry);

    $sth->execute($shipment_id, $template_id, $operator_id);

}

### Subroutine : get_email_template_info                 ###
# usage        : $hash_ptr = get_email_template_info(      #
#                       $dbh,                              #
#                       $template_id                       #
#                   );                                     #
# description  : Returns an email template record for a    #
#                given template id.                        #
# parameters   : Database Handle, Email Template Id.       #
# returns      : A pointer to a HASH.                      #

sub get_email_template_info :Export() {

    my ( $dbh, $template_id )   = @_;

    my $qry = "SELECT * FROM correspondence_templates WHERE id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($template_id);

    my $row = $sth->fetchrow_hashref();

    return $row;
}

=head2 send_templated_email

A wrapper method to allow sending of emails using either file or database
based templating - pass 'from_file' or 'from_db' hash for it to decide which
method you mean.

example
send_templated_email(
        to => customercare_email($config_section),
        subject => 'Nominated Day Shipments - SLA Breach',
# where the template is stored in the database - not implemented!!
        from_db => {
            dbh => '',
            template_id => '',
        },
# OR from a file
        from_file => {
            path => $NOMINATEDDAY_BREACH_TEMPLATE,
        },
        stash => {
            shipments => $shipments,
            template_type => 'email',
        },
    );

=cut

sub send_templated_email :Export() {
    my(%args) = @_;

    # compulsory fields
    foreach my $key (qw/to subject/) {
        if (!defined $args{$key}) {
            croak "Missing parameter: $key";
        }
    }

    my $has_from_db = (defined $args{from_db}) || undef;
    my $has_from_file = (defined $args{from_file}) || undef;

    # only want either from_db OR from_file.. everything else is wrong
    if (!(($has_from_db || $has_from_file)
        && !($has_from_db && $has_from_file))) {
        croak "Call can only have either 'from_db' or 'from_file'. Not both";
    }

    my $mesg = $has_from_db
        ? make_message_from_db_template($args{stash},$args{from_db})
        : make_message_from_file_template(
            $args{stash},$args{from_file}->{path});

    send_email(
        $args{from} || undef,
        $args{replyto} || undef,
        $args{to} || undef,
        $args{subject} || undef,
        $mesg || '',
        $args{type} || undef,
        $args{attachments} || undef,
    );
    return $mesg;
}

=head send_internal_email( %args );

A wrapper for send_templated_email to default from to something sensible if
not passed in. See send_templated_email for params

=cut

sub send_internal_email :Export() {
    my(%args) = @_;

    # if not specified default to a reasonably sensible From address
    if (!$args{from}) {
        $args{from} = 'XT-'
            . config_var('DistributionCentre','name')
            . ' <'
            . config_var('Email', 'xtracker_email')
            . '>'
        ;
    }

    return send_templated_email(%args);
}

=head2 send_and_log_internal_email

Sends an email to an internal address and, optionally, calls a log method to
record that the email was sent.

Takes all the inputs send_internal_email does plus a data_object parameter,
which must contain a blessed object with a log_internal_email method. Once
the email is sent that log_internal_email method is called with the input
received by this function.

=cut

sub send_and_log_internal_email :Export() {
    my ( %args ) = @_;

    my $object = delete $args{data_object};

    my $message =  send_internal_email( %args );
    unless ( $message ) {
        require Data::Dumper;
        warn "Failed to send internal email with args: ".
            Data::Dumper->Dump([\%args],['*args']);
    }

    if ( $message && blessed($object) && $object->can('log_internal_email') ) {
        $object->log_internal_email( \%args );
    }

    return $message;
}

sub make_message_from_db_template {
    my($dbh,$stash,$template_id) = @_;

    croak "'make_message_from_db_template' hasn't be implemented yet";
}

sub make_message_from_file_template {
    my($stash,$path) = @_;

    my $template = XTracker::XTemplate->template({
        PRE_CHOMP  => 0,
        POST_CHOMP => 1,
        STRICT => 0,
    });

    my $out = '';
    $template->process($path, $stash, \$out);

    return $out;
}

=head2 send_ddu_email

    $boolean    = send_ddu_email( $schema, $shipment_obj, { template => 'data' }, 'notify' or 'followup' );

This will send out either the DDU Request Notification email to the Customer or the DDU Follow-Up email depending
on the 4th parameter - email type - passed in: 'notify' or 'followup'.

=cut

sub send_ddu_email :Export(:DEFAULT) {
    my ( $schema, $shipment, $template_data, $email_type )  = @_;

    return 0 if( !defined( $email_type ) || ( $email_type !~ m/^(notify|followup)$/ ) );

    # check parameters are what is expected
    if ( !$schema || ref( $schema ) !~ m/Schema$/ ) {
        croak "No Schema Handler was passed to '" . __PACKAGE__ . "::send_ddu_email'";
    }
    if ( !$shipment || ref( $shipment ) !~ m/::Shipment$/ ) {
        croak "No Shipment Object was passed to '" . __PACKAGE__ . "::send_ddu_email'";
    }
    if ( !$template_data || ref( $template_data ) ne 'HASH' ) {
        croak "No Template Data HASH Ref. was passed to '" . __PACKAGE__ . "::send_ddu_email'";
    }

    # decide which template to use
    my $template_id = (
                        $email_type eq 'notify'
                        ? $CORRESPONDENCE_TEMPLATES__DDU_ORDER__DASH__REQUEST_ACCEPT_SHIPPING_TERMS
                        : $CORRESPONDENCE_TEMPLATES__DDU_ORDER__DASH__FOLLOW_UP
                    );

    my $order   = $shipment->order;

    # use a standard placeholder for the Order Number
    $template_data->{order_number}  = ( $order ? $order->order_nr : '' );
    my $email_info  = get_and_parse_correspondence_template( $schema, $template_id, {
                                                        channel     => $shipment->get_channel,
                                                        data        => $template_data,
                                                        base_rec    => $shipment,
                                                } );

    if ( send_customer_email( {
                            to          => $template_data->{email_to},
                            from        => localised_email_address(
                                $schema,
                                ( $order ? $order->customer->locale : '' ),
                                $template_data->{shipping_email},
                            ),
                            subject     => $email_info->{subject},
                            content     => $email_info->{content},
                            content_type=> $email_info->{content_type},
                } ) == 1 ) {
        $shipment->log_correspondence( $template_id, $template_data->{operator_id} );
        return 1;
    }

    return 0;
}

=head2 localised_email_address

    $string = localised_email_address( $schema, $locale, $email_address );
                or
    $string = localised_email_address( $schema, $language, $email_address );

Given an Email Address will return the localised version of it based on the 'locale' or 'language' that
was passed in, if no localised version could be found then what was given is returned.

You can pass either a language 'en' or a locale 'en_GB' and it will search the table 'localised_email_address'
for the suitable localised Email Address. Passing no Locale or Language will just return the email address
passed in.

=cut

sub localised_email_address :Export(:DEFAULT) {
    my ( $schema, $locale, $email_address_in )  = @_;

    return ''                       if ( !$email_address_in );
    return $email_address_in        if ( !$locale );
    # don't have to be that stringent in seeing if an actual email
    # address has been passed in as all that ends up happening is
    # a simple text search, but it's at least got to have an '@' symbol
    return $email_address_in        if ( $email_address_in !~ m/@/ );

    # will return what was passed in if no localisation found
    my $localised_address   = $email_address_in;

    # locales should have have an 'underscore'
    if ( $locale !~ m/_/ ) {
        # if not, assume a language has been passed
        # and put a '%' after it to be used in an 'ILIKE'
        $locale .= '%';
    }

    my $localisation = $schema->resultset('Public::LocalisedEmailAddress')->search(
        {
            'LOWER(email_address)'  => lc( $email_address_in ),
            locale                  => { 'ILIKE' => $locale },
        },
    )->first;

    if ( $localisation ) {
        $localised_address  = $localisation->localised_email_address;
    }

    return $localised_address;
}

1;
