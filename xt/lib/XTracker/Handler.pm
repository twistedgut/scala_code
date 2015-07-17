package XTracker::Handler;
use NAP::policy "tt";
# vim: ts=4 sts=4 et sw=4 sr sta
use Log::Log4perl ':easy';

use Plack::App::FakeApache1::Constants qw(:common);

use Class::Load 'load_class';
use HTML::HTMLDoc;
use Lingua::EN::Inflect ();
use Readonly;
use Scalar::Util qw/blessed/;
use Module::Runtime 'require_module';
use XTracker::DblSubmitToken;

use XTracker::Config::Local qw(
    config_section_exists
    config_section_slurp
    config_var
    local_datetime_now
);
use XTracker::Utilities qw/
    parse_url_path
    trim
    unpack_handler_params
    was_sent_ajax_http_header
/;
use XTracker::Constants::FromDB qw( :authorisation_level :business );
use XTracker::Database qw ( :common );
use XTracker::Database::Channel qw ( get_channel_config get_channel );
use XTracker::Error ();
use XTracker::Logfile qw( xt_logger );
use XTracker::Navigation; # qw ( build_sidenav );
use XTracker::PrinterMatrix;
use XTracker::Session ();
use XTracker::XTemplate;
use XTracker::Utilities::ACL    qw( main_nav_option_to_url_path );
use URI;
use URI::Escape;
use XTracker::DBEncode qw(decode_it encode_it);
use Digest::MD5 'md5_hex';
use Carp 'croak';
use XTracker::Cookies;

use XTracker::QueryAnalyzer qw(
    dump_sorted
    store_analyzed_queries
);
use XTracker::Role::WithAMQMessageFactory;

use DBIx::Class::QueryLog::Analyzer;
use DBIx::Class::QueryLog;
use XTracker::QueryLog;

# Modules for use with Job Queue
use XT::JQ::DC;
use XT::Domain::PRLs;

# service methods
Readonly our $SERVICE_PKG_PREFIX => 'XT::Service';

# to be placed in $schema
use XT::AccessControls;

=head1 NAME

XTracker::Handler

=cut

