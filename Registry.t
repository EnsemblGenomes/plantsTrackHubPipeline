
use Test::More qw(no_plan);
use Test::Exception;

use Capture::Tiny ':all';


# -----
# checks if the module can load
# -----

#test1
use_ok(Registry);  

# -----
# test constructor
# -----

my $registry_obj = Registry->new("testing" ,"testing" );

# test2
isa_ok($registry_obj,'Registry','checks whether the object constructed is of my class type');

# test3
dies_ok(sub{Registry->new("blabla")},'checks if wrong object construction of my class dies');

# -----
# test register_track_hub method
# -----

#test4
my $return_of_method = $registry_obj->register_track_hub("SRP045759","ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs/thr_testing/SRP045759/hub.txt","Oryza_brachyantha.v1.4b,GCA_000231095.2");

ok($return_of_method=~/Registered/,"TH registered successfully");

#test5
my ($stdout1, $stderr1,$return_of_method_wrong_assembly_id) =capture { 
  $registry_obj->register_track_hub("SRP045759","ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs/thr_testing/SRP045759/hub.txt","Oryza_brachyantha.v1.4b,GCA_0002310");
};

ok($return_of_method_wrong_assembly_id=~/Didn't manage to register the track hub/,"TH not registered successfully as expected, given wrong assembly id");

#test6
# the first parameter, the hub id, is not used by the THR, so if it's wrong it will not affect anything, just the log file.
my ($stdout2, $stderr2, $return_of_method_wrong_url )= capture { 
  $registry_obj->register_track_hub("SRP045759","ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs/thr_testing/SRP045759/hub.tx","Oryza_brachyantha.v1.4b,GCA_000231095.2");
};

ok($return_of_method_wrong_url=~/Didn't manage to register the track hub/,"TH not registered successfully as expected, given wrong hub.txt URL");

#test7
my ($stdout3, $stderr3, $return_of_method_wrong_params )=  capture {
   $registry_obj->register_track_hub("ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs/thr_testing/SRP045759/hub.txt","Oryza_brachyantha.v1.4b,GCA_0002310");
};

ok($return_of_method_wrong_params==0,"TH not registered successfully as expected, given wrong number of parameters");


# -----
# test delete_track_hub method
# -----

#test8
my ($stdout4, $stderr4 ,$return_of_method_delete_no_param) = capture {
  $registry_obj->delete_track_hub();
};
 
ok($return_of_method_delete_no_param==0,"TH not deleted successfully as expected, given no parameter");

#test9
$registry_obj->register_track_hub("SRP045759","ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs/thr_testing/SRP045759/hub.txt","Oryza_brachyantha.v1.4b,GCA_000231095.2");

 my ($stdout5, $stderr5, $exit) = capture {
   $registry_obj->delete_track_hub("SRP045759");
 };

ok($stdout5=~/Done/,"Successful deletion of track hub");

#-----
#test registry_login method
#-----


#test10
dies_ok(sub{$registry_obj->registry_login("testing","no_valid_username")} , "Successfully died when given unvalid username");

#test11
dies_ok(sub{$registry_obj->registry_login("testing")} , "Successfully died when not given username");

# -----
# test give_all_Registered_track_hub_names method
# -----

# I am regstering 1 track hub first
$registry_obj->register_track_hub("SRP045759","ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs/thr_testing/SRP045759/hub.txt","Oryza_brachyantha.v1.4b,GCA_000231095.2");

 my ($stdout6, $stderr6, $hash_ref) = capture {
   $registry_obj->give_all_Registered_track_hub_names();
 };

ok($hash_ref->{"SRP045759"},"Successfully returns the name of the 1 track hub");

# -----
# test get_Registry_hub_last_update method
# -----

# -----
# test give_all_bioreps_of_study_from_Registry method
# -----


# -----
# test registry_get_request method
# -----

# -----
# test registry_logout method
# -----
