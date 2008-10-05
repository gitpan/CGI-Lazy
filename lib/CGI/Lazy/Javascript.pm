package CGI::Lazy::Javascript;

use strict;
use warnings;

use CGI::Lazy::Globals;
use CGI::Lazy::Ajax::JSONParser;
use JavaScript::Minifier qw(minify);

#javascript for ajax requests
our $AJAXJS = q[
function ajaxSend(request, outgoing, returnHandler, returnTarget) {
    try {
        request = new XMLHttpRequest();
	browser = "standards-compliant";
    } catch (err) {
	try {
            	request = new ActiveXObject("Msxml12.XMLHTTP");
		browser = "bogus";
	} catch (err) {
		try {
			request = new ActiveXObject("Microsoft.XMLHTTP");
            		browser = "bogus";
		} catch (err) {
			alert("your browser doesn't support AJAX, try upgrading to Firefox");
                	request = null;
            	}
        }
    }

	try {
		request.open('POST',parent.location,true);
	} catch (err) {
		alert("AJAX call failed: "+ err);
	}
										
	request.send(JSON.stringify(outgoing)); 
	request.onreadystatechange = function() {
		if (request.readyState == 4) {
			returnHandler(request.responseText, returnTarget);
		}
	}
}
];

#javascript for sjax requests
our $SJAXJS = q[
function sjaxSend(request, outgoing, returnHandler) {
    try {
        request = new XMLHttpRequest();
	browser = "standards-compliant";
    } catch (err) {
	try {
            	request = new ActiveXObject("Msxml12.XMLHTTP");
		browser = "bogus";
	} catch (err) {
		try {
			request = new ActiveXObject("Microsoft.XMLHTTP");
            		browser = "bogus";
		} catch (err) {
			alert("your browser doesn't support AJAX, try upgrading to Firefox");
                	request = null;
            	}
        }
    }

	try {
		request.open('POST',parent.location,false);
	} catch (err) {
		alert("AJAX call failed: "+ err);
	}
										
	request.send(JSON.stringify(outgoing)); 
	returnHandler(request.responseText);
}
];

#javascript for Ajax::Dataset
our $DatasetJS = <<END;
function datasetController(ID, validator, ParentID, searchObject, flagcolor) {
	this.widgetID = ID;
	this.validator = validator;
	this.parentID = ParentID;
	this.flagcolor = flagcolor;
	this.fieldcolor = null;
	this.searchObject = searchObject;
}

datasetController.prototype.constructor = datasetController;

datasetController.prototype.deleteRow = function(caller) {
	var myRow = caller.parentNode.parentNode;
	var deleter;

	for (i=0;i<myRow.cells.length; i++) {
		var Cell;
		var Widget;

		for (var j=0; j< myRow.cells[i].childNodes.length; j++) {
			if (myRow.cells[i].childNodes[j].id) { //grab the first thing with an id
				Cell = myRow.cells[i];
				Widget = Cell.childNodes[j];
			}
		}
		
		if (/UPDATE/.test(Widget.name)) {
			Widget.name = Widget.name.replace(/UPDATE/, 'DELETE');
			Widget.disabled = true;
			try {
				this.validator[Widget.id].ignore = 1;
			} catch(e) {
			}
			if (!deleter) {
				deleter = document.createElement('input');
				deleter.type = 'hidden';
				deleter.name = Widget.name;
				deleter.id = Widget.name+'DELETER';
				deleter.value = 1;
				myRow.appendChild(deleter);
			}

		} else if (/DELETE/.test(Widget.name)) {
			Widget.disabled = false;
			try {
				this.validator[Widget.id].ignore = 0;
			} catch(e) {
			}
			Widget.name = Widget.name.replace(/DELETE/, 'UPDATE');

			if (deleter) {
				myRow.removeChild(deleter);
			}
		} else if (/INSERT/.test(Widget.name)) {
			Widget.name = Widget.name.replace(/INSERT/, 'IGNORE');
			try {
				this.validator[Widget.id].ignore = 1;
			} catch(e) {
			}
			Widget.disabled = true;
		} else if (/IGNORE/.test(Widget.name)) {
			Widget.disabled = false;
			try {
				this.validator[Widget.id].ignore = 0;
			} catch(e) {
			}
			Widget.name = Widget.name.replace(/IGNORE/, 'INSERT');
		}
	

	}
}

