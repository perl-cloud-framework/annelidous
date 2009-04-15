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

package Annelidous::Frontend;

sub new {
	my $self={};
	bless $self, shift;
	return $self;
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


1;