sub new {
    my ( $class, $r, $params ) = @_;

    if (not $r->isa('Plack::App::FakeModPerl1')) {
        die sprintf('%s - unsupported request object type', ref($r));
    }

    my ($dbh, $schema) = (undef, undef);
    my ($request, $referer);

    # some support for our hacked plack object
    $request = $r;
    $referer = $request->headers_in->{referer};

    if ( exists $params->{submit_param} ) {
        my $submit_ok = 0;
        my $submit_val = $request->param($params->{submit_param}) || "";
        if ( exists $params->{submit_value} ) {
            $submit_ok = 1 if ($submit_val eq $params->{submit_value});
        }
        else {
            $submit_ok = 1 if ($submit_val ne "");
        }
        if (!$submit_ok) {
            my $self = {
                no_submit => 1,
                request => $request,
                r => $r
            };
            bless( $self, $class );
            $self->_get_params();
            return $self;
        }
    }

    if ( ($params->{dbh_type}||q{}) eq 'transaction' ) {
        $dbh = transaction_handle();

        # get a DBiC schema as well so all modules can play with it.
        # *** NOTE *** If you use the $schema then make sure you
        # commit & rollback yourself when using 'txn_do' as
        # AutoCommit will be zero (off) when being used in transaction mode
        # and your changes won't be stored unless you do.

        $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    }
    else {
        # get a Schema connection and a Read Only DBH connection as well
        ( $schema, $dbh )   = get_schema_and_ro_dbh('xtracker_schema');
    }

    my $session = XTracker::Session->session();
    # Set the operator_id accessor on the schema object
    $schema->operator_id($session->{operator_id});

    # sticky pages controlled by configuration but can be overridden by request
    # parameter
    my $sticky_pages = ((config_var('StickyPages', 'enable_sticky_pages') // '') eq 'yes');
    my $sticky_override = $request->param('sticky_pages');
    if (defined $sticky_override) {
        $sticky_pages = !!$sticky_override;
    }

    my $data = {
        operator_id      => $session->{operator_id}    || 0,
        username         => $session->{operator_username}       || 0,
        name             => $session->{operator_name}  || 0,
        department_id    => $session->{department_id}  || 0,
        auth_level       => $session->{auth_level}     || 0,
        preferences      => $session->{op_prefs}       || '',
        error            => $request->param( 'error' ) || undef,
        error_msg        => $request->param( 'error_msg' ) || undef,
        display_msg      => $request->param( 'display_msg' ) || undef,
        # The first two keys below have been named in a slightly confusing
        # manner...  uri should be path and path_query should be uri. Won't be
        # replacing all instances of uri, but for the moment, adding another
        # key called path that returns the URI's path
        uri              => $r->parsed_uri->path,
        path_query       => join('?', grep { defined } $r->parsed_uri->path, $r->parsed_uri->equery),
        path             => $r->parsed_uri->path,

        instance         => config_var('XTracker', 'instance'),
        datalite         => ( $request->param('datalite') ? 1 : 0 ),
        sticky_pages     => $sticky_pages,
        handheld         => lc($request->param('view')||'') eq "handheld",
        local_datetime   => local_datetime_now(),
        PL               => \&Lingua::EN::Inflect::PL,
    };

    if ($data->{auth_level} == $AUTHORISATION_LEVEL__MANAGER) {
        $data->{is_manager} = 1;
        $data->{is_operator} = 1;
    } elsif ($data->{auth_level} == $AUTHORISATION_LEVEL__OPERATOR) {
        $data->{is_manager} = undef;
        $data->{is_operator} = 1;
    } else {
        $data->{is_manager} = undef;
        $data->{is_operator} = undef;
    }


    $data->{channel_config} = $schema ?
                              $schema->resultset('Public::Channel')->get_channel_config() :
                              get_channel_config( $dbh );

    # provide links to PRL web applications
    $data->{prl_webapp_urls} = XT::Domain::PRLs::get_webapp_links;

    my $self = {
        r               => $r,
        request         => $request,
        dbh             => $dbh,
        schema          => $schema,
        data            => $data,
        session         => $session,
        template        => XTracker::XTemplate->template(),
        referer         => $referer,
        jobq_onstrike   => config_var("job_queue","on_strike") || 0,
        jobq_allow_scab => config_var("job_queue","allow_scab")|| 0,
        #was_sent_ajax_header => was_sent_ajax_http_header( $r ),
    };

    bless( $self, $class );

    # get params and store them in ->{param_of}
    $self->_get_params();

    delete $self->{param_of}{dbl_submit_token} unless $params->{expose_dbl_submit_token};
    delete $self->{param_of}{csrf_secret} unless $params->{expose_csrf_secret};

    # get an 'XT::AccessControls' object and place
    # it in '$schema' so access to ACL functionality
    # is available wherever '$schema' is in the system
    $schema->clear_acl;     # make sure it is empty first of all
    if ( my $operator = $self->operator ) {
        my $acl = XT::AccessControls->new( {
            operator    => $operator,
            session     => $session,
        } );
        $schema->set_acl( $acl );
        # make ACL available to the Templates
        $self->{data}{acl_obj} = $acl;
    }

    # has there been a request to automatically show a particular channel tab
    if ( exists $self->{param_of}{show_channel} ) {
        my $channel_id  = $self->{param_of}{show_channel};
        $channel_id     =~ s/[^0-9]//g;         # make sure it's a number
        if ( $channel_id ) {
            $self->{data}{auto_show_channel}
                = $schema->resultset('Public::Channel')->get_channel( $channel_id );
        }
    }

    # set our IWS and PRL rollout phases
    #
    # note that we reset the phases on each page request to the configured value,
    # because that's the behaviour that the test harnesses currently expect
    $self->{data}{prl_rollout_phase} = config_var('PRL', 'rollout_phase');
    if (defined $self->{param_of}{override_iws_phase}) {
        $self->{data}{iws_rollout_phase} = $self->{param_of}{override_iws_phase};
    }
    else {
        $self->{data}{iws_rollout_phase} = config_var('IWS', 'rollout_phase');
    }

    # and update the rollout phase values in the session, so that
    # page templates that want to know them can get them
    $self->{session}{application}{iws_rollout_phase} = $self->{data}{iws_rollout_phase};
    $self->{session}{application}{prl_rollout_phase} = $self->{data}{prl_rollout_phase};

    # would we like to analyze queries? (we can only do this with DBIC Schema
    # objects)
    if (defined $self->{schema}) {
        my $do_analysis = config_var('Debugging', 'query_analysis');

        if ($do_analysis) {
            # let people know what we're doing
            xt_logger->debug(
                  q{Analysing queries for: }
                . ref($self->{schema})
            );
            # set up the analyser
            $self->{query_log} = DBIx::Class::QueryLog->new;
            $self->{schema}->storage->debugobj($self->{query_log});
            $self->{schema}->storage->debug(1);
        }
    }

    # Database SQL logging - controlled with LOGLEVEL_SQL
    XTracker::QueryLog->start();

    # stuff the product image URL into the environment, so that
    # templates can have it without faffing about

    # somehow discover if this request is using SSL
    #$self->{data}{ssl} = $ENV{HTTPS}
    #                         || Apache::URI->parse($r)->scheme =~ m/^https/;

    # If we're behind a reverse proxy the protocol of the original request
    # will be eaten. Let's hope this header is set (and stripped) properly in
    # the proxy configuration
    my $forward_protocol    = $r->headers_in->{'X-Forwarded-Protocol'} // '';
    $self->{data}{ssl}
       = ( $forward_protocol eq 'https' ? 1 : 0 );

    my $image_host_url_name = 'image_host_url';

    $image_host_url_name .= '_ssl' if $self->{data}{ssl};

    $self->{data}{image_host_url} = config_var('Images',$image_host_url_name);

    # so, you want to insist on calling it a URI, even though it's
    # obviously a URL?  fine.  knock yourself out, kid.

    $self->{data}{image_host_uri} = $self->{data}{image_host_url};

    # we make sure that the Net::Stomp::Producer singleton uses the
    # same schema connection we do
    my $msg_factory = $self->msg_factory;
    $msg_factory->transformer_args->{schema} = $self->{schema};

    return $self;
}

=head2 uri

Returns a L<URI> object for this request.

=cut

sub uri { $_[0]{request}{request}->uri; }

# this is not a Moose class, so we can't just consume the role
sub msg_factory {
    return XTracker::Role::WithAMQMessageFactory->build_msg_factory;
}

### Subroutine : process_template                                 ###
# usage        : $h->process_template                               #
# description  : An experiment to declutter handler()'s             #
# parameters   :
# returns      : Apache::Constants::OK                              #

sub process_template {
    my ( $self, $params ) = @_;

    if ( $params->{data} ) {
        merge_data( $self, { data => $params->{data} } );
    }
    my $template_name = delete $self->{data}{content};
    warn "No template name is set - expect strange behaviour from this point on"
        unless $template_name;

    my $mainnav = ( $self->acl ? $self->acl->build_main_nav() : undef );

    $self->{data}->{mainnav} = $mainnav;
    $self->{data}->{mainnav_section_subsection_sub} = sub {
        my ($section, $subsection) = @_;
        my $this_section = $mainnav->{$section} or return;

        my @this_subsection = (
            grep { $_->{sub_section} eq $subsection }
            values %$this_section
        ) or return;

        return $this_subsection[0]; # could be undef, if not found
    };

    $self->{data}->{sidenav} = build_sidenav( { navtype => $params->{sidenavtype}, po_id => $self->{data}->{po_id} } )
        if $params->{sidenavtype}; #  hmm bug alert .. seems I've hard coded POP type logic in this generic handler.
    # decide if ACL protection is required for the Sidenav
    $self->{data}->{can_acl_protect_sidenav} = (
        $self->acl
        ? $self->acl->can_protect_sidenav( { call_frame => 1 } )
        : 0
    );


    if (defined $self->{data}{template_type}){
        # do nothing. Use the template type defined in the handler
    }
    elsif (
        ( defined $self->{data}{view}     and uc($self->{data}{view}) eq 'HANDHELD' )
     or ( defined $self->{data}{handheld} and $self->{data}{handheld} == 1 )
    ) {
        # deprecated way of saying it's handheld, but we'll support it for now.
        # better to just set $self->{data}{template_type} to 'handheld' directly
        $self->{data}{template_type} = 'handheld'
    }
    else {
        # default to 'main'
        $self->{data}{template_type} = 'main';
    }

    # send headers
    given (ref($self->{r})) {
        when ('Plack::App::FakeModPerl1') {
            # TODO: work out what we need to do for PSGI
            given ($self->{data}{template_type}) {
                when ('csv') {
                }

                default {
                    $self->{r}->content_type('text/html');
                }
            }
        }

        default {
            warn sprintf(
                'unexpected request object type: %s',
                ref($self->{r})
            );
            given ($self->{data}{template_type}) {
                when ('csv') {
                    $self->{r}->content_type( 'text/csv' );
                }
                default {
                    $self->{r}->content_type( 'text/html' );
                }
            }
        }
    }

    # force save the session. otherwise you get a race condition where a fast
    # user agent may request some other page before we save
    $self->_flush_session;

    # process page template
    $self->{template}->process( $template_name, $self->{data}, $self->{r} );

    return OK;

    # WARNING: This method is intended to be the last to be called before the
    #          calling handler exits.  Just in case this design gets changed,
    #          note the above $self gets directly altered.

}


sub merge_data {
    my ( $self, $params ) = @_;

    # Problem
    #
    # You need to make a new hash with the entries of two existing hashes.
    # Solution
    #
    # Treat them as lists, and join them as you would lists.
    #
    # %merged = (%A, %B);
    #
    # To save memory, loop over the hashes' elements and build a new hash that way:

    my %merged = ();

    while ( my ( $k, $v ) = each( %{$self->{data}} ) ) {
        $merged{$k} = $v;
    }

    while ( my ( $k, $v ) = each( %{$params->{data}} ) ) {
        $merged{$k} = $v;
    }

    $self->{data} = \%merged;
}

sub hh_redirect_to {
    my ($self, $redirect_uri) = @_;
    return $self->redirect_to(
        XTracker::Utilities::hh_uri($redirect_uri, $self->is_viewed_on_handheld)
    );
}

sub redirect_to {
    my ($self, $redirect_url) = @_;
    # See: http://en.wikipedia.org/wiki/List_of_HTTP_status_codes#3xx_Redirection
    $self->{r}{response}->redirect( $redirect_url, 303 );
    return 303; # because some code returns the value from this method
                # e.g. /GoodsIn/ReturnsIn --> check_for_printer()
}

sub _flush_session {
    my ($self) = @_;

    if (defined($self->session)) {
        my $session_object = tied(%{$self->session});
        if (blessed($session_object) && $session_object->can('save')) {
            $session_object->save();
        }
    }
}

=head2 warn_and_redirect($message, $redirect_url) : $http_redirect_response_code

Report $message as a Warn to the user on the page $redirect_url.

=cut

sub warn_and_redirect {
    my ($self, $message, $redirect_url) = @_;

    $self->xt_warn($message);
    return $self->redirect_to($redirect_url);
}

=head2 fatal_and_redirect($error, $redirect_url) : $http_redirect_response_code

Report $error as a Fatal, unexpected error to the user on the page
$redirect_url.

=cut

sub fatal_and_redirect {
    my ($self, $error, $redirect_url) = @_;

    xt_die("Unexpected error: $error");
    return $self->redirect_to($redirect_url);
}

sub auth_level {
    my ( $self, $params ) = @_;
    return $self->{data}->{auth_level};
}


sub department_id {
    my ( $self, $params ) = @_;
    return $self->{data}->{department_id};
}

=head2 operator

Return a DBIC object for the current operator.

=cut

sub operator {
    my ( $self ) = @_;
    return $self->schema->resultset('Public::Operator')->find($self->operator_id);
}

sub operator_id {
    my ( $self, $params ) = @_;
    return $self->{data}->{operator_id};
}

sub pref_channel_id {
    my ( $self, $params ) = @_;
    return $self->{session}->{op_prefs}->{pref_channel_id};
}

# Returns the parameter as a list, guaranteed. List may be empty, have one item
# or have many items. Needs to be called after _get_params below has been called
# as to avoid knowing too much about Apache, we use the preprepared version of
# the params
sub param_as_list {
    my ( $handler, $param ) = @_;

    if ( my $data = $handler->{'param_of'}{$param} ) {
        if ( ref( $data ) eq 'ARRAY' ) {
            return @$data;
        } else {
            return ($data);
        }
    } else {
        return;
    }
}

### Subroutine : _get_params                    ###
# usage        :                                  #
# description  : get  query params from URI       #
# parameters   : $apr                             #
# returns      : \%handler                        #
sub _get_params {
    my ($handler) = @_;
    my $apr = $handler->{request};

    foreach my $param ( $apr->param ) {
        my @values = map { decode_it($_) } $apr->param($param);
        if (scalar(@values) > 1) {
            $handler->{param_of}{$param} = \@values;
        }
        else {
            $handler->{param_of}{$param} = $values[0];
        }

    }

    return;
}

# a method that allows calling of the services available in the new layout
sub call_service {
    my($self,$service,$method) = @_;
    my $fullpkg = $SERVICE_PKG_PREFIX .'::'. $service;
    my $execute_status = undef;

    # make sure we've at least tried to load the package
    try { require_module($fullpkg) }
    catch {
        $self->xt_die("$fullpkg: $_");
        xt_logger->error($_);
        return;
    } or return;

    if (not ${fullpkg}->isa($SERVICE_PKG_PREFIX)) {
        $self->xt_warn("Expecting $SERVICE_PKG_PREFIX based class for ${fullpkg}");

        return;
    }

    # make the call and capture any signals
    eval {

        my $obj = $fullpkg->new({
            schema => $self->{schema},
            handler => $self,
        });

        $execute_status = $obj->execute( $method );
    };

    if ($@) {
        $self->xt_warn($@);
        xt_logger->warn($@);
    }

    return unless defined $execute_status;
    return OK eq $execute_status
         ? $execute_status
         : $self->redirect_to( $execute_status );
}

### Subroutine : create_job                                         ###
# usage        : $job = $handler->create_job (                        #
#                   $funcname,                                        #
#                   $payload,                                         #
#                   $feedback - optional                              #
#                );                                                   #
# description  : This will create a job and put it on the Job Queue.  #
#                If the job can't be put on the queue such as         #
#                invalid payload then this method will crash, so this #
#                method should be called within an 'eval' statement.  #
#                If the 'feedback' parameter is passed then this will #
#                be passed to the job using 'set_feedback_to'.        #
#                If in the <job_queue> entry in the config file       #
#                'on_strike' is set then this function will just      #
#                return a 1 and no job will be attempted to be put on #
#                the queue, if along with 'on_strike' 'allow_scab' is #
#                set then a job will be attempted to be put on the    #
#                queue using an eval statement if this fails then     #
#                this function will still return 1. PLEASE NOTE that  #
#                when on strike and regardless of whether allow scab  #
#                is set a log entry will be made showing that the     #
#                queue is on strike everytime this function is called.#
# parameters   : Name of the Function (or Worker) that will process   #
#                the job e.g. 'Send::WorkerName', The Payload that    #
#                will be sent to the worker, Feedback is an optional  #
#                paramater which can contain one of 3 types:          #
#                   Ptr to HASH  - This will just be sent to          #
#                                  set_feedback_to as is.             #
#                   Ptr to ARRAY - This will be assumed to be a list  #
#                                  of operator id's and put into a    #
#                                  hash with the key 'operators' and  #
#                                  then passed onto set_feedback_to.  #
#                   A SCALAR     - This must be an integer and        #
#                                  assumed to be an operator id,      #
#                                  which will be put into a hash with #
#                                  the key operator in an array ref   #
#                                  and passed onto set_feedback_to.   #
# returns      : A Job Queue Object with:                             #
#                       $job->client                                  #
#                       $job->dsn_hashed                              #
#                       $job->jobid                                   #

sub create_job {
    my ( $handler, $funcname, $payload, $feedback ) = @_;

    my $job_rq  = 1;
    my $feedback_to;

    if ( defined $feedback ) {
        if ( ref($feedback) eq "HASH" ) {
            $feedback_to    = $feedback;
        }
        elsif ( ref($feedback) eq "ARRAY" ) {
            $feedback_to    = { operators => $feedback };
        }
        else {
            $feedback   =~ s/[^0-9]//g;
            $feedback_to= { operators => [ $feedback ] }        if ( $feedback =~ /[0-9]/ );
        }
    }

    TRACE "Enter with ", join', ', ($funcname || 'no funcname'), ($payload || 'no payload'), ($feedback || 'no feedback');

    if ( $handler->{jobq_onstrike} ) {
        my $errmsg  = "JOBQ ON STRIKE";
        if ( $handler->{jobq_allow_scab} ) {
            eval {
                my $job = XT::JQ::DC->new({ funcname => $funcname });
                $job->set_feedback_to( $feedback_to )       if ( defined $feedback_to );
                $job->set_payload( $payload );
                $job_rq = $job->send_job();
                $errmsg .= " BUT SCAB SUCCEEDED: ID ".$job_rq->jobid.", ";
            };
            if ($@) {
                $errmsg .= " AND SCAB FAILED: " ;
            }
        }
        else {
            $errmsg .= " JOB NOT CREATED: ";
        }
        xt_logger->error( $errmsg.$funcname );
    }
    else {
        my $job = XT::JQ::DC->new({ funcname => $funcname });
        $job->set_feedback_to( $feedback_to )       if ( defined $feedback_to );
        $job->set_payload( $payload );
        $job_rq = $job->send_job();

        xt_logger->debug( "JOB Created on Queue: ID ".$job_rq->jobid.", ".$funcname );
    }

    return $job_rq;
}

sub DESTROY {
    my $handler = shift;

    # We don't want the schema object to persist in our msg_factory singleton
    delete $handler->msg_factory->transformer_args->{schema}
        if $handler->msg_factory;

    return unless $handler->{schema};
    return unless config_var('Debugging', 'query_analysis');

    my $ana = DBIx::Class::QueryLog::Analyzer->new(
        { querylog => $handler->{query_log} }
    );
    my @queries = $ana->get_sorted_queries();
    xt_logger->debug(
        q{QUERY ANALYSIS: }
        . scalar(@{ $queries[0] })
        . q{ queries run}
    );

    store_analyzed_queries( $handler, $ana );

    return;
}

# helper methods
sub session {
    return $_[0]->{session};
}

sub schema {
    return $_[0]->{schema};
}

sub dbh {
    return $_[0]->{dbh};
}

sub is_manager {
    return $_[0]->{data}{is_manager};
}

=head2 acl

Returns the 'XT::AccessControls' instance.

=cut

sub acl {
    my $self    = shift;
    return $self->{data}{acl_obj};
}

sub session_stash {
    my $self = shift;

    if (not exists $self->{session}{stash}) {
        $self->{session}{stash} = {};
    }

    return $self->{session}{stash};
}

sub domain {
    my ($self, $name) = @_;

    LOGCONFESS "Name required" unless length $name;

    my $class = "XT::Domain::$name";

    my $domain = $self->{_domains}{$class};
    return $domain if $domain;

    load_class($class);

    $self->{schema} ||= schema_handle;

    my $args = { schema => $self->{schema} };

    # If the domain has a msg_factory attribute, provide it a value
    $args->{msg_factory} = $self->msg_factory
      if $class->meta->has_attribute('msg_factory');

    $domain = $class->new($args);

    return $self->{_domains}{$class} = $domain;
}

=head2 has_printer_station

This method will return a true value if the logged-in operator has a printer
station assigned to the current section.

=head3 NOTE

All new printer framework work should B<not> use this method (see
L<XTracker::Schema::Result::Public::Operator::has_location_for_section>).

=cut

sub has_printer_station {
    my ( $self ) = @_;

    my @levels      = split( m{/}, $self->{data}{uri} );
    my $subsection  = $levels[2]//'';

    my $schema = $self->schema;
    my $preferences = $schema->resultset('Public::OperatorPreference')
        ->find($self->operator_id);
    my ($station) = map { ($_ && $_->printer_station_name) || q{} } $preferences;

    # If the (slightly transformed) station name contains the subsection
    # string, the operator has a printer station selected for the given section
    return 1 if map { $_ =~ m{$subsection} } $station =~ s{[_\s]}{}gr;

    # Some unported printers have a section attribute - if so we can match
    # against that, even if the station name doesn't contain the section
    # string.
    # We don't have a channel_id at this point, so just pass them all as the
    # method dies without it. Rubbish API.
    my $stations_with_section = XTracker::PrinterMatrix->new->get_printers_by_section(
        $subsection, [$schema->resultset('Public::Channel')->get_column('id')->all]
    );

    # We can return true if the station is in the section
    return !!grep { $station eq $_ } @$stations_with_section;
}

=head2 sent_ajax_header

    $boolean = $self->sent_ajax_header;

=cut

sub was_sent_ajax_header {
    my $self    = shift;
    return $self->{was_sent_ajax_header};
}

=head2 printer_station_uri( $channel_id )

This method will build the URI for the printer station page of the current
section.

=cut

sub printer_station_uri {
    my ( $self, $channel_id ) = @_;

    # Defaults to NAP
    $channel_id //= $self->schema
                         ->resultset('Public::Channel')
                         ->search({business_id=>$BUSINESS__NAP})
                         ->slice(0,0)
                         ->single
                         ->id;

    my @levels = split( m{/}, $self->path );
    my ( $section, $subsection ) = map { $levels[$_] || q{} } 1..2;

    return $section && $subsection
         ? join( q{?},
             '/My/SelectPrinterStation',
             "section=$section&subsection=$subsection&channel_id=$channel_id" )
         : q{};
}

=head2 check_for_printer( $channel_id )

This method will redirect you to the printer station page for the current
section if the operator doesn't have a printer station set. Not particularly
intuitively named, but keeping here for legacy reasons.

=cut

sub check_for_printer {
    my ($self,$channel_id)  = @_;

    return $self->has_printer_station
         ? undef
         : $self->redirect_to($self->printer_station_uri($channel_id));
}

=head2 path

Returns this page's path.

=cut

sub path { return $_[0]->{data}{path}; }

=head2 iws_rollout_phase

Returns a number with the rollout phase of the DCEA project:

=over 4

=item *

C<0> is the "pre" phase, where we use XT and Ravni

=item *

C<1> is "Phase 1", where we have IWS (and stop using Ravni), but we
don't have robots (and so we don't have to think about pigeon holes and
conveyors)

=item *

C<2> is "Phase 2", where we have IWS, conveyors and robots

=item *

C<3> is "Phase 3", where we change some processes to make them more
sensible

=back

All this is needed because we roll out different pieces at different
times in each DC.

=cut

sub iws_rollout_phase  {
    return shift->{data}{iws_rollout_phase};
}

=head2 prl_rollout_phase

Returns a number representing the PRL rollout phase (initially for
DC2, will probably soon be used in DC3 too)

=over 4

=item *

C<0> is when we're not using PRLs at all.

=item *

C<1> is when we have one PRL for the whole warehouse.

=back

Similar to the iws_rollout_phase idea that we used for DCEA in DC1.

=cut

sub prl_rollout_phase  {
    return shift->{data}{prl_rollout_phase};
}


=head2 method

Returns GET or POST

=cut

sub method {
    return shift->{r}->method();
}

sub get_postdata {
    my $self = shift;
    return $self->{param_of};
}

=head2 clean_query_param($param_name) : $value_without_surrounding_whitespace | undef

Return the GET query parameter $param_name, with surrounding
whitespace removed, or undef if $param_name isn't available.

Note: currently there's no distinction between GET/POST.

=cut

sub clean_query_param {
    my ($self, $param_name) = @_;
    return $self->_clean_param($self->{param_of}, $param_name);
}

=head2 clean_body_param($param_name) : $value_without_surrounding_whitespace | undef

Return the POST body parameter $param_name, with surrounding
whitespace removed, or undef if $param_name isn't available.

Note: currently there's no distinction between GET/POST.

=cut

sub clean_body_param {
    my ($self, $param_name) = @_;
    return $self->_clean_param($self->get_postdata, $param_name);
}

=head2 clean_param($param_name) : $value_without_surrounding_whitespace | undef

Return the GET or POST body parameter $param_name, with surrounding
whitespace removed, or undef if $param_name isn't available.

=cut

sub clean_param {
    my ($self, $param_name) = @_;
    return $self->_clean_param($self->{param_of}, $param_name);
}

sub _clean_param {
    my ($self, $param_of, $param_name) = @_;
    return scalar trim( $param_of->{ $param_name } );
}

sub freeze_sticky_page {
    my ( $self, $args ) = @_;

    # do nothing unless sticky pages are enabled
    return unless $self->{data}{sticky_pages};

    my $operator_id = $self->operator_id;
    my $schema = $self->{schema};

    my $sticky_class = $args->{sticky_class}
        or die q|Can't freeze sticky page without a sticky_class|;

    my $sticky_id = $args->{sticky_id}
        or die q|Can't freeze sticky page without a sticky_id|;

    my $signature_object = $args->{signature_object}
        or die q|Can't freeze sticky page without a signature_object|;

    # create or update the sticky page object
    my $sticky_page = $schema->resultset($sticky_class)->new({
        operator_id => $operator_id,
        sticky_id => $sticky_id,
        html => '',
        signature => md5_hex( encode_it($signature_object->state_signature) ),
        sticky_url => $self->{data}{path_query},
    })->update_or_insert;

    # keep a reference to the sticky page object so the template rendering code
    # can find it to update the HTML later
    $self->{data}{sticky_page} = $sticky_page;
}

=head2 add_to_data

Stuff a hashref full of data into C<$handler->{data}>, merging it with the existing
contents.

=cut

sub add_to_data {
    my ( $self, $data ) = @_;

    if ($data) {
        if (ref $data && ref $data eq 'HASH') {
            $self->{data}{$_} = $data->{$_} for keys %$data;
        } else {
            croak 'data must be a hashref';
        }
    }

    return $self;
}

=head2 xt_warn( $message )

Makes a call to L<XTracker::Error::xt_warn>.

=cut

sub xt_warn { XTracker::Error::xt_warn($_[1]); }

=head2 xt_die( $message )

Makes a call to L<XTracker::Error::xt_die>.

=cut

sub xt_die { XTracker::Error::xt_die($_[1]); }

=head2 xt_info( $message )

Makes a call to L<XTracker::Error::xt_info>.

=cut

sub xt_info { XTracker::Error::xt_info($_[1]); }

=head2 xt_success( $message )

Makes a call to L<XTracker::Error::xt_success>.

=cut

sub xt_success { XTracker::Error::xt_success($_[1]); }

=head2 xt_debug( $message )

Makes a call to L<XTracker::Error::xt_debug>.

=cut

sub xt_debug { XTracker::Error::xt_debug($_[1]); }

=head2 xt_has_warnings()

Makes a call to L<XTracker::Error::xt_has_warnings>.

=cut

sub xt_has_warnings { XTracker::Error::xt_has_warnings($_[1]); }

=head2 operator_authorised

    do_something() if $handler->operator_authorised( {
        sub_section => 'Order Search',
        section     => 'Customer Care',
    } );

Returns true if the operator is authorised to see the
specified sub section of the specified section.

section and sub_section are required parameters.

=cut

sub operator_authorised {
    my ( $self, $args ) = @_;

    foreach my $required ( qw ( section sub_section ) ) {
        if ( ! exists $args->{$required} && $args->{$required} ) {
            die "$required is required";
        }
    }

    return 0    if ( !$self->acl );

    # remove all spaces and then turn the
    # section and sub-section into a URL
    my $url_path = main_nav_option_to_url_path( $args->{section}, $args->{sub_section} );

    my $authorised = $self->acl->has_permission( $url_path, {
        can_use_fallback => 1,
    } );

    return $authorised ? 1 : 0;
}

=head2 get_cookies

Returns a cookie object (that fulfils XTracker::Cookies::Role::ManipulatesCookies)

param - $plugin : If a specialised cookie object is required, this should
    be the name of the plugin ( where = XTracker::Cookies::Plugin::$plugin )
    Else a generic XTracker::Cookies object will be returned

return - XTracker::Cookies::Role::ManipulatesCookies implementing cookie object

=cut
sub get_cookies {
    my ($self, $plugin) = @_;
    return XTracker::Cookies->get_cookies(
        request     => $self->{request}->{request},
        response    => $self->{request}->{response},
        plugin      => $plugin,
    );
}

=head2 parse_referer_url

    $hash_ref = $handler->parse_referer_url;

Will parse the Referer using the 'parse_url_path'
function in 'XTracker::Utilities', see this
function's docs for an explanation in what is
returned.

=cut

sub parse_referer_url {
    my $self = shift;

    my $uri = URI->new( $self->{referer} );

    return parse_url_path( $uri->path );
}

=head2 get_config(@keys) : $config_value

Get the config value for the given keys.

=cut

sub get_config {
    my $self = shift;
    return config_var(@_);
}

=head2 dc_name() : $dc_name

Return DC name from config.

=cut

sub dc_name {
    return $_[0]->get_config(qw/DistributionCentre name/);
}

=head2 is_viewed_on_handheld() : Bool

Return true if the page is viewed on a handheld device.

=cut

sub is_viewed_on_handheld {
    return $_[0]{data}{handheld};
}

=head2 unpack_params() : ($data_ref, $rest_ref)

A 'compatibility' method that allows us to stop importing
L<XTracker::Utilities::unpack_handler_params> and
L<XTracker::Utilities::unpack_params> in legacy handlers.

=cut

sub unpack_params {
    return unpack_handler_params($_[0]{param_of});
}

1;
