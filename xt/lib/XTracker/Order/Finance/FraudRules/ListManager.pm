package XTracker::Order::Finance::FraudRules::ListManager;
use NAP::policy;

use XTracker::Handler;
use XTracker::Navigation qw( build_sidenav );
use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Error;
use XTracker::Logfile qw( xt_logger );

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $schema = $handler->{schema};
    my $data   = $handler->{data};
    my $log    = xt_logger( __PACKAGE__ );

    $data->{content}       = 'ordertracker/finance/fraudrules/list_manager.tt';
    $data->{section}       = 'Finance';
    $data->{subsection}    = 'Fraud Rules';
    $data->{subsubsection} = 'List Manager';
    $data->{sidenav}       = build_sidenav( {
        navtype => 'fraud_rules'
    } );

    $handler->{data}{js} = [ '/javascript/fraudrules/fraudrules-list_manager.js' ];
    $handler->{data}{css} = [ '/css/fraudrules/fraudrules-list_manager.css' ];

    my $action = $handler->{param_of}->{action} // '';
    my $list;

    eval {

        given ( $action ) {

            when ( 'delete' ) {

                $list = list_delete( $handler );

            }

            when ( 'edit' ) {

                $list = list_edit( $handler );

            }

            when ( 'update' ) {

                $list = list_update( $handler );

            }

            when ( 'create' ) {

                $list = list_create( $handler );

            }

            default {

                $list = {
                    action      => 'create',
                    id          => '',
                    name        => '',
                    description => '',
                    type_id     => '',
                };

            }

        }

    };

    if ( my $error = $@ ) {

        $log->warn( "Problem processing request: $error" );
        xt_warn( 'There was a problem processing the request, please try again.' );

    }

    $data->{dynamic} = {
        lists      => [ $schema->resultset('Fraud::StagingList')->all ],
        list_types => [ $schema->resultset('Fraud::ListType')->all ],
        list       => $list,
    };

    $handler->process_template;

    return OK;

}

sub params_ok {
    my ( $handler ) = @_;

    my $result = 1;
    my %params = (
        list_name        => 'list name',
        list_description => 'list description',
        list_type_id     => 'list type',
    );

    while ( my ( $name, $message ) = each %params ) {

        unless ( $handler->{param_of}->{ $name } ) {

            xt_warn( "You must provide a $message" );
            $result = 0;

        }

    }

    return $result;

}

sub list_delete {
    my ( $handler ) = @_;

    if ( my $list = get_fraud_list_item( $handler ) ) {

        my $list_name = $list->name;

        if ( list_is_in_use( $handler, $list->id ) ) {
            xt_warn( "Unable to delete list '$list_name' as it is in use" );
            return list_hash();
        }

        if ( $list->staging_list_items->delete && $list->delete ) {

            xt_success( "List '$list_name' deleted." );

        } else {

            xt_warn( "Unable to delete list '$list_name', please try again." );

        }

    }

    return list_hash();

}

sub list_edit {
    my ( $handler ) = @_;

    if ( my $list = get_fraud_list_item( $handler ) ) {

        return list_hash( 'update',
            $handler->{param_of}->{list_id},
            $list->name,
            $list->description,
            $list->list_type_id,
            [ map { $_->value } $list->staging_list_items->all ],
        );

    }

}