datasetController.prototype.pushRow = function(caller) {
	var callername = caller.name;
	var callervalue = caller.value;
	var callerid = caller.id;
	var oldRow = caller.parentNode.parentNode;
	var table = oldRow.parentNode.parentNode;

	var oldRownum = oldRow.rowIndex;
	var newRownum = oldRownum +1;

	if (! document.getElementById("row" + newRownum)) {
		var newRow = table.insertRow(table.rows.length);
		newRow.id = 'row'+newRownum;
		var newRownum = newRow.rowIndex;

		for (var i = 0; i< oldRow.cells.length; i++) {
			var oldCell;
			var oldWidget;
			var newCell;
			var position = newRow.cells.length;
			newCell 		= newRow.insertCell(position);

			for (var j=0; j< oldRow.cells[i].childNodes.length; j++) {
				oldCell = oldRow.cells[i];
				oldWidget = oldCell.childNodes[j];
				newCell.align 		= oldCell.align;

				var fieldName;

				if (oldWidget.name && oldWidget.id) {
					oldWidget.name 		= oldWidget.name.replace(/(.+)-(.+)--(\\d+\$)/, "\$1-:INSERT:\$2--\$3");
					fieldName 		= oldWidget.id.replace(/\\d+\$/, ''); 
				}

				var newWidget		= oldWidget.cloneNode(true);
				newWidget.name		= fieldName + newRownum;
				newWidget.id 		= fieldName + newRownum;
				newWidget.value		= '';

				if (oldWidget.name && oldWidget.id) {
					try {	
						this.validator[newWidget.id] = this.validator[oldWidget.id];
					} catch (e) {
					}
				}

				newCell.appendChild(newWidget);
			}
		}
	}
}

datasetController.prototype.validate = function () {
	var errorMsg = null;
	for (fieldname in this.validator) {
		errorMsg += this.tester(fieldname);
	}

	if (errorMsg) {
		return false;
	}
	return true;
};

datasetController.prototype.tester = function(fieldname) {
	var field = document.getElementById(fieldname);
	//alert("fieldname: "+fieldname+" field: "+field);
	var insert = /INSERT/;
	var update = /UPDATE/;
	var re = /^\\/.+\\/\$/;
	var cmd = /^:.+\$/;

	if (insert.test(field.name) || update.test(field.name)) {
		try {
			if (!this.validator[fieldname].ignore) {
				for (var i in this.validator[fieldname].rules) {
					var rule = this.validator[fieldname].rules[i];
					if (re.test(rule)) {
						var match = new RegExp(rule.replace(/^\\/(.+)\\/\$/, "\$1"));
						if (!match.test(field.value)) {
								this.flag(fieldname);
								return fieldname;
						} else {
							return null;
						}
					} else if (cmd.test(rule)) {


					}
				}
			}
		} catch(e) {
			//alert(fieldname + e);
		}
	}
};

datasetController.prototype.flag = function(fieldname) {
	var field = document.getElementById(fieldname);
	this.fieldcolor = field.style.backgroundColor;

	var flagBackgroundColor = this.flagcolor ? this.flagcolor : "red";

	field.style.backgroundColor = flagBackgroundColor;
};

datasetController.prototype.unflag = function(field) {
	field.style.backgroundColor = this.fieldcolor;
};

datasetController.prototype.searchResults = function(text, target) {
	var incoming = JSON.parse(text);
	for (widgetname in incoming.validator) {
		var controller = eval(widgetname + 'Controller');
		delete controller.validator;
		controller.validator = incoming.validator[widgetname];
	}

	var html = incoming.html;

	document.getElementById(target).innerHTML = html;

};

datasetController.prototype.multiSearch = function(id) {
	var primaryKey = eval(this.widgetID + 'MultiSearchPrimaryKey');
	var outgoing = {CGILazyID : this.widgetID};
	outgoing[primaryKey] = id;

	var multiSearchRequest;
	ajaxSend(multiSearchRequest, outgoing, this.searchResults, this.parentID);

};

