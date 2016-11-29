package EGPlantTHs::ArrayExpress;

use strict ;
use warnings;

use EGPlantTHs::JsonResponse;

#my $array_express_url =  "http://plantain:3000/json/70";   # AE private server of the REST URLs

my $array_express_url =  "http://www.ebi.ac.uk/fg/rnaseq/api/json/70";   # AE public server of the REST URLs

# On success: return a hash with keys = plant_names
# On failure: return 0
sub get_plant_names_AE_API {  # returns reference to a hash

  my $url = $array_express_url . "/getOrganisms/plants" ; # gives all distinct plant names with processed runs by ENA

  my %plant_names;

#response:
#[{"ORGANISM":"aegilops_tauschii","REFERENCE_ORGANISM":"aegilops_tauschii"},{"ORGANISM":"amborella_trichopoda","REFERENCE_ORGANISM":"amborella_trichopoda"},
#{"ORGANISM":"arabidopsis_kamchatica","REFERENCE_ORGANISM":"arabidopsis_lyrata"},{"ORGANISM":"arabidopsis_lyrata","REFERENCE_ORGANISM":"arabidopsis_lyrata"},
#{"ORGANISM":"arabidopsis_lyrata_subsp._lyrata","REFERENCE_ORGANISM":"arabidopsis_lyrata"},{"ORGANISM":"arabidopsis_thaliana","REFERENCE_ORGANISM":"arabidopsis_thaliana"},

  my $json_response = EGPlantTHs::JsonResponse::get_Json_response($url); 
  
  if(!$json_response){ # if response is 0

    return 0;

  }else{

    my @plant_names_json = @{$json_response}; # json response is a ref to an array that has hash refs

    foreach my $hash_ref (@plant_names_json){
      $plant_names{ $hash_ref->{"REFERENCE_ORGANISM"} }=1;  # this hash has all possible names of plants that Robert is using in his REST calls ; I get them from here: http://www.ebi.ac.uk/fg/rnaseq/api/json/70/getOrganisms/plants        
    }

    return \%plant_names;
  }
}


sub get_runs_json_for_study { # returns json string or 0 if url not valid
  
  my $study_id = shift;
   
  if(defined $study_id){

    my $url = $array_express_url . "/getBiorepsByStudy/$study_id";  
    return EGPlantTHs::JsonResponse::get_Json_response($url);

  } else{
    die __METHOD__ ." needs to be called with parameter study_id\n";
  }
}

sub get_completed_study_ids_for_plants{ # I want this method to return only studies with status "Complete"

  my $plant_names_href_EG = shift;

  if(!$plant_names_href_EG){
    die __METHOD__ ." needs to be called with parameter of a hash ref where the hash contains the plant names as keys.\n";
  }

  my $url;
  my %study_ids;
  my $get_runs_by_organism_endpoint=$array_express_url."/getRunsByOrganism/"; # gets all the bioreps by organism to date that AE has processed so far

  foreach my $plant_name (keys %{$plant_names_href_EG}){

    $url = $get_runs_by_organism_endpoint . $plant_name;
    my $json_response = EGPlantTHs::JsonResponse::get_Json_response( $url);

    if(!$json_response){ # if response is 0

      die "Json response unsuccessful for plant $plant_name\n";

    }else{
      my @biorep_stanza_json = @{$json_response};

      foreach my $hash_ref (@biorep_stanza_json){
        if($hash_ref->{"STATUS"} eq "Complete" ){
          $study_ids{ $hash_ref->{"STUDY_ID"} }=1; 
        } 
      }
    }
  }
  
  return \%study_ids;

}

sub get_study_ids_for_plant{

  my $plant_name = shift;
  my $url= $array_express_url."/getRunsByOrganism/" . $plant_name;

  if(!$plant_name){
    die __METHOD__ ." needs to be called with parameter of a plant name\n";
  }
  
  my %study_ids;
#response:
#[{"STUDY_ID":"DRP000315","SAMPLE_IDS":"SAMD00009892","BIOREP_ID":"DRR000749","RUN_IDS":"DRR000749","ORGANISM":"oryza_sativa_japonica_group","REFERENCE_ORGANISM":"oryza_sativa","STATUS":"Complete","ASSEMBLY_USED":"IRGSP-1.0","ENA_LAST_UPDATED":"Fri Jun 19 2015 17:39:45","LAST_PROCESSED_DATE":"Mon Sep 07 2015 00:39:36","FTP_LOCATION":"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/DRR000/DRR000749/DRR000749.cram","MAPPING_QUALITY":70},
  my $json_response = EGPlantTHs::JsonResponse::get_Json_response($url); 
  
  if(!$json_response){ # if response is 0

    return 0;

  }else{

    my @plant_names_json = @{$json_response}; # json response is a ref to an array that has hash refs

    foreach my $hash_ref (@plant_names_json){
      if($hash_ref->{"STATUS"} eq "Complete"){
        $study_ids{ $hash_ref->{"STUDY_ID"} }=1;  # this hash has all possible names of plants that Robert is using in his REST calls ; I get them from here: http://www.ebi.ac.uk/fg/rnaseq/api/json/70/getOrganisms/plants        
      }
    }

    return \%study_ids;

  }
}

sub get_all_recalled_study_ids {

  my $plant_names_href_EG = shift;
  my $url = $array_express_url."/getRecalledRuns";
  my %recalled_study_ids;

  if(!$plant_names_href_EG){
    die __METHOD__ ." needs to be called with parameter of a hash ref where the hash contains the plant names as keys\n";
  }
 
#response:
#[{"STUDY_ID":"DRP001347","SAMPLE_IDS":null,"BIOREP_ID":"DRR015062","RUN_IDS":"DRR015062","ORGANISM":"mus_musculus","REFERENCE_ORGANISM":"mus_musculus","STATUS":"Suppressed_in_ENA","ASSEMBLY_USED":"GRCm38","ENA_LAST_UPDATED":"Thu Dec 03 2015 01:17:20","LAST_PROCESSED_DATE":"Wed Jan 06 2016 07:33:15","CRAM_LOCATION":"NA","BEDGRAPH_LOCATION":"NA","BIGWIG_LOCATION":"NA","MAPPING_QUALITY":0},{"STUDY_ID":"DRP001347","SAMPLE_IDS":null,"BIOREP_ID":"DRR015063","RUN_IDS":"DRR015063","ORGANISM":"mus_

  my $json_response = EGPlantTHs::JsonResponse::get_Json_response($url); 
  
  if(!$json_response){ # if response is 0

    return 0;

  }else{

    my @json = @{$json_response}; # json response is a ref to an array that has hash refs

    foreach my $hash_ref (@json){
      if($plant_names_href_EG->{$hash_ref->{"REFERENCE_ORGANISM"}}){ # I want to get only the recalled studies of plants
        $recalled_study_ids{ $hash_ref->{"STUDY_ID"}}=$hash_ref->{"REFERENCE_ORGANISM"};          
      }
    }

    return \%recalled_study_ids;
  }
}

1;