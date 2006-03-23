#/usr/bin/perl -T
# $Id$

use strict;
use diagnostics;

use Test::More;
use CGI::Session;

{
    no strict 'refs';
    no warnings 'redefine';
    *CGI::Session::ErrorHandler::set_error = sub {
        shift;
        die @_;
    };

}

if (! eval { symlink("",""); 1 }) {
    plan skip_all => "Your OS doesn't support symlinks";
}

plan tests => 11;

unlink('t/cgisess_symlink_session','t/cgisess_symlink_session_link');
ok(my $s = CGI::Session->new('driver:file;id:static','symlink_session',{Directory=>'t'}),'Create new session named symlink');
ok($s->id, 'We have an id');
$s->param('passthru',1);
$s->flush();
my $path = $s->_driver->_file($s->id);

# test retrieve
my $new_path = $s->_driver->_file('symlink_session_link');
ok(symlink($path,$new_path), 'Created symlink');
ok(-l $new_path, 'Check to make certain symlink was created');
ok(my $ns = CGI::Session->new('driver:file;id:static','symlink_session_link',{Directory=>'t'}), 'Get our symlinked session');
ok(! -l $ns,'we should have wiped out the symlink');
isnt($ns->param('passthru'),1,'this session should be unique');

unlink('t/cgisess_symlink_session_link');

# swap the symlink and session
ok(rename($path,$new_path),'moving session file');
ok(symlink($new_path,$path),'creating symlink');
$s->param('change',1);
ok($s->flush(),'flush should wipe out the symlink');
ok(! -l $path,'original session file has been restored');

