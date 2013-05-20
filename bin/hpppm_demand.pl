#!/usr/bin/perl -w

=head1 Purpose and Change log


    Changed by         Date                    Comment
						     
=cut

use strict;
use FieldParser qw(parser);
use HPPPM::Demand::Management;

my ($hpppm, $tags, $inputs, $req, $fields, $res, $ret);

#Initialize HPPPM::Demand::Management
$hpppm = HPPPM::Demand::Management->new();

$fields = $hpppm->validate_read_cmdargs(@ARGV);
$tags   = $hpppm->get_inputs($hpppm->get_current_oper());
$inputs = FieldParser::parser($fields, $tags);
$ret    = $hpppm->validate_inputs($inputs); 
$ret    = $hpppm->validate_tokens($inputs->{'fields'}) 
                            if grep /^fields$/, @{ $tags };  

$req    = $hpppm->create_request($inputs);
$res    = $hpppm->post_request($inputs->{'serviceUrl'}, $req);
$ret    = $hpppm->extract($res, ['faultcode', 'faultstring', 
                                 'exception:detail', 'id', 'return']);

print $res;
