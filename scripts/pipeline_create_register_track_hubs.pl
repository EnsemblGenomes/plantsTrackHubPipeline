
# ALWAYS RUN IT IN THE FARM:

# do first:
# export THR_USER=your_user_name_in_your_track_hub_registry_account
# export THR_PWD=your_password_in_your_track_hub_registry_account

# example run:
# perl pipeline_create_register_track_hubs.pl -server_dir_full_path /nfs/ensemblgenomes/ftp/pub/misc_data/Track_Hubs -server_url ftp://ftp.ensemblgenomes.org/pub/misc_data/Track_Hubs -th_visibility public 1> output_wh_23Feb 2>errors_wh_23Feb
# perl pipeline_create_register_track_hubs.pl -server_dir_full_path /nfs/ensemblgenomes/ftp/pub/misc_data/Track_Hubs -server_url ftp://ftp.ensemblgenomes.org/pub/misc_data/Track_Hubs -th_visibility public  -do_track_hubs_from_scratch 1> output_fs_wh_16Feb 2>errors_fs_wh_16Feb

use strict ;
use warnings;
use autodie;
use File::Path qw(remove_tree);

use FindBin;
use lib $FindBin::Bin . '/../modules';
use Getopt::Long;
use DateTime;   
use Time::HiRes;
use Time::Piece;

use EGPlantTHs::Registry;
use EGPlantTHs::TrackHubCreation;
use EGPlantTHs::EG;
use EGPlantTHs::ArrayExpress;
use EGPlantTHs::AEStudy;

my $registry_user_name = $ENV{'THR_USER'}; 
my $registry_pwd = $ENV{'THR_PWD'};

defined $registry_user_name and $registry_pwd
  or die "Track Hub Registry username and password are required to be set as shell variables\n";

my $server_dir_full_path ; # ie. ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs
my $server_url ;  # ie. /nfs/ensemblgenomes/ftp/pub/misc_data/.TrackHubs;
my $track_hub_visibility; # defines whether when I register a TH in the THR will be publicly available or not. Give "hidden" or "public"
my $from_scratch; # if I want to keep archived track hubs this flag should not be used as it deletes all existing tracks hubs. The old ones will be lost forever..

my $start_time = time();

GetOptions(
  "server_dir_full_path=s" => \$server_dir_full_path,
  "server_url=s" => \$server_url,  
  "th_visibility=s" => \$track_hub_visibility, # "hidden" or "public"
  "do_track_hubs_from_scratch"  => \$from_scratch  # flag
);

if(!$server_dir_full_path){
  die "Please specify where the track hubs should be made, run pipelinme using -server_dir_full_path option and value\n";
}

if(!$server_url){
  die "Please give the url web location of the directory of the track hubs, run pipeline using -server_url option and value\n";
}

if(!$track_hub_visibility){
  die "\nPlease give TH visibility setting in the THR either hidden or public\n";
}

my $start_run = time();

{ # main method

  print_calling_params_logging($registry_user_name , $registry_pwd , $server_dir_full_path , $server_url, $track_hub_visibility, $from_scratch);
  
  my $registry_obj = EGPlantTHs::Registry->new($registry_user_name, $registry_pwd, $track_hub_visibility);
  
  if (! -d $server_dir_full_path) {  # if the directory that the user defined to write the files of the track hubs doesnt exist, I try to make it

    print "\nThis directory: $server_dir_full_path does not exist, I will make it now.\n";

    mkdir $server_dir_full_path;  # it dies when mkdir returns false
  }

  my $plant_names_AE_response_href = EGPlantTHs::ArrayExpress::get_plant_names_AE_API();

  if($plant_names_AE_response_href == 0){

    die "Could not get plant names with processed runs from AE API , calling script ".__FILE__." line: ".__LINE__."\n";
  }

  my $study_ids_href_AE = get_list_of_all_AE_plant_studies_currently(); #  gets all Array Express current plant study ids

  my $organism_assmblAccession_EG_href = EGPlantTHs::EG::get_species_name_assembly_id_hash(); #$hash{"brachypodium_distachyon"} = "GCA_000005505.1"         also:  $hash{"oryza_rufipogon"} = "0000"
  my $unsuccessful_studies_href;

  if ($from_scratch){  # this option will not be used, since we want to keep archived track hubs with old assemblies , if we run it from scratch , they will be deleted since AE is not archiving them..

    $unsuccessful_studies_href = run_pipeline_from_scratch_with_logging($registry_obj, $study_ids_href_AE , $server_dir_full_path, $organism_assmblAccession_EG_href, $plant_names_AE_response_href); 

  }
  else {  # incremental update -ALWAYS TO BE RUN WITH INCREMENTAL UPDATE

    print_registered_TH_in_THR_stats($registry_obj);
    $unsuccessful_studies_href= run_pipeline_with_incremental_update_with_logging($study_ids_href_AE,$registry_obj,$server_dir_full_path,$plant_names_AE_response_href,$organism_assmblAccession_EG_href);
  }

  print_run_duration_so_far($start_time);

  ## after the pipeline finishes running, I print some log info:

  my ($study_id_biorep_ids_AE_currently_href , $plant_study_id_AE_currently_number_of_bioreps_href) = give_hashes_with_AE_current_stats($study_ids_href_AE,$plant_names_AE_response_href);

  print_current_AE_studies_stats($study_id_biorep_ids_AE_currently_href ,$plant_study_id_AE_currently_number_of_bioreps_href , $server_dir_full_path);

  print_registered_TH_in_THR_stats_after_pipeline_is_run($registry_obj,$plant_names_AE_response_href,$unsuccessful_studies_href);
  print_run_duration_so_far($start_time);
  
  my $date_string_end = localtime();
  print "\n Finished running the pipeline on:\n";
  print "Local date,time: $date_string_end\n";

}


##METHODS##

sub print_registered_TH_in_THR_stats{

  my $registry_obj = shift;

  my $all_track_hubs_in_registry_after_update_href = $registry_obj->give_all_Registered_track_hub_names();
  my %distinct_bioreps;

  foreach my $hub_name (keys %{$all_track_hubs_in_registry_after_update_href}){
  
    my %bioreps_hash = %{$registry_obj->give_all_bioreps_of_study_from_Registry($hub_name)};
    map { $distinct_bioreps{$_}++ } keys %bioreps_hash;
  }

  print "There are in total ". scalar (keys %{$all_track_hubs_in_registry_after_update_href});
  print " track hubs with total ".scalar (keys %distinct_bioreps)." bioreps registered in the Track Hub Registry\n\n";

}


