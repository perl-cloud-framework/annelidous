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

#
# All class variables starting '-' are arguments to 'new'.
# Method 'id' returns self{'_id'}, the set id.
# Thus, '-id' is an argument to 'new', '_id' is the current id.
#
sub new {
	my $class=shift;
	my $self={
		-id=>undef,
		-search_module=>undef
		@_
	};
	bless $self, $class;

	if (defined($self->{-search_module})) {
	    $self->search($self->{-search_module});
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
    if (my $result=$self->search->find_byid($given_id))
    {
        $self->init($result);
    }
    return $self->{_id};
}

#
# Accesses the search object.
# Optional argument sets the default search object...
#
sub search {
    my $self=shift;
    my $sobj=shift;
    if (defined($sobj)) {
        # Do we need to baby people this much?
        # Maybe its overkill...
        if (ref($sobj) eq "SCALAR") {
            $self->{_search_obj}=eval "new $sobj (".@_.")";
        } else {
            $self->{_search_obj}=$sobj;
        }
    }
    return $self->{_search_obj};
}

1;