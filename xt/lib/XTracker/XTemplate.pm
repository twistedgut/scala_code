package XTracker::XTemplate;
use strict;
use warnings;
use base qw( Template );
use HTML::FillInForm;
use Path::Class qw(dir);
use English '-no_match_vars';
use XTracker::Logfile qw( xt_logger );
use XTracker::Session;
use vars qw ( $TT );
use Data::Dump qw( pp );
use XTracker::Constants ':conversions';
use XTracker::Constants::FromDB;
use XTracker::Error;
use XTracker::Config::Local qw( app_root_dir config_var local_timezone local_datetime_format );
use Template::Timer;
use XTracker::Utilities ();
use XTracker::RAVNI_transient 'remove_ravni_disabled_nav';
use NAP::DC::Barcode::Container;
use XTracker::DBEncode qw( encode_it );
use Safe::Isa;

### Subroutine : template                       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #
sub template {
    my ($class, $options) = @_;



    if ($options && keys %$options) {
        return $class->_make_instance($options);
    }

    $TT ||= $class->_make_instance({});

    return $TT;
}

sub _make_instance {
    my ($class, $options) = @_;

    my $compile_dir = dir( config_var('SystemPaths','tt_compile_dir'), $EUID );
    my $config = {
        ENCODING => 'UTF8',
        INCLUDE_PATH => [
            map { app_root_dir . $_ } qw(
                root/base
                root/base/css
                root/base/print
                root/base/ordertracker
                root/base/stocktracker
            )
        ],
        POST_CHOMP  => 0,
        PRE_CHOMP   => 0,
        WRAPPER     => 'shared/layout/wrapper',
        COMPILE_DIR => $compile_dir,
        PLUGIN_BASE => 'NAP::Template::Plugin',
        VARIABLES => {
            config_dirs => {
                map {; $_ => config_var('SystemPaths',"${_}_dir") }
                    qw(
                            barcode
                            document
                            xtdc_base
                            product_images
                    ),
            },
            local_timezone => local_timezone(),
            local_datetime_format => local_datetime_format(),
            local_date => \&XTracker::Utilities::local_date,

            iws_rollout_phase => (config_var('IWS', 'rollout_phase') || 0),
            prl_rollout_phase => (config_var('PRL', 'rollout_phase') || 0),

            # Look up DB constants from the DB
            db_constant      => sub {
                # Constant required
                my $constant = shift;
                $constant = "XTracker::Constants::FromDB::$constant";
                # Nasty soft-ref lookup
                my $value;
                { no strict 'refs'; $value = ${$constant}; } ## no critic(ProhibitNoStrict)
                # Get upset if we couldn't find it
                die "Can't find $constant" unless defined $value;
                # Give it back!
                return $value;
            },
            convert => sub {
                my ( $from, $to, $value ) = @_;
                return $CONVERT{$from}{$to}($value);
            },

            # Container validation in JS (as hash with "container type" => JS regex)
            valid_container_regex => {
                # contains regexp to accept all possible container barcodes
                container_general => NAP::DC::Barcode::Container->valid_javascript_regex_combined,
                # contains regexps to accept any possible Tote barcode, e.g. simple one,
                # one with orientation etc
                tote_general => NAP::DC::Barcode::Container::Tote->valid_javascript_regex_combined,
                # generate entries for each individual container type
                map
                    { $_->type => $_->valid_javascript_regex }
                    NAP::DC::Barcode::Container->concrete_container_classes
            },
        },
        %$options
    };

    # uncomment the following line if you'd like to see Template::Timer
    # timings in your page source
    #$config->{CONTEXT} = Template::Timer->new( $config );

    my $tt = $class->SUPER::new( $config) or die Template->error(), "\n";

    return $tt;
}

sub _ok_blob {
    my $blob = shift;

    return 1
        if ref($blob) =~ m{^Apache};
    return 1
        if ref($blob) =~ m{\bPlack\b};

    return 0;
}