sub list_update {
    my ( $handler ) = @_;

    my $list_id           = $handler->{param_of}->{list_id};
    my $list_name         = $handler->{param_of}->{list_name};
    my $list_description  = $handler->{param_of}->{list_description};
    my $list_type_id      = $handler->{param_of}->{list_type_id};
    my $list_values       = [ get_values_for_list_id( $handler ) ];

    return list_hash( 'update', $list_id, $list_name, $list_description, $list_type_id, $list_values )
        unless params_ok( $handler );

    if ( my $list = get_fraud_list_item( $handler ) ) {

        my $old_name = $list->name;

        if ( $list_name ne $old_name && get_fraud_list_item( $handler, 1 ) ) {

            xt_warn( "The list '$list_name' already exists" );
            return list_hash( 'update', $list_id, $list_name, $list_description, $list_type_id, $list_values );

        }
        elsif ( list_is_in_use( $handler, $list->id ) && $list_type_id != $list->list_type_id ) {
            xt_warn( "You cannot change the type of list '$list_name' as the list is in use" );
            return list_hash( 'update', $list_id, $list_name, $list_description, $list_type_id, $list_values );
        }
        else {

            my $result = $list->update( {
                name         => $list_name,
                description  => $list_description,
                list_type_id => $list_type_id,
            } );

            $list->staging_list_items->delete;
            $list->staging_list_items->populate(
                get_db_values_for_list_id( $handler, $list_type_id )
            );

            if ( $result ) {

                xt_success( "List '$old_name' updated." );
                return list_hash();

            } else {

                xt_warn( "List '$old_name' not update, please try again." );
                return list_hash( 'update', $list_id, $list_name, $list_description, $list_type_id, $list_values );

            }

        }

    }

}

sub list_create {
    my ( $handler ) = @_;

    my $list_name        = $handler->{param_of}->{list_name};
    my $list_description = $handler->{param_of}->{list_description};
    my $list_type_id     = $handler->{param_of}->{list_type_id};
    my $list_values      = [ get_values_for_list_id( $handler ) ];

    return list_hash( 'create', '', $list_name, $list_description, $list_type_id, $list_values )
        unless params_ok( $handler );

    if ( get_fraud_list_item( $handler, 1 ) ) {

        xt_warn( "The list '$list_name' already exists" );
        return list_hash( 'create', '', $list_name, $list_description, $list_type_id, $list_values );

    } else {

        my $result = get_fraud_list( $handler )->create( {
            name         => $list_name,
            description  => $list_description,
            list_type_id => $list_type_id,
        } );

        $result->staging_list_items->populate(
            get_db_values_for_list_id( $handler, $list_type_id )
        );

        if ( $result ) {

            xt_success( "List '$list_name' created" );
            return list_hash();

        } else {

            xt_warn( "Failed to create list '$list_name', please try again." );
            return list_hash( 'create', '', $list_name, $list_description, $list_type_id, $list_values );

        }

    }

}

sub get_fraud_list {
    my ( $handler ) = @_;

    return $handler->{schema}->resultset('Fraud::StagingList');

}

sub get_fraud_list_item {
    my ( $handler, $by_name ) = @_;

    my $list = get_fraud_list( $handler )->find(
            $by_name
                ? { name => { ILIKE => $handler->{param_of}->{list_name} } }
                : { id   => $handler->{param_of}->{list_id} }
        );

    if ( $list ) {

        return $list;

    } else {

        xt_warn( "List with ID '$handler->{param_of}->{list_id}' not found" )
            unless $by_name

    }

    return;

}

sub list_hash {
    my ( $action, $id, $name, $description, $type_id, $values ) = @_;

    $values = {
        map { $_ => 1 } @$values
    };

    return {
        action      => $action      // 'create',
        id          => $id          // '',
        name        => $name        // '',
        description => $description // '',
        type_id     => $type_id     // '',
        values      => $values      // {},
    };

}

sub get_values_for_list_id {
    my ( $handler, $id ) = @_;

    $id //= $handler->{param_of}->{list_type_id};

    my $value_list = $handler->{param_of}->{ "list_value_$id" };

    # Make sure we have an ArrayRef.
    return ref( $value_list ) eq 'ARRAY'
        ? @$value_list
        : ( $value_list );

}

sub get_db_values_for_list_id  {
    my ( $handler, $id ) = @_;

    return [
       map
        { { value => $_ } }
        get_values_for_list_id( $handler, $id )
    ];

}

=head list_is_in_use

Returns true if the list is being used in any condition in any rule
in the current list of Staging rules.

=cut

sub list_is_in_use {
    my ( $handler, $list_id ) = @_;

    die "You must pass in a list_id" unless $list_id;

    my $list = $handler->{schema}->resultset('Fraud::StagingList')->find( $list_id );
    die "List with id '$list_id' does not exist" unless $list;

    return $list->is_used ? 1 : 0;
}
