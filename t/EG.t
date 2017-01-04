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
# test get_species_name_by_tax_id method
# -----

#test5
my $species_name=EGPlantTHs::EG::get_species_name_by_tax_id("4577"); # tax id for zea mays is currently 4577
is($species_name,"zea_mays", "Taxon id 4577 gives the expected species name, zea mays");

#test6
$species_name=EGPlantTHs::EG::get_species_name_by_tax_id("51351"); # tax id for brassica rapa is currently 51351
is($species_name,"brassica_rapa", "Taxon id 51351 gives the expected species name, brassica rapa");

#test7
$species_name=EGPlantTHs::EG::get_species_name_by_tax_id("01"); # wrong tax id
is($species_name,0, "Wrong taxon id returns 0");


# -----
# test get_assembly_name_using_species_name method
# -----

#test8
my $assembly_name = EGPlantTHs::EG::get_assembly_name_using_species_name("triticum_aestivum");
is($assembly_name,"TGACv1", "Triticum aestivum has the exprected assembly name");

#test9
$assembly_name = EGPlantTHs::EG::get_assembly_name_using_species_name("arabidopsis_thaliana");
is($assembly_name,"TAIR10", "Arabidopsis thaliana has the exprected assembly name");

#test10
my ($stdout, $stderr, $assembly_name_unknown) = capture {
  EGPlantTHs::EG::get_assembly_name_using_species_name("arabidopsis_thalian");
};

is($assembly_name_unknown,"unknown", "Returns \"unknown\" as an assembly name to a non-existent species name");

#test11
ok($stderr=~/The species name: \w+ is not in EG REST response/,'got the expected standard error when trying to use a species name that does not exist in plants');

# -----
# test get_assembly_id_using_species_name method
# -----

#test12
my $assembly_id=EGPlantTHs::EG::get_assembly_id_using_species_name("triticum_aestivum");
is($assembly_id, "GCA_900067645", "Triticum aestivum has the exprected assembly id");

#test13
$assembly_id=EGPlantTHs::EG::get_assembly_id_using_species_name("zea_mays");
is($assembly_id, "0000", "Zea mays has the exprected assembly id");

#test14
$assembly_id=EGPlantTHs::EG::get_assembly_id_using_species_name("rice");
is($assembly_id, "unknown", "Rice is not a species name in the EG REST response, so it returns unknown for an assembly id");

#test15
my $species_name_assembly_id_href = EGPlantTHs::EG::get_species_name_assembly_id_hash();
is($species_name_assembly_id_href->{arabidopsis_thaliana}, "GCA_000001735.1", "Arabidopsis thaliana has the exprected assembly id");

#test16
is($species_name_assembly_id_href->{zea_mays}, "0000", "Zea mays has the exprected assembly id");

done_testing();