sub run_pipeline_with_incremental_update_with_logging{

  my $study_ids_href_AE = shift;
  my $registry_obj = shift;
  my $server_dir_full_path = shift;
  my $plant_names_AE_response_href = shift;
  my $organism_assmblAccession_EG_href = shift;

  my %unsuccessful_studies=();

  my $registered_track_hubs_href = $registry_obj->give_all_Registered_track_hub_names; # track hubs that are already registered

  #remove_obsolete_studies($registry_obj, $registered_track_hubs_href, $server_dir_full_path); # if there are any obsolete track hubs, they are removed from the THR and the server

  my ($new_study_ids_aref, $common_study_ids_aref) = get_new_and_common_study_ids($study_ids_href_AE,$registered_track_hubs_href);

  print "\n************* Updates of studies (new/changed) from last time the pipeline was run:\n\n";

  if(scalar (@$new_study_ids_aref) == 0){
    print "No new studies are found between current AE API studies and registered studies in the THR\n";
  }else{
    print "\nNew studies (".scalar (@$new_study_ids_aref) ." studies) from last time the pipeline was run:\n\n";
    %unsuccessful_studies= create_new_studies_in_incremental_update($new_study_ids_aref,$server_dir_full_path ,$plant_names_AE_response_href,$registry_obj,$organism_assmblAccession_EG_href,\%unsuccessful_studies); 
  }

  %unsuccessful_studies= update_common_studies($common_study_ids_aref,$registry_obj,$plant_names_AE_response_href,$server_dir_full_path ,$organism_assmblAccession_EG_href,\%unsuccessful_studies);

  return \%unsuccessful_studies; 
}


sub update_common_studies{

  my $common_study_ids_aref = shift;
  my $registry_obj = shift;
  my $plant_names_AE_response_href = shift;
  my $server_dir_full_path = shift;
  my $organism_assmblAccession_EG_href = shift;
  my $unsuccessful_studies_href = shift;

  my ($common_studies_to_be_updated_href , $common_studies_to_be_updated_with_new_assembly_href)= get_study_ids_to_be_updated($common_study_ids_aref, $registry_obj,$plant_names_AE_response_href); #hash looks like: $common_study_ids_to_be_updated {$common_study_id}=\@holder_of_reason_of_update and $common_studies_to_be_updated_with_new_assembly_href{$common_study_id}=\%hash_info

  my %common_studies_to_be_updated = %$common_studies_to_be_updated_href;

  if(scalar (keys %common_studies_to_be_updated) == 0 and scalar (keys (%{$common_studies_to_be_updated_with_new_assembly_href}) ==0)){
    print "\n\nNo common studies between current AE API and registered studies in the THR are found to need updating\n\n";
  }else{
    print "\nStudies to be updated (".scalar (keys %common_studies_to_be_updated)." studies and ". scalar (keys %{$common_studies_to_be_updated_with_new_assembly_href}) ." with new assembly) from last time the pipeline was run:\n\n";
  }

  my $study_counter = 0;

  foreach my $study_id (keys %common_studies_to_be_updated){

    my $study_obj = EGPlantTHs::AEStudy->new($study_id,$plant_names_AE_response_href);

    my $sample_ids_href = $study_obj->get_sample_ids();
    if(!$sample_ids_href){  # there are cases where the AE API returns a study with the the sample_ids field to be null , I want to skip these studies
      $unsuccessful_studies_href->{"missing samples in AE API"}{$study_id}=1;
      next;
    }

    $study_counter++;

    my @info_array = @{$common_studies_to_be_updated{$study_id}};

    my $old_study_counter = $study_counter;

    my $backup_name = $study_id."_backup";
    remove_tree "$server_dir_full_path/$backup_name" if -d "$server_dir_full_path/$backup_name";  # i remove it in case it exists from previous un-successful runs
    mkdir "$server_dir_full_path/$backup_name" ; # I create a backup directory of this track hub- in case the update of this track hub with the new assembly goes wrong, the track hub remains the way it was before the attempt to update
    `cp -r $server_dir_full_path/$study_id/* $server_dir_full_path/$backup_name`;
    remove_tree "$server_dir_full_path/$study_id";  # i remove it, to re-make it
    
    my $date_registry_last = localtime($registry_obj->get_Registry_hub_last_update($study_id))->strftime('%F %T');
    my $reason_of_unsuccessful_study;

    ($reason_of_unsuccessful_study,$study_counter) = make_and_register_track_hub($study_obj,$registry_obj,$old_study_counter, $server_dir_full_path,$organism_assmblAccession_EG_href ,$plant_names_AE_response_href); 

    if($reason_of_unsuccessful_study ne "successful_study"){

      remove_tree "$server_dir_full_path/$study_id" if -d "$server_dir_full_path/$study_id"; 
      rename ("$server_dir_full_path/$backup_name","$server_dir_full_path/$study_id"); 

      #$registry_obj->delete_track_hub($study_id);  # this is an update of a study, so the study is already registered in the THR, if something goes wrong in the process of making it in the server, I have to remove it from the THR too
      $unsuccessful_studies_href->{$reason_of_unsuccessful_study}{$study_id}=1;
    }else{ # if successful

      remove_tree "$server_dir_full_path/$backup_name" if -d "$server_dir_full_path/$backup_name"; 
    }

#######
    print "\t..Update needed because: ";
    if($info_array[0] eq "diff_time_only"){

      #my $date_registry_last = localtime($registry_obj->get_Registry_hub_last_update($study_id))->strftime('%F %T');
      my $date_cram_created = localtime($study_obj->get_AE_last_processed_unix_date)->strftime('%F %T');

      print " Last registered date: ".$date_registry_last  . ", Max last processed date of CRAMS from study: ".$date_cram_created."\n";

    }elsif($info_array[0] eq "diff_bioreps_diff_time"){

      #my $date_registry_last = localtime($registry_obj->get_Registry_hub_last_update($study_id))->strftime('%F %T');
      my $date_cram_created = localtime($study_obj->get_AE_last_processed_unix_date)->strftime('%F %T');

      print " Last registered date: ".$date_registry_last  . ", Max last processed date of CRAMS from study: ".$date_cram_created . " and also different number/ids of runs: "." Last Registered number of runs: ".$info_array[1].", Runs in Array Express currently: ".$info_array[2]."\n";

    }elsif($info_array[0] eq "diff_bioreps_only") {

      print " Different number/ids of runs: Last Registered number of runs: ".$info_array[1].", Runs in Array Express currently: ".$info_array[2]."\n";

    }else{

      print "Don't know why this study is being updated\n" and print STDERR "Something went wrong with common study between the THR and AE $study_id that I decided to update; don't know why needs updating\n";
    }
  }
## extra code start

  print "\n\n Assembly updates:\n\n";

  foreach my $study_id (keys %{$common_studies_to_be_updated_with_new_assembly_href}){

    my $backup_name = $study_id."_backup";
    remove_tree "$server_dir_full_path/$backup_name" if -d "$server_dir_full_path/$backup_name"; 
    mkdir "$server_dir_full_path/$backup_name" ; # I create a backup directory of this track hub- in case the update of this track hub with the new assembly goes wrong, the track hub remains the way it was before the attempt to update
    `cp -r $server_dir_full_path/$study_id/* $server_dir_full_path/$backup_name`;

    my $study_obj = EGPlantTHs::AEStudy->new($study_id,$plant_names_AE_response_href);

    my $sample_ids_href = $study_obj->get_sample_ids();
    if(!$sample_ids_href){  # there are cases where the AE API returns a study with the the sample_ids field to be null , I want to skip these studies
      $unsuccessful_studies_href->{"missing samples in AE API"}{$study_id}=1;
      next;
    }

    $study_counter++;
#$info_hash{$organism_name}="New assembly name found for study $common_study_id for species $organism_name in AE: ".$organism_name_assembly_name_hash_AE{$organism_name}." ; we had in the THR for this plant assembly name/s: ",join (",", @assembly_names_THR)) ;
    my %info_hash = %{$common_studies_to_be_updated_with_new_assembly_href->{$study_id}}; 

    my $old_study_counter = $study_counter;

    my $reason_of_unsuccessful_study;

    ($reason_of_unsuccessful_study,$study_counter) = make_and_register_track_hub_with_new_assembly($study_obj,$registry_obj,$old_study_counter, $server_dir_full_path,$organism_assmblAccession_EG_href ,$plant_names_AE_response_href,$common_studies_to_be_updated_with_new_assembly_href); 

    if($reason_of_unsuccessful_study ne "successful_study"){

      remove_tree "$server_dir_full_path/$study_id" if -d "$server_dir_full_path/$study_id";
      rename ("$server_dir_full_path/$backup_name","$server_dir_full_path/$study_id") ;
      $unsuccessful_studies_href->{$reason_of_unsuccessful_study}{$study_id}=1;

    }else{ # if the update of the track hubs is successful, I can remove the back up directory- track hub
      remove_tree "$server_dir_full_path/$backup_name" if -d "$server_dir_full_path/$backup_name" ;
    }

    print "\t..Assembly update needed because: ";
    foreach my $organism_name (keys %info_hash){
    
      my @array_info=@{$info_hash{$organism_name}};
      print join(" ",@array_info)."\n";
    }
  }
## end of extra code
  return %$unsuccessful_studies_href; 

}

