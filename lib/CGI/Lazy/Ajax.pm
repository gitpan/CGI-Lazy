package CGI::Lazy::Ajax;

use strict;
use warnings;

use JSON;
use JavaScript::Minifier qw(minify);
use CGI::Lazy::Globals;
use CGI::Lazy::Ajax::Dataset;
use CGI::Lazy::Ajax::DomLoader;
use CGI::Lazy::Ajax::Composite;

#----------------------------------------------------------------------------------------
sub ajaxReturn {
	my $self = shift;
	my $widgets = shift;
	my $data = shift;

	my @widgetlist = ref $widgets  eq 'ARRAY' ? @$widgets : ($widgets);
	my @datalist = ref $data eq 'ARRAY' ? @$data : ($data);

	my $outgoingdata;
       	$outgoingdata .= $_ for @datalist;

	my $validator = {};

	$validator->{$_->widgetID} = $_->validator for @widgetlist;

	my $json = to_json($validator);

        return '{"validator" : '.$json.', "html" : "'.$outgoingdata .'"}';

}

#----------------------------------------------------------------------------------------
sub ajaxSelect {
	my $self = shift;
	my %args = @_;

	my $incoming = $args{incoming} || from_json(($self->q->param('POSTDATA') || $self->q->param('keywords') || $self->q->param('XForms:Model')));
	my $div = $args{div};
	my $vars = $args{vars};
	my $like = $args{like};
	my $likevars = $args{likevars};


	my $widgetID = $self->widgetID;
	my @fields;
	my $bind;
	my $binds = [];

#	$self->q->util->debug->edump($incoming);

	delete $incoming->{CGILazyID}; #key/value pair only used at cgi level, will cause problems here (set automatically by Dataset with name of widget)

	if ($like) {
		$bind = " like ? ";

	} else {
		$bind = " = ? ";
	}

	my %likemap = (
			'%?%'	=> sub {return '%'.$_[0].'%';},
			'?%'	=> sub {return $_[0].'%';},
			'%?'	=> sub {return '%'.$_[0];},

		      );

	foreach my $field (keys %$incoming) {
		unless ($field =~ /['"&;]\(\)/) {
			if ($incoming->{$field}) {
				(my $fieldname = $field) =~ s/^$widgetID-//;
				push @fields, $fieldname.$bind;
				if (ref $incoming->{$field}) {
					if ($likevars) {
						my $value = $likemap{$likevars}->(${$incoming->{$field}});
						push @$binds, $value;
					} else {
						push @$binds, ${$incoming->{$field}};
					}
				} else {
					if ($like) {
						my $value = $likemap{$like}->($incoming->{$field});
						push @$binds, $value;
					} else {
						push @$binds, $incoming->{$field};
					}
				}
			}
		}
	}
	
	my $bindstring = join ' and ', @fields;	
	
	$self->recordset->where($bindstring);

#	$self->q->util->debug->edump("bindstring: $bindstring binds: @$binds");

	my %parameters = (
			mode => 'select', 
			binds => $binds, 
			vars => $vars, 
			);

	$parameters{nodiv} = 1 unless $div; #pass the div tag if we prefer

	return $self->rawContents(%parameters);
}

#----------------------------------------------------------------------------------------
sub ajaxBlank {
	my $self = shift;

	return $self->rawContents(mode => 'blank', nodiv => 1);
}

#----------------------------------------------------------------------------------------
sub composite {
	my $self = shift;
	my $vars = shift;
	
	return CGI::Lazy::Ajax::Composite->new($self->q, $vars);
}

#----------------------------------------------------------------------------------------
sub config {
	my $self = shift;

	return $self->q->config;
}

#----------------------------------------------------------------------------------------
sub dataset {
	my $self = shift;
	my $vars = shift;

	return CGI::Lazy::Ajax::Dataset->new($self->q, $vars);
}

#----------------------------------------------------------------------------------------
sub db {
	my $self = shift;

	return $self->q->db;
}

#----------------------------------------------------------------------------------------
sub dbwrite {
	my $self = shift;
	my %args = @_;

	if (ref $self eq 'CGI::Lazy::Ajax::Composite') {
		foreach (@{$self->memberarray}) {
			$_->dbwrite;
		}
		return;
	}

	my %deleteargs = %{$args{delete}} if $args{delete};
	delete $args{delete};
	my %updateargs = %{$args{update}} if $args{update};
	delete $args{update};
	my %insertargs = %{$args{insert}} if $args{insert};
	delete $args{insert};

	$deleteargs{$_} = $args{$_} for keys %args;
	$updateargs{$_} = $args{$_} for keys %args;
	$insertargs{$_} = $args{$_} for keys %args;

	$self->rundelete(%deleteargs);
	$self->update(%updateargs);
	$self->insert(%insertargs);


	return;
}

#----------------------------------------------------------------------------------------
sub displaySelect {
	my $self = shift;
	my %args = @_;

	my $vars = $args{vars};

	my @fields;
	my $binds = [];

#	$self->q->util->debug->edump($incoming);

	foreach my $field (grep {!/vars/} keys %args) {
		unless ($field =~ /['"&;]/) {
			if ($args{$field}) {
				push @fields, $field." = ? ";
				if (ref $args{$field}) {
					push @$binds, ${$args{$field}};
				} else {
					push @$binds, $args{$field};
				}
			}
		}
	}
	
	my $bindstring = join ' and ', @fields;	
	
	$self->recordset->where($bindstring);

#	$self->q->util->debug->edump("bindstring: $bindstring binds: @$binds");

	return $self->display(mode => 'select', binds => $binds, vars => $vars );
}

#----------------------------------------------------------------------------------------
sub deletes {
	my $self = shift;

	if (ref $self eq 'CGI::Lazy::Ajax::Composite') {
		foreach (@{$self->memberarray}) {
			$_->deletes;
		}
		return;
	}

        my $data;
	my $widgetID = $self->vars->{id};

        foreach my $key (grep {/^$widgetID-:DELETE:/} $self->q->param) {
                if ($key =~ /^($widgetID-:DELETE:)(.+)-:-(.+)::(\d+)$/) {
			my ($pre, $fieldname, $ID, $row) = ($1, $2, $3, $4);
			$data->{$ID}->{$fieldname} = $self->q->param($key) if $self->q->param($key);
		} elsif ($key =~ /^($widgetID-:DELETE:)(.+)-:-(.+)$/) {
			my ($pre, $fieldname, $ID) = ($1, $2, $3);
			$data->{$ID}->{$fieldname} = $self->q->param($key) if $self->q->param($key);
		}
        }
        return $data;
}

#----------------------------------------------------------------------------------------
sub displayblank {
	my $self = shift;

	return $self->display(mode => 'blank'); #run display function with blank argument
}

#----------------------------------------------------------------------------------------
sub domload {
	my $self = shift;

	my $objectJs;

        foreach my $object (keys %{$self->vars->{objects};}) {
		$objectJs .= "var $object = JSON.parse('".to_json($self->vars->{objects}->{$object})."');\n";
        }

        $objectJs = $self->jswrap($objectJs) if $objectJs;

	return $objectJs;
}

#----------------------------------------------------------------------------------------
sub domloader {
	my $self = shift;
	my $vars = shift;

	return CGI::Lazy::Ajax::DomLoader->new($self->q, $vars);
}

#----------------------------------------------------------------------------------------
sub insert {
	my $self = shift;
	my %vars = @_;

	if (ref $self eq 'CGI::Lazy::Ajax::Composite') {
		foreach (@{$self->memberarray}) {
			$_->insert(%vars);
		}
		return;
	}

	$self->recordset->insert($self->inserts, \%vars);
	return;
}

#----------------------------------------------------------------------------------------
sub inserts {
	my $self = shift;

	if (ref $self eq 'CGI::Lazy::Ajax::Composite') {
		foreach (@{$self->memberarray}) {
			$_->inserts;
		}
		return;
	}

        my $data;
	my $widgetID = $self->vars->{id};

        foreach my $key (grep {/^$widgetID-:INSERT:/} $self->q->param) {
                if ($key =~ /^($widgetID-:INSERT:)(.+)--(\d+)$/) {
			my ($pre, $field, $row) = ($1, $2, $3);
			$data->{$row}->{$field} = $self->q->param($key) if $self->q->param($key);
#			$self->q->util->debug->edump($field, $self->q->param($key)) if $self->q->param($key);
		} elsif ($key =~ /^($widgetID-:INSERT:)--(.+)$/) {
			my ($pre, $field) = ($1, $2);
			$data->{1}->{$field} = $self->q->param($key) if $self->q->param($key);
		}
        }

#	$self->q->util->debug->edump($data);
        return $data;
}

#----------------------------------------------------------------------------------------
sub jsload {
	my $self = shift;
	my $file = shift;
	
	my $jsdir = $self->q->config->jsDir;
	my $docroot = $ENV{DOCUMENT_ROOT};
	$docroot =~ s/\/$//; #strip the trailing slash so we don't double it

	open IF, "< $docroot$jsdir/$file" or $self->q->errorHandler->couldntOpenJsFile($docroot, $jsdir, $file, $!);
	my $script = minify(input => *IF);

	close IF;

	return $self->jswrap($script);

}

#----------------------------------------------------------------------------------------
sub jsonescape {
	my $self = shift;
	my $target = shift;

	if (ref $target eq 'HASH') {
		foreach (keys %$target) {
			foreach (values %{$target->{$_}}) {
				s/'//g;
			}
		}

	} elsif (ref $target eq 'ARRAY') { #finish this
		foreach (@$target) {
			
		}

	} else {

	}
}

#----------------------------------------------------------------------------------------
sub jswrap {
	my $self = shift;
	my $js = shift;
	my $jspre = "\n<script type='text/javascript'>\n<!--\n";
	my $jspost = "\n-->\n</script>\n";
	return $jspre.$js.$jspost;
}

#----------------------------------------------------------------------------------------
sub q {
	my $self = shift;

	return $self->{_q};
}

#----------------------------------------------------------------------------------------
sub new {
	my $class = shift;
	my $q = shift;

	return bless {_q => $q }, $class;
}

#----------------------------------------------------------------------------------------
sub postdata {
        my $self = shift;

	if (ref $self eq 'CGI::Lazy::Ajax::Composite') {
		foreach (@{$self->memberarray}) {
			$_->postdata;
		}
		return;
	}

        my $data;
	my $widgetID = $self->vars->{id};

        foreach my $key (grep {/^$widgetID/} $self->q->param) {
                $key =~ /^($widgetID-)(.+)(\d*)$/;
                my ($pre, $field, $row) = ($1, $2, $3);
                $data->{$row}->{$field} = $self->q->param($key) if $self->q->param($key);
        }

        return $data;
}

#----------------------------------------------------------------------------------------
sub preloadLookup {
	my $self = shift;

	my $preloadLookupJs;
        my $lookups = $self->vars->{lookups};
        my %lookuptype = (
                        hash            => 'gethash',
                        hashlist        => 'gethashlist',
                        array           => 'getarray',
                        );

        foreach my $queryname (keys %$lookups) {
                if ($lookups->{$queryname}->{preload}) {
                        my $query = $lookups->{$queryname}->{sql};
                        my $binds = $lookups->{$queryname}->{binds};
                        my $output = $lookups->{$queryname}->{output};

                        my $orderby = $lookups->{$queryname}->{orderby};
                        my $orderbystring = join ',', @$orderby;
                        $query .= " order by " if $orderby;
                        $query .=$orderbystring;

                        my $results;

                        if ($lookuptype{$output} eq 'gethash') {
                                $results = $self->db->gethash($query, $binds, $lookups->{$queryname}->{primarykey});
                        } else {
                                my $type = $lookuptype{$output};
                                $results = $self->db->$type($query, $binds);
                        }

                        $results = [] unless ref $results;
                        $self->jsonescape($results);

                        $preloadLookupJs .= "var $queryname = JSON.parse('".to_json($results)."');\n";
                }
        }
        $preloadLookupJs = $self->jswrap($preloadLookupJs) if $preloadLookupJs;

	return $preloadLookupJs;
}

#----------------------------------------------------------------------------------------
sub rawContents {
	my $self = shift;
	my %args = @_;

	my $output = $self->contents(%args);
	$output =~ s/"/\\"/g;
	$output =~ s/[\t\n]//g;

	return $output;
}

#----------------------------------------------------------------------------------------
sub recordset {
	my $self = shift;

	return $self->{_recordset};
}

#----------------------------------------------------------------------------------------
sub rundelete {
	my $self = shift;
	my %vars = @_;

	if (ref $self eq 'CGI::Lazy::Ajax::Composite') {
		foreach (@{$self->memberarray}) {
			$_->rundelete(%vars);
		}
		return;
	}

	$self->recordset->delete($self->deletes);

	return;
}

#----------------------------------------------------------------------------------------
sub update {
	my $self = shift;
	my %vars = @_;

	if (ref $self eq 'CGI::Lazy::Ajax::Composite') {
		foreach (@{$self->memberarray}) {
			$_->update(%vars);
		}
		return;
	}

#	$self->q->util->debug->edump('fromupdate', $self->updates, \%vars);
	$self->recordset->update($self->updates, \%vars);

	return;
}

#----------------------------------------------------------------------------------------
sub updates {
	my $self = shift;

	if (ref $self eq 'CGI::Lazy::Ajax::Composite') {
		foreach (@{$self->memberarray}) {
			$_->updates;
		}
		return;
	}

        my $data;
	my $widgetID = $self->widgetID;

        foreach my $key (grep {/^$widgetID-:UPDATE:/} $self->q->param) {
                if ($key =~ /^($widgetID-:UPDATE:)(.+)-:-(.+)::(\d+)$/) {
			my ($pre, $fieldname, $ID, $row) = ($1, $2, $3, $4);
			$data->{$ID}->{$fieldname} = $self->q->param($key) if $self->q->param($key);
		} elsif ($key =~ /^($widgetID-:UPDATE:)(.+)-:-(.+)$/) {
			my ($pre, $fieldname, $ID) = ($1, $2, $3);
			$data->{$ID}->{$fieldname} = $self->q->param($key) if $self->q->param($key);
		}
        }
#	$self->q->util->debug->edump($data);
        return $data;
}

#----------------------------------------------------------------------------------------
sub validator {
	my $self = shift;

	return $self->{_validator};
}

#----------------------------------------------------------------------------------------
sub vars {
	my $self = shift;

	return $self->{_vars};
}

#----------------------------------------------------------------------------------------
sub widgetID {
	my $self = shift;

	return $self->{_widgetID};
}

1

__END__

=head1 LEGAL

#===========================================================================

Copyright (C) 2008 by Nik Ogura. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Bug reports and comments to nik.ogura@gmail.com. 

#===========================================================================

=head1 NAME

CGI::Lazy::Ajax

=head1 SYNOPSIS

	use CGI::Lazy;

	my $q = CGI::Lazy->new('/path/to/config');

	my $widget = $q->ajax->dataset({...});

=head1 DESCRIPTION

CGI::Lazy::Ajax is an abstract class for the Lazy Ajax widgets such as Dataset, Composite, and Domloader.

Its methods are called internally by its child classes.  There are, at present, no real uses for the class by itself.

=head1 METHODS

=head2 ajaxReturn ( widgets, data )

Wraps data (presumably from widget) in json format with validator from widgets for returning to browser in response to an ajax reqeust

=head3 widgets

List of widgets to be parsed for validators

=head3 data

Widget html output


=head2 ajaxSelect (args)

Runs select based on args and returns output.  


=head3 args

Hash of select parameters.  Expects to see a key called 'incoming' that contains the incoming parameters in widgetID-fieldname => value format.  

Widgets such as Dataset will also have a parameter called CGILazyID which will contain the name of the widget (for doing different things at the cgi level based on which widget is talking to the app). This key/value will be stripped automatically.

The rest of the hash supports the following options:

	div 		=> 1  #By default will be sans enclosing div tags, but div can be included if you pass div => 1.  This is useful for members of composite widgets.
	
	like		=> '%?%' # search will be like %value%, in other words anything containing 'value'. Like is applied only to searches coming in from web, not vars added in cgi

	like	 	=> '?%'  # search will be on value%

	like		=> '%?'  # search on %v

	vars 		=> {fieldname => {optionname => optionvalue}}

	vars 		=> {fieldname => {value => 'bar'}} #extra search parameter.

	vars		=> {foo => {handle => $ref}}} # when retrieved $$ref will have the value of field foo. ('handle' is a 'handle' on that value for use in tying things together.)
	
	likevars	=> '%?%' # search will be like %value%, in other words anything containing 'value'.  like is applied to vars specified from cgi

	likevars 	=> '?%'  # search will be on value%

	likevars	=> '%?'  # search on %v



=head2 jsonescape ( var )

traverses variable and strips out single quotes to prevent JSON parser blowing up.

Strips them out rather than escaping them, as at present I can't figure out how to just add a single fracking backslash to them.  s/'/\\'/g gives 2 backslashes, and s/'/\'/g gives none.  grr.  problem seems to be in either JSON or JSONPARSER

=head3 var

whatever variable you're going to convert to json and then parse


=head2 preloadLookup

Runs queries for lookup tables and parses then into JSON wrapped in javascript suitable for loading into the DOM of a page.

Useful only for tables that are intended to be preloaded into a page at load. 


=head2 ajaxBlank ()

Convenience method.  Returns blank widget output


