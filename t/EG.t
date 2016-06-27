
use Test::More;
use Test::Exception;
#use Devel::Cover;
use Capture::Tiny ':all';

use FindBin;
use lib $FindBin::Bin . '/../modules';

# -----
# checks if the module can load
# -----

#test1
use_ok(EGPlantTHs::EG);  # it checks if it can use the module correctly

#test2
use_ok(EGPlantTHs::JsonResponse);  # it checks if it can use the module correctly

#test3
my $ens_genomes_plants_call = "http://rest.ensemblgenomes.org/info/genomes/division/EnsemblPlants?content-type=application/json";
my $json_response_aref = EGPlantTHs::JsonResponse::get_Json_response($ens_genomes_plants_call);  

foreach my $hash_ref (@$json_response_aref){
  foreach my $key (keys(%$hash_ref)){
    like($key,qr/["division":"EnsemblPlants" "base_count" arabidopsis_thaliana]/,'there is some expected content of the e!genomes REST response');
    last;
  }
  last;
}

# -----
# test get_plant_names method
# -----

#test4
my $plant_names_href=EGPlantTHs::EG::get_plant_names();
ok(exists $plant_names_href->{arabidopsis_thaliana} ,"Arabidopsis_thaliana exists in the REST response");

# -----
# test get_assembly_name_using_species_name method
# -----

#test5
my $assembly_name = EGPlantTHs::EG::get_assembly_name_using_species_name("triticum_aestivum");
is($assembly_name,"IWGSC1+popseq", "Triticum aestivum has the exprected assembly name");

#test6
$assembly_name = EGPlantTHs::EG::get_assembly_name_using_species_name("arabidopsis_thaliana");
is($assembly_name,"TAIR10", "Arabidopsis thaliana has the exprected assembly name");

#test7
my ($stdout, $stderr, $assembly_name_unknown) = capture {
  EGPlantTHs::EG::get_assembly_name_using_species_name("arabidopsis_thalian");
};

is($assembly_name_unknown,"unknown", "Returns \"unknown\" as an assembly name to a non-existent species name");

#test8
ok($stderr=~/The species name: \w+ is not in EG REST response/,'got the expected standard error when trying to use a species name that does not exist in plants');

# -----
# test get_species_name_assembly_id_hash method
# -----

#test9
my $species_name_assembly_id_href=EGPlantTHs::EG::get_species_name_assembly_id_hash();
is($species_name_assembly_id_href->{triticum_aestivum}, "0000", "Triticum aestivum has the exprected assembly id");

#test10
is($species_name_assembly_id_href->{arabidopsis_thaliana}, "GCA_000001735.1", "Arabidopsis thaliana has the exprected assembly id");

done_testing();