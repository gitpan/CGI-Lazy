=head1 LEGAL

#===========================================================================
Copyright (C) 2008 by Nik Ogura. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Bug reports and comments to nik.ogura@gmail.com. 

#===========================================================================

=head1 NAME

CGI::Lazy::Session

=head1 SYNOPSIS

use CGI::Lazy;
our $q = CGI::Lazy->new({
				tmplDir 	=> "/templates",
				jsDir		=>  "/js",
				plugins 	=> {
					mod_perl => {
						PerlHandler 	=> "ModPerl::Registry",
						saveOnCleanup	=> 1,
					},
					ajax	=>  1,
					dbh 	=> {
						dbDatasource 	=> "dbi:mysql:somedatabase:localhost",
						dbUser 		=> "dbuser",
						dbPasswd 	=> "letmein",
						dbArgs 		=> {"RaiseError" => 1},
					},
					session	=> {
						sessionTable	=> 'SessionData',
						sessionCookie	=> 'frobnostication',
						saveOnDestroy	=> 1,
						expires		=> '+15m',
					},
				},
			});

=head1 DESCRIPTION

CGI::Lazy::Session is for maintaining state between requests.  It's enabled in the config file or config hash.  Once it's enabled, any calls to $q->header will automatically include a cookie that will be used to retrieve session data.

To function, the session needs the following arguments:
	sessionTable	=> name of table to store data in
	sessionCookie	=> name of the cookie
	expires		=> how long a session can sit idle before expiring

By default, sessions are automatically saved when the Lazy object is destroyed, or in the cleanup stage of the request cycle for mod_perl apps.  Both mechanisms are enabled by default.  (call me paranoid)  Should you wish to disable the save on destroy:
	saveOnDestroy	=> 0

If the key is missing from the config, it's as if it was set to 1.  You will have to set it to 0 to disable this functionality.  Same goes for the mod_perl save.  See CGI::Lazy::ModPerl for details

Session data is stored in the db as JSON formatted text at present.  Fancier storage (for binary data and such) will have to wait for subsequent releases.

The session table must have the following fields at a bare minimum:

	sessionID	not null, primary key
	data		text (mysql) large storage (blob in oracle)
	expired		bool (mysql) 1 digit number basically

=cut

package CGI::Lazy::Session;

use strict;
use warnings;

use JSON;
use CGI::Lazy::ID;
use CGI::Lazy::CookieMonster;
use CGI::Lazy::Session::Data;
use CGI::Lazy::Globals;

#--------------------------------------------------------------------------------------
=head2 cookiemonster

returns reference to CGI::Lazy::CookieMonster object

=cut

sub cookiemonster {
	my $self = shift;
	
	return $self->{_cookiemonster};
}

#--------------------------------------------------------------------------------------
=head2 config

returns reference to the config object

=cut

sub config {
	my $self = shift;
	
	my $q = $self->q;
	return $q->config;
}

#----------------------------------------------------------------------------------------------	
=head2 data ()

returns reference to the CGI::Lazy::Session::Data object

=cut

sub data {
	my $self = shift;
	return $self->{_data};
}

#--------------------------------------------------------------------------------------
=head2 db ()

returns reference to CGI::Lazy::DB object

=cut

sub db {
	my $self = shift;
	
	return $self->q->db;

}

#--------------------------------------------------------------------------------------
=head2 expire ()

expires the session

=cut

sub expire {
	my $self = shift;

	my $table = $self->sessionTable;

	$self->db->do("update $table set expired = 1 where sessionID = ?", $self->sessionID);

	return;
}

#----------------------------------------------------------------------------------------------	
=head2 expires ()

Returns time in epoch when session expires.

=cut

sub expires {
	my $self = shift;
	return $self->{_expires};
}

#---------------------------------------------------------------------------------------
=head2 getData ()

Called internally on CGI::Lazy::Session::Data creation.  Queries db for session data

=cut

sub getData {
	my $self = shift;

	my $sessionTable = $self->config->plugins->{session}->{sessionTable};
	my $results = $self->db->getarray("select data from $sessionTable where sessionID = ?", $self->sessionID);
	my $data = $results->[0]->[0];

	if ($data) {
		return from_json($data);
	} else {
		return;
	}
}

#--------------------------------------------------------------------------------------
=head2 id ()

returns session id

=cut

sub id {
	my $self = shift;

	return $self->{_id};
}

#---------------------------------------------------------------------------------------
=head2 new ( sessionID )

Constructor.  Creates new session.

=head3 sessionID

valid session ID string

=cut

sub new {
	my $self = shift;
	my $sessionID = shift;

	my $sessionTable = $self->sessionTable;

	my $query = "insert into $sessionTable (sessionID, data) values (?, ?)";
	my $now = time();
	my $expires = $self->parseExpiry($now);
	
	#set creation time, expiry time, last accessed time
	my $var = {
		created	=> $now,
		updated	=> $now,
		expires	=> $expires,
	};

	my $data = to_json($var);

	$self->db->do($query, $sessionID, $data);

	return $sessionID;	
}
 
