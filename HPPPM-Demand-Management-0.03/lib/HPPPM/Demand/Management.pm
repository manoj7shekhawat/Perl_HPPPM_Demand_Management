package HPPPM::Demand::Management;

use strict;
use warnings;
use Carp;
use Moose;
use Template;
use LWP::UserAgent;
use Error::TryCatch;
use POSIX qw(strftime);
use LWP::Protocol::https;
use HTTP::Request::Common;
use namespace::autoclean;
use English qw(-no_match_vars);

our $VERSION = '0.01';

has 'ops_inputs_reqd' => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_set_ops_inputs_reqd',
);

has 'ops_inputs' => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_set_ops_inputs',
);

has 'operations' => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_set_operations',
);

has 'service_url' => (
    is      => 'rw',
    isa     => 'Str',
);

has 'current_operation' => (
    is      => 'rw',
    isa     => 'Str',
);

has 'user' => (
    is      => 'rw',
    isa     => 'Str',
);

has 'password' => (
    is      => 'rw',
    isa     => 'Str',
);

extends 'HPPPM::ErrorHandler';


#Stores the mapping between operation and the mandatory inputs/types.
#For e.x. "createRequest" operation needs atleast the "requestType"
#type to be present in the input fields.

sub _set_ops_inputs_reqd {
    my $self = shift;
    my %ops_inputs_reqd;

    %ops_inputs_reqd
        = (
            #operations          => Mandatory inputs/types
            createRequest        => ["serviceUrl", "requestType", "fields"],
            addRequestNotes      => ["serviceUrl", "requestId", "notes"],
            executeWFTransitions => ["serviceUrl", "receiver", "transition"],
            deleteRequests       => ["serviceUrl", "requestIds"],
            getRequests          => ["serviceUrl", "requestIds"],
            setRequestFields     => ["serviceUrl", "requestId", "fields"],
            setRequestRemoteReferenceStatus => ["serviceUrl", "receiver",
                                             "source", "status", "fields"],
          );

    return \%ops_inputs_reqd;
}


#Stores the mapping between operation and inputs/types.

sub _set_ops_inputs {
    my $self = shift;
    my %ops_inputs;

    %ops_inputs
        = (
            createRequest        => ["serviceUrl", "requestType", "fields",
                                     "URLReferences", "notes"],
            addRequestNotes      => ["serviceUrl", "requestId", "notes"],
            executeWFTransitions => ["serviceUrl", "receiver", "transition"],
            deleteRequests       => ["serviceUrl", "requestIds"],
            getRequests          => ["serviceUrl", "requestIds"],
            setRequestFields     => ["serviceUrl", "requestId", "fields"],
            setRequestRemoteReferenceStatus => ["serviceUrl", "receiver",
                                                "source", "status", "fields"],
          );

    return \%ops_inputs;
}


sub get_supported_ops {
    my $self = shift;

    return keys %{ $self->ops_inputs };
}


sub get_current_oper {
    my $self = shift;

    return $self->current_operation();
}


sub get_reqd_inputs {
    my $self = shift;
    my $oper = shift;

    return $self->ops_inputs_reqd->{ $oper } if $oper;
    return $self->ops_inputs_reqd();
}


sub get_inputs {
    my $self = shift;
    my $oper = shift;

    return $self->ops_inputs->{ $oper } if $oper;
    return $self->ops_inputs();
}


sub create_request {
    my $self   = shift;
    my $inputs = shift || confess "No inputs to construct request passed in!";
    my $tt     = Template->new( INTERPOLATE => 1);
    my $logger = Log::Log4perl->get_logger( $PROGRAM_NAME );
    my $oper   = $self->current_operation();
    my $req;
    
    $inputs->{'DATETIME'} = strftime ('%Y-%m-%dT%H:%M:%SZ', gmtime);
    $inputs->{'USER'}     = $self->user();
    $inputs->{'PASSWORD'} = $self->password();
    $inputs->{'CURRENT_OPERATION'} = $oper;

    $logger->info("Creating request for $oper operation");

    try {
        $tt->process("templates/$oper".'.tt2', $inputs, \$req) 
                          || throw new Error::Unhandled -text => $tt->error;
    }
    catch Error::Unhandled with {
        $logger->logcroak($tt->error);
    }

    $logger->info("Request created successfully!");
    $logger->debug("Request created:\n$req");

    return $req;
}


