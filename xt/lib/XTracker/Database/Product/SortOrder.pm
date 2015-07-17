package XTracker::Database::Product::SortOrder;

use strict;
use warnings;
use Carp;
use Data::Dumper;
#use GD::Graph::bars;
use List::AllUtils qw(any);
use Perl6::Export::Attrs;
use Readonly;
use Statistics::Descriptive;

use XTracker::Database              qw(:common);
use XTracker::Database::Utilities   qw(results_list);
use XTracker::Logfile               qw(xt_logger);
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw( :flow_status );


################################################################################
# Constants
################################################################################

## location in which to save frequency distribution graphs
Readonly my  $GRAPH_PATH    => config_var('SystemPaths','images_graphs_dir');

## weighting range
Readonly my $WEIGHT_RANGE   => 100;

## sort variable attributes
Readonly my @SORT_VARIABLES => (
        {
            name    => 'inverse_price',
            qry     => q{
                SELECT
                    pc.product_id,
                    pc.channel_id,
                    (1/
                        (
                            CASE
                                WHEN (
                                    CASE
                                        WHEN pa.id IS NULL THEN pd.price
                                        ELSE round((pd.price - (pa.percentage * (pd.price / 100))), 2)
                                    END
                                ) < 1 THEN 1
                                ELSE (
                                    CASE
                                        WHEN pa.id IS NULL THEN pd.price
                                        ELSE round((pd.price - (pa.percentage * (pd.price / 100))), 2)
                                    END
                                )
                            END
                        )
                    ) AS value
                FROM public.product_channel pc
                LEFT JOIN public.price_default pd
                    ON (pd.product_id = pc.product_id)
                LEFT JOIN public.price_adjustment pa
                    ON ((pc.product_id = pa.product_id) AND current_timestamp BETWEEN pa.date_start AND pa.date_finish)
                WHERE pc.visible IS TRUE
            },
            default_weight  => ($WEIGHT_RANGE / 100) * 0.03,
        },
        {
            name    => 'price',
            qry     => q{SELECT
                            pc.product_id
                        ,    pc.channel_id
                        ,   CASE
                                WHEN pa.id IS NULL THEN pd.price
                                ELSE round((pd.price - (pa.percentage * (pd.price / 100))), 2)
                            END AS value
                        FROM public.product_channel pc
                        LEFT JOIN public.price_default pd
                            ON (pd.product_id = pc.product_id)
                        LEFT JOIN public.price_adjustment pa
                            ON ((pc.product_id = pa.product_id) AND current_timestamp BETWEEN pa.date_start AND pa.date_finish)
                        WHERE pc.visible IS TRUE
            },
            default_weight  => ($WEIGHT_RANGE / 100) * 0.03,
        },
        {
            name    => 'available_to_sell',
            qry     => q{SELECT
                            pc.product_id
                        ,   pc.channel_id
                        ,   CASE WHEN (ss.main_stock - (ss.reserved + ss.pre_pick + ss.cancel_pending)) IS NULL THEN 0 ELSE (ss.main_stock - (ss.reserved + ss.pre_pick + ss.cancel_pending)) END AS value
                        FROM public.product_channel pc
                        LEFT JOIN product.stock_summary ss
                            ON (pc.product_id = ss.product_id AND pc.channel_id = ss.channel_id)
            },
            default_weight  => ($WEIGHT_RANGE / 100) * 0.9,
        },
        {
            name    => 'pcnt_sizes_in_stock',
            qry     => qq{SELECT
                            pc.product_id
                        ,   pc.channel_id
                        ,   round(((CAST(COALESCE(sizes_in_stock.num_sizes_in_stock, 0) AS numeric) / CAST(sizes.num_sizes AS numeric)) * 100), 2) AS value
                        FROM public.product_channel pc
                        INNER JOIN
                            (SELECT product_id, COUNT(*) AS num_sizes
                            FROM variant
                            WHERE type_id = 1
                            GROUP BY product_id) sizes
                            ON (pc.product_id = sizes.product_id)
                        LEFT JOIN
                            (SELECT v.product_id, q.channel_id, COUNT(*) AS num_sizes_in_stock
                            FROM variant v, quantity q
                            WHERE v.id = q.variant_id
                            AND q.quantity > 0
                            AND q.status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS
                            GROUP BY product_id, channel_id) sizes_in_stock
                            ON (pc.product_id = sizes_in_stock.product_id AND pc.channel_id = sizes_in_stock.channel_id )
            },
            default_weight  => 1,
        },
        {
            name    => 'inverse_upload_days',
            qry     => q{SELECT
                            product_id
                        ,   channel_id
                        ,   (1 / ((EXTRACT(epoch from current_timestamp) / 86400)
                                - CASE WHEN ((EXTRACT(epoch from upload_date) / 86400)) < 1 THEN 1 ELSE ((EXTRACT(epoch from upload_date) / 86400)) END)) AS value
                        FROM public.product_channel
                        WHERE upload_date IS NOT NULL
            },
            default_weight  => ($WEIGHT_RANGE / 100) * 10000,
        },
    );


