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

package Annelidous::Transport;

sub new {
	my $self={};
	bless $self, shift;
	return $self;
}

sub get_host {
    my $self=shift;
    my $guest=$self->{account};
    
    if (defined ($guest->{host})) {
        $hostname=$guest->{host};
    } elsif (defined ($guest->{cluster})) {
        $hostname=$self->parent->search->get_cluster($guest->{cluster})->get_host;
    } else {
        $hostname=$self->parent->search->get_default_cluster()->get_host;
    }
}

1;