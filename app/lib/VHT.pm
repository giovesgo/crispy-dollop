package VHT;

use utf8;
use Dancer2;
use Dancer2::Plugin::Database;
use Dancer2::Plugin::FlashNote;
use Dancer2::Session::YAML;

our $VERSION = '0.1';

get '/' => sub {
    template 'index' => { 'title' => 'VanHack Technical Test' };
};

post '/persona' => sub {
    my $name_count = database->quick_count('people', { name => params->{user_name} });

    if ( $name_count > 0 ) {
        flash 'alert-danger' => 'Your name has already been used. Please try again';
    }
    else {
       database->quick_insert('people', { name  => params->{user_name},
                                            color => params->{color},
                                            pet   => params->{pet}
                                           } );
        flash 'alert-success' => 'Information Saved. Thank you ' . params->{user_name} . ' for sharing';
    }
    redirect '/';
};

true;
