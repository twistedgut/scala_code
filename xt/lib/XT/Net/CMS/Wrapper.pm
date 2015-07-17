package XT::Net::CMS::Wrapper;
use NAP::policy "tt", "class";


use REST::Client;
use XT::Net::CMS::XMLParser;

use XTracker::Config::Local     qw( config_var has_cmsservice );
use XTracker::Logfile           qw( xt_logger );
use XTracker::Version;
use Template;
use Data::Printer;      # used for dumping data when logging
use MIME::Base64;

=head1 NAME

XT::Net::CMS::Wrapper

=head1 DESCRIPTION

API Client for calling a CMS Service to pull email templates.

=cut

has channel => (
    is       => "ro",
    isa      => "XTracker::Schema::Result::Public::Channel",
    required => 1,
);

has cms_template_id => (
    is        => 'ro',
    isa       => 'Str',
    required  => 1,
);

has instance_name => (
    is         => "ro",
    isa        => "Str",
    default    => sub {
        return lc(config_var("XTracker", "instance"));
    },
    init_arg   => undef,
);

has language_pref_code => (
    is          => "ro",
    isa         => "Str",
    required    => 1,
    writer      => '_set_language_pref_code',
);

has logger => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        return xt_logger();
    },
    init_arg=> undef,
);


sub get {
    my $self = shift;

    # check if cms is switched on in config
    return      if (!has_cmsservice($self->channel->business->config_section)) ;

    # If a language_pref_code is specified (not empty string) but that language
    # is not supported for the channel revert to the default language
    if ( $self->language_pref_code && ! $self->channel->supports_language( $self->language_pref_code ) ) {
        $self->logger->warn( 'Language "'.$self->language_pref_code.'" requested but not supported on this channel. Using system default instead.' );
        my $schema = $self->channel->result_source->schema;
        my $default_language = $schema->resultset('Public::Language')->get_default_language_preference->code;
        $self->_set_language_pref_code( $default_language );
    }

    # build query params
    my $query_params = {
        emailKey            => $self->cms_template_id, # TT_PAYMENT_COMPLETE
        brand               => $self->channel->web_brand_name,# nap/jc/out/mrp $channel->business->name
        channel             => lc( $self->instance_name ), #intl/am
        language            => $self->language_pref_code, # en
    };

    my $xml_string;
    my $return_now=0;
    try {
        # make REST request
        my $client = $self->_make_request($query_params);
        # get content
        if( $self->_handle_responsecode($client) ) {
            $xml_string = $client->responseContent() // '';
        } else {
            $return_now=1;
        }
    }
    catch {
        $self->logger->error(
                                "Couldn't make Request to CMS: " . $_
                                . "\nQRY Params: " . p( $query_params )
                            );
        #fall back to database email templates method
        $return_now=1;
    };
    return if $return_now;

    # parse content
    my $data;
    if ( $xml_string ) {
        try {

            $data = $self->_parse_content($xml_string);

            # bailout if cms does not give us full data
            if( !exists $data->{is_success} ) {
                $return_now=1;
            } elsif( $data->{is_success} == 0  ) {
                $return_now=1;
            } else {
                # make sure language is not null
                if(! exists $data->{language }) {
                    $data->{language} = $self->language_pref_code;
                } elsif ( lc($data->{language} ) eq 'null' ||
                    $data->{language} eq '' )
                {
                    $data->{language} = $self->language_pref_code;
                } else {
                }
           }

            # data validation to test for template parser errors
            $data = $self->_template_validation($data);

            if($data->{is_success} == 0){
                $return_now=1;
            }

         }
         catch {
            $self->logger->error(
                                    "Couldn't Parse XML from CMS: " . $_
                                    . "\nQRY Params: " . p( $query_params )
                                    . "\nXML String: ${xml_string}"
                                );
           $return_now=1;
        };
        return if $return_now;
    }

    return $data;
}

# REST request
sub _make_request {
    my ( $self, $args ) = @_;

    #build the request  url
    my $username    = config_var("CMSService",'username');
    my $password    = config_var("CMSService",'password');
    my $headers     = {
        Accept => 'application/xml',
        Authorization => 'Basic '.encode_base64($username . ':' . $password)
    };

    my $timeout     = config_var("CMSService",'timeout');
    my $port        = config_var("CMSService",'port');
    my $url_path    = config_var("CMSService",'url_path');
    my $base_url    = lc(config_var("CMSService",'base_url') // ''); # CMS API url

    die "CMS API host is not defined in config"  unless (defined $base_url);

    $base_url = $base_url . ':' . $port if $port;

    # Make Rest Request
    my $client  = REST::Client->new();
    my $param = $client->buildQuery( $args);
    $client->setHost($base_url);
    #timeout in seconds
    $client->setTimeout( $timeout) if $timeout;

    $client->GET($url_path.$param,$headers);

    return $client;
}

sub _parse_content {
    my ( $self, $xml_str ) = @_;

    my $parser = XT::Net::CMS::XMLParser->new( { xml_string => $xml_str });
    return $parser->parse;
}

sub  _handle_responsecode {
    my ($self, $client ) = @_;

    if($client->responseCode() eq '200' ) {
        $self->logger->debug("Got Back Response from CMS API");
        return 1;
    } else {
        $self->logger->error("CMS API Response Error: " . $client->responseContent());
        return 0;
    }
}

# this function is here to be used as a target for Template's
# ->process method in _template_validation; we used to use
# '/dev/null', but that threw encoding errors since we were writing
# character strings to a filehandle without a binmode. Using a coderef
# that does nothing is much easier and won't ever produce encoding
# issues, since we never leave Perl space
#
# this function will be called with the template output as its only
# parameter
sub _dev_null { }

sub _template_validation {
    my $self    = shift;
    my $data    = shift;
    my $html_flag = (exists $data->{html}) ? 1 : 0;
    my $text_flag = (exists $data->{text}) ? 1 : 0;
    my $msg;
    my $template = Template->new();

    #try processing subject
    my $err;
    try {
        $template->process(\$data->{subject},{ },\&_dev_null) || die $template->error();
        $err=0;
    } catch  {
        $self->logger->error("Subject - template processing error: $_");
        $data->{is_success} = 0;
        $err=1;
    };
    return $data if $err;

    # email body
    if( $html_flag) {
        try {
            $template->process(\$data->{html},{ },\&_dev_null) || die $template->error();
        } catch {
            $self->logger->error("HTML - template processing error: $_");
            delete($data->{html});
        };
    }

    if ( $text_flag ) {
        try {
            $template->process(\$data->{text},{ },\&_dev_null) || die $template->error();
        } catch {
            $self->logger->error("Text - template processing error: $_");
            delete($data->{text});
        };
    }

    if( exists ($data->{html}) || exists ( $data->{text} )) {
        $data->{is_success} = 1;
    } else {
        $data->{is_success} = 0;
    }
    return $data;
}
1;