## initialise logger (text file)
my $logger  = xt_logger('XTracker::Comms::DataTransfer');



sub update_pws_sort_data :Export() {

    my ($arg_ref)       = @_;
    my $destination     = defined $arg_ref->{destination} ? $arg_ref->{destination} : '';
    my $channel_id      = $arg_ref->{channel_id};

    croak "Invalid destination ($destination).  Must be be 'preview' or 'main'" if $destination !~ m{\A(?:preview|main)\z}xms;
    croak "Undefined channel_id" if not defined $channel_id;

    ## create sort_var hash
    my %sort_var        = ();
    my @sort_var_seq    = ();
    my @sort_var_keys   = keys %{$SORT_VARIABLES[0]};
    foreach my $sort_var_ref ( @SORT_VARIABLES ) {
        push @sort_var_seq, $sort_var_ref->{name};
        foreach (@sort_var_keys) {
            $sort_var{ $sort_var_ref->{name} }{$_} = $sort_var_ref->{$_};
        }
    }

    my @sort_pids       = ();
    my $qry_pws_sort    = '';

    my $dbh_read        = get_database_handle( { name => 'xtracker', type => 'readonly' } );
    my $dbh_trans       = get_database_handle( { name => 'xtracker', type => 'transaction' } );


    eval {

        ## get pws_sort_variable list and user weightings
        my $pws_sort_variable_weightings_ref = list_pws_sort_variable_weightings( { dbh => $dbh_read, destination => $destination, channel_id => $channel_id } );

        foreach my $variable_ref ( @{$pws_sort_variable_weightings_ref} ) {
            ## check for corresponding %sort_var entry
            croak "Missing sort_variable attributes ($variable_ref->{name})" unless exists $sort_var{ $variable_ref->{name} };
        }

        ## add appropriate weight coefficients to %sort_var
        foreach my $var_name ( @sort_var_seq ) {
            my $weight_ref = _calculate_weighting({ dbh => $dbh_read, sort_variable_ref => $sort_var{$var_name}, destination => $destination, channel_id => $channel_id });
            foreach my $key ( keys %{$weight_ref} ) {
                $sort_var{$var_name}{$key} = $weight_ref->{$key};
            }
        }

        ## clear existing sort data
        $logger->info("Clearing current xT sort data...\n");
        _clear_sort_data( { dbh => $dbh_trans, destination => $destination, channel_id => $channel_id } );

        my @qry_pws_sort_select = ();
        my @qry_pws_sort_sub    = ();

        foreach my $variable_ref ( @{$pws_sort_variable_weightings_ref} ) {

            ## insert sort values
            my $sql_insert_values
                = qq{INSERT INTO product.pws_product_sort_variable_value (product_id, pws_sort_variable_id, pws_sort_destination_id, actual_value, weighted_value, channel_id)
                        (SELECT
                            A.product_id
                        ,   $variable_ref->{id} AS pws_sort_variable_id
                        ,   (SELECT id FROM product.pws_sort_destination WHERE name = '$variable_ref->{destination}') AS pws_sort_destination_id
                        ,   A.value AS actual_value
                        ,   ($sort_var{ $variable_ref->{name} }{weight} * A.value) AS weighted_value
                        ,   A.channel_id
                        FROM ($sort_var{ $variable_ref->{name} }{qry}) A WHERE A.channel_id = ?)
                };
            $logger->debug($sql_insert_values);
            $logger->info("INSERTING pws_product_sort_variable_values ('$variable_ref->{name}', $variable_ref->{destination})...\n");
            my $sth_insert_values = $dbh_trans->prepare($sql_insert_values);
            $sth_insert_values->execute( $channel_id );


            ## assemble score SELECT list items
            push @qry_pws_sort_select, qq{$variable_ref->{name}.$variable_ref->{name}_weighted};

            ## assemble score subquery
            my $qry_pws_sort_sub
                = qq{(SELECT product_id, actual_value AS $variable_ref->{name}, weighted_value AS $variable_ref->{name}_weighted, channel_id
                    FROM product.pws_product_sort_variable_value
                    WHERE pws_sort_variable_id = $variable_ref->{id}
                    AND channel_id = $channel_id
                    AND pws_sort_destination_id = (SELECT id FROM product.pws_sort_destination WHERE name = '$variable_ref->{destination}')) $variable_ref->{name}
                    ON ($variable_ref->{name}.product_id = pc.product_id AND $variable_ref->{name}.channel_id = pc.channel_id)
                };
            push @qry_pws_sort_sub, $qry_pws_sort_sub;

        } ## END foreach


        ## build final score query
        $qry_pws_sort
            = qq{SELECT
                    pc.product_id
                ,   (@{[join(' + ', @qry_pws_sort_select)]}) AS score
                ,   psa.sort_score_offset
                ,   (@{[join(' + ', @qry_pws_sort_select)]}) + psa.sort_score_offset AS final_score
                FROM product_channel pc
                INNER JOIN product.pws_sort_adjust psa
                    ON (pc.pws_sort_adjust_id = psa.id)
                LEFT JOIN @{[join(' LEFT JOIN ', @qry_pws_sort_sub)]}
                WHERE pc.channel_id = $channel_id
                AND pc.visible is true
                AND pc.upload_date is not null
                ORDER BY final_score DESC, pc.product_id
            };
        $logger->info("[ xT values Committed ]\n\n") if $dbh_trans->commit;

    };
    if ($@) {
        $logger->info("ERROR: $@\n");
        $logger->info("[ ** xT values Rolled Back ** ]\n\n") if $dbh_trans->rollback;
    }


    eval {

        $logger->debug("$qry_pws_sort\n\n");
        my $sth_pws_sort = $dbh_read->prepare($qry_pws_sort);
        $sth_pws_sort->execute();

        ## populate product sort table
        my $sort_order  = 0;

        my $sql_insert_pws_sort
            = q{INSERT INTO product.pws_sort_order (product_id, pws_sort_destination_id, score, score_offset, sort_order, channel_id)
                    VALUES (?, (SELECT id FROM product.pws_sort_destination WHERE name =?), ?, ?, ?, ?)
            };
        my $sth_insert_pws_sort = $dbh_trans->prepare($sql_insert_pws_sort);


        $logger->info("UPDATING xtracker.product.pws_sort_order ($destination)...\n");
        while ( my $row_ref = $sth_pws_sort->fetchrow_hashref ) {
            $sort_order++;
            $sth_insert_pws_sort->execute(
                $row_ref->{product_id},
                $destination,
                $row_ref->{score},
                $row_ref->{sort_score_offset},
                $sort_order,
                $channel_id
            );
            push @sort_pids, $row_ref->{product_id};
        }

        $logger->info("[ xT sort Committed ]\n\n") if $dbh_trans->commit;

    };
    if ($@) {
        $logger->info("ERROR: $@\n");
        $logger->info("[ ** xT sort Rolled Back ** ]\n\n") if $dbh_trans->rollback;
    }

    return \@sort_pids;

} ## END sub update_pws_sort_data