#--------------------------------------------------------------------------------------
=head2 open ( q sessionID )

Opens a previous session, or creates a new one.  If it's opening an existing session, it will check to see that the session given has not expired.   If it has, it will create a new one.

=head3 q

CGI::Lazy object

=head3 sessionID

valid session ID

=cut

sub open {
	my $class = shift;
	my $q = shift;
	my $sessionID = shift;

	my $self = {};
	$self->{_q} = $q;
	$self->{_sessionTable} = $q->plugin->session->{sessionTable};
	$self->{_sessionCookie} = $q->plugin->session->{sessionCookie};
	$self->{_expires} = $q->plugin->session->{expires};

	bless $self, $class;

	$self->{_cookiemonster} = CGI::Lazy::CookieMonster->new($q);
   	$self->{_id} = CGI::Lazy::ID->new($self);

       	$sessionID = $self->cookiemonster->getCookie($self->sessionCookie)  unless $sessionID;

	if ($sessionID) { #check sessionID against db, compare expiry time to last accessed time, reopen if valid
		#$q->util->debug->edump("have sessionID");
		$self->{_sessionID} = $sessionID;
		$self->{_data} = CGI::Lazy::Session::Data->new($self);
		
		my $now = time();
		my $expiry = $self->data->expires;

		if ($expiry > $now) { #valid sesion, update expiration
			#$q->util->debug->edump("not expired", "now: ".$now, "expires: ".$expiry, "difference: ".($expiry - $now));
			$self->data->expires($self->parseExpiry($now)); #reset expiry time

		} else {
			#$q->util->debug->edump("expired");
			$self->expire();

			$sessionID = $self->new($self->id->generate); #session expired.  create a new one
		}

	} else { # create new session
		$sessionID = $self->new($self->id->generate); #if we don't have a valid sessionID, we'll generate one
	}

	$q->errorHandler->badSession($sessionID) unless $self->id->valid($sessionID); #error out if we still don't have something we can work with.

	$self->{_sessionID} = $sessionID;
	$self->{_data} = CGI::Lazy::Session::Data->new($self);

	return $self;

}

#--------------------------------------------------------------------------------------
=head2 parseExpiry ( time)

Parses expiration string from session plugin and returns time in epoch when session should expire.

Currently only can parse seconds, minutes, hours and days.  Is more really necessary?

=head3 time
epoch returned from time() function

=cut 

sub parseExpiry {
	my $self = shift;
	my $time = shift;

	my $expirestring = $self->expires;

	$expirestring =~ /([+-])(\d+)(\w)/;
	my ($sign, $num, $unit) = ($1, $2, $3);

	unless ($sign && $num && $unit) {
		$self->q->errorHandler->badSessionExpiry;
	}

	my $minute = 60; #seconds in a minute
	my $hour = 3600; #seconds in an hour
	my $day = 43200; #seconds in a day
	my $factor;
	my $expiry;

	if ($unit eq 'm') {
		$factor = $minute * $num;
	} elsif ($unit eq 'h') {
		$factor = $hour * $num;
	} elsif ($unit eq 'd') {
		$factor = $day * $num;
	} else { #we'll assume it's seconds then (why would someone do this?)
		$factor = $num;
	}

	if ($sign eq '+') {
		$expiry = $time + $factor;
	} elsif ($sign eq '-') {
		$expiry = $time - $factor;
	}
	
	return $expiry;
}

#--------------------------------------------------------------------------------------
=head2 q ()

returns reference to CGI::Lazy object

=cut 

sub q {
	my $self = shift;

	return $self->{_q};
}

#--------------------------------------------------------------------------------------
=head2 sessionCookie ()

returns name of session cookie specified by session plugin

=cut

sub sessionCookie {
	my $self = shift;

	return $self->{_sessionCookie};
}

#--------------------------------------------------------------------------------------
=head2 sessionID ()

returns session id

=cut

sub sessionID {
	my $self = shift;
	
	return $self->{_sessionID};
}

#--------------------------------------------------------------------------------------
=head2 sessionTable ()

returns session table name specified by session plugin

=cut

sub sessionTable {
	my $self = shift;

	return $self->{_sessionTable};
}

#--------------------------------------------------------------------------------------
=head2 save ()

saves session variable to database

=cut

sub save {
	my $self = shift;

	my $sessionID = $self->sessionID;
	my $datastring = to_json($self->data->{_data});
	my $sessionTable = $self->q->plugin->session->{sessionTable};

	$self->db->do("update $sessionTable set data = ? where sessionID = ?", $datastring, $sessionID);
}

1
