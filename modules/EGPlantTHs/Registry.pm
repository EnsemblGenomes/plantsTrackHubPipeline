package EGPlantTHs::Registry;

use strict;
use warnings;

use JSON;
use HTTP::Request::Common qw/GET DELETE POST/;
use LWP::UserAgent;
use EGPlantTHs::EG;

my $server = "http://www.trackhubregistry.org";
my $ua = LWP::UserAgent->new;
$| = 1; 

sub new {

  my $class = shift;

  my $username  = shift;
  my $password = shift;
 
  my $visibility = shift; # in the THR I can register track hubs but being not publicly available. This is useful for testing. I can only see the track hubs with visibility "hidden" in my THR account, they are not seen by anyone else
  
  defined $username and $password and $visibility
    or die "Some required parameters are missing in the constructor in order to construct a Registry object\n";

  my $self = {
    username  => $username,
    pwd => $password,
    visibility => $visibility,
    auth_token => undef
  };

  bless $self,$class;	
  $self->login;
 
  return $self;
}

sub register_track_hub{
 
  my $self = shift;

  my $track_hub_id = shift;
  my $trackHub_txt_file_url = shift;
  my $assembly_name_accession_pairs = shift; 

  defined $track_hub_id and $trackHub_txt_file_url and $assembly_name_accession_pairs
    or print "Some required parameters are missing in order to register track hub the Track Hub Registry\n" and return 0;

  my $return_string;

  my $username = $self->{username};
  my $auth_token = $self->{auth_token};

  my $url = $server . '/api/trackhub';

  #my $assembly_name_accession_pairs=  "ASM242v1,GCA_000002425.1,IRGSP-1.0,GCA_000005425.2";
  my @words = split(/,/, $assembly_name_accession_pairs);
  my $assemblies;
  for(my $i=0; $i<$#words; $i+=2) {
    $assemblies->{$words[$i]} = $words[$i+1];
  }

  my $request ;

  if($self->{visibility} eq "public"){

    $request = POST($url,'Content-type' => 'application/json',
	 #  assemblies => { "$assembly_name" => "$assembly_accession" } }));
    'Content' => to_json({ url => $trackHub_txt_file_url, type => 'transcriptomics', assemblies => $assemblies }));

  }else{  # hidden
    $request = POST($url,'Content-type' => 'application/json',
	 #  assemblies => { "$assembly_name" => "$assembly_accession" } }));
    'Content' => to_json({ url => $trackHub_txt_file_url, type => 'transcriptomics', assemblies => $assemblies , public => 0 }));
  }
  $request->headers->header(user => $username);
  $request->headers->header(auth_token => $auth_token);

  my $response = $ua->request($request);

  my $response_code= $response->code;

  if($response_code == 201) {

   $return_string= "	..$track_hub_id is Registered\n";

  }else{ 

    $return_string= "Couldn't register track hub with the first attempt: " .$track_hub_id."\t".$assembly_name_accession_pairs."\t".$response->code."\t" .$response->content."\n";

    my $flag_success=0;

    for(my $i=1; $i<=10; $i++) {

      $return_string = "\t".$return_string. $i .") Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      $response = $ua->request($request);
      $response_code= $response->code;

      if($response_code == 201){
        $flag_success =1 ;
        $return_string = $return_string. "	..$track_hub_id is Registered\n";
        last;
      }

    }

    if($flag_success ==0){

      $return_string = $return_string . "	..Didn't manage to register the track hub $track_hub_id , check in STDERR\n";
      print STDERR $track_hub_id."\t".$assembly_name_accession_pairs."\t".$response->code."\t". $response->content."\n\n";
    }

  }
  return $return_string;
}