sub _calculate_weighting {

    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $sort_var_ref    = $arg_ref->{sort_variable_ref};
    my $channel_id      = $arg_ref->{channel_id};
    my $weight_range    = defined $arg_ref->{weight_range} ? $arg_ref->{weight_range} : $WEIGHT_RANGE;
    my $destination     = defined $arg_ref->{destination} ? $arg_ref->{destination} : '';
    my $create_graphs   = defined $arg_ref->{create_graphs} ? $arg_ref->{create_graphs} : 1;

    croak "Invalid destination ($destination).  Must be be 'preview' or 'main'" if $destination !~ m{\A(?:preview|main)\z}xms;
    croak "Invalid weight_range ($weight_range)" if $weight_range !~ m{\A[1-9]\d*\z}m;
    croak "Undefined channel_id" if not defined $channel_id;

    my $qry_value = qq{SELECT v.value FROM ($sort_var_ref->{qry}) v ORDER BY v.value};
    my $sth_value = $dbh->prepare($qry_value);
    $sth_value->execute();

    my $stat = Statistics::Descriptive::Full->new();
    $stat->presorted(1);

    my $value;
    $sth_value->bind_columns(\$value);
    while ( $sth_value->fetch ) {
        $stat->add_data($value);
    }

    my ($values_min, $values_max, $values_range, $values_mean, $values_median, $values_mode, $values_stdev);
    $values_min     = $stat->min();
    $values_max     = $stat->max() || 1;
    $values_range   = $stat->sample_range();
    $values_mean    = $stat->mean();
    $values_median  = $stat->median();
    $values_mode    = $stat->mode();
    $values_stdev   = $stat->standard_deviation();

    my $str_stats   = '';
    $str_stats     .= "Variable: $sort_var_ref->{name}\n";
    $str_stats     .= "Default weight: $sort_var_ref->{default_weight}\n";
    $str_stats     .= "Min: $values_min\nMax: $values_max\nRange: $values_range\n";
    $str_stats     .= "Mean: $values_mean\nMedian: $values_median\nMode: $values_mode\n";
    $str_stats     .= "Standard Deviation: $values_stdev\n";

    my $weighting_coefficients_ref = get_weighting_coefficients( { dbh => $dbh, destination => $destination, channel_id => $channel_id } );

    my ($weight, $ceiling);

    ##TODO: do something cleverer with stats below...

    if (any { $sort_var_ref->{name} eq $_ }
        qw(price available_to_sell pcnt_sizes_in_stock inverse_upload_days inverse_price)
    ) {
        $weight = ($weighting_coefficients_ref->{ $sort_var_ref->{name} } // 0) * ($WEIGHT_RANGE / $values_max);
    }
    else {
        croak "Invalid variable specified ($sort_var_ref->{name})";
    }
    $ceiling = $WEIGHT_RANGE;
    croak "Invalid ceiling ($ceiling)" if $ceiling <= 0;

    $str_stats .= "Calculated weight: $weight\n";
    $logger->debug("$str_stats\n\n");

#    if ( $create_graphs ) {
#        my %freq_dist   = $stat->frequency_distribution(100);
#        _create_graph( { name => $sort_var_ref->{name}, data_ref => \%freq_dist } );
#    }

    my $weight_ref = { weight => $weight, ceiling => $ceiling };

    return $weight_ref;

} ## END sub _calculate_weighting



sub list_pws_sort_variables :Export() {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};

    my $qry = q{SELECT * FROM product.pws_sort_variable};
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    return results_list($sth);

} ## END sub list_pws_sort_variables



