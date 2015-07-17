package XT::JQ::DC::Receive::Generate::PDF;
use Moose;

use Data::Dump qw/pp/;
use File::Basename;
use File::Temp;
use HTML::HTMLDoc;
use PDF::WebKit;
use XTracker::EmailFunctions qw( send_email );
use XTracker::Logfile qw( xt_logger );
use XTracker::Config::Local qw( config_var );
use XTracker::Database::Operator qw( get_operator_by_id );

use MooseX::Types::Moose        qw( Str Int Maybe HashRef );
use MooseX::Types::Structured   qw( Dict );

use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';

has payload => (
    is => 'ro',
    isa => Dict[
        output_filename => Str,
        html_content    => Str,
        current_user    => Int,
        pdf_options     => Maybe[HashRef],
        email_options   => Maybe[HashRef],
    ],
    required => 1
);

has logger => (
    is => 'rw',
    default => sub { return xt_logger('XT::JQ::DC'); }
);


sub do_the_task {
    my ($self, $job) = @_;
    my $error   = "";

    # CANDO-1262 : This iteration we are not investing time to
    # fix webkit errors, it seems /lib/site_perl/5.14.2/XT/Common/JQ/Daemon.pm modules
    # throws up error  trying to trap STDERR
    # We are  hardcoding to use HTMLDoc as of now.

    #if (config_var('Printing', 'use_webkit')) {
    if (1 == 2) {

        my $options_hash = {};

        # Translate passed in options to webkit options
        if ( exists  $self->payload->{pdf_options}) {
            $options_hash = _options_translator('webkit',$self->payload->{pdf_options},\$self->payload->{html_content});
        }

        my %pdf_options = ( encoding => 'UTF-8', %{$options_hash} );

        my $html = $self->payload->{html_content};
        my $webkit = PDF::WebKit->new(\$html, %pdf_options);
        $webkit->to_file($self->payload->{output_filename})
            || die('Unable to create PDF file ' .
                   "$self->payload->{output_filename}): $!");
    }
    else {
        my $doc = HTML::HTMLDoc->new(
            mode    => 'file',
            tmpdir  => File::Temp->newdir(),
        );

        # vaguely sane default options
        $doc->set_compression(6);
        $doc->set_jpeg_compression(70);
        # make sure header and footer does not get default values
        $doc->set_footer('.','.','.');
        $doc->set_header('.','.','.');

        # apply any options passed to us
        if (exists $self->payload->{pdf_options}) {

            # Translate passed in options to HTMLDoc options
            my $pdf_options = _options_translator('htmldoc',$self->payload->{pdf_options}, \$self->payload->{html_content});
            my  @values;
            foreach my $option (keys % { $pdf_options } ) {
                @values =  $pdf_options->{$option};
                eval {
                    $doc->$option( @values );
                };
                if (my $e=$@) { warn "$option error: $e"; }
            }

        }

        $doc->set_html_content($self->payload->{html_content});
        my $pdf = $doc->generate_pdf();
        $pdf->to_file($self->payload->{output_filename})
            || die("Unable to create PDF file: $!");
    }

    my $operator = get_operator_by_id( $self->dbh, $self->payload->{current_user} );

    # CCW likes 'nice' email addressed
    my $xt_email =
          'XT-'
        . config_var('DistributionCentre','name')
        . ' <'
        . config_var('Email', 'xtracker_email')
        . '>'
    ;

    my $subject_line;
    if (defined $self->payload->{email_options}{subject}) {
        $subject_line = $self->payload->{email_options}{subject};
    }
    else {
        $subject_line =
              'XT-'
            . config_var('DistributionCentre','name')
            . ': '
            . basename($self->payload->{output_filename})
        ;
    }
    my $message = "$operator->{name},\n\nYour requested file is attached.\n\nRegards,\n\nThe Application";

    send_email(
        $xt_email,  # from
        $xt_email,  # #reply-to
        $operator->{email_address}, # victim
        $subject_line,
        $message,
        'text',
        {
            filename => $self->payload->{output_filename},
            type     => 'application/pdf',
        },
    );

    return ($error);
}

sub check_job_payload {
    my ($self, $job) = @_;
    return ();
}

=head _symbol_translator

    _symbol_translator('PAGE_NUMBER','webkit|htmldoc', ref_to_html_content);

Returns undef if symbol mapping is not found else mapped value.

For HTML::HTMLDoc/Webkit different characters are used for displaying header/footer information

for example:
 C An uppercase "C" indicates that the field should contain the current chapter page number. in HTMLDoc
 1 The number 1 indicates that the field should contain the current page number in decimal format (1, 2, 3, ...)

For webkit
 [page]       Replaced by the number of the pages currently being printed