sub create_new_studies_in_incremental_update{

  my $new_study_ids_aref = shift;
  my $server_dir_full_path = shift;
  my $plant_names_AE_response_href = shift;
  my $registry_obj = shift;
  my $organism_assmblAccession_EG_href = shift;
  my $unsuccessful_studies_href = shift;

  my $study_counter = 0;

  foreach my $study_id (@$new_study_ids_aref) {

    my $ls_output = `ls $server_dir_full_path` ;

    if($ls_output =~/$study_id/){ # i check if the directory exists for some reason ; because I decide which are new studies comparing AE and the THR, so maybe the study is in the server even though it shouldn't!

      my $study_dir = "$server_dir_full_path/$study_id";

      if(-d $study_dir){
        remove_tree $study_dir;
      }
    }
    my $study_obj = EGPlantTHs::AEStudy->new($study_id,$plant_names_AE_response_href);

    my $sample_ids_href = $study_obj->get_sample_ids();
    if(!$sample_ids_href){  # there are cases where the AE API returns a study with the the sample_ids field to be null , I want to skip these studies
      $unsuccessful_studies_href->{"missing samples in AE API"}{$study_id}=1;
      next;
    }

    $study_counter++;

    my $old_study_counter = $study_counter;

    my $return_reason_of_unsuccessful_study;

    ($return_reason_of_unsuccessful_study,$study_counter) = make_and_register_track_hub($study_obj,$registry_obj,$old_study_counter, $server_dir_full_path,$organism_assmblAccession_EG_href, $plant_names_AE_response_href ); 

    if($return_reason_of_unsuccessful_study ne "successful_study"){

      $unsuccessful_studies_href->{$return_reason_of_unsuccessful_study}{$study_id}=1;
    }

  }  
  return %$unsuccessful_studies_href; 

}

sub remove_obsolete_studies {   # a study is obsolete when it is returned in the getRecalledRuns call and when the getBiorepsByStudy returns null ([]) or all runs are status "Mapping_failed"

  my $registry_obj = shift;
  my $registered_track_hubs_href = shift;
  my $server_dir_full_path= shift;

  my $plant_names_href_EG = EGPlantTHs::EG::get_plant_names;
  my %recalled_study_ids = %{EGPlantTHs::ArrayExpress::get_all_recalled_study_ids($plant_names_href_EG)};

  my @track_hubs_for_deletion;
  my @track_hubs_with_recalled_runs;

  foreach my $recalled_study_id (keys %recalled_study_ids){
    if($registered_track_hubs_href->{$recalled_study_id}){ # if the recalled study is registered in the THR, I will remove it
      push(@track_hubs_with_recalled_runs , $recalled_study_id);
    }
  }

  foreach my $track_hub_name_with_recalled_runs (@track_hubs_with_recalled_runs){

    my $url = "http://www.ebi.ac.uk/fg/rnaseq/api/json/70/getBiorepsByStudy/$track_hub_name_with_recalled_runs";
    my $json_response = EGPlantTHs::JsonResponse::get_Json_response($url); 

    if(!$json_response){ # if response is 0

      print STDERR "Could get a json response for call $url in script ".__FILE__." ,line ".__LINE__."\n";
      next;

    }else{

      my @json = @{$json_response}; # json response is a ref to an array that has hash refs
#[{"STUDY_ID":"DRP000315","SAMPLE_IDS":"SAMD00009892","BIOREP_ID":"DRR000749","RUN_IDS":"DRR000749","ORGANISM":"oryza_sativa_japonica_group","REFERENCE_ORGANISM":"oryza_sativa","STATUS":"Complete","ASSEMBLY_USED":"IRGSP-1.0","ENA_LAST_UPDATED":"Fri Jun 19 2015 17:39:45","LAST_PROCESSED_DATE":"Mon Sep 07 2015 00:39:36","FTP_LOCATION":"ftp://ftp.ebi.ac.uk/pub/databases/arrayexpress/data/atlas/rnaseq/DRR000/DRR000749/DRR000749.cram","MAPPING_QUALITY":70},
      my $flag_study_to_be_done_later = 0;

      foreach my $hash_ref (@json){

        if($plant_names_href_EG->{$hash_ref->{"REFERENCE_ORGANISM"}}){ # I want to see only the runs for plants

          if($hash_ref->{"STATUS"} eq "Queued" or $hash_ref->{"STATUS"} eq "In_progress" or $hash_ref->{"STATUS"} eq "Complete"){ # these study has at least 1 run pending , so I won't delete it as it will be available from AE later..

            $flag_study_to_be_done_later = 1;
          }
        }
      }

      if($flag_study_to_be_done_later ==0){
        push(@track_hubs_for_deletion,$track_hub_name_with_recalled_runs);
      }
    }
  }

  my $counter = 0;
  if(scalar @track_hubs_for_deletion > 0){

    print "\n************* Starting to delete obsolete track hubs from the trackHub Registry and the server:\n\n";

    foreach my $track_hub_id (@track_hubs_for_deletion){

      $counter++;
      print $counter.".\t";
      $registry_obj->delete_track_hub($track_hub_id) ; # it's an obsolete study- it needs deletion
 
      my $study_dir = "$server_dir_full_path/$track_hub_id";
      
      remove_tree $study_dir if -d $study_dir;
      
    }
  }else{

    print "\n************* There are not any obsolete track hubs to be removed since the last time the pipeline was run.\n\n";
  }
}