sub process {
    my ($self, $template, $data, $blob) = @_;

    # get sticky page
    my $sticky_page = $data->{sticky_page};

    if (exists $data->{sidenav} && defined $data->{sidenav}) {
        $data->{sidenav} = remove_ravni_disabled_nav($data->{sidenav});
    }

    # dc name
    $data->{DC_NAME} = config_var('DistributionCentre', 'name');

    # Helper sub to conditionally transform our URI into a handheld one
    $data->{hh_uri} = sub {
        XTracker::Utilities::hh_uri(shift, $data->{handheld})
    };

    # only do Apache based stuff if we have an apache object
    if (_ok_blob($blob)) {
        # inject application information into the TT stash
        my $session = XTracker::Session->session;
        $data->{application} = $session->{application};

        # a bit like catalyst ... if we have a "stash" make it available to TT
        if (defined $session->{stash}) {
            $data->{stash} = $session->{stash};
        }

        # allow some pages to reload themselves
        if (exists $session->{stash}{meta_refresh}) {
            $data->{meta_refresh}
                = delete($session->{stash}{meta_refresh});
            xt_info(
                    q{Page will automatically reload in }
                . $data->{meta_refresh}
                . q{ seconds.}
            );
        }

        # automatically push an error information out to TT
        my $xt_error_data = XTracker::Session::prepare_xt_error_for_view(
            $session
        );
        $data->{xt_error} = $xt_error_data
            if (defined $xt_error_data);

        # operator name for header
        $data->{operator_name} = $session->{operator_name};

        # page title
        my $appname = 'XT-' . $data->{DC_NAME};
        if (defined $session->{current_sub_section}) {
            $data->{html_page_title} =
                $session->{current_sub_section}
                . q{ &#8226; }
                . $appname
            ;
        }
        else {
            $data->{html_page_title} = $appname;
        }

        # if we have 'form_data' in the stash, use it to re-fill a form
        if (defined $data->{stash}{form_data}) {
            my ($html, $output, $fif);

            # process the template
            my $status = $self->SUPER::process($template, $data, \$html);

            # fill it out - replacing the blob with straight html-text
            $fif  = HTML::FillInForm->new();
            delete $data->{stash}{form_data}{dbl_submit_token};
            $output = $fif->fill(
                scalarref   => \$html,
                fdat        => delete($data->{stash}{form_data}),
            );

            # save the sticky page HTML if necessary
            if ($sticky_page) {
                $sticky_page->html($output);
                $sticky_page->update;
            }

            # print the output
            $self->_check_unicode(\$output);
            $blob->print($output);
            return;
        }
        else {
        }
    }

    # continue TT processing
    my $status_ok;
    eval {
        my $html = '';
        if ($sticky_page) {
            $status_ok = $self->SUPER::process($template, $data, \$html);
            # update sticky_page row by inserting html
            $sticky_page->html($html);
            $sticky_page->update;
            # and send HTML to browser
            if ($blob->$_can('print')) {
                $self->_check_unicode(\$html);
                $blob->print($html);
            } else {
                # what do we do here? # XXX
            }
        } else {
            if ( $blob->$_can('print') || ( ref( $blob ) eq 'SCALAR' ) ) {
                my $html = '';
                $status_ok = $self->SUPER::process($template, $data, \$html);
                $self->_check_unicode(\$html);

                if ($blob->$_can('print')) {
                    $blob->print( $html );
                }
                else {
                    # SCALAR ref was passed in
                    $$blob = $html;
                }
            }
            else {
                # this won't have any further unicode handling
                $status_ok  = $self->SUPER::process($template, $data, $blob);
            }
        }
    };
    my $e = $@;
    # if we have a sticky page but no HTML, remove it so we never present blank
    # to user
    if ($sticky_page && !$sticky_page->html) {
        $sticky_page->delete;
    }
    if ($e) {
        xt_logger->fatal($e);
        local $@ = $e;
        die;
    }
    if (not $status_ok) {
        xt_logger->fatal($self->error);
        if ($blob->$_can('print')) {
            $blob->print($self->error);
        }
        else {
            die $self->error;
        }
    };

    return;
}

sub _check_unicode {
    my ( $self, $output ) = @_;
    # Yes we really are going to encode it again!
    # We are making sure that we don't output double encoded UTF8 and this
    # horrible hack is here as a last chance measure to prevent anything
    # getting out without passing through the XTracker::DBEncode->encode()
    # method (which calls decode_it internally to avoid double encoding).

    # DO NOT REMOVE THIS CODE WITHOUT KNOWING EXACTLY WHAT YOU ARE DOING!

    # The output is a scalar ref so we can "fix" it in place.
    $$output = encode_it($$output);

    # As we fixed it in place we can simply return true
    return 1;
}

1;
