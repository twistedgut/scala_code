package Sub::Actions;
use NAP::policy "tt", "class";

=head1 NAME

Sub::Actions - Collect subrefs and optionally run them

=head1 DESCRIPTION

Add subrefs actions to be run (or not) at a later date, then
optionally execute all of them.

The point of this is to pass around an object which can have subrefs
(maybe closures) added to it while determining whether to go ahead and
do this thing. They can later be executed if it turns out all
conditions were met.

=head1 SYNOPSIS

    my $actions = Sub::Actions->new();
    $actions->add( sub { print "Hello\n" } );
    $actions->add( sub { print "world!\n" } );

    # ...

    $actions->perform();

=cut

=head1 ATTRIBUTES

=cut

has actions => (
    is      => "ro",
    isa     => "ArrayRef[ CodeRef ]",
    default => sub { [] },

    traits  => [ "Array" ],
    handles => {
        add         => "push",
        all_actions => "elements",
    },
);



=head1 METHODS

=head2 perform() : @actions | die

Execute all ->actions subrefs in order and return the list of subrefs.

No exeptions will be caught if anything dies in there.

=cut

sub perform {
    my $self = shift;

    for my $action ($self->all_actions) {
        $action->(); # might die
    }

    return $self->all_actions;
}
