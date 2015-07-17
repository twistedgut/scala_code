package XT::Net::Seaview::Utils;

use NAP::policy "tt", 'class';
use XTracker::Config::Local qw/ config_var /;

=head1 NAME

XT::Net::Seaview::Utils

=head1 DESCRIPTION

Seaview helper utilities

=head1 CLASS METHODS

=head2 category_urn

Construct a Seaview category URN from an XT local category name

=cut

sub category_urn {
    my ($class, $category_name) = @_;

    my $urn_root = 'urn:nap:category:';
    my $category_str = lc($category_name);
    $category_str =~ s/[^\w]/ /xmsg;
    $category_str =~ s/\A\s+//xmsg;
    $category_str =~ s/\s+\Z//xmsg;
    $category_str =~ s/\s+/_/xmsg;

    return $urn_root . $category_str;
}

=head2 urn_to_category

Construct an XT local category name from a Seaview category URN

=cut

sub urn_to_category {
    my ($class, $category_urn) = @_;

    my $category = undef;
    my $fully_capitalised_words = { eip => 1,
                                    psp => 1,
                                    pr  => 1,
                                    ip  => 1,
                                    vip => 1,
                                    ton => 1 };

    my $parenthesised_phrases
      = { psp_personal_shopping_program => { open => 'personal',
                                             close => 'program', }};

    my $mixedcap_words = { founderscard => 'FoundersCard' };
    my $all_bets_off = { pr_discount => 'PR discount' };

    my $hyphenated_phrases
      = { ex_eip => [qw/ex eip/],
          hot_contact_client_relations => [qw/contact client/], };

    (my $category_part = $category_urn) =~ s/urn:nap:category://xmsg;

    if( exists $all_bets_off->{$category_part} ){
        $category = $all_bets_off->{$category_part};
    }
    else {

        foreach my $word (split /_/, $category_part){

            if( defined $fully_capitalised_words->{$word} ){
                $category .= uc($word);
            }
            elsif( defined $mixedcap_words->{$word} ){
                $category .= $mixedcap_words->{$word};
            }
            else {
                if(defined $parenthesised_phrases->{$category_part}){
                    if($word
                         eq $parenthesised_phrases->{$category_part}->{open}){
                        $category .= '(' . ucfirst($word);
                    }
                    elsif($word
                            eq $parenthesised_phrases->{$category_part}->{close} ){
                        $category .= ucfirst($word) . ')';
                    }
                    else {
                        $category .= ucfirst($word);
                    }
                }
                else {
                    $category .= ucfirst($word);
                }
            }

            if(defined $hyphenated_phrases->{$category_part}->[0]){
                if( $word eq $hyphenated_phrases->{$category_part}->[0] ){
                    $category .= ' - ';
                }
                else {
                    $category .= ' ';
                }
            }
            else {
                $category .= ' ';
            }
        }
    }

    # Trim trailing whitespace
    $category =~ s/\s+$//xmsg;

    return $category;
}

=head2 state_county_switch

In the webapp and Seaview we have distinct fields 'state' and 'county'. In the
XT database we have a single field called 'county' which contains the 'state'
value sent over in the order file in DC2 and contains the 'county' value *if
present* otherwise the 'state' value in DC1 and DC3. Oh deary me.

This method replicates the conditional state/county logic from
XT::Order::Parser::PublicWebsiteXML on an individual address

=cut

sub state_county_switch {
    my ($class, $address) = @_;

    # Get distribution centre for mangling state/county
    my $dc = config_var('DistributionCentre', 'name');

    if( $dc eq 'DC2' ){
        # In DC2 always use the 'state' field if present
        if( defined $address->{state} ){
            $address->{county} = $address->{state};
        }
    }
    else {
        # In DC{1,3} use the 'state' field if present and 'county'
        # is empty
        if( defined $address->{state} ){
            $address->{county} ||= $address->{state};
        }
    }

    return $address;
}