sub list_pws_sort_variable_weightings :Export() {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $destination = defined $arg_ref->{destination} ? $arg_ref->{destination} : '';
    my $channel_id  = $arg_ref->{channel_id};

    croak "Invalid destination ($destination).  Must be be 'preview' or 'main'" if $destination !~ m{\A(?:preview|main)\z}xms;

    ## list sort variables, with the most recent sort_variable_weighting values for the specified destination
    my $qry
        = q{SELECT
                psv.id
            ,   psv.name
            ,   psv.description
            ,   psvw.relative_weighting
            ,   psd.name AS destination
            ,   psvw.created
            ,   op.name AS created_by
            FROM product.pws_sort_variable psv
            INNER JOIN product.pws_sort_variable_weighting psvw
                ON (psvw.pws_sort_variable_id = psv.id)
            INNER JOIN product.pws_sort_destination psd
                ON (psvw.pws_sort_destination_id = psd.id)
            INNER JOIN operator op
                ON (psvw.created_by = op.id)
            WHERE psvw.created =
                (SELECT MAX(created)
                FROM product.pws_sort_variable_weighting
                WHERE pws_sort_variable_id = psvw.pws_sort_variable_id
                AND channel_id = psvw.channel_id
                AND pws_sort_destination_id = psvw.pws_sort_destination_id)
            AND psd.name = ?
            AND psvw.channel_id = ?
            ORDER BY psv.id
        };
    my $sth = $dbh->prepare($qry);
    $sth->execute($destination, $channel_id);

    return results_list($sth);

} ## END sub list_pws_sort_variable_weightings



