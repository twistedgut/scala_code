package XTracker::PRLPages;
use strict;
use warnings;
use Perl6::Export::Attrs;
use XTracker::Config::Local 'config_var';

=head1 NAME

XTracker::PRLPages

=head1 DESCRIPTION

Provides methods to deal with XT functionality that should be enabled/disabled
according to the current PRL config.

=head1 SETUP

=head2 C<@prl_only>

An array of strings, of the form C<section/sub section>, like we use for
C<login_with_permissions>.

These represent pages which should only be enabled if PRLs are turned
ON in the config

=cut

my @prl_only = (
    'Fulfilment/Induction',
    'Goods In/Putaway Prep',
    'Goods In/Putaway Prep Admin',
    'Goods In/Putaway Problem Resolution',
    'Goods In/Putaway Prep Packing Exception',
    'Fulfilment/Picking Overview',
    'Fulfilment/GOH Integration',
);

=head2 C<@prl_disabled>

An array of strings, of the form C<section/sub section>, like we use for
C<login_with_permissions>.

These represent pages which should only be enabled if PRLs are turned
OFF in the config

=cut

my @prl_disabled = (
    # TODO: DCA-1726: Really Remove stock control/cancellations page
    'Stock Control/Cancellations', # XTracker::Stock::CancelIn::PutAway
                                   # XTracker::Stock::Actions::SetCancelPutAway
);


=head1 METHODS

=head2 is_prl_disabled_section

Return a true value if the section+subsection form a currently disabled page.

Used in C<XTracker::Navigation> and C<XTracker::Authenticate> to decide whether
to allow links or pages to be displayed.

=cut

my @_pages_to_disable = config_var('PRL', 'rollout_phase')
    ? @prl_disabled
    : @prl_only;
my %_disabled = map { $_ => 1 } @_pages_to_disable;
sub is_prl_disabled_section :Export() {
    my ($section, $sub_section) = @_;
    return unless (defined $section && defined $sub_section);

    return $_disabled{ $section.'/'.$sub_section };
}

1;