sub delete_track_hub{

  my $self = shift;

  my $track_hub_id = shift;

  defined $track_hub_id
    or print "Track hub id parameter required to remove track hub from the Track Hub Registry\n" and return 0;

  my $auth_token = eval { $self->{auth_token} };

  my %trackhubs;
  my $url = $server . '/api/trackhub';

  if ($track_hub_id eq "all"){
    %trackhubs= %{$self->give_all_Registered_track_hub_names()};
    
  }else{
    $trackhubs{$track_hub_id} = 1;
  }

  my $counter_of_deleted=0;

  foreach my $track_hub (keys %trackhubs) {

    $counter_of_deleted++;
    if($track_hub_id eq "all"){
      print "$counter_of_deleted";
    }
    print "\tDeleting trackhub ". $track_hub."\t";
    my $request = DELETE("$url/" . $track_hub);

    $request->headers->header(user => $self->{username});
    $request->headers->header(auth_token => $auth_token);
    my $response = $ua->request($request);
    my $response_code= $response->code;

    if ($response->code != 200) {
      $counter_of_deleted--;
      print "..Error- couldn't be deleted - check STDERR.\n";
      printf STDERR "\n\tCouldn't delete track hub from THR : " . $track_hub . " with response code ".$response->code . " and response content ".$response->content." in script " .__FILE__. " line " .__LINE__."\n";
    } else {
      print "..Done\n";
    }
  }
}

sub login {

  my $self = shift;

  my $endpoint = '/api/login';
  my $url = $server.$endpoint; 

  my $request = GET($url);
  $request->headers->authorization_basic($self->{username}, $self->{pwd});

  my $response = $ua->request($request);
  my $auth_token;

  if ($response->is_success) {
    $auth_token = from_json($response->content)->{auth_token};
    defined $auth_token or die "Undefined authentication token when trying to login in the Track Hub Registry\n";	

    $self->{auth_token} = $auth_token;
  } else {
    die "Unable to login to Registry, reason: " .$response->code ." , ". $response->content."\n";
  }
  
  return;
}

sub logout {

  my $self = shift;

  my $endpoint = '/api/logout';
  my $url = $server.$endpoint; 

  defined $self->{auth_token} or die "Undefined auth token";
  my $request = GET($url);
  $request->headers->header(user => $self->{username});	
  $request->headers->header(auth_token => $self->{auth_token});
  my $response = $ua->request($request);
  my $response_code= $response->code;

  if($response_code == 200) {
    #print "Successfully logged out from THR\n";
    $self->{auth_token} = undef;

  }else{

    print "\tCould not log out from the THR in script " . __FILE__ . "\n";
    print "Got error ".$response->code ." , ". $response->content."\n";
  }
}

sub give_all_Registered_track_hub_names{

  my $self = shift;

  my $registry_user_name= $self->{username};
  my %track_hub_names;

  my $auth_token = eval { $self->{auth_token} };

  my $request = GET("$server/api/trackhub");
  $request->headers->header(user => $registry_user_name);
  $request->headers->header(auth_token => $auth_token);
  my $response = $ua->request($request);

  my $response_code= $response->code;

  if($response_code == 200) {
    my $trackhubs = from_json($response->content);
    map { $track_hub_names{$_->{name}} = 1 } @{$trackhubs}; # it is same as : $track_hub_names{$trackhubs->[$i]{name}}=1; 

  }else{

    print "\tCouldn't get Registered track hubs with the first attempt when calling method give_all_Registered_track_hub_names in script ".__FILE__."\n";
    print "Got error ".$response->code ." , ". $response->content."\n";
    my $flag_success=0;
    
    for(my $i=1; $i<=10; $i++) {

      print "\t".$i .") Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      $response = $ua->request($request);
      if($response->is_success){
        $flag_success =1 ;
        my $trackhubs = from_json($response->content);
        map { $track_hub_names{$_->{name}} = 1 } @{$trackhubs};
        last;
      }
    }

    die "Couldn't get list of track hubs in the Registry when calling method give_all_Registered_track_hub_names in script: ".__FILE__." line ".__LINE__."\n"
    unless $flag_success ==1;
  }

  return \%track_hub_names;

}

