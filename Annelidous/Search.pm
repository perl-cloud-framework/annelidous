#!/usr/bin/perl

package Annelida::Search;

use strict;

use DBI;
use Data::Dumper;

# Email
use MIME::Lite::TT;
sub new {
	my $class=shift;
	my $self={
		subclass=>undef,
		@_
	};

	#
	# If we were given a subclass, then return an object of that
	# subclass instead.  This way, for instance, you can create a new
	# search based on the Annelida::Search::XenCfgDir module with the
	# following code:
	#	
	# PERL> new Annelida::Search(subclass=>'Annelida::Search::XenCfgDir')
	#
	# While users could just do this directly, doing it this way allows
	# code based on this module to store the subclass as a configuration
	# variable and just pass the "hard" work to us.
	#
	if (defined($self->{subclass})) {
		eval { 
			require $self->{subclass};
			$self=new $self->{subclass};
		};
		if ($@) {
			return {};
		}
	} else {
		bless $self, $class;
	}

	return $self;
}

# DBI gives us a nice easy way to do this, but
# it is ugly, so I wrapped it up in a nice package.
sub db_fetch {
	my $self=shift;
    my $statement=shift;
    return @{$self->{dbh}->selectall_arrayref($statement,{ Slice=>{} }, @_)};
}

# where @to is a client-list or any array of hashes containing key email.
# args (template, subject, from, (ClientList) @cl)
sub email_list {
	my $self=shift;
    my $template = shift;
    my $subject = shift;
    my $from = shift;
    my @cl = @_;

    foreach my $client (@cl) {
        #print Dumper $client;
        my $msg = MIME::Lite::TT->new(
            From => $from,
            To => $client->{'email'},
            Subject => $subject,
            Template => $template,
            TmplOptions => {
                INCLUDE_PATH => 'email-tmpl'
            },
            TmplParams => $client
        );
        $msg->send;
    }
}

#
# Generic function to find a group/batch,
# given a search method and a list of search terms...
#
sub find_group {
	my $self=shift;
    my $method=shift;
    my @terms=@_;
    my @result_set;
    foreach my $t (@terms) {
        eval("push \@result_set, find_".$method."(\$t);");
    }
    return @result_set;
}

1;
