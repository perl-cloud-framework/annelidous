#!/usr/bin/perl
#
# Annelidous - the flexibile cloud management framework
# Copyright (C) 2009  Eric Windisch <eric@grokthis.net>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

package Annelidous::VM;
use strict;

use Data::Dumper;

#
# All class variables starting '-' are arguments to 'new'.
# Method 'id' returns self{'_id'}, the set id.
# Thus, '-id' is an argument to 'new', '_id' is the current id.
#
sub new {
    my $invocant = shift;
    my $class   = ref($invocant) || $invocant;
	my $self={
		#-id=>undef,
		#-search_module=>undef
		#-connector_module=>undef
		@_
	};
	bless $self, $class;

	if (defined($self->{-search_module})) {
	    $self->search($self->{-search_module});
	}	

	if (defined($self->{-connector_module})) {
	    $self->search($self->{-connector_module});
	}	

	if (defined($self->{-id})) {
	    $self->id($self->{-id});
	}
	return $self;
}

sub init {
    my $self=shift;
    my $sresult=shift;
    $self->{_data}=$sresult;
    $self->{_id}=$self->{_data}->{id};
    return;
}

sub id {
    my $self=shift;
    my $given_id=shift;

    unless (defined($given_id)) {
        return $self->{_id};
    }
    
    # If we've gotten this far, we're setting a new id.
    if (my @result=$self->search->by_id($given_id)) {
        $self->init($result[0]);
    }

    return $self->{_id};
}

sub data {
	my $self=shift;
	return $self->{_data};
}

#
# Module wrapper
#
sub _module_wrapper {
    my $self=shift;
    my $objkey=shift;
    my $obj=shift;
    if (defined($obj)) {
        # Do we need to baby people this much?
        # Maybe its overkill...
        if (ref($obj) eq "SCALAR") {
            $self->{$objkey}=eval "new $obj (".@_.")";
        } else {
            $self->{$objkey}=$obj;
        }
    }
    return $self->{$objkey};
}

sub connector {
    my $self=shift;
    return $self->_module_wrapper('_connector_obj', @_)
}

sub search {
    my $self=shift;
    return $self->_module_wrapper('_search_obj', @_)
}

#sub uptime {
#	my $self=shift;
#	return $self->connector->uptime;
#}
#
#sub boot {
#	shift->connector->boot
#}
#
#sub shutdown {
#	shift->connector->shutdown
#}

1;