This method declares the mapping for symbols which would translate to respective package (ie, HTMLDoc or Webkit )

=cut
sub _symbol_translator {
    my $symbol        = shift;
    my $toolkit_type  = shift;

    if ( $toolkit_type !~ /\b(webkit|htmldoc)\b/ ) {
        return;
    }

    # ADD more symbols if required
    my $symbol_hash = {
        'webkit' => {
            'PAGE_NUMBER' => '[page]',
         },
        'htmldoc' => {
            'PAGE_NUMBER' => '$CHAPTERPAGE(1)',
        },
    };

    if( defined $symbol_hash->{$toolkit_type} && exists $symbol_hash->{$toolkit_type}->{$symbol} ) {
        return $symbol_hash->{$toolkit_type}->{$symbol};
    }

    return;
}

sub _analyse_pdf_options_hash_recursively {
    my $pdf_options     = shift;
    my $toolkit_type    = shift;
    # these 2 on the first call are both 'undef'
    my $return_option   = shift // {};
    my $OPTIONS_HASH    = shift;

    # Add more options mapping, if required

    $OPTIONS_HASH //= {
        'webkit' => {
            page       => { size    => 'page_size' },
            header     => {
                'left'   => 'header-left',
                'centre' => 'header-center',
                'right'  => 'header-right',
            },
            footer     => {
                'left'   => 'footer-left',
                'centre' => 'footer-center',
                'right'  => 'footer-right',
            },
        },
        'htmldoc' => {
            page => { size        => 'set_page_size'},
            body_font => { face   => 'set_bodyfont' },
            header    => {
                left   => '<!-- HEADER LEFT "%s" -->',
                centre => '<!-- HEADER CENTER "%s" -->',
                right  => '<!-- HEADER RIGHT "%s" -->',
            },

            footer => {
                left   => '<!-- FOOTER LEFT "%s" -->',
                centre => '<!-- FOOTER CENTER "%s" -->',
                right  => '<!-- FOOTER RIGHT "%s" -->',
            },
        },
    }->{$toolkit_type};

    foreach my $key ( keys %{$pdf_options} ){
        if ( $key ne 'symbol' &&  !exists $OPTIONS_HASH->{$key} ) {
            # doesn't exist for the $toolkit_type
            next;
        } elsif (ref $pdf_options->{$key} eq 'HASH') {
            _analyse_pdf_options_hash_recursively( $pdf_options->{$key}, $toolkit_type, $return_option, $OPTIONS_HASH->{$key} )

        } elsif ( ref $pdf_options->{$key} eq ''){
            my ( $value,$arg );
            if ( $key eq 'symbol' ) {
                $arg   = $OPTIONS_HASH;
                $value = _symbol_translator( $pdf_options->{$key}, $toolkit_type);

                next if !$value ;
            } else {
                $arg = $OPTIONS_HASH->{$key};
                $value = $pdf_options->{$key};
            }
            $return_option->{$arg} = $value;
        } else {
            #ignore it for now
        }

    }

    return $return_option;
}
=head2 _options_translator

    _options_translator('webkit|htmldoc', $hash_to be translated );

Return a hash with keys as options names and value as options value. Also appends
header and footer to html_content for HTMLDoc.

for example for given input hash
    { page_size => 'a4'}

this method return
    { page_size => 'a4'}  for webkit
    { set_page_size => 'a4' } for htmldoc

=cut

sub _options_translator {
    my $toolkit_type   = shift;
    my $pdf_option     = shift;
    my $html_content   = shift;

    if ( $toolkit_type  !~ /\b(webkit|htmldoc)\b/ ) {
        return;
    }

    my $return_options = _analyse_pdf_options_hash_recursively($pdf_option ,$toolkit_type );


    # For HTMLDoc, header and footer options are translated to
    #  <!-- FOOTER RIGHT "TEXT" --> etc and appended to html_content

    if($toolkit_type eq 'htmldoc' ) {
        my $conf_line;
        my @hfkeys = grep { /^<!--/ } keys %{$return_options};

        # put in html doc
        foreach my $line ( @hfkeys ) {
            # delete from options hash
            my $value = delete($return_options->{$line});
            $conf_line .= sprintf($line , $value ) if $value;
        }
        if( $conf_line ) {
            $$html_content = $conf_line.$$html_content;
        }

    }

    return $return_options;
}

1;

__END__

=head1 NAME

XT::JQ::DC::DC::StockControl::Reservation::PreparePDF

=head1 DESCRIPTION

Expected Payload should look like:

    my $job_payload = {
       channel_id      => $channel_id,
       output_filename => $pdf_filename,
       upload_date     => $upload_date,
       current_user    => $handler->operator_id,
    };

=cut
