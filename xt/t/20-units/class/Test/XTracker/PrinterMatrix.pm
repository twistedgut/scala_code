package Test::XTracker::PrinterMatrix;

use NAP::policy "tt", 'test';

use FindBin::libs;

use Test::XTracker::Data;
use XTracker::PrinterMatrix;
use XTracker::PrinterMatrix::PrinterList;

use parent 'NAP::Test::Class';

sub startup : Test(startup => 2) {
    my ( $self ) = @_;
    $self->SUPER::startup;
    $self->startup_can_ok;
}

sub startup_can_ok {
    my ( $self ) = @_;
    my %can_ok = (
        'XTracker::PrinterMatrix' => [qw{
            schema
            printer_list
            get_printers_by_section
            get_printer
            locations_for_section
            printers_for_location
            get_printer_by_name
        }],
        'XTracker::PrinterMatrix::PrinterList' => [qw{
            printers
            search
            order_by
            names
            locations
            get_list_for
            count
        }],
    );
    can_ok( $_, @{$can_ok{$_}} ) for keys %can_ok;
}

sub setup : Test(setup) {
    my ( $self ) = @_;
    $self->SUPER::setup;

    $self->{printer_matrix} = $self->new_printer_matrix;
}

sub new_printer_matrix {
    no warnings 'redefine';
    # When we use this method to prepare our printer matrix the below code will
    # allow overriding the config - so we can test our printers against a known
    # set
    local *XTracker::PrinterMatrix::PrinterList::_build_printers = sub { ## no critic(ProtectPrivateVars)
        my $self = shift;

        # This will return an array that will look like so:
        # [
        #   {
        #     section => 'section_1',
        #     location => 'section_1_location_1,
        #     name => 'section_1_location_1_name_1',
        #     lp_name => 'section_1_location_1_lp_name_1',
        #   },
        #   ...
        # ]
        # Some entries won't contain section/location keys
        return [
            (map {
                my $section = $_;
                (map {
                    my $location = $_;
                    map {;
                        my $i = $_;
                        \%{{
                            ( $section ? ( section => $section ) : () ),
                            ( $location ? ( location => join q{_}, grep { $_ } $section, $location ) : () ),
                            (map { $_ => join q{_}, grep { $_ } $section, $location, $_, $i } qw{name lp_name}),
                        }}
                    } 1..2
                } q{}, qw{location_2 location_1})
            } q{}, qw{section_1 section_2})
        ];
    };
    return XTracker::PrinterMatrix->new;
}

sub test_search : Tests {
    my ( $self ) = @_;

    my $pl = $self->{printer_matrix}->printer_list;

    is( $pl->search(section => 'section_1')->count, 6,
        'string search should return exact matches' );
    is( $pl->search(section => 'section_1')
           ->search(location => 'section_1_location_1')
           ->count,
        2,
        'chained search should filter twice' );
    is( $pl->search(location => qr{LOCATION}i)->count, 12,
        'regexp search should work' );
}

sub test_order_by : Tests {
    my ( $self ) = @_;
    my $pl = $self->{printer_matrix}->printer_list;

    eq_or_diff(
        $pl->search(section => 'section_1')->order_by('name')->printers,
        [
            {
                section  => 'section_1',
                location => 'section_1_location_1',
                name     => 'section_1_location_1_name_1',
                lp_name  => 'section_1_location_1_lp_name_1',
            },
            {
                section  => 'section_1',
                location => 'section_1_location_1',
                name     => 'section_1_location_1_name_2',
                lp_name  => 'section_1_location_1_lp_name_2',
            },
            {
                section  => 'section_1',
                location => 'section_1_location_2',
                name     => 'section_1_location_2_name_1',
                lp_name  => 'section_1_location_2_lp_name_1',
            },
            {
                section  => 'section_1',
                location => 'section_1_location_2',
                name     => 'section_1_location_2_name_2',
                lp_name  => 'section_1_location_2_lp_name_2',
            },
            {
                section => 'section_1',
                name    => 'section_1_name_1',
                lp_name => 'section_1_lp_name_1',
            },
            {
                section => 'section_1',
                name    => 'section_1_name_2',
                lp_name => 'section_1_lp_name_2',
            },
        ],
        'ordered printers should match'
    );
    is( $pl->search(section => 'section_1')->order_by('location')->count,
        4, q{should filter out any printers without the field we're ordering by} );
}

sub test_get_list_for_and_wrappers : Tests {
    my ( $self ) = @_;

    my $pl = $self->{printer_matrix}->printer_list;

    my @lp_names = $pl->order_by('lp_name')->get_list_for('lp_name');
    ok( (grep { m{lp_name} } @lp_names), 'should contain lp_name fields' );

    # Test wrappers for get_list_for
    my @names = $pl->names;
    ok( (grep { m{name_\d+$} } @names), 'names should contain name fields' );

    my @locations = $pl->locations;
    ok( (grep { m{location_\d+$} } @locations), 'locations should contain location fields' );
    ok( @locations == 12, 'locations should filter out printers without location field' );
}

sub test_printer_matrix_methods : Tests {
    my ( $self ) = @_;

    my $pm = $self->{printer_matrix};
    ok( $pm->locations_for_section('section_1') == 2,
        'should return correct number of locations for given section' );
    ok( $pm->printers_for_location('section_1_location_1')->names == 2,
        'should return correct number of printers for given location'
    );
    is_deeply( $pm->get_printer_by_name('name_1'),
        { name => 'name_1', lp_name => 'lp_name_1', },
        'should return one printer picked by name' );
}
