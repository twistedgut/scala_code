package XT::DC::Controller::Reporting::Distribution;

use NAP::policy qw(tt class);

BEGIN { extends 'Catalyst::Controller' }

use DateTime::Format::Strptime;

use XTracker::Navigation qw( build_sidenav );

with 'XT::Order::Role::Parser::Common::Dates';

=head1 NAME

XT::DC::Controller::Reporting::Distribution

=cut

sub index : Path :Args(0) {
    my ( $self, $c ) = @_;
    # If we don't match anything redirect to our landing page
    $c->res->redirect('/Reporting/DistributionReports');
}

sub begin : Private {
    my ( $self, $c ) = @_;

    $c->check_access('Reporting', 'Distribution Reports');

    $c->stash->{sidenav} = build_sidenav({ navtype => 'distribution_reports' });
}

=head2 inbound_by_action

=cut

sub inbound_by_action : Local Args(0) {
    my ( $self, $c ) = @_;

    $c->stash(
        section       => 'Reporting',
        subsection    => 'Distribution',
        subsubsection => 'Inbound By Action',
    );

    # Populate our delivery actions checkboxes
    my $schema = $c->model('DB')->schema;
    $c->stash->{delivery_actions} = [
        $schema->resultset('Public::DeliveryAction')->search(
            undef, { order_by => 'rank' }
        )->all
    ];

    # Populate Sales Channel checkboxes
    $c->stash->{channels} = $schema->resultset('Public::Channel')->get_channels;

    # By default populate start/end dates with today/tomorrow
    my $today = $schema->db_now;
    $c->stash->{formdata}{start_date} = $today->strftime('%F');
    $c->stash->{formdata}{end_date} = $today->add(days => 1)->strftime('%F');

    # If we haven't passed any parameters, we do nothing else
    my $params = $c->req->query_params||{};
    return unless %$params;

    # HACK ALERT! So it turns out that with fillinform both operator_id and
    # operator_name get filled (as they should). However this comes with the
    # caveat that if you pass no operator_name *after* you've set it,
    # operator_id doesn't get reset to an empty string any more.
    # So as the javascript is quite painful and we should really spend time in
    # porting it to jQuery anyway, I'm adding a hack here that resets the
    # operator id if the operator_name is unset. It's pretty ugly, sorry :/
    # Also, ignore whitespace
    $params->{operator_id} = q{} unless $params->{operator_name} =~ s{\s+}{}gr;
    $c->stash->{formdata} = $params;

    return unless $c->forward('inbound_by_action_is_valid');

    # Get our timestamps to filter our resultset
    my ( $start_dt, $end_dt ) = map {
        my $date_type = $_;
        my @fields = @{$params}{map { "${date_type}_$_" } qw/date hour minute/};
        $self->_generate_datetime(@fields);
    } qw/start end/;

    my $log_delivery_rs = $schema->resultset('Public::LogDelivery')
        ->filter_between_dates( $start_dt, $end_dt );
    $log_delivery_rs = $log_delivery_rs->inbound_by_action(
        { map { $_ => $params->{$_} } qw/delivery_action_id operator_id channel_id/ },
        $params->{order_by}, !!(($params->{asc_desc}||'asc') eq 'desc')
    );
    # Let's not inflate our rows into objects as we can potentially return
    # thousands of results, and this will give us a nice performance
    # improvement
    $log_delivery_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    $c->stash->{log_deliveries} = [ $log_delivery_rs->all ];
}

# Wow plenty of horrible manual validation here - in hindsight I should
# probably have used a module, say HTML::FormHandler
sub inbound_by_action_is_valid : Private {
    my ( $self, $c ) = @_;

    my $params = $c->req->query_params;

    my $is_valid = 1;
    # The user must select both start and end dates - let's validate them
    for my $date_field ( @{$params}{qw/start_date end_date/} ) {
        unless ( $date_field ) {
            $c->feedback_warn('You must choose both a start and and end date');
            $is_valid = 0;
            next;
        }
        # If our pattern only consists of '%F', it ignore invalid datetimes
        # such as YYYY-MM-DDfoobarbaz, so we need to check against a dummy time
        # or else we fall over later when we try and create our datetime
        # objects.
        my $strp = DateTime::Format::Strptime->new(pattern => '%F %R');
        next if $strp->parse_datetime("$date_field 00:00");

        $c->feedback_warn("Invalid date date $date_field");
        $is_valid = 0;
    }
    # The user must always pass at least one action
    unless ( $params->{delivery_action_id} ) {
        $c->feedback_warn('You must select at least one delivery action');
        $is_valid = 0;
    }
    # If we have an operator, validate it
    # Note that this validation is very paranoid, as the YUI autocomplete thing
    # does weird scary magic with the fields it's in control of
    if ( $params->{operator_id} ) {
        my $operator = $c->model('DB::Public::Operator')->find($params->{operator_id});
        # A pretty horrible check here - again to do with our autocomplete
        # plugin. As the user sees operator_name but we use operator_id, we need
        # to:
        # a. Check that the operator_id actually exists.
        # b. Check that the operator_id we're using is the same operator the
        # user selected. Checking just the name is not 100% but good enough.
        if ( !$operator || $operator->name ne $params->{operator_name} ) {
            $c->feedback_warn('Unknown operator');
            $is_valid = 0;
        }
    }
    return $is_valid;
}

sub _generate_datetime {
    my ( $self, $date, $hour, $minute ) = @_;
    # 'floating' makes me shudder, but until we add timezones to
    # log_delivery.date it will have to do :(
    $self->_translate_time(
        sprintf('%s %02i:%02i', $date, $hour, $minute), 'floating'
    );
}
