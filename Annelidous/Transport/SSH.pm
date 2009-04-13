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

#
# STUB: This file is only stub!
#
package Annelidous::Transport::SSH;
use base 'Annelidous::Transport';

sub new {
	my $self={
	    use_openssh=>0,
	    username=>'root',
	    account=>undef,
	    @_
	};
	bless $self, shift;
	
	if ($self->{use_openssh}==0) {
	    require Net::SSH::Perl;
	    $self->login();
	}
	
	return $self;
}

sub login {
    my $self=shift;    
    $self->{_session} = Net::SSH::Perl->new($self->get_host);
    $self->{_session}->login($self->{username});
}

sub _session {
    my $self=shift;
    # We want to make sure that we're connected.
    # for this reason, subroutines connecting to the SSH session
    # should always use this method and not directly accessing the hash-key
    # of {_session}.
    eval {
        my $sock=$self->{_session}->sock;
    };
    if ($@) {
        $self->login();
    }
    return $self->{_session};
}

sub exec {
    my $self=shift;
    my @exec=@_;
    if ($self->{use_openssh}) {
        system("ssh","-l","root",@exec);
    } else {
        $self->_session->cmd(join (" ",@exec));
    }
}

1;