sub post_request {
    my $self   = shift;
    my $url    = shift || confess "No WebService url passed in!";
    my $req    = shift || confess "No request to post passed in!";
    my $ct     = shift || 'application/xml';
    my $ua     = LWP::UserAgent->new();
    my $logger = Log::Log4perl->get_logger( $PROGRAM_NAME );
    my $oper   = $self->current_operation();
    my $res;

    return 0 if ! $self->check_url_availability( $url );

    $logger->info("About to POST request to $url");

    try {
        $res = $ua->request(
                    POST         => $url,
                    Content_type => $ct,
                    Content      => $req,
               ) || throw new Error::Unhandled -text => $res->status_line;
    }
    catch Error::Unhandled with {
        $logger->logcroak( $res->status_line );
    }

    $logger->info("POSTing successful!");
    $logger->debug("Response received:\n".$res);

    return $res->content;
}

__PACKAGE__->meta->make_immutable;

1; # End of HPPPM::Demand::Management

__END__


=head1 NAME

HPPPM::Demand::Management - Web Service Automation for HPPPM Demand Management

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

Command Call:

perl bin/hpppm_demand.pl -o createRequest -u user -p password -f data/createRequest.data -c cfg/logging.conf

-o or --operation  is the webservice operation being performed

-u or --user       user authorized to perform web service operation

-p or --password   user's password

-f or --fields     location of file containing input fields that will be used to create
                   the web service request.Instead of a path this can also be a string
                   containing the input fields.A sample data file for each web service
                   operation has been bundled along with distribution under data dir.

-c or --logconfig  location to the configuration file that drives logging behavior.

-h or --help or -? display help.

Typical Usage:

$hpppm  = HPPPM::Demand::Management->new();

$fields = $hpppm->validate_read_cmdargs(@ARGV);

$tags   = $hpppm->get_inputs($hpppm->get_current_oper());

$inputs = FieldParser::parser($fields, $tags);

$ret    = $hpppm->validate_inputs($inputs); 

$ret    = $hpppm->validate_tokens($inputs->{'fields'}) 
                            if grep /^fields$/, @{ $tags };  

$ret    = $hpppm->extract($res, ['faultcode', 'faultstring', 
                                 'exception:detail', 'id', 'return']);

=head1 DESCRIPTION

A framework that helps automate the Web service interaction offered by
HP Project and Portfolio Management(aka - HPPPM).HPPPM is an industry
wide tool that is used to standardize, manage and capture the execution
of a project and operational activities.For more on HPPPM refer the
online documentation at HP.HPPPM offers Web Service operations to
various interfacing applications involved in a project to talk to each
other.HPPPM offers solutions for various activities of an organization
viz - application portfolio, demand, financial and so on.This framework
currently supports Demand Management only.

The framework is built up on 3 modules that have a designated task to do:

field_parser  - A Higher Order Perl parser meant to parse the input fields
                that will be used in creating the Web service request.
                This module is generic and can be used by others after
                tweaking as per need.

error_handler - Performs command line parsing, validation and error/info
                extraction.

demand_management - Creates the Web Service request and does an HTTP post
                    to the Web service.

All the above modules offer utilities/methods/functions to the outside
world.The framework is typically meant to run via a wrapper script that
uses the utilities offered.A sample wrapper script is bundled along with
this distribution under the bin dir.

A little knowledge in how HPPPM works is absolutely necessary if you
intend to use this framework to automate webservice calling for you.
In HPPPM each work item is designated as a request and is similar in
concept to a ticket in many ticketing systems.
A request in HPPPM is made up of request type, request header type
and workflow.The request type and header are made up of request fields,
validations, rules, security and statuses.The workflow is the request
component that gets activated once the request is submitted.The workflow
is made up various sub components that are classified as Executional,
Decisional, Conditional and SubWorkflows.The Decisional subcompnents
are the trigger points for user action and they in turn trigger the
Executional and/or Conditional sub components as governed by the
business logic.Please note that all fields have a unique token name
through which it is referenced internally and also in the Webservice
call.

Following are the Web Service Operations that the framework helps you
play with:

addRequestNotes - Add notes to an existing PPM request.

createRequest   - Create a new request in PPM.

deleteRequest   - Delete PPM requests.

executeWFTransitions - Move workflow and the request as a whole from
                       one Decision step to another.

getRequests     - Get PPM request fields and their values.

setRequestFields - Update fields of an existing PPM request.

setRequestRemoteReferenceStatus - Updates the status of a remote
                                  reference in a request in PPM.

example:

Let us assume that application XYZ wants to create a HP PPM request
using this framework.XYZ application will need the following(apart
from this framework installed and working)

username of the user authorized in PPM to do the webservice operation

password of the above user in PPM

input fields in the format the framework expects

A sample input field format:

"<serviceUrl>" "http://abc.com:8080/ppmservices/DemandService?wsdl" "</serviceUrl>" "<requestType>" "ABC" "</requestType>" "<fields>" "REQ.VP.APPLICATION" "COMMON" "REQ.VP.ID" "1102" "REQD.VP.RELATED" "No" "REQ.VP.PRIORITY" "2" "</fields>" "<URLReferences>" "abc" "abc" "abc" "</URLReferences>" "<notes>" "varun" "test by varun" "</notes>"