sub get_new_and_common_study_ids{ 

  my $study_ids_href_AE = shift;  # current study ids from AE
  my $registered_track_hubs_href = shift;

  my @new_study_ids;
  my @common_study_ids;

  foreach my $study_id_currently_AE (keys %{$study_ids_href_AE}){

    if($registered_track_hubs_href->{$study_id_currently_AE}){

      push(@common_study_ids ,$study_id_currently_AE) ; # it's a common study

    }else{
      push(@new_study_ids,$study_id_currently_AE) ; # it's a new study
    }
  }

  return (\@new_study_ids, \@common_study_ids);

}

sub get_study_ids_to_be_updated{ # gets a list of common study ids and decides which ones have changed, hence need updating

  my $common_study_ids_array_ref = shift;  # these are the common study ids between the AE and the THR
  my $registry_obj = shift;
  my $plant_names_AE_response_href = shift;

  my %common_study_ids_to_be_updated;
  my %common_study_ids_to_be_updated_with_new_assembly;

  foreach my $common_study_id (@$common_study_ids_array_ref){ 

    my $study_obj = EGPlantTHs::AEStudy->new($common_study_id,$plant_names_AE_response_href);

## extra code

    my %organism_name_assembly_name_hash_AE = %{$study_obj->get_organism_names_assembly_names()}; # hash{brachypodium_distachyon}="v1.0" , hash{arabidopsis_thaliana}="TAIR10" -> in AE

    # hash{brachypodium_distachyon}{"v1.0"}="GCA_000005505.1", hash{brachypodium_distachyon}{"v2.0"}= "GCA_000005505.2"  -> in the THR
    my %old_organism_name_assembly_id_assembly_name_hash_THR = %{$registry_obj->give_species_names_assembly_names_of_track_hub($common_study_id)};

    my %log_hash;
    my @assembly_names_THR;

    foreach my $plant_name (keys %old_organism_name_assembly_id_assembly_name_hash_THR ){

      foreach my $assembly_name (keys %{$old_organism_name_assembly_id_assembly_name_hash_THR{$plant_name} }){

        push (@assembly_names_THR,$assembly_name); # I store all assembly names of the study of this plant that are in the THR to print them in the log
      }     
    }  

    foreach my $organism_name (keys %organism_name_assembly_name_hash_AE){ # loop through the plant names of the study in AE

      my $flag_assembly_name_of_AE_found_in_THR = 0;

      if($old_organism_name_assembly_id_assembly_name_hash_THR{$organism_name}){ # if this plant species is already in the THR registered under this study, i will check if they have the same assembly as in AE

        foreach my $assembly_name_THR (keys %{$old_organism_name_assembly_id_assembly_name_hash_THR{$organism_name}}){

          if($organism_name_assembly_name_hash_AE{$organism_name} eq $assembly_name_THR){ # if in the THR the AE assembly name does not exist, we have a new assembly of the plant
    
            $flag_assembly_name_of_AE_found_in_THR =1;

          }
        }
      }

      if ($flag_assembly_name_of_AE_found_in_THR ==0 and $old_organism_name_assembly_id_assembly_name_hash_THR{$organism_name}) { # if the AE assembly is not found registered under this species in the THR, I need to add the new assembly to the TH
        my @array;
        $array[0] = "New assembly name found for study $common_study_id for species $organism_name in AE: ".$organism_name_assembly_name_hash_AE{$organism_name}." ; we had in the THR for this plant assembly name/s: ";
        $array[1] = join (",", @assembly_names_THR);
        $log_hash{$organism_name}=(\@array) ;
      }
    }  # if there is a new species in the study it continues with the old code, line 456 onwards..

    if(%log_hash){ # if the log is not empty it means we have at least 1 new assembly in AE from a species of the current study I am looping through
    
      $common_study_ids_to_be_updated_with_new_assembly{$common_study_id}=\%log_hash;
      next; # go to the next common study id
    }  

### extra code end

    my $AE_last_processed_unix_time = $study_obj->get_AE_last_processed_unix_date; # AE current response: the unix date of the creation the cram of the study (gives me the max date of all bioreps of the study)
    my $registry_study_created_date_unix_time = eval { $registry_obj->get_Registry_hub_last_update($common_study_id) }; # date of registration of the study

    if ($@) { # if the get_Registry_hub_last_update method fails to return the date of the track hub , then i re-do it anyways to be on the safe side

      my @table;
      $table[0]= "registry_no_response";
      $common_study_ids_to_be_updated{$common_study_id} = \@table;
      print "Couldn't get hub update: $@\ngoing to update hub anyway\n"; 

    }elsif($registry_study_created_date_unix_time) {

      # I want to check also if the bioreps of the common study are the same in the Registry and in Array Express:
      my %bioreps_in_Registry = %{$registry_obj->give_all_bioreps_of_study_from_Registry($common_study_id)};  # when last registered
      my %bioreps_in_Array_Express = %{$study_obj->get_biorep_ids()} ;   # currently 

      my @holder_of_reason_of_update; # i save the numbers because I want to print them out as log
      $holder_of_reason_of_update[1]= scalar (keys %bioreps_in_Registry); # in cell 1 of this table it's stored the number of bioreps of the common study in the Registry
      $holder_of_reason_of_update[2]= scalar (keys %bioreps_in_Array_Express);  # in cell 2 of this table it's stored the number of bioreps of the common study in current Array Express API call

      my $are_bioreps_the_same = hash_keys_are_equal(\%bioreps_in_Registry,\%bioreps_in_Array_Express); # returns 0 id they are not equal, 1 if they are
        
      if( $registry_study_created_date_unix_time < $AE_last_processed_unix_time or $are_bioreps_the_same ==0) { # if the study was registered before AE changed it OR it has now different bioreps, it needs to be updated

        if( $registry_study_created_date_unix_time < $AE_last_processed_unix_time and $are_bioreps_the_same ==1){  # study was changed by AE after it was created and registered in the THR
          $holder_of_reason_of_update[0] = "diff_time_only";
          $common_study_ids_to_be_updated {$common_study_id}=\@holder_of_reason_of_update;
        }
        if ( $registry_study_created_date_unix_time >= $AE_last_processed_unix_time and $are_bioreps_the_same ==0) { # different number of bioreps
          $holder_of_reason_of_update[0] = "diff_bioreps_only";
          $common_study_ids_to_be_updated {$common_study_id}=\@holder_of_reason_of_update;
        }
        if( $registry_study_created_date_unix_time < $AE_last_processed_unix_time and $are_bioreps_the_same ==0){ #  both 
          $holder_of_reason_of_update[0] = "diff_bioreps_diff_time";
          $common_study_ids_to_be_updated {$common_study_id}=\@holder_of_reason_of_update;
        }
      }
    } else {
      die "I have to really die here since I don't know what happened in script ".__FILE__." line ".__LINE__."\n";
    } 
  }
  return (\%common_study_ids_to_be_updated,\%common_study_ids_to_be_updated_with_new_assembly);
}