sub get_Registry_hub_last_update { # gives the last update date(unix time) of the registration of the track hub

  my $self = shift;
  my $name = shift;  # track hub name, ie study_id

  defined $name
    or print "Track hub name parameter required to get the track hub's last update date in the Track Hub Registry\n" and return 0;

  my $registry_user_name= $self->{username};

  my $auth_token = $self->{auth_token};
 
  my $request = GET("$server/api/trackhub/$name");
  $request->headers->header(user       => $registry_user_name);
  $request->headers->header(auth_token => $auth_token);
  my $response = $ua->request($request);
  my $hub;

  if ($response->is_success) {
    $hub = from_json($response->content);
  } else {  

    print "\tCouldn't get Registered track hub $name with the first attempt when calling method get_Registry_hub_last_update in script ".__FILE__."\n";
    my $flag_success=0;

    for(my $i=1; $i<=10; $i++) {

      print "\t".$i .") Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      $response = $ua->request($request);
      if($response->is_success){
        $hub = from_json($response->content);
        $flag_success =1 ;
        last;
      }
    }

    die "Couldn't get track hub $name in the Registry when calling method get_Registry_hub_last_update in script: ".__FILE__." line ".__LINE__." I am getting code ".$response->code."\n"
    unless $flag_success==1;
  }

  die "Couldn't find hub $name in the Registry to get the last update date when calling method get_Registry_hub_last_update in script: ".__FILE__." line ".__LINE__."\n" 
  unless $hub;

  my $last_update = -1;

  foreach my $trackdb (@{$hub->{trackdbs}}) {  # this cabn give multiple track hubs as for one study we can have more than 1 assembly 

    ($request, $response )= $self->make_authorised_request($trackdb->{uri});

    my $doc;
    if ($response->is_success) {
      $doc = from_json($response->content);
    } else {  
      die "\tCouldn't get trackdb at ", $trackdb->{uri}." from study $name in the Registry when trying to get the last update date \n";
    }

    if (exists $doc->{updated}) {
      $last_update = $doc->{updated}
      if $last_update < $doc->{updated};
    } else {
      exists $doc->{created} or die "Trackdb does not have creation date in the Registry when trying to get the last update date of study $name\n";
      $last_update = $doc->{created}
      if $last_update < $doc->{created};
    }
  }

  die "Couldn't get date as expected: $last_update\n" unless $last_update =~ /^[1-9]\d+?$/;

  return $last_update;
}

sub give_all_bioreps_of_study_from_Registry {

  my $self = shift;
  my $name = shift;  # track hub name, ie study_id

  defined $name
    or print "Track hub name parameter required to get the track hub's bioreps from the Track Hub Registry\n" and return 0;

  my ($request, $response) = $self->make_authorised_request("$server/api/trackhub/$name");
  my $hub;

  if ($response->is_success) {

    $hub = from_json($response->content);

  } else {  

    print "\tCouldn't get Registered track hub $name with the first attempt when calling method give_all_bioreps_of_study_from_Registry in script ".__FILE__." reason " .$response->code ." , ". $response->content."\n";
    my $flag_success=0;
    if ($response->code == 401) {
      $self->logout;
      $self->login;
    }

    for(my $i=1; $i<=10; $i++) {

      print "\t".$i .") Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      ($request , $response) = $self->make_authorised_request("$server/api/trackhub/$name");
      if($response->is_success){
        $hub = from_json($response->content);
        $flag_success =1 ;
        last;
      }else{
        print "\tCouldn't get Registered track hub $name with the $i attempt when calling method give_all_bioreps_of_study_from_Registry in script ".__FILE__." reason " .$response->code ." , ". $response->content."\n";
      }
    }

    die "Couldn't get the track hub $name in the Registry when calling method give_all_runs_of_bioreps_from_Registry in script: ".__FILE__." line ".__LINE__."\n"
    unless $flag_success==1;
  }

  die "Couldn't find hub $name in the Registry to get its runs when calling method give_all_bioreps_of_study_from_Registry in script: ".__FILE__." line ".__LINE__."\n" 
  unless $hub;

  my %runs ;

  foreach my $trackdb (@{$hub->{trackdbs}}) {

    $request = GET($trackdb->{uri});
    $request->headers->header(user       => $self->{username});
    $request->headers->header(auth_token => $self->{auth_token});
    $response = $ua->request($request);
    my $doc;

    if ($response->is_success) {

      $doc = from_json($response->content);

      foreach my $sample (keys %{$doc->{configuration}}) {
	map { $runs{$_}++ } keys %{$doc->{configuration}{$sample}{members}}; 
      }
    } else {

      print "\tCouldn't get runs of track hub $name with the first attempt when calling method give_all_bioreps_of_study_from_Registry in script ".__FILE__." reason " .$response->code ." , ". $response->content."\n";
      my $flag_success=0;
      if ($response->code == 401) {
        $self->logout;
        $self->login;
      }

      for(my $i=1; $i<=10; $i++) {

        print "\t".$i .") Retrying attempt: Retrying after 5s...\n";
        sleep 5;
        ($request , $response) = $self->make_authorised_request($trackdb->{uri});
        if($response->is_success){
          $hub = from_json($response->content);
          $flag_success =1 ;
          last;
        }else{
          print "Attempt $i: Couldn't get trackdb at ", $trackdb->{uri} , " from study $name in the Registry when trying to get all its runs, reason: " .$response->code ." , ". $response->content."\n";
        }
    }

    die "Couldn't get trackdb at ", $trackdb->{uri} , " from study $name in the Registry when trying to get all its runs, reason: " .$response->code ." , ". $response->content."\n"
    unless $flag_success==1;  
    }
  }


  return \%runs;

}