All token names and their values go inside the <fields> tags.If you are
setting URLReferences they must atleast have a single field which is the
name("abc" above) of the URLReference that will appear in the PPM request.
For notes write the authorname first followed by the note.Enclose all tags
,fields and their values in double quotes and separated by spaces.

The XYZ application needs to change the input fields as per their requirement
and use the command call listed in SYNOPSIS to create a request in the PPM
environment enclosed between serviceUrl tag.

Following is a listing of supported Web services operations and their
mandatory input types:

createRequest                   : serviceUrl, requestType, fields

addRequestNotes                 : serviceUrl, requestId, notes

executeWFTransitions            : serviceUrl, receiver, transition

deleteRequests                  : serviceUrl, requestIds

getRequests                     : serviceUrl, requestIds

setRequestFields                : serviceUrl, requestId, fields

setRequestRemoteReferenceStatus : serviceUrl, receiver, source, status, fields

Following is the sample input for various operations supported by this
framework:

addRequestNotes:
"<serviceUrl>" "http://abc.com:8080/ppmservices/DemandService?wsdl" "</serviceUrl>" "<requestId>" "30990" "</requestId>" "<notes>" "varun" "test by varun" "</notes>"

deleteRequests:
"<serviceUrl>" "http://abc.com:8080/ppmservices/DemandService?wsdl" "</serviceUrl>" "<requestIds>" "31520" "31521" "</requestIds>"

executeWFTransitions:
"<serviceUrl>" "http://abc.com:8080/ppmservices/DemandService?wsdl" "</serviceUrl>" "<receiver>" "31490" "</receiver>" "<transition>" "Review Complete" "</transition>"

getRequests:
"<serviceUrl>" "http://abc.com:8080/ppmservices/DemandService?wsdl" "</serviceUrl>" "<requestIds>" "30935" "30936" "</requestIds>"

setRequestFields:
"<serviceUrl>" "http://abc.com:8080/ppmservices/DemandService?wsdl" "</serviceUrl>" "<requestId>" "31490" "</requestId>" "<fields>" "REQD.VP.ORG" "ABC" "REQD.VP.DETAILED_DESC" "Test by Varun" "</fields>"

setRequestRemoteReferenceStatus:
"<serviceUrl>" "http://abc.com:8080/ppmservices/DemandService?wsdl" "</serviceUrl>" "<receiver>" "31490" "http://t.com:8090" "</receiver>" "<source>" "31490" "http://t.com:8090" "</source>" "<status>" "Assigned" "</status>" "<fields>" "REQD.VP.ORG" "Another test" "REQD.VP.DETAILED_DESC" "Another test Varun" "</fields>"

For reference sake the above sample inputs for various operations are also
saved in data dir under base distribution.

=head1 INHERITANCE,ATTRIBUTES AND ROLES

=head1 METHODS

=head2 get_supported_ops

Returns supported operations

=head2 get_current_oper

Returns current operation

=head2 get_reqd_inputs

Lists mandatory types needed inorder to perform the operation.If operation
is not passed or is undef, returns all the operations supported along
with the mandatory types for each.

for e.g. - for createRequest operation the input fields must have
           "requestType" and "fields".
 

=head2 get_inputs

Lists types needed inorder to perform the operation.If operation
is not passed or is undef, returns all the operations supported along
with the mandatory types for each.

for e.g. - for createRequest operation the input fields(mandatory and optional)
           have "requestType", "fields", "URLReferences", and "notes".

=head2 create_request

Creates request from inputs passed using templates

=head2 post_request 

POSTs the request to the url passed in.Checks if the web service url
is available before posting the request.

=head1 LOGGING & DEBUGGING

To enable troubleshooting the framework logs activites in a log file(
sample stored under logs dir).The logging is controlled via a config
file stored under cfg dir.

=head1 IMPORTANT NOTE

The framework supports test driven development and has a test suite
to help in unit testing.The test suite can be located under the t
dir under base dist.Also, before using this framework take a look
at the various templates under the templates directory and modify 
as per need.This framework works for HPPPM 9.14 and is backward
compatiable as well.However, if you come across any deviations please
feel free to mail me your observations.

=head1 AUTHOR

Varun Juyal, <varunjuyal123@yahoo.com>

=head1 BUGS

Please report any bugs or feature requests to C<bug-hpppm-demand-management at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=HPPPM-Demand-Management>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc HPPPM::Demand::Management


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=HPPPM-Demand-Management>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/HPPPM-Demand-Management>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/HPPPM-Demand-Management>

=item * Search CPAN

L<http://search.cpan.org/dist/HPPPM-Demand-Management/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Varun Juyal.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

