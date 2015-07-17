package XT::Net::CMS::XMLParser;
use NAP::policy "tt", "class";


use XML::LibXML;

use XTracker::Config::Local qw( config_var );
use XTracker::Logfile qw( xt_logger );

use Carp;

=head1 NAME

XT::Net::CMS::XMLParser

=head1 DESCRIPTION

This is XML parser for CMS Service specifically for parsing Email Templates.

=cut

has xml_string => (
    is          => "ro",
    isa         => "Str",
    required    => 1,
);

sub parse {
    my $self = shift;

    my $parser = XML::LibXML->new();
    my $doc = undef;
    my $data;

    my $err;
    try {
        $doc = $parser->parse_string($self->xml_string);
        $err=0;
    }
    catch {
         xt_logger->error("Failed to parse xml string -  $_" );
         $data->{is_success} = 0;
         $err=1;
    };
    return $data if $err;

    my $root = $doc->getDocumentElement;

    my $mapping = {
        brand   => 'channel',
        channel => 'instance',
    };

    # check for email subject
    # if subject is empty or undef then no point in processing further
    if( $root->exists('subject') ) {
        $data->{subject} = $root->findvalue('subject');
        if( $data->{subject} eq '' ){
            $data->{is_success} = 0;
            xt_logger->error("Parsed CMS XML has empty subject tag" );
            return $data;
        }
    } else {
        $data->{is_success} = 0;
        xt_logger->error("Parsed CMS XML has does not contain subject tag" );
        return $data;
    }

    # creates $data{html/text} = html/text content
    foreach my $entry ( $root->findnodes('email/entry') ) {
        my $key = lc($entry->findvalue('key'));
        $key = "text" if $key eq 'textbody';
        $key = "html" if $key eq 'htmlbody';
        my $value = $entry->findvalue('value');
        $data->{$key} = $value;
    }

    if(exists $data->{html} && $data->{html} ne '' ) {
        $data->{is_success} = 1;
    } elsif( exists $data->{text} && $data->{text} ne '') {
        $data->{is_success} = 1;
    } else {

        xt_logger->error("Parsed CMS XML has missing email body data" );
        $data->{is_success} = 0;
    }

    foreach my $matched ( $root->findnodes('criteria/matched')) {
        my  $key   = lc($matched->findvalue('key'));
        $key = exists $mapping->{$key} ? $mapping->{$key} : $key;
        my $value  = $matched->findvalue('value');
        $data->{$key} = $value;
    }

    return $data;
}


1;