sub get_weighting_coefficients :Export() {

    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $destination = defined $arg_ref->{destination} ? $arg_ref->{destination} : '';
    my $channel_id  = $arg_ref->{channel_id};

    croak "Invalid destination ($destination).  Must be be 'preview' or 'main'" if $destination !~ m{\A(?:preview|main)\z}xms;
    croak "Undefined channel_id" if not defined $channel_id;

    my $pws_sort_variable_weightings_ref = list_pws_sort_variable_weightings( { dbh => $dbh, destination => $destination, channel_id => $channel_id } );

    my $weightings_total    = 0;
    my @weightings_values   = ();
    foreach my $variable_ref ( @{$pws_sort_variable_weightings_ref} ) {
        $weightings_total += $variable_ref->{relative_weighting};
        push @weightings_values, $variable_ref->{relative_weighting};
    }

    croak "non-positive weightings_total" if $weightings_total <= 0;
    my $max_value       = (reverse sort {$a <=> $b} @weightings_values)[0];
    my $scale_factor    = 1 / $max_value;

    my %weighting_coefficient = ();
    foreach my $variable_ref ( @{$pws_sort_variable_weightings_ref} ) {
        $weighting_coefficient{ $variable_ref->{name} } = ($scale_factor * $variable_ref->{relative_weighting});
    }

    return \%weighting_coefficient;

} ## END get_weighting_coefficients



sub _clear_sort_data {

    my ($arg_ref)   = @_;
    my $dbh_trans   = $arg_ref->{dbh};
    my $destination = defined $arg_ref->{destination} ? $arg_ref->{destination} : '';
    my $channel_id  = $arg_ref->{channel_id};

    croak "Invalid destination ($destination).  Must be be 'preview' or 'main'" if $destination !~ m{\A(?:preview|main)\z}xms;

    foreach my $table ( qw(pws_product_sort_variable_value pws_sort_order) ) {
        my $sql_delete  = qq{DELETE FROM product.$table WHERE channel_id = ? AND pws_sort_destination_id = (SELECT id FROM product.pws_sort_destination WHERE name = ?)};
        my $sth_delete  = $dbh_trans->prepare($sql_delete);
        $sth_delete->execute($channel_id, $destination);
    }

    return;

} ## END sub _clear_table_data


=for hide
sub _create_graph {

    my ($arg_ref)   = @_;
    my $name        = $arg_ref->{name};
    my $data_ref    = $arg_ref->{data_ref};

    my @data = ();

    foreach ( sort {$a <=> $b} keys %{$data_ref} ) {
        push @{ $data[0] }, $_;
        push @{ $data[1] }, $data_ref->{$_};
    }

    my $y_max_value = ( reverse sort {$a <=> $b} (@{$data[1]}) )[0];
    $y_max_value += (2 * ($y_max_value / 100));
    $y_max_value = int($y_max_value);

    my $graph = GD::Graph::bars->new(1024, 768);

    $graph->set(
        title               => 'Frequency Distribution',
        x_label             => "Range ($name)",
        x_label_position    => 0.5,
        x_labels_vertical   => 1,
        y_label             => 'Frequency',
        y_label_position    => 0.5,
        y_tick_number       => 10,
        y_max_value         => $y_max_value,
        dclrs               => [ qw(green blue cyan) ],
        show_values         => 1,
    ) or croak $graph->error;

    open IMG, '>',"$GRAPH_PATH/$name.png" or croak $!;
    binmode IMG;
    print IMG $graph->plot(\@data)->png;
    close IMG;

} ## END sub _create_graph
=cut


1;

__END__