sub print_run_duration_so_far{

  my $start_run = shift;

  my $end_run = time();
  my $run_time = $end_run - $start_run;

  print "\nRun time was $run_time seconds (". $run_time/3600 ." hours)\n";
}

sub print_current_AE_studies_stats{

  my $study_id_biorep_ids_AE_currently_href = shift;   # stores from AE API the hash with key: study id , value: hash with keys the biorep ids of the study  hash{"SRP067728"} = \%hash{biorep_id}
  my $plant_study_id_AE_currently_number_of_bioreps_href = shift;  # it would be : hash{"oryza_sativa"}{"SRP067728"} = 20
  my $server_dir_full_path = shift;

  my $current_date = return_current_date();

  my %total_bioreps; # to get number of distinct biorep ids 

  foreach my $study_id (keys %{$study_id_biorep_ids_AE_currently_href}){
    foreach my $biorep_id (keys %{$study_id_biorep_ids_AE_currently_href->{$study_id}}){
      $total_bioreps{$biorep_id}=1;
    }
  }

  print "\n####################################################################################\n";
  print "\nArray Express REST calls give the following stats:\n";
  print "\nThere are " . scalar (keys %total_bioreps) ." plant bioreps completed to date ( $current_date )\n";
  print "\nThere are " . scalar (keys %{$study_id_biorep_ids_AE_currently_href}) ." plant studies completed to date ( $current_date )\n";

  print "\n****** Plants done to date: ******\n\n";


  my $index = 0;

  my %plant_number_of_bioreps=(); # $hash{"oryza_sativa"}  = 50 #(number of bioreps)

  foreach my $plant (keys %{$plant_study_id_AE_currently_number_of_bioreps_href}){

    my $number_of_bioreps = 0;
    foreach my $study_id (keys %{$plant_study_id_AE_currently_number_of_bioreps_href->{$plant}}){

      $number_of_bioreps=$number_of_bioreps + $plant_study_id_AE_currently_number_of_bioreps_href->{$plant}{$study_id};
    }

    $plant_number_of_bioreps{$plant} = $number_of_bioreps;
  }

  foreach my $plant (keys %{$plant_study_id_AE_currently_number_of_bioreps_href}){
    $index++;
    print $index.".\t".$plant." =>\t".$plant_number_of_bioreps{$plant} ." bioreps / ". scalar keys (%{$plant_study_id_AE_currently_number_of_bioreps_href->{$plant}})." studies\n";

  }
  print "\n";

  print "In total there are " .scalar (keys %{$plant_study_id_AE_currently_number_of_bioreps_href})." Ensembl plants done to date.\n\n";
  print "####################################################################################\n\n";

  my $total_disc_space_of_track_hubs = `du -sh $server_dir_full_path`;
  
  print "\nTotal disc space occupied in $server_dir_full_path is:\n $total_disc_space_of_track_hubs\n";

  print "There are in total ". give_number_of_dirs_in_ftp($server_dir_full_path). " files in the ftp server\n\n";
}

sub print_registered_TH_in_THR_stats_after_pipeline_is_run{

  my $registry_obj = shift;
  my $plant_names_AE_response_href  = shift ;

  my $unsuccessful_studies_href = shift;


  print_registered_TH_in_THR_stats($registry_obj,$plant_names_AE_response_href);
  
  my $count_skipped_studies=0;

  if(scalar keys %$unsuccessful_studies_href > 0){
    print "\nThese studies could not be made into Track Hubs:\n";
    foreach my $reason (keys %$unsuccessful_studies_href){
      foreach my $study_id (keys %{$unsuccessful_studies_href->{$reason}}){

        $count_skipped_studies++;
        my $study_obj = EGPlantTHs::AEStudy->new($study_id,$plant_names_AE_response_href);
        my %bioreps_hash = %{$study_obj->get_biorep_ids};
        print $count_skipped_studies. ". ". $study_id. " (".scalar (keys %bioreps_hash)." bioreps)\t$reason\n";
      }
    }
  }

}
sub delete_registered_th_and_remove_th_from_server{  # called only when option is run pipeline from scratch

  my $registry_obj = shift ;
  my $server_dir_full_path = shift;

  my $number_of_registered_th_initially = print_registry_registered_number_of_th($registry_obj);

  print " ******** Deleting all track hubs registered in the Registry under my account\n\n";  
 
  if($number_of_registered_th_initially ==0){

    print "there were no track hubs registered \n";

  }else{

    print $registry_obj->delete_track_hub("all") ; # method that deletes all registered track hubs under this THR account
  }

  print "\n ******** Deleting everything in directory $server_dir_full_path\n\n";

  remove_tree "$server_dir_full_path", { keep_root => 1 };   # removing the track hub files in the server/dir
  
  print "All directories under $server_dir_full_path are deleted\n";

  $| = 1; 
}