sub make_authorised_request {

  my ($self, $endpoint) = @_;

  defined $self->{username} or die "Undefined username";
  defined $self->{auth_token} or die "Undefined auth_token";

  my $request = GET($endpoint);
  $request->headers->header(user => $self->{username});
  $request->headers->header(auth_token => $self->{auth_token});
  return ($request, $ua->request($request));
}


sub give_species_names_assembly_names_of_track_hub { 

  my $self = shift;
  my $name = shift;  # track hub name, ie study_id

  defined $name
    or print "Track hub name parameter required to get the track hub's assembly id from the Track Hub Registry\n" and return 0;

  my ($request , $response) = $self->make_authorised_request("$server/api/trackhub/$name");
  my $hub;

  if ($response->is_success) {

    $hub = from_json($response->content);

  } else {  

    print "\tCouldn't get Registered track hub $name with the first attempt when calling method give_species_names_assembly_names_of_track_hub in script ".__FILE__." reason " .$response->code ." , ". $response->content."\n";
    my $flag_success=0;

    if ($response->code == 401) {
      $self->logout;
      $self->login;
    }

    for(my $i=1; $i<=10; $i++) {
      print "\t".$i .") Retrying attempt: Retrying after 5s...\n";
      sleep 5;
      ($request , $response) = $self->make_authorised_request("$server/api/trackhub/$name");
      
      if($response->is_success){
        $hub = from_json($response->content);
        $flag_success =1 ;
        last;
      }else{
        print "\tCouldn't get Registered track hub $name with the $i attempt when calling method give_species_names_assembly_names_of_track_hub in script ".__FILE__." reason " .$response->code ." , ". $response->content."\n";
      }
    }

    die "Couldn't get the track hub $name in the Registry when calling method give_species_names_assembly_names_of_track_hub in script: ".__FILE__." line ".__LINE__."\n"
    unless $flag_success==1;
  }

  die "Couldn't find hub $name in the Registry to get its runs when calling method give_species_names_assembly_names_of_track_hub in script: ".__FILE__." line ".__LINE__."\n" 
  unless $hub;


  my %assembly_info ;

  foreach my $trackdb (@{$hub->{trackdbs}}) {

    my $tax_id = $trackdb->{species}{tax_id};
    my $assembly_name ;
    if($trackdb->{assembly}{synonyms}){
      $assembly_name = $trackdb->{assembly}{synonyms};
    }else{
      $assembly_name = $trackdb->{assembly}{name};  # in t.aestivum the assembly name is stored only under name and not under synonym like the rest of the species
    }
    my $assembly_id ;
    if ($trackdb->{assembly}{accession} ne "NA"){
      $assembly_id= $trackdb->{assembly}{accession};
    }else{
      $assembly_id= "0000";
    }
    my $species_name = EGPlantTHs::EG::get_species_name_by_tax_id($tax_id);
    $assembly_info{$species_name}{$assembly_name}=$assembly_id;
    
  }

  return \%assembly_info;

}


1;