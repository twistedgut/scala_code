package XTracker::Printers::Populator;

use NAP::policy 'class';

use Data::Dumper;
use Digest::MD5 'md5_hex';

use XTracker::Logfile 'xt_logger';
use XTracker::Printers::Source;
use XTracker::DBEncode  qw( encode_it );

with 'XTracker::Role::WithSchema';

=head1 NAME

XTracker::Printers::Populator - A class to populate printers

=head1 SYNOPSIS

    use XTracker::Printers::Populator;

    use NAP::policy 'class';

    # Build the XTracker::Printers object from config
    my $xpp = XTracker::Printers::Populator->new;

    # Populate the printer schema only if your source has changed
    $xpp->populate_if_updated;

=head1 ATTRIBUTES

=head2 source

The printer data source module. Defaults to selecting source from config.

=cut

has source => (
    is      => 'ro',
    isa     => 'XTracker::Printers::Source',
    builder => '_build_source',
);
sub _build_source { return XTracker::Printers::Source->new_from_config; }

=head1 METHODS

=head2 populate_db() : true

Deletes everything from the printer schema and repopulates with data obtained
by the source. Also updates the C<printer_digest> field in the
C<runtime_property> table. Returns true on success.

=cut

sub populate_db {
    my $self = shift;

    my $normalised_printers = $self->_normalise_printers;
    xt_logger->info("Printers to be inserted:\n" . Dumper $normalised_printers);

    my $schema = $self->schema;
    $schema->txn_do(sub{
        # Delete any existing data - note that the order of deletion is
        # important due to foreign key constraints
        $_->delete for map {
            $schema->resultset(join q{::}, 'Printer', ucfirst $_)
        } (qw{printer type location section});

        # Repopulate
        for my $section_name ( keys %$normalised_printers ) {
            my $section_row = $schema->resultset('Printer::Section')
                ->create({name => $section_name});

            for my $location_name ( keys %{$normalised_printers->{$section_name}} ) {
                my $location_row = $section_row->create_related('locations', { name => $location_name });

                while (
                    my ( $type, $lp_name )
                  = each %{$normalised_printers->{$section_name}{$location_name}}
                ) {
                    my $type_row = $schema->resultset('Printer::Type')
                        ->find_or_create({name => $type});

                    $location_row->create_related('printers', {
                        lp_name => $lp_name,
                        type_id => $type_row->id,
                    });
                }
            }
        }

        # Store the new digest
        $self->_current_digest_row->update({
            value => $self->_generate_digest($self->source->printers)
        });
    });
    return 1;
}

sub _normalise_printers {
    my $self = shift;

    my $printers = $self->source->printers;

    # Transform our list into a form that is convenient for db insertion, i.e.
    # { $section => { $location => { $type => $lp_name } } }
    my $normalised;
    for my $printer ( @$printers ) {
        die sprintf(
            q{Duplicate definition of type '%s' at section '%s', location '%s'},
            map { $_->type, $_->section, $_->location } $printer
        ) if defined $normalised->{$printer->section}{$printer->location}{$printer->type};

        $normalised->{$printer->section}{$printer->location}{$printer->type}
            = $printer->lp_name;
    }
    return $normalised;
}

sub _generate_digest {
    my ( $self, $structure ) = @_;
    local $Data::Dumper::Sortkeys = sub {
        my ($hash) = @_;
        return [ sort keys %$hash ];
    };
    return md5_hex( encode_it( Dumper $structure ) );
}

sub _current_digest_row {
    return shift->schema
                ->resultset('Public::RuntimeProperty')
                ->find({name => 'printer_digest'});
}

=head2 has_config_changed() : Bool

Determines whether the new printer config matches the current one.

=cut

sub has_config_changed {
    my $self = shift;
    my $new_digest = $self->_generate_digest($self->source->printers);
    return $self->_current_digest_row->value ne $new_digest;
}

=head2 populate_if_updated() : Bool

Only updates the printer schema if the digest has changed. Returns true on
success.

=cut

sub populate_if_updated {
    my $self = shift;
    return $self->has_config_changed ? $self->populate_db : undef;
}
