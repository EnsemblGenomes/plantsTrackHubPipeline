
# do first:
# export THR_USER=your_user_name_in_your_track_hub_registry_account
# export THR_PWD=your_password_in_your_track_hub_registry_account

# this script creates and registers track hubs for only the study ids or species names defined in the input file

# example run:
# perl make_and_register_track_hubs.pl -server_dir_full_path /nfs/ensemblgenomes/ftp/pub/misc_data/Track_Hubs -server_url ftp://ftp.ensemblgenomes.org/pub/misc_data/Track_Hubs -th_visibility public -file_location_of_study_ids_or_species ./file_with_ids -file_content_study_ids 1> output 2>errors

# or 
# perl make_and_register_track_hubs.pl -server_dir_full_path /nfs/ensemblgenomes/ftp/pub/misc_data/Track_Hubs -server_url ftp://ftp.ensemblgenomes.org/pub/misc_data/Track_Hubs -th_visibility public  -file_location_of_study_ids_or_species ./file_with_ids -file_content_species_names 1> output 2>errors

use strict ;
use warnings;
use autodie;
use File::Path qw(remove_tree);

use FindBin;
use lib $FindBin::Bin . '/../modules';
use Getopt::Long;
use EGPlantTHs::ArrayExpress;
use EGPlantTHs::TrackHubCreation;
use EGPlantTHs::AEStudy;
use EGPlantTHs::Registry;
use EGPlantTHs::EG;

my $registry_user_name = $ENV{'THR_USER'}; 
my $registry_pwd = $ENV{'THR_PWD'};

defined $registry_user_name and $registry_pwd
  or die "Track Hub Registry username and password are required to be set as shell variables\n";

my $server_dir_full_path ; # ie. ftp://ftp.ensemblgenomes.org/pub/misc_data/.TrackHubs
my $server_url ;  # ie. /nfs/ensemblgenomes/ftp/pub/misc_data/.TrackHubs;
my $track_hub_visibility; # defines whether when I register a TH in the THR will be publicly available or not. Give "hidden" or "public"
my $file_location_of_study_ids_or_species;
my $species_file_content; #flag
my $study_ids_file_content; #flag

my $start_time = time();

