package Test::XT::Fixture::Migration::Product;
use NAP::policy "tt", "class";
with (
    "Test::XT::Fixture::Role::WithProduct",
    "NAP::Test::Class::PRLMQ",
    "NAP::Test::Class::PRLMQ::Messages",
);

=head1 NAME

Test::XT::Fixture::Migration::Product - Migration Product fixture setup

=head1 DESCRIPTION

Test fixture with a Product and two SKUs. With those you can receive
StockAdjust messages and send Advice messages to test Migration.

=cut

use Test::XT::Data::Container;
use XTracker::Constants qw(
    :prl_type
);


has "+pid_count"     => ( default => 1 );
has "+variant_count" => ( default => 2 );

has container_rows => (
    is      => "rw",
    isa     => "ArrayRef",
    lazy    => 1,
    default => sub { [ ] },
);

sub container_row {
    my $self = shift;
    return $self->container_rows->[ -1 ];
}

sub pprep_container_row {
    my $self = shift;
    my $container_row = $self->container_row or return undef;
    return $container_row->putaway_prep_containers->search(
        undef,
        {
            order_by => { -desc => "created" },
            rows => 1,
        },
    )->first;
}

sub pprep_container_mgid {
    my $self = shift;
    my $pprep_container_row = $self->pprep_container_row or return undef;
    my $pprep_inventory = $pprep_container_row->putaway_prep_inventories->first
        or return undef;
    return $pprep_inventory->pgid;
}

sub discard_changes { }

sub with_new_container {
    my $self = shift;

    push(
        @{$self->container_rows},
        Test::XT::Data::Container->create_new_container_row(),
    );

    return $self;
}

sub with_sent_stock_adjust_message {
    my ($self, $args) = @_;
    $args //= {};

    my $sku = delete( $args->{sku} ) || $self->variant_rows->[0]->sku;

    $self->send_migration_stock_adjust({
        delta_quantity         => -4,
        total_quantity         => 1,
        sku                    => $sku,
        migration_container_id => $self->container_row->id . "",
        migrate_container      => $PRL_TYPE__BOOLEAN__FALSE,
        %$args,
    });

    return $self;
}

sub with_sent_final_stock_adjust_message {
    my ($self, $args) = @_;
    $args //= {};
    $args->{migrate_container} //= $PRL_TYPE__BOOLEAN__TRUE;
    return $self->with_sent_stock_adjust_message( $args );
}

sub with_received_advice_reponse_message {
    my ($self, $args) = @_;
    $args ||= {};
    $self->receive_adjust_response({
        container_id => $self->container_row->id,
        %$args,
    });
}

