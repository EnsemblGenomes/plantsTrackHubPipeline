
use Test::More;
use Test::JSON; # had to install also from cpan the module JSON::Any which is used in Test::Json
use HTTP::Tiny;
use Test::HTTP::Response;
use Capture::Tiny ':all';

use FindBin;
use lib $FindBin::Bin . '/../modules';

# -----
# checks if the module can load
# -----

#test1
use_ok(EGPlantTHs::JsonResponse);  # it checks if it can use the module correctly

# -----
# test get_Json_response method
# -----

#test2
my $http = HTTP::Tiny->new();
my $url= "http://plantain:3000/json/70/getRunsByStudy/SRP068911";

my $response = $http->get($url);

my $json=$response->{content};

is_valid_json ( $json,'Json from the e!genomes plant call is well formed');

#test3
my $json_response_aref = EGPlantTHs::JsonResponse::get_Json_response($url);

isa_ok($json_response_aref,"ARRAY"); # it checks if I get back a ref to an array

#test4

foreach my $hash_ref (@$json_response_aref){
  foreach my $key (keys(%$hash_ref)){
    like($key,qr/[ORGANISM STATUS FTP_LOCATION]/,'keys of the key-value pairs in the json stanza include ORGANSIM or STATUS or FTP_LOCATION');
    last;
  }
  last;
}

#test5
my $wrong_url= "http://plantain:3000/json/70/getLibrariesByStudyId/SRP033494";

my ($stdout, $stderr, $wrong_url_response) = capture {
 EGPlantTHs::JsonResponse::get_Json_response($wrong_url);
};

ok($stderr=~/ERROR in/,'got the expected standard error when I am trying to get an http response of a wrong URL');

# test6
is($wrong_url_response,0,"checks respose of REST call wrong URL"); # it checks if I get back a 0

done_testing();


