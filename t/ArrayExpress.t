
use Test::More;
use Test::Exception;
#use Devel::Cover;
use Capture::Tiny ':all';

use FindBin;
use lib $FindBin::Bin . '/../modules';

# -----
# checks if the module can load
# -----
# 

#test1
use_ok(EGPlantTHs::ArrayExpress);  # it checks if it can use the module correctly

#test2
use_ok(EGPlantTHs::JsonResponse);  # it checks if it can use the module correctly

#test3
use_ok(EGPlantTHs::EG);  # it checks if it can use the module correctly

# -----
# # test get_plant_names_AE_API method
# -----

#test4
my $plant_names_AE_href = EGPlantTHs::ArrayExpress::get_plant_names_AE_API();

isa_ok($plant_names_AE_href,"HASH"); # it checks if I get back a ref to a hash

#test5
ok(exists($plant_names_AE_href->{"arabidopsis_thaliana"}) , "arabidopsis_thaliana exists in the hash"); # it checks if the REST response is not empty, and includes this plant

#test6
my $eg_plant_names_href= EGPlantTHs::EG::get_plant_names();
my $number_of_plants_in_Eg= scalar keys %{$eg_plant_names_href};
 
my $number_of_plants_in_AE = scalar keys (%$plant_names_AE_href);

cmp_ok($number_of_plants_in_AE , '<=', $number_of_plants_in_Eg ,"Number of plants completed by AE is less than the plants in EG ($number_of_plants_in_Eg plants in EG, $number_of_plants_in_AE plants in AE)" );

#test7
cmp_ok($number_of_plants_in_AE, 'gt', 30 , "Number of plants completed by AE is more than 30");

# -----
# # test get_runs_json_for_study method
# -----

#this method is bacically calling EGPlantTHs::JsonResponse::get_Json_response($url) method which is tested in the EGPlantTHs:: JsonResponse.t script


# -----
# # test get_completed_study_ids_for_plants method
# -----

#test8
my $study_ids_href= EGPlantTHs::ArrayExpress::get_completed_study_ids_for_plants($eg_plant_names_href);
cmp_ok(scalar keys (%$study_ids_href), 'gt', 1000 , "Number of cram alignments completed by AE is more than 1000");

# -----
# # test get_study_ids_for_plant method
# -----

#test9
my $study_ids_zea_mays_href= EGPlantTHs::ArrayExpress::get_study_ids_for_plant("zea_mays");
cmp_ok(scalar keys (%$study_ids_zea_mays_href), 'gt', 140 , "Number of cram alignments completed by AE is more than 140"); # 18 May 2016 it is 143

# -----
# # test get_all_recalled_study_ids method
# -----

#test10
my $recalled_study_ids_href= EGPlantTHs::ArrayExpress::get_all_recalled_study_ids($plant_names_AE_href);
ok(exists $recalled_study_ids_href->{SRP071563} ,"Recalled study id SRP071563 is returned from the method");

#test11
dies_ok(sub{EGPlantTHs::ArrayExpress::get_all_recalled_study_ids()},'checks if method called without parameter dies');

done_testing();