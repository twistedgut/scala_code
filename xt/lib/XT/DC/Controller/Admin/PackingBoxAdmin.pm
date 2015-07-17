package XT::DC::Controller::Admin::PackingBoxAdmin;
use NAP::policy qw(tt class);
use XTracker::Config::Local qw( config_var );
use XTracker::Utilities qw( trim );
use Scalar::Util qw( looks_like_number );

BEGIN { extends 'Catalyst::Controller' };

=head1 NAME

XT::DC::Controller::Admin::PackingBoxAdmin

=head1 DESCRIPTION

Controller for /Admin/PackingBoxAdmin which is used to create and edit boxes
(Public::Box) and inner boxes (Public::InnerBox) which are used in packing.

=head1 METHODS

=cut

sub root : Chained('/') PathPart('Admin/PackingBoxAdmin') CaptureArgs(0) {
    my ($self, $c) = @_;
    $c->check_access('Admin', 'Packing Box Admin');
    $c->stash(
        dc_code              => config_var('DistributionCentre', 'name'),
        pims_url             => config_var('Pims', 'js_url'),
        weight_unit          => config_var('Units', 'weight'),
        dimensions_unit      => config_var('Units', 'dimensions'),
        sidenav              => [ { 'Shipment Boxes' =>
                                      [ { 'title' => 'Add Purchase Order', 'url' => '#', 'id' => 'addpo' },
                                        { 'title' => 'Outer Boxes', 'url' => '/Admin/PackingBoxAdmin/boxes' },
                                        { 'title' => 'Inner Boxes', 'url' => '/Admin/PackingBoxAdmin/inner_boxes' } ]
                                  }
                                ]
    );
}

=head2 create_box

Action for Admin/PackingBoxAdmin

=cut

sub admin_box : Chained('root') PathPart('') Args() ActionClass('REST') {
    my ($self, $c, $box_type) = @_;
    $box_type = 'boxes' if !$box_type;
    if ( $box_type eq 'boxes' || $box_type eq 'inner_boxes' ){
        $c->stash->{form_box_type} = $box_type;
    }
    else {
        $c->feedback_warn( "$box_type is not a valid box type. Retry using 'boxes' or 'inner_boxes'.");
        $c->detach;
    }
}

=head2 edit_box

Action for Admin/PackingBoxAdmin/edit

=cut

sub edit_box : Chained('root') PathPart('edit') Args(2) ActionClass('REST') {
    my ($self, $c, $box_type, $box_id) = @_;

    my $is_valid_type = $box_type eq 'boxes' || $box_type eq 'inner_boxes';
    if ( $is_valid_type ) {
        my $table_name = $box_type eq 'boxes' ? 'Box' : 'InnerBox';
        if ( my $box = $c->model("DB::Public::$table_name")->find($box_id) ) {
            $c->stash(
                edit_box      => $box,
                form_box_type => $box_type,
                table_name    => $table_name,
            );
        }
        else {
            $c->feedback_warn( "$table_name ID: $box_id not found");
            $c->detach;
        }
    }
    else {
        $c->feedback_warn( "$box_type is not a valid box type. Retry using 'boxes' or 'inner_boxes'.");
        $c->detach;
    }
}

=head2 admin_box_GET

GET REST action for Admin/PackingBoxAdmin.

Populates the page with box or inner box details for each channel, depending on
the 'box_type' parameter.

=cut

sub admin_box_GET {
    my ( $self, $c ) = @_;

    my $box_type = $c->stash->{form_box_type};
    my @channels = $c->model('DB::Public::Channel')->all;
    my $channel_data = $self->_get_channel_box_mappings( $c, $box_type, \@channels );
    $c->stash(
        channel_data         => $channel_data,
    );
    return;
}

=head2 edit_box_GET

GET REST action for Admin/PackingBoxAdmin/edit.

Populates the edit form with the details of the box to be edited, as well as the
box or inner box details for the other boxes of the channel.

=cut

sub edit_box_GET {
    my ( $self, $c ) = @_;

    my $box     = $c->stash->{edit_box};
    if ( my $channel = $c->model('DB::Public::Channel')->find( $box->channel_id ) ) {
        my $channel_data = $self->_get_channel_box_mappings( $c, $c->stash->{form_box_type}, [$channel] );
        $c->stash(
            channel_data         => $channel_data,
            edit_channel         => $channel->name,
        );
    }
    else {
        $c->feedback_warn( "Channel ID: " . $box->channel_id . " not found");
        $c->detach;
    }
    return;
}

=head2 admin_box_POST

POST REST action for Admin/PackingBoxAdmin.

Creates or updates (if a box_id is supplied) box/inner box details on the database
with the parameters supplied.


=cut