sub run_pipeline_from_scratch_with_logging{

  my $registry_obj = shift ;
  my $study_ids_href_AE = shift; # all the study ids that currently the AE API returns for plants.
  my $server_dir_full_path = shift;
  my $organism_assmblAccession_EG_href = shift;
  my $plant_names_AE_response_href = shift;

  my %unsuccessful_studies=();

  delete_registered_th_and_remove_th_from_server($registry_obj,$server_dir_full_path);
 
  print "\n ******** Starting to make directories and files for the track hubs in the ftp server: $server_url\n\n";

  my $study_counter = 0;

  foreach my $study_id (keys %{$study_ids_href_AE}){

    my $study_obj = EGPlantTHs::AEStudy->new($study_id,$plant_names_AE_response_href);

    my $sample_ids_href = $study_obj->get_sample_ids();
    if(!$sample_ids_href){  # there are cases where the AE API returns a study with the the sample_ids field to be null , I want to skip these studies
      $unsuccessful_studies{"missing samples in AE API"}{$study_id}=1;
      next;
    }

    $study_counter++;
    my $old_study_counter = $study_counter;
    # method make_and_register_track_hub returns the $study_counter reduced by 1 if the TH creation and registration is unsuccessful
    
    my $reason_of_unsuccessful_study;
    ($reason_of_unsuccessful_study, $study_counter)= make_and_register_track_hub($study_obj ,$registry_obj ,$old_study_counter, $server_dir_full_path,$organism_assmblAccession_EG_href, $plant_names_AE_response_href);
    if($reason_of_unsuccessful_study ne "successful_study"){
      $unsuccessful_studies{$reason_of_unsuccessful_study}{$study_id}=1;
    }

  }

  my $date_string2 = localtime();
  print " \n Finished creating the files,directories of the THs on the server and registering all THs in the THR on:\n";
  print "Local date,time: $date_string2\n";

  print "\n***********************************\n";
  $| = 1; 
  return (\%unsuccessful_studies); 
}

sub give_hashes_with_AE_current_stats{

  my $study_ids_href_AE = shift; # all the study ids that currently the AE API returns for plants.
  my $plant_names_AE_response_href  = shift;

  my %study_id_biorep_ids_AE_currently;  # stores from AE API the hash with key: study id , value: hash with keys the biorep ids of the study
  my %plant_study_id_AE_currently_number_of_bioreps;   # it would be : hash{"oryza_sativa"}{"SRP067728"} = 20
 
  foreach my $study_id (keys %{$study_ids_href_AE}){

    my $study_obj = EGPlantTHs::AEStudy->new($study_id,$plant_names_AE_response_href );

    my %biorep_ids = %{$study_obj->get_biorep_ids};

    $study_id_biorep_ids_AE_currently{$study_id}=\%biorep_ids;

    my $species_of_study_href = $study_obj->get_organism_names_assembly_names(); # hash-> key: organism_name , value: assembly_name , a study can have more than 1 species

    foreach my $species_name (keys %{$species_of_study_href}){

      $plant_study_id_AE_currently_number_of_bioreps{$species_name}{$study_id}=scalar (keys %{$study_obj->get_biorep_ids_by_organism($species_name)}); 
      
    }
  }
  
  return (\%study_id_biorep_ids_AE_currently , \%plant_study_id_AE_currently_number_of_bioreps);
}

sub return_current_date{

  my $dt = DateTime->today;

  my $date_wrong_order = $dt->date;  # it is in format 2015-10-01
  # i want 01-10-2015

  my @words = split(/-/, $date_wrong_order);
  my $current_date = $words[2] . "-". $words[1]. "-". $words[0];  # ie 01-10-2015 (1st October)

  return $current_date;
}

sub give_number_of_dirs_in_ftp {

  my $ftp_location = shift;
  
  my @files = `ls $ftp_location` ;
  
  return  scalar @files;
}

sub hash_keys_are_equal{
   
  my ($hash1, $hash2) = @_;
  my $areEqual=1;

  if(scalar(keys %{$hash1}) == scalar (keys %{$hash2})){

    foreach my $key1(keys %{$hash1}) {
      if(!$hash2->{$key1}) {

        $areEqual=0;
      }
    }
  }else{
    $areEqual = 0;
  }

  return $areEqual;
}

sub print_calling_params_logging{
  
  my ($registry_user_name , $registry_pwd , $server_dir_full_path ,$server_url, $track_hub_visibility, $from_scratch) = @_;
  my $date_string = localtime();

  print "* Using these shell variables of the THR account:\n\n";
  print " THR_USER=$registry_user_name\n THR_PWD=$registry_pwd\n\n";
 
  print "* Started running the pipeline on:\n";
  print "Local date,time: $date_string\n";

  print "\n* Ran this pipeline:\n\n";
  print "perl pipeline_create_register_track_hubs.pl -server_dir_full_path $server_dir_full_path -server_url $server_url -th_visibility $track_hub_visibility";
  if($from_scratch){
    print " -do_track_hubs_from_scratch";
  }

  print "\n";
  print "\n* I am using this server to eventually build my track hubs:\n\n $server_url\n\n";
  print "* I am using this Registry account:\n\n user:$registry_user_name \n password:$registry_pwd\n\n";

  $| = 1;  # it flashes the output

}

sub print_registry_registered_number_of_th{

  my $registry_obj = shift;
  my %studies_last_run_of_pipeline = %{$registry_obj->give_all_Registered_track_hub_names()};
  my %distinct_bioreps_before_running_pipeline;

  foreach my $hub_name (keys %studies_last_run_of_pipeline){
  
    map { $distinct_bioreps_before_running_pipeline{$_}++ } keys %{$registry_obj->give_all_bioreps_of_study_from_Registry($hub_name)}; 
  }

  print "\n* Before starting running the updates, there were in total ". scalar (keys %studies_last_run_of_pipeline). " track hubs with total ".scalar (keys %distinct_bioreps_before_running_pipeline)." bioreps registered in the Track Hub Registry under this account.\n\n";

  $| = 1;  # it flashes the output

  return scalar (keys %studies_last_run_of_pipeline);
}

sub get_list_of_all_AE_plant_studies_currently{

  my $plant_names_href_EG = EGPlantTHs::EG::get_plant_names;
  
  my $study_ids_href = EGPlantTHs::ArrayExpress::get_completed_study_ids_for_plants($plant_names_href_EG);

  return $study_ids_href;
}

