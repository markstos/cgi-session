package CGI::Session::Driver::db_file;

use strict;
use Carp;
use DB_File;
use File::Spec;
use File::Basename;
use CGI::Session::Driver;
use Fcntl qw( :DEFAULT :flock );
use vars qw( $VERSION @ISA );

@ISA = qw( CGI::Session::Driver );
$CGI::Session::Driver::db_file::FILE_NAME = "cgisess.db";


sub init {
    my $self = shift;

    $self->{FileName}  ||= $CGI::Session::Driver::db_file::FILE_NAME;
    unless ( $self->{Directory} ) {
        $self->{Directory} = dirname( $self->{FileName} );
        $self->{FileName}  = basename( $self->{FileName} );
    }
    unless ( -d $self->{Directory} ) {
        require File::Path;
        File::Path::mkpath($self->{Directory}) or return $self->error("init(): couldn't mkpath: $!");
    }
    return 1;
}


sub retrieve {
    my $self = shift;
    my ($sid) = @_;
    croak "retrieve(): usage error" unless $sid;

    my ($dbhash, $unlock) = $self->_tie_db_file(O_RDONLY) or return;
    my $datastr =  $dbhash->{$sid};
    untie(%$dbhash);
    $unlock->();
    return $datastr || 0;
}


sub store {
    my $self = shift;
    my ($sid, $datastr) = @_;
    croak "store(): usage error" unless $sid && $datastr;

    my ($dbhash, $unlock) = $self->_tie_db_file(O_RDWR|O_CREAT, LOCK_EX) or return;    
    $dbhash->{$sid} = $datastr;
    untie(%$dbhash);
    $unlock->();
    return 1;
}



sub remove {
    my $self = shift;
    my ($sid) = @_;
    croak "remove(): usage error" unless $sid;

    my ($dbhash, $unlock) = $self->_tie_db_file(O_RDWR, LOCK_EX) or return;
    delete $dbhash->{$sid};
    untie(%$dbhash);
    $unlock->();
    return 1;
}


sub DESTROY {}


sub _lock {
    my $self = shift;
    my ($db_file, $lock_type) = @_;

    croak "_lock(): usage error" unless $db_file;
    $lock_type ||= LOCK_SH;

    my $lock_file = $db_file . '.lck';
    sysopen(LOCKFH, $lock_file, O_RDWR|O_CREAT) or die "couldn't create lockfile '$lock_file': $!";
    flock(LOCKFH, $lock_type)                   or die "couldn't lock '$lock_file': $!";
    return sub {
        close(LOCKFH) && unlink($lock_file);
        1;
    };
}



sub _tie_db_file {
    my $self                 = shift;
    my ($o_mode, $lock_type) = @_;
    $o_mode     ||= O_RDWR|O_CREAT;
    
    my $db_file     = File::Spec->catfile( $self->{Directory}, $self->{FileName} );
    my $unlock = $self->_lock($db_file, $lock_type);
    my %db;
    unless( tie %db, "DB_File", $db_file, $o_mode, 0666 ){
        $unlock->();
        return $self->error("_tie_db_file(): couldn't tie '$db_file': $!");
    }
    return (\%db, $unlock);
}






1;