sub admin_box_POST {
    my ( $self, $c ) = @_;

    my $box_type = $c->req->param('box_type');
    my ( $model, $box_name_field );

    if ( $box_type eq 'boxes' ) {
        $model = 'DB::Public::Box';
        $box_name_field = 'box';
    }
    elsif ( $box_type eq 'inner_boxes' ) {
        $model = 'DB::Public::InnerBox';
        $box_name_field = 'inner_box';
    }
    else {
        $c->feedback_warn( "$box_type is not a valid box type. Retry using 'Box' or 'InnerBox'.");
        $c->detach;
    }

    my $current_sort_order = $c->req->param('current_sort_order');
    my $sort_order         = assign_number( $c->req->param('sort_order'), 'Sort Order' );
    my $box_name           = $c->req->param('box_name');
    my $box_id             = $c->req->param('box_id');
    my $box;
    $box                   = $c->model($model)->find( $box_id )
                               or die "Unable to find $model with id $box_id" if $box_id;

    my $is_conveyable = $c->req->param('is_conveyable');
    my $requires_tote = $c->req->param('requires_tote');

    my @channels;
    if ( $c->req->param('all_channels') ) {
        for my $channel ($c->model('DB::Public::Channel')->all) {
            push @channels, $channel->id;
        }
    }
    else {
        push @channels, $c->req->param('channel_id');
    }
    my $schema = $c->model($model)->result_source->schema;

    eval {
        my $txn = $schema->txn_scope_guard;

        foreach my $channel_id ( @channels ){
            die "The box name field is empty. Please enter a box name and resubmit"
                if ! length $box_name;
            die "Invalid input: the 'Is conveyable' and 'requires tote' fields are both set to 'Yes'"
                if $is_conveyable && $requires_tote;
            my $parameters;
            if ( $box_type eq 'boxes' ){
                my $weight   = assign_number( $c->req->param('weight'), 'Weight' );
                my $length   = assign_number( $c->req->param('length'), 'Length' );
                my $width    = assign_number( $c->req->param('width'), 'Width' );
                my $height   = assign_number( $c->req->param('height'), 'Height' );
                my $label_id = assign_number( $c->req->param('label_id'), 'Label ID' );
                $parameters = {
                    'sort_order'        => $sort_order,
                    'box'               => $box_name,
                    'is_conveyable'     => $is_conveyable,
                    'requires_tote'     => $requires_tote,
                    'active'            => $c->req->param('active'),
                    'channel_id'        => $channel_id,
                };
                $parameters->{label_id} = $label_id if $label_id;
                $parameters->{weight}   = $weight   if $weight;
                $parameters->{length}   = $length   if $length;
                $parameters->{width}    = $width    if $width;
                $parameters->{height}   = $height   if $height;
            }
            else {
                my $outer_box_id = assign_number( $c->req->param('outer_box_id'), 'Outer Box ID' );
                my $grouping_id  = assign_number( $c->req->param('grouping_id'), 'Grouping ID' );
                $parameters = {
                    'sort_order'    => $sort_order,
                    'inner_box'     => $box_name,
                    'active'        => $c->req->param('active'),
                    'channel_id'    => $channel_id,
                };
                $parameters->{outer_box_id} = $outer_box_id if $outer_box_id;
                $parameters->{grouping_id}  = $grouping_id  if $grouping_id;
            }
            $parameters->{id} = $box->id if $box;
            $c->model($model)->update_or_create( $parameters );
        }
        $c->feedback_success("Box successfully updated");
        $txn->commit();
    };
    if ( my $err = $@ ) {
        $c->feedback_warn("Problem updating box: $err");
    }

    $c->response->redirect( $c->uri_for_action('/admin/packingboxadmin/admin_box', $box_type) );

    return;
}

=head2 _get_channel_box_mappings

Get the mappings of channels and boxes required for the display page.

=cut

sub _get_channel_box_mappings {
    my ( $self, $c, $box_type, $channels ) = @_;
    my ( %outer_box_map, %channel_config, %channel_map, %active_boxes, %inactive_boxes );
    my $max_box_sort_order = 0;
    foreach my $channel ( @{ $channels } ){
        $channel_map{$channel->name} = $channel->id;
        $channel_config{$channel->name} = $channel->business->config_section;
        my $channel_boxes_rs = $channel->$box_type;
        while (my $box = $channel_boxes_rs->next) {
            $active_boxes{$channel->name}{$box->id} = $box if $box->active;
            $inactive_boxes{$channel->name}{$box->id} = $box if !$box->active;
        }
        my $channel_max_sort_order =
                $channel->$box_type->get_column('sort_order')->max() || 0;
        $max_box_sort_order = $channel_max_sort_order
                if $channel_max_sort_order > $max_box_sort_order;

        # get a mapping of outer box ids and names so that the outer box names
        # can be displayed on inner box edit pages
        for my $outer_box ( $channel->boxes->all ) {
            $outer_box_map{$channel->name}{ $outer_box->id } = $outer_box->box
                if $outer_box->active;
        }
    }

    # Retrieve the current stock quantities for the boxes
    my $box_quantities = [];
    try {
        $box_quantities = $c->model('Pims')->get_quantities;
    } catch {
        $c->feedback_warn("Problem calling Pims for box quantities: $_");
    };
    my %box_quantity_hash = map { $_->{code} => $_->{quantity} } @$box_quantities;

    my $return_parameters = {
        sales_channels       => \%channel_map,
        channel_config       => \%channel_config,
        channel_box_list     => \%active_boxes,
        channel_box_inactive => \%inactive_boxes,
        channel_box_map      => \%outer_box_map,
        max_box_sort_order   => $max_box_sort_order+1,
        box_quantities       => \%box_quantity_hash,
        dc_name              => config_var('DistributionCentre', 'name'),
        dc_code              => config_var('DistributionCentre', 'name'),
        pims_url             => config_var('Pims', 'js_url'),
    };

    return $return_parameters;
}

# small helper method to remove looks_like_number cruft
sub assign_number {
    my ($input, $parameter) = @_;
    return undef unless $input;
    return $input if looks_like_number( $input );
    die "The value of $parameter ($input) is not a valid number.";
}

__PACKAGE__->meta->make_immutable;

1;