sub make_and_register_track_hub{

  my $study_obj = shift;
  my $registry_obj = shift;
  my $line_counter = shift;
  my $server_dir_full_path = shift;
  my $organism_assmblAccession_EG_href = shift;
  my $plant_names_AE_response_href = shift;

  my $study_id = $study_obj->id;
  print "$line_counter.\tcreating track hub for study $study_id\t"; 

  my $track_hub_creator_obj = EGPlantTHs::TrackHubCreation->new($study_id,$server_dir_full_path);
  my $script_output = $track_hub_creator_obj->make_track_hub($plant_names_AE_response_href);

  print $script_output;
  my $return_reason_of_unsuccessful_study="successful_study";
  my $date_registry_last;

  if($script_output !~ /..Done/){  # if for some reason the track hub didn't manage to be made in the server, it shouldn't be registered in the Registry, for example Robert gives me a study id as completed that is not yet in ENA

    print STDERR "Track hub of $study_id could not be made/updated in the server - Folder $study_id is deleted or if it's an update it is not updated in the server\n\n" ;

    remove_tree "$server_dir_full_path/$study_id";

    print "\t..Skipping registration part\n";

    $line_counter --;

    if ($script_output=~/No ENA Warehouse metadata found/){

      $return_reason_of_unsuccessful_study = "Sample metadata not yet in ENA";

    }elsif($script_output=~/Skipping this TH because at least 1 of the cram files of the TH is not yet in ENA/){

      $return_reason_of_unsuccessful_study = "At least 1 cram file of study is not yet in ENA";

    }else{

      $return_reason_of_unsuccessful_study = "Study not yet in ENA";
    }

  }else{  # if the study is successfully created in the ftp server, I go ahead and register it

    my $output = register_track_hub_in_TH_registry($registry_obj,$study_obj,$organism_assmblAccession_EG_href );  

    my $return_string = $output;

    if($output !~ /is Registered/){# if something went wrong with the registration, i will not make a track hub out of this study

      remove_tree "$server_dir_full_path/$study_id";

      $line_counter --;
      $return_string = $return_string . "\t..Something went wrong with the Registration process -- this study will be skipped..\n";
      print STDERR "Study $study_id could not be registered or re-registered in the THR - Folder $study_id is deleted from the server if this is not a new study\n";

      $return_reason_of_unsuccessful_study = "Registry issue";

    }

    print $return_string;
      
  }
  
  return ($return_reason_of_unsuccessful_study,$line_counter);
}


sub make_and_register_track_hub_with_new_assembly{

  my $study_obj = shift;
  my $registry_obj = shift;
  my $line_counter = shift;
  my $server_dir_full_path = shift;
  my $organism_assmblAccession_EG_href = shift;
  my $plant_names_AE_response_href = shift;
  my $common_studies_to_be_updated_with_new_assembly_href = shift;


  my $return_string;

  my $study_id= $study_obj->id;
  print "$line_counter.\tcreating assembly update for track hub for study $study_id\t";  

  my @script_output_list = @{update_TH_with_new_assembly($study_obj, $common_studies_to_be_updated_with_new_assembly_href, $registry_obj,$plant_names_AE_response_href, $server_dir_full_path ,$organism_assmblAccession_EG_href )};
  my $script_output = $script_output_list[0];
  my @assembly_names_assembly_ids_pairs = @{$script_output_list[1]};

  print $script_output;

  my $return_reason_of_unsuccessful_study="successful_study";

  if($script_output !~ /..Done/){  # if for some reason the track hub didn't manage to be made in the server, it shouldn't be registered in the Registry, for example Robert gives me a study id as completed that is not yet in ENA

    print STDERR "Track hub of $study_id could not be updated with the new assembly - Folder $study_id will be skipped from assembly update\n\n" ;

    print "\t..Skipping registration part\n";

    $line_counter --;

    if ($script_output=~/No ENA Warehouse metadata found/){

      $return_reason_of_unsuccessful_study = "Sample metadata not yet in ENA";

    }elsif($script_output=~/Skipping this TH because at least 1 of the cram files of the TH is not yet in ENA/){

      $return_reason_of_unsuccessful_study = "At least 1 cram file of study is not yet in ENA";

    }else{

      $return_reason_of_unsuccessful_study = "Something else went wrong";
    }

  }else{  # if the study is successfully created in the ftp server, I go ahead and register it

    my $assemblyNames_assemblyAccesions_string = join(",",@assembly_names_assembly_ids_pairs);
    my $hub_txt_url = $server_url . "/" . $study_id . "/hub.txt" ;

    print "trying to register: $study_id,$hub_txt_url,$assemblyNames_assemblyAccesions_string\n";  # comment this!   
    my $output = $registry_obj->register_track_hub($study_id,$hub_txt_url,$assemblyNames_assemblyAccesions_string);

    $return_string = $output;

    if($output !~ /is Registered/){# if something went wrong with the registration, i will not make a track hub out of this study

      $line_counter --;
      $return_string = $return_string . "\t..Something went wrong with the Registration process -- this study will be skipped from assembly update..\n\n";
      print STDERR "Study $study_id could not be re-registered in the THR\n";

      $return_reason_of_unsuccessful_study = "Registry issue";

    }

    print $return_string;
      
  }
  
  return ($return_reason_of_unsuccessful_study,$line_counter);
  
}

sub get_assembly_names_assembly_ids_string_for_study{

  my $study_obj = shift;
  my $organism_assmblAccession_EG_href = shift; #$hash{"brachypodium_distachyon"} = "GCA_000005505.1"  


  my $assemblyNames_assemblyAccesions_string="not found";
  my @assembly_name_assembly_id_pairs;

  my %study_organism_names_AE_assembly_name = %{$study_obj->get_organism_names_assembly_names}; # from AE API: $hash{"selaginella_moellendorffii"}= "TAIR10"

  foreach my $organism_name_AE (keys %study_organism_names_AE_assembly_name) { # the organism name AE is the reference species name, so the same as the EG names

    if($organism_assmblAccession_EG_href->{$organism_name_AE}){

      my $string = $study_organism_names_AE_assembly_name{$organism_name_AE} ."," . $organism_assmblAccession_EG_href->{$organism_name_AE};
      push(@assembly_name_assembly_id_pairs , $string);

    }else{
      die "Could not find AE organism name $organism_name_AE in EG REST response\n";
    }
    $assemblyNames_assemblyAccesions_string= join(",",@assembly_name_assembly_id_pairs);  
  }

  return $assemblyNames_assemblyAccesions_string;
}

sub register_track_hub_in_TH_registry{

  my $registry_obj = shift;
  my $study_obj = shift;
  my $organism_assmblAccession_EG_href = shift ;

  my $study_id = $study_obj->id; 
 
  my $hub_txt_url = $server_url . "/" . $study_id . "/hub.txt" ;

  my $assemblyNames_assemblyAccesions_string = get_assembly_names_assembly_ids_string_for_study($study_obj,$organism_assmblAccession_EG_href);
  my $output = $registry_obj->register_track_hub($study_id,$hub_txt_url,$assemblyNames_assemblyAccesions_string);
  return $output;
  
}