datasetController.prototype.search = function() {
	var outgoing = {CGILazyID : this.widgetID};
	for (i in this.searchObject) {
		try {
			outgoing[this.searchObject[i]] = document.getElementById(this.searchObject[i]).value;
		}
		catch (e) { 
			//silently let it go if theres no input for this name built in the template
		}
	}

	var sendRequest;
	ajaxSend(sendRequest, outgoing, this.searchResults, this.widgetID);

};

END

#javascript for domloader
our $DOMLOADJS;
#javascript for composite
our $COMPJS;

our %component = (
		'CGI::Lazy::Ajax::Dataset'		=> $DatasetJS,
		'CGI::Lazy::Ajax::DomLoader'		=> $DOMLOADJS,
		'CGI::Lazy::Ajax::Composite'		=> $COMPJS,
);

#-------------------------------------------------------------------------------------------------
sub q {
	my $self = shift;

	return $self->{_q};
}

#-------------------------------------------------------------------------------------------------
sub modules {
	my $self = shift;
	my @args = @_;

	my $output = $JSONPARSER . minify(input => $AJAXJS). minify(input => $SJAXJS);
	my %inc;
	
	if (@args) {
		foreach my $widget (@args) {
			if (ref $widget eq 'CGI::Lazy::Ajax::Composite') {
				$inc{ref $widget} = 1;
				foreach my $subwidget (@{$widget->memberarray}) {
					$inc{ref $subwidget} = 1;
				}
			} else {
				$inc{ref $widget} = 1;
			}
		}

		$output .= minify(input => $component{$_}) foreach keys %inc;
	}

	return $self->q->jswrap($output);
}

#----------------------------------------------------------------------------------------
sub load {
	my $self = shift;
	my $file = shift;
	
	my $jsdir = $self->dir;
	my $docroot = $ENV{DOCUMENT_ROOT};
	$docroot =~ s/\/$//; #strip the trailing slash so we don't double it

	open IF, "< $docroot$jsdir/$file" or $self->q->errorHandler->couldntOpenJsFile($docroot, $jsdir, $file, $!);
	my $script = minify(input => *IF);

	close IF;

	return $self->q->jswrap($script);

}

#-------------------------------------------------------------------------------------------------
sub new {
	my $class = shift;
	my $q = shift;

	return bless {
		_q 		=> $q,
		_dir		=> $q->config->jsDir,
	
	}, $class;
}

#-------------------------------------------------------------------------------------------------
sub dir {
	my $self = shift;

	return $self->{_dir};
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

CGI::Lazy::Javascript

=head1 SYNOPSIS

	use CGI::Lazy;

	my $q = CGI::Lazy->new();

	my $widget1 = $q->ajax->activeDataSet({...});

	my $widget2 = $q->ajax->activeDataSet({...});

	print $q->header,

	      $q->javascript->modules($widget1, $widget2);

	print $q->javascript->load('somefile.js');

=head2 DESCRIPTION

CGI::Lazy::Javascript is predominately a javascript container.  It holds the js modules necessary for widgets to function, and outputs them for printing to the browser.  It also has some convenience methods for loading javascript files

=head1 METHODS

=head2 dir ()

Returns directory path where javascript files can be found as specified on Lazy object creation.

=head2 q ( ) 

Returns CGI::Lazy object.

=head2 modules ( components )

Returns javascript for parsing JSON and making ajax calls, as well as the clientside goodness for the ajax widgets.  This method needs to be printed on any page that is going to use JSON or the Ajax objects.

It's included as a separate method as it should be sent only once per page, and would be included in the header except this would be an irritation for cases where CGI::Lazy is not using Ajax objects.  If called without components, it will send out only the defaults listed below.

=head3 components

List of widgets whose javascript needs to be loaded.  JSON parser, ajaxSend, and sjaxSend are exported by default, the rest is on a per widget basis.  

The modules method is smart enough to only output the necessary code for a given type of module once.  Multiple widgets of the same type will not result in the same code being printed over and over.

For composite widgets, it loads each constituent widget in turn.

=head2 load (file)

Wraps, minifies, and loads file from javascript directory for output to browser

=head3 file

filename of javascript file

=head2 new ( q )

constructor.

=head3 q

CGI::Lazy object

=cut