GetOptions(

  "server_dir_full_path=s" => \$server_dir_full_path,
  "server_url=s" => \$server_url,  
  "th_visibility=s" => \$track_hub_visibility,
  "file_location_of_study_ids_or_species=s" => \$file_location_of_study_ids_or_species,
  "file_content_species_names"  => \$species_file_content,  # flag OR 
  "file_content_study_ids"  => \$study_ids_file_content  # flag

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

if(!$file_location_of_study_ids_or_species){
  die "Please give full path of file with track hub ids or species names to be updated, run pipeline using -file_location_of_study_ids_or_species option and value"
}

if(!$species_file_content and !$study_ids_file_content){
  die "\nPlease give flag \"-file_content_species_names\" or \"-file_content_study_ids\" , depending on the content of the file \"$file_location_of_study_ids_or_species\" (does it have study ids or species names?)\n\n";
}

if($species_file_content and $study_ids_file_content){
  die "\nPlease give only 1 flag: \"-file_content_species_names\" or \"-file_content_study_ids\" , depending on the content of the file \"$file_location_of_study_ids_or_species\" (does it have study ids or species names?)\n\n";
}

my %study_ids;
my %species_names;
my @obsolete_studies;

my $plant_names_href_EG = EGPlantTHs::EG::get_plant_names;

my %study_ids_from_AE ;

open(IN, $file_location_of_study_ids_or_species) or die "Can't open $file_location_of_study_ids_or_species.\n";

if($study_ids_file_content){

  %study_ids_from_AE= %{EGPlantTHs::ArrayExpress::get_completed_study_ids_for_plants($plant_names_href_EG)}; # i need to get study ids from AE currently

  while(<IN>){
    chomp;
    if($study_ids_from_AE{$_}){  # i have to check if this study id is still in AE , if it's not now in AE, I leave this TH the way it was without updating it. It will be updated when I run the pipeline with the update option
      $study_ids{$_}=1;
    }else{
      push(@obsolete_studies,$_);
    }
  }
  close (IN);

}else{  # the user will have species names in the text file

  my %eg_species_names= %$plant_names_href_EG;

  while(<IN>){
    chomp;

    if($eg_species_names{$_}){ # if the plant species defined in the line of the file exists in EG
      $species_names{$_}=1;
    }else{
      die "\nPlant name ".$_." is not part of the EnsemblGenomes plant names. Please run again the pipeline using these names inside the file $file_location_of_study_ids_or_species : \n\n". join("\n",keys %eg_species_names)."\n\n";
    }
  }
  close (IN);

  foreach my $species_name (keys %species_names){

    my %study_ids_of_plant = %{EGPlantTHs::ArrayExpress::get_study_ids_for_plant($species_name)};

    foreach my $study_id_of_plant (keys %study_ids_of_plant){

      $study_ids{$study_id_of_plant}=1;

    }    
  }
}


{
  print_calling_params_logging($registry_user_name , $registry_pwd , $server_dir_full_path , $server_url , $track_hub_visibility, $file_location_of_study_ids_or_species);

  my $registry_obj = EGPlantTHs::Registry->new($registry_user_name, $registry_pwd, $track_hub_visibility); 

  if (! -d $server_dir_full_path) {  # if the directory that the user defined to write the files of the track hubs doesnt exist, I try to make it

    print "\nThis directory: $server_dir_full_path does not exist, I will make it now.\n";
    mkdir $server_dir_full_path;
  }

  my $all_track_hubs_in_registry_href = $registry_obj->give_all_Registered_track_hub_names();
  print_registry_registered_number_of_th($registry_obj,$all_track_hubs_in_registry_href );

  my $plant_names_AE_response_href = EGPlantTHs::ArrayExpress::get_plant_names_AE_API();

  if($plant_names_AE_response_href == 0){

    die "Could not get plant names with processed runs from AE API calling script ".__FILE__." line: ".__LINE__."\n";
  }
 
  my $study_ids_to_be_updated_with_new_assemblies_href = get_study_ids_to_be_updated_with_new_assembly($registry_obj, \%study_ids ,$plant_names_AE_response_href,$all_track_hubs_in_registry_href);
  my %study_ids_other_than_ones_with_new_assembly_update;

  foreach my $study_id (keys %study_ids){
    if(!($study_ids_to_be_updated_with_new_assemblies_href->{$study_id})){
      $study_ids_other_than_ones_with_new_assembly_update{$study_id}=1;
    }
  }

  my $organism_assmblAccession_EG_href = EGPlantTHs::EG::get_species_name_assembly_id_hash(); #$hash{"brachypodium_distachyon"} = "GCA_000005505.1"         also:  $hash{"oryza_rufipogon"} = "0000"
  my $unsuccessful_studies_href_non_new_assemblies={};  
  my $unsuccessful_studies_href_new_assemblies={};

  print "\n";
  my $counter_of_study_ids_other_than_ones_with_new_assembly_update=keys (%study_ids_other_than_ones_with_new_assembly_update);
  if($counter_of_study_ids_other_than_ones_with_new_assembly_update > 0){
    print "Updates / new track hubs: "." ( ".$counter_of_study_ids_other_than_ones_with_new_assembly_update." )\n\n"; # if there is an cram update of a TH with archive assemblies, it gets updated the same way as the assembly updates by calling make_register_THs_with_logging("new_assembly",...)
    $unsuccessful_studies_href_non_new_assemblies = make_register_THs_with_logging("non_new_assembly",$registry_obj, \%study_ids_other_than_ones_with_new_assembly_update , $server_dir_full_path, $organism_assmblAccession_EG_href,$plant_names_AE_response_href); 
  }

  my $counter_of_study_ids_to_be_updated_with_new_assemblies = keys (%$study_ids_to_be_updated_with_new_assemblies_href);
  if ($counter_of_study_ids_to_be_updated_with_new_assemblies> 0){
    print "\n\nAssembly updates (or updates of track hubs with archived assemblies) of existing track hubs: $counter_of_study_ids_to_be_updated_with_new_assemblies\n\n";  
    $unsuccessful_studies_href_new_assemblies = make_register_THs_with_logging("new_assembly", $registry_obj, $study_ids_to_be_updated_with_new_assemblies_href , $server_dir_full_path, $organism_assmblAccession_EG_href,$plant_names_AE_response_href); 
  }

  if(scalar (keys %{$unsuccessful_studies_href_non_new_assemblies}) > 0 or scalar (keys %{$unsuccessful_studies_href_new_assemblies}) > 0){
    print "\nThere were some studies that failed to be made or failed to have their track hubs updated:\n\n";
  }

  if(scalar (keys %{$unsuccessful_studies_href_non_new_assemblies}) > 0){
    print "From the updates/new with no new assemblies\n\n";
  }
  my $counter=0;
  foreach my $reason_of_failure (keys %{$unsuccessful_studies_href_non_new_assemblies}){  # hash looks like: $unsuccessful_studies{"Missing all Samples in AE REST API"}{$study_id}= 1;

    foreach my $failed_study_id (keys %{$unsuccessful_studies_href_non_new_assemblies->{$reason_of_failure}}){

      $counter ++;
      print "$counter. $failed_study_id\t".$reason_of_failure."\n";
    }
  }

  if (scalar (keys %{$unsuccessful_studies_href_new_assemblies}) > 0){
        print "\nFrom the updates with new assemblies\n\n";
  }
  foreach my $reason_of_failure (keys %{$unsuccessful_studies_href_new_assemblies}){  # hash looks like: $unsuccessful_studies{"Missing all Samples in AE REST API"}{$study_id}= 1;

    foreach my $failed_study_id (keys %{$unsuccessful_studies_href_new_assemblies->{$reason_of_failure}}){

      $counter ++;
      print "$counter. $failed_study_id\t".$reason_of_failure."\n";
    }
  }

  my $date_string2 = localtime();
  print " \n Finished creating the files,directories of the track hubs on the server on:\n";
  print "Local date,time: $date_string2\n";

  print "\nAfter the updates:\n";
  $all_track_hubs_in_registry_href = $registry_obj->give_all_Registered_track_hub_names();
  print_registry_registered_number_of_th($registry_obj , $all_track_hubs_in_registry_href);
  print "\nThere are in total ". give_number_of_dirs_in_ftp($server_dir_full_path). " files in the ftp server\n\n";

  print_run_duration_so_far($start_time);


  $| = 1; 

  if (scalar @obsolete_studies > 0){
    print "\nObsolete studies list (not any more in AE) but still in THR and on the server as tracks hubs, I haven't deleted them:\n";
    foreach my $obsolete_study (@obsolete_studies){
      print $obsolete_study."\n";
    }
  }
}

sub get_study_ids_to_be_updated_with_new_assembly{ # this method also considers the studies that have archived assemblies and the current assembly has a cram update

  my $registry_obj = shift;
  my $study_ids_href = shift;
  my $plant_names_AE_response_href = shift;
  my $all_track_hubs_in_registry_href = shift;

  my %study_ids_to_be_updated_with_new_assembly; # I return a hash table with keys the study ids that need updating with a new assembly

  foreach my $study_id (keys %$study_ids_href){ # the study ids that the user has given and that they exist in AE

    if(!$all_track_hubs_in_registry_href->{$study_id}){ # if this study is not in the THR I skip it 
      next;
    }
    my $study_obj = EGPlantTHs::AEStudy->new($study_id,$plant_names_AE_response_href);

    my %organism_name_assembly_name_hash_AE_for_study = %{$study_obj->get_organism_names_assembly_names()}; # hash{brachypodium_distachyon}="v1.0" , hash{arabidopsis_thaliana}="TAIR10" -> in AE

    # hash{brachypodium_distachyon}{"v1.0"}="GCA_000005505.1", hash{brachypodium_distachyon}{"v2.0"}= "GCA_000005505.2"  -> in the THR
    my %old_organism_name_assembly_name_assembly_id_hash_THR = %{$registry_obj->give_species_names_assembly_names_of_track_hub($study_id)};

    my %log_hash; 
    my @assembly_names_THR_of_study;

    foreach my $plant_name (keys %old_organism_name_assembly_name_assembly_id_hash_THR){

      foreach my $assembly_name (keys %{$old_organism_name_assembly_name_assembly_id_hash_THR{$plant_name} }){

        push (@assembly_names_THR_of_study,$assembly_name); # I store all assembly names of the study that are in the THR to print them in the log
      }     
    }  

    foreach my $organism_name_in_AE (keys %organism_name_assembly_name_hash_AE_for_study){ # loop through the plant names of this particular study in AE

      my $flag_assembly_name_of_AE_found_in_THR=0;

      if($old_organism_name_assembly_name_assembly_id_hash_THR{$organism_name_in_AE}){ # if this plant species is already in the THR registered under this study, i will check if they have the same assembly as in AE

        foreach my $assembly_name_THR (keys %{$old_organism_name_assembly_name_assembly_id_hash_THR{$organism_name_in_AE}}){ # there could be already more than 1 assembly names in the THR for this species

          if($organism_name_assembly_name_hash_AE_for_study{$organism_name_in_AE} eq $assembly_name_THR){ # if in the THR the AE assembly name does not exist, we have a new assembly of the plant

            $flag_assembly_name_of_AE_found_in_THR =1;

          }
        }
      }

      if ($flag_assembly_name_of_AE_found_in_THR ==0 and $old_organism_name_assembly_name_assembly_id_hash_THR{$organism_name_in_AE} or keys %{$old_organism_name_assembly_name_assembly_id_hash_THR{$organism_name_in_AE}} > 1) { # if the AE assembly is not found registered under this species in the THR, I need to add the new assembly to the TH
        my @array;
        $array[0] = "New assembly name found (or multiple assemblies found in a study that needs update) for study $study_id for species $organism_name_in_AE in AE: ".$organism_name_assembly_name_hash_AE_for_study{$organism_name_in_AE}." ; we had in the THR for this study assembly name/s: ";
        $array[1] = join (",", @assembly_names_THR_of_study);
        $log_hash{$organism_name_in_AE}=(\@array) ;
      }

    }  # if there is a new species in the study it continues with the old code, line 456 onwards..

    if(keys %log_hash> 0){ # if the log is not empty it means we have at least 1 new assembly in AE from a species of the current study I am looping through
    
      $study_ids_to_be_updated_with_new_assembly{$study_id}=\%log_hash;
    }  
  }

  return \%study_ids_to_be_updated_with_new_assembly;
}

sub make_register_THs_with_logging{

  my $new_or_not_assembly_flag = shift;
  my $registry_obj = shift;
  my $study_ids_href = shift;
  my $server_dir_full_path = shift;
  my $organism_assmblAccession_EG_href = shift;
  my $plant_names_AE_response_href = shift;

  my $line_counter = 0;
  my %unsuccessful_studies;

  foreach my $study_id (keys %$study_ids_href){

    my $study_obj = EGPlantTHs::AEStudy->new($study_id,$plant_names_AE_response_href);

    my $sample_ids_href = $study_obj->get_sample_ids();
    if(!$sample_ids_href){  # there are cases where the AE API returns a study with the the sample_ids field to be null , I want to skip these studies
      $unsuccessful_studies{"Missing all Samples in AE REST API"}{$study_id}= 1;
      next;
    }

    $line_counter++;
    print "$line_counter.\tcreating track hub in the server for study $study_id\t"; 

    if($new_or_not_assembly_flag eq "non_new_assembly"){

      my $ls_output = `ls $server_dir_full_path`  ;
      if($ls_output =~/$study_id/){ # i check if the directory of the study exists already, I want to replace the Track Hub or make a new one
   
        my $backup_name = $study_id."_backup";
        if (-d "$server_dir_full_path/$backup_name"){
          remove_tree "$server_dir_full_path/$backup_name"; # i remove it in case it exists from previous un-successful runs
        }  
        mkdir "$server_dir_full_path/$backup_name" ; # I create a backup directory of this track hub- in case the update of this track hub with the new assembly goes wrong, the track hub remains the way it was before the attempt to update
        `cp -r $server_dir_full_path/$study_id/* $server_dir_full_path/$backup_name`;
        remove_tree "$server_dir_full_path/$study_id";  # i remove it, to re-make it
  
        print " (update) "; # if it already exists
      }else{
        print " (new) ";
      }
    }else{ # if it's an assembly update
        my $backup_name = $study_id."_backup";
        if (-d "$server_dir_full_path/$backup_name"){
          remove_tree "$server_dir_full_path/$backup_name"; # i remove it in case it exists from previous un-successful runs
        }  
        mkdir "$server_dir_full_path/$backup_name" ; # I create a backup directory of this track hub- in case the update of this track hub with the new assembly goes wrong, the track hub remains the way it was before the attempt to update
        `cp -r $server_dir_full_path/$study_id/* $server_dir_full_path/$backup_name`;
    }

    my $script_output;
    my @assembly_names_assembly_ids_pairs ;

    if($new_or_not_assembly_flag eq "non_new_assembly"){

      my $track_hub_creator_obj = EGPlantTHs::TrackHubCreation->new($study_id,$server_dir_full_path);
      $script_output = $track_hub_creator_obj->make_track_hub($plant_names_AE_response_href);

    }else{

      my @script_output_list = @{update_TH_with_new_assembly($study_obj, $study_ids_href, $registry_obj,$plant_names_AE_response_href, $server_dir_full_path ,$organism_assmblAccession_EG_href )};
      $script_output = $script_output_list[0];
      @assembly_names_assembly_ids_pairs = @{$script_output_list[1]};
    }

    print $script_output;
 
    if($script_output !~ /..Done/){  # if for some reason the track hub didn't manage to be made in the server, it shouldn't be registered in the Registry, for example Robert gives me a study id as completed that is not yet in ENA

      print STDERR "Track hub of $study_id could not be made in the server - Folder $study_id is deleted from the server\n\n" ;

      print "\t..Skipping registration part\n";
      
      if (-d "$server_dir_full_path/$study_id"){
        remove_tree "$server_dir_full_path/$study_id" ; 
      }
      my $backup_name = $study_id."_backup";
        if (-d "$server_dir_full_path/$backup_name" ) {
          rename ("$server_dir_full_path/$backup_name","$server_dir_full_path/$study_id"); 
      }

      $line_counter --;

      if ($script_output=~/No ENA Warehouse metadata found/){

        $unsuccessful_studies{"Sample metadata not yet in ENA"} {$study_id}= 1;

      }elsif($script_output=~/Skipping this TH because at least 1 of the cram files of the TH is not yet in ENA/){ 

        $unsuccessful_studies{"At least 1 cram file of study is not yet in ENA"} {$study_id}= 1;

      }else{

        $unsuccessful_studies{"Study not yet in ENA"} {$study_id}= 1;
      }

    }else{  # if the study is successfully created in the ftp server, I go ahead and register it
        
      my $return_string;
      if($new_or_not_assembly_flag eq "non_new_assembly") {

        $return_string = register_track_hub_in_TH_registry($registry_obj,$study_obj,$organism_assmblAccession_EG_href );  

      } else {

        my $assemblyNames_assemblyAccesions_string = join(",",@assembly_names_assembly_ids_pairs);
        my $hub_txt_url = $server_url . "/" . $study_id . "/hub.txt" ;
        $return_string = $registry_obj->register_track_hub($study_id,$hub_txt_url,$assemblyNames_assemblyAccesions_string);

        print "trying to register: $study_id,$hub_txt_url,$assemblyNames_assemblyAccesions_string\n";  # comment this!  
      }

      if($return_string !~ /is Registered/){# if something went wrong with the registration, i will not make a track hub out of this study

        my $backup_name = $study_id."_backup";
        if (-d "$server_dir_full_path/$study_id") {remove_tree "$server_dir_full_path/$study_id"; }
        if (-d "$server_dir_full_path/$backup_name") { rename ("$server_dir_full_path/$backup_name","$server_dir_full_path/$study_id");} 

        $line_counter --;
        $return_string = $return_string . "\t..Something went wrong with the Registration process -- this study will be skipped..\n";
        print STDERR "Study $study_id could not be registered in the THR - Folder $study_id is deleted from the server\n";
        $unsuccessful_studies{"Registry issue"}{$study_id}= 1;

      }else{ # successful overall
        my $backup_name = $study_id."_backup";
        if (-d "$server_dir_full_path/$backup_name") {remove_tree "$server_dir_full_path/$backup_name" ;} 
      }
      print $return_string;
      
    }
  }

  return (\%unsuccessful_studies);
}

sub update_TH_with_new_assembly{ # i need to update the genomes.txt file and add a new assembly folder for the updated assembly of the species and also update the rest if any species of the study

  my $study_obj = shift;
  my $study_ids_to_be_updated_with_new_assembly_href= shift;
  my $registry_obj = shift;
  my $plant_names_AE_response_href = shift;
  my $server_dir_full_path = shift;
  my $organism_assmblAccession_EG_href = shift; #$hash{"brachypodium_distachyon"} = "GCA_000005505.1"  

  my $study_id = $study_obj->id;
  my %assembly_name_accession_pairs_hash;
  my @assembly_name_accession_pairs; # for the THR, to do the registration of the TH  , elements of array like : "ASM242v1,GCA_000002425.1"

  my %organism_name_assembly_name_hash_AE_for_study = %{$study_obj->get_organism_names_assembly_names()}; # AE: hash{brachypodium_distachyon}="v1.0" , hash{arabidopsis_thaliana}="TAIR10" -> in AE

  my $track_hub_creator_obj = EGPlantTHs::TrackHubCreation->new($study_id,$server_dir_full_path);

  # THR: hash{brachypodium_distachyon}{v1.0}="GCA_000005505.1" , hash{brachypodium_distachyon}{v2.0}="GCA_000005505.2" , $hash{triticum_aestivum}{IWGSC1+popseq}="0000" , $hash{triticum_aestivum}{TGACv1}="0000"
  my %old_organism_name_assembly_name_assembly_id_hash_THR = %{$registry_obj->give_species_names_assembly_names_of_track_hub($study_id)};

  #content: $hash_log{$organism_name}="New assembly name found for study $common_study_id for species $organism_name in AE: ".$organism_name_assembly_name_hash_AE_for_study{$organism_name}." ; we had in the THR for this plant, assembly name/s: ",join (",", @assembly_names_THR_of_study)) ;
  my %hash_log = %{$study_ids_to_be_updated_with_new_assembly_href->{$study_id}}; 
  
  my @return_array;

  foreach my $species_name (keys %organism_name_assembly_name_hash_AE_for_study){ # I loop through the species that AE gives me for the this study currently

    if ($hash_log{$species_name}){      
      my @array=@{$hash_log{$species_name}};
      print "\n".$array[0];
      print $array[1]."\n";
    }
    my $assembly_name_AE  = $organism_name_assembly_name_hash_AE_for_study{$species_name};
    $assembly_name_accession_pairs_hash{$assembly_name_AE}{$organism_assmblAccession_EG_href->{$species_name}}=1;

    foreach my $assembly_name (keys %{$old_organism_name_assembly_name_assembly_id_hash_THR{$species_name}} ){
     
      my $assembly_accession=$old_organism_name_assembly_name_assembly_id_hash_THR{$species_name}{$assembly_name};
      $assembly_name_accession_pairs_hash{$assembly_name}{$assembly_accession}=1;
    }

    @assembly_name_accession_pairs=();
    foreach my $assembly_name (keys %assembly_name_accession_pairs_hash){
      foreach my $assembly_accession (keys %{$assembly_name_accession_pairs_hash{$assembly_name}}){
        my $string= $assembly_name . ",". $assembly_accession;
        push(@assembly_name_accession_pairs, $string);
      }
    }
 
    if (-d "$server_dir_full_path/$study_id/$assembly_name_AE"){ remove_tree "$server_dir_full_path/$study_id/$assembly_name_AE"  or die "I could not remove dir $server_dir_full_path/$study_id/$assembly_name_AE for $species_name\n";}
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
      return ( \@return_array);  # print the assemblies done so far in the code
    }

  } # end of loop through the species name of AE.

  # THR: hash{brachypodium_distachyon}{GCA_000005505.1}="v1.0" , hash{brachypodium_distachyon}{GCA_000005505.2}="v2.0" 
  foreach my $species_name_THR (keys %old_organism_name_assembly_name_assembly_id_hash_THR){

    if(!$organism_name_assembly_name_hash_AE_for_study{$species_name_THR}){ # the species is redundant, not anymore in AE , so i will remove it 

      foreach my $assembly_name (keys %{$old_organism_name_assembly_name_assembly_id_hash_THR{$species_name_THR}}){ #hash{brachypodium_distachyon}{v2.0}="GCA_000005505.2"  

        if (-d "$server_dir_full_path/$study_id/$assembly_name"){remove_tree "$server_dir_full_path/$study_id/$assembly_name" ;}
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

sub print_calling_params_logging{
  
  my ($registry_user_name , $registry_pwd , $server_dir_full_path ,$server_url, $track_hub_visibility, $file_location_of_study_ids_or_species) = @_;
  my $date_string = localtime();

  print "* Using these shell variables of the THR account:\n\n";
  print " THR_USER=$registry_user_name\n THR_PWD=$registry_pwd\n\n";
 
  print "* Started running the pipeline on:\n";
  print "Local date,time: $date_string\n";

  print "\n* Ran this pipeline:\n\n";
  print "perl make_and_register_track_hubs.pl -server_dir_full_path $server_dir_full_path -server_url $server_url -th_visibility $track_hub_visibility -file_location_of_study_ids_or_species $file_location_of_study_ids_or_species";
  if ($species_file_content){
    print " -file_content_species_names";
  }else{
    print " -file_content_study_ids";
  }

  print "\n";
  print "\n* I am using this server to eventually build my track hubs:\n\n $server_url\n\n";
  print "* I am using this Registry account:\n\n user:$registry_user_name \n password:$registry_pwd\n\n";

  $| = 1;  # it flashes the output

}

sub print_registry_registered_number_of_th{

  my $registry_obj = shift;
  my $all_track_hubs_in_registry_href=shift;

  my %distinct_bioreps;

  foreach my $hub_name (keys %{$all_track_hubs_in_registry_href}){
    my %bioreps_hash = %{$registry_obj->give_all_bioreps_of_study_from_Registry($hub_name)};
    map { $distinct_bioreps{$_}++ } keys %bioreps_hash;
  }

  print "There are in total ". scalar (keys %$all_track_hubs_in_registry_href);
  print " track hubs with total ".scalar (keys %distinct_bioreps)." bioreps registered in the Track Hub Registry under this account\n\n";

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

sub give_number_of_dirs_in_ftp {

  my $ftp_location = shift;
  
  my @files = `ls $ftp_location` ;
  
  return  scalar @files;
}

sub print_run_duration_so_far{

  my $start_run = shift;

  my $end_run = time();
  my $run_time = $end_run - $start_run;

  print "\nRun time was $run_time seconds (". $run_time/3600 ." hours)\n";
}