sub update_TH_with_new_assembly{ # i need to update the genomes.txt file and add a new assembly folder for the updated assembly of the species and also update the rest if any species of the study

  my $study_obj = shift;
  my $common_studies_to_be_updated_with_new_assembly_href = shift;
  my $registry_obj = shift;
  my $plant_names_AE_response_href = shift;
  my $server_dir_full_path = shift;
  my $organism_assmblAccession_EG_href = shift; #$hash{"brachypodium_distachyon"} = "GCA_000005505.1"  

  my $study_id = $study_obj->id;
  my @assembly_name_accession_pairs; # for the THR, to do the registration of the TH  , elements of array like : "ASM242v1,GCA_000002425.1"

  my %organism_name_assembly_name_hash_AE = %{$study_obj->get_organism_names_assembly_names()}; # AE: hash{brachypodium_distachyon}="v1.0" , hash{arabidopsis_thaliana}="TAIR10" -> in AE

  my $track_hub_creator_obj = EGPlantTHs::TrackHubCreation->new($study_id,$server_dir_full_path);

  # THR: hash{brachypodium_distachyon}{v1.0}="GCA_000005505.1" , hash{brachypodium_distachyon}{v2.0}="GCA_000005505.2" , $hash{triticum_aestivum}{IWGSC1+popseq}="0000" , $hash{triticum_aestivum}{TGACv1}="0000"
  my %old_organism_name_assembly_id_assembly_name_hash_THR = %{$registry_obj->give_species_names_assembly_names_of_track_hub($study_id)};

  #$hash_log{$organism_name}="New assembly name found for study $common_study_id for species $organism_name in AE: ".$organism_name_assembly_name_hash_AE{$organism_name}." ; we had in the THR for this plant, assembly name/s: ",join (",", @assembly_names_THR)) ;
  my %hash_log = %{$common_studies_to_be_updated_with_new_assembly_href->{$study_id}}; 

  my @return_array;

  foreach my $species_name (keys %organism_name_assembly_name_hash_AE){ # I loop through the species that AE gives me for the this study currently

    my $assembly_name_AE  = $organism_name_assembly_name_hash_AE{$species_name};
    my $assembly_name_accession_pair = $assembly_name_AE.",".$organism_assmblAccession_EG_href->{$species_name}; 
    push(@assembly_name_accession_pairs,$assembly_name_accession_pair); # should be "ASM242v1,GCA_000002425.1,IRGSP-1.0,GCA_000005425.2";

    if (!$hash_log{$species_name}){   # the species has the same assembly in the THR and in AE, but I will update it anyways
       
      remove_tree "$server_dir_full_path/$study_id/$assembly_name_AE" if -d "$server_dir_full_path/$study_id/$assembly_name_AE" or die "I could not remove dir $server_dir_full_path/$study_id/$assembly_name_AE for $species_name\n";    

    }else{ # for same species have new assembly so I need to get its old assembly info from the THR

      foreach my $assembly_name (keys %{$old_organism_name_assembly_id_assembly_name_hash_THR{$species_name}} ){

        my $assembly_name_accession_pair_old = $assembly_name . ",". $old_organism_name_assembly_id_assembly_name_hash_THR{$species_name}{$assembly_name} ;
        push(@assembly_name_accession_pairs,$assembly_name_accession_pair_old); # should be "ASM242v1,GCA_000002425.1,IRGSP-1.0,GCA_000005425.2";
        
      }       
    }

    `mkdir $server_dir_full_path/$study_id/$assembly_name_AE`; #  I make updated assembly directories either way from AE
    my $return_of_make_trackDbtxt_file = $track_hub_creator_obj->make_trackDbtxt_file($server_dir_full_path, $study_obj ,$assembly_name_AE);

    if (!$return_of_make_trackDbtxt_file) { # method returns 0 when there is no ENA warehouse metadata

      $return_array[0] = ".. No ENA Warehouse metadata found for at least 1 of the sample ids\n";
      $return_array[1] = \@assembly_name_accession_pairs;
      return ( \@return_array); 
    }
    if ($return_of_make_trackDbtxt_file eq "at least 1 cram file of the TH that was not found in ENA"){

      $return_array[0] = "..Skipping this TH because at least 1 of the cram files of the TH is not yet in ENA\n" ;
      $return_array[1] = \@assembly_name_accession_pairs;
      return ( \@return_array); 
    }

  }
  # THR: hash{brachypodium_distachyon}{GCA_000005505.1}="v1.0" , hash{brachypodium_distachyon}{GCA_000005505.2}="v2.0" 
  foreach my $species_name_THR (keys %old_organism_name_assembly_id_assembly_name_hash_THR){

    if(!$organism_name_assembly_name_hash_AE{$species_name_THR}){ # the species is redundant, not anymore in AE , so i will remove it 

      foreach my $assembly_name (keys %{$old_organism_name_assembly_id_assembly_name_hash_THR{$species_name_THR}}){ #hash{brachypodium_distachyon}{v2.0}="GCA_000005505.2"  

        remove_tree "$server_dir_full_path/$study_id/$assembly_name" if -d "$server_dir_full_path/$study_id/$assembly_name";
      }
    }
  }
 
  my @current_assembly_names_in_server= @{give_dir_names_of_dir_content("$server_dir_full_path/$study_id")};
  my $genomes_txt_file = "$server_dir_full_path/$study_id/genomes.txt";

  `rm $genomes_txt_file`;
  touch_file($genomes_txt_file);

  open(my $fh, '>', $genomes_txt_file); 

  foreach my $assembly_name (@current_assembly_names_in_server){

    print $fh "genome ".$assembly_name."\n"; 
    print $fh "trackDb ".$assembly_name."/trackDb.txt"."\n\n"; 
  }

  $return_array[0] = "..Done\n" ;
  $return_array[1] = \@assembly_name_accession_pairs;
  return (\@return_array);
}

sub give_dir_names_of_dir_content {

  my $path = shift;
  
  my @dir_names;

  my $ls_output_study = `ls -d $path/*/`;

  my @dirs = split (/\/\s/,$ls_output_study);  # $ls_output_study = /homes/tapanari/electra/dir1/ new line /homes/tapanari/electra/dir2/

  foreach my $full_path_dir (@dirs){
    my @paths = split (/\//, $full_path_dir); #/homes/tapanari/electra/dir1
    my $last_element_index = scalar @paths -1;
    push (@dir_names ,$paths[$last_element_index]);
  }

  return \@dir_names;
}

sub touch_file {
  my @files = @_;
  
  for my $path (@files) {
    if (not -f $path) {
      open my $fileh, ">$path";
      close $fileh;
    }
    utime(undef, undef, $path) or print STDERR "Can't touch this: $path ($!)";
  }
  return;
}