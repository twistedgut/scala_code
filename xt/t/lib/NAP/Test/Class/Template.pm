package NAP::Test::Class::Template;

use NAP::policy "tt", 'role';

use Template;
use Template::Stash;

# 13/12/12/PS: I suspect this should be 'bare', but I don't have a working dev
# environment to be able to check that...
use XTracker::Constants::FromDB qw(
    :putaway_prep_container_status
);

=head1 NAME

NAP::Test::Class::Template

=head1 DESCRIPTION

A NAP::Test::Class role for adding template processing

=head1 USAGE

 with 'NAP::Test::Class::Template';

 ...

 my $html = $self->process(
     'product_shipping_details.tt',
     {
         restricted  => ["Unicorn tears", "Puppy dog tails", "The One Ring"],
         destination => "Best Korea",
     }
 );

=head1 METHODS

=head2 process

Accepts a template filename, and a hashref of template vars. Attempts to work
like the L<Template> object in L<XTracker::XHandler>, setting up C<db_constant>
aliases, template include paths...

=cut

sub process {
    my ($self, $template_filename, $template_vars) = @_;

    # Set up test template
    my $basedir = $ENV{'XTDC_BASE_DIR'} or BAILOUT('XTDC_BASE_DIR not set, cannot continue');
    my $tt = Template->new({
        # All these paths will be searched for templates
        INCLUDE_PATH => [
            $basedir . '/t/data', # test template dir, for putaway/group_status.tt
            $basedir . '/root/base', # production template dir
        ],
        RELATIVE => 1,
        VARIABLES => {
            db_constant => sub {
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
        },
    }) || die "$Template::ERROR\n";

    my $output;
    $tt->process($template_filename, $template_vars, \$output) || die $tt->error();

    return $output;
}

=head1 AUTHOR

Probably Pavel, even though git suggests it was p.sergeant

=cut

1;
