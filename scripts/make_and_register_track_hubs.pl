
# do first:
# export THR_USER=your_user_name_in_your_track_hub_registry_account
# export THR_PWD=your_password_in_your_track_hub_registry_account

# example run:
# perl make_and_register_track_hubs.pl -server_dir_full_path /nfs/ensemblgenomes/ftp/pub/misc_data/Track_Hubs -server_url ftp://ftp.ensemblgenomes.org/pub/misc_data/Track_Hubs -th_visibility public -file_location_of_study_ids_or_species ./file_with_ids -file_content_study_ids 1> output 2>errors

# or 
# perl make_and_register_track_hubs.pl -server_dir_full_path /nfs/ensemblgenomes/ftp/pub/misc_data/Track_Hubs -server_url ftp://ftp.ensemblgenomes.org/pub/misc_data/Track_Hubs -th_visibility public  -file_location_of_study_ids_or_species ./file_with_ids -file_content_species_names 1> output 2>errors

use strict ;
use warnings;


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
my $species_file_content;
my $study_ids_file_content;

my $start_time = time();

GetOptions(

  "server_dir_full_path=s" => \$server_dir_full_path,
  "server_url=s" => \$server_url,  
  "th_visibility=s" => \$track_hub_visibility,
  "file_location_of_study_ids_or_species=s" => \$file_location_of_study_ids_or_species,
  "file_content_species_names"  => \$species_file_content,  # flag
  "file_content_study_ids"  => \$study_ids_file_content  # flag

);

if(!$species_file_content and !$study_ids_file_content){
  die "\nPlease give flag \"-file_content_species_names\" or \"-file_content_study_ids\" , depending on the content of the file \"$file_location_of_study_ids_or_species\" (does it have study ids or species names?)\n\n";
}

if(!$track_hub_visibility){
  die "\nPlease give TH visibility setting in the THR either hidden or public\n";
}

my %study_ids;
my %species_names;
my @obsolete_studies;

my $plant_names_href_EG = EGPlantTHs::EG::get_plant_names;

my %study_ids_from_AE = %{EGPlantTHs::ArrayExpress::get_completed_study_ids_for_plants($plant_names_href_EG)};

open(IN, $file_location_of_study_ids_or_species) or die "Can't open $file_location_of_study_ids_or_species.\n";

if($study_ids_file_content){

  while(<IN>){
    chomp;
    if($study_ids_from_AE{$_}){  # i have to check if this study id is still in AE , if it's not now in AE, I leave this TH the way it was without updating it. I t will be updated when I run the pipeline with the update option
      $study_ids{$_}=1;
    }else{
      push(@obsolete_studies,$_);
    }
  }
  close (IN);

}else{  # the user will have species names in the text file

  my %eg_species_names= %{EGPlantTHs::EG::get_plant_names()};

  while(<IN>){
    chomp;
    if($eg_species_names{$_}){
      $species_names{$_}=1;
    }else{
      die "\nPlant name ".$_." is not part of the EnsemblGenomes plant names. Please run again the pipeline using these names inside the file $file_location_of_study_ids_or_species : \n\n". join("\n",keys %eg_species_names)."\n\n";
    }
  }
  close (IN);

  foreach my $species_name (keys %species_names){

    my %study_ids_of_plant = %{EGPlantTHs::ArrayExpress::get_study_ids_for_plant($species_name)};

    foreach my $study_id_of_plant (keys %study_ids_of_plant){

      if($study_ids_from_AE{$study_id_of_plant}){ # i have to check if this study id is still in AE

        $study_ids{$study_id_of_plant}=1;

      }else{
        push(@obsolete_studies,$study_id_of_plant);
      }
    }    
  }
}


{
  print_calling_params_logging($registry_user_name , $registry_pwd , $server_dir_full_path , $server_url , $track_hub_visibility, $file_location_of_study_ids_or_species);

  my $registry_obj = EGPlantTHs::Registry->new($registry_user_name, $registry_pwd,$track_hub_visibility); 

  if (! -d $server_dir_full_path) {  # if the directory that the user defined to write the files of the track hubs doesnt exist, I try to make it

    print "\nThis directory: $server_dir_full_path does not exist, I will make it now.\n";

    Helper::run_system_command("mkdir $server_dir_full_path")
      or die "I cannot make dir $server_dir_full_path in script: ".__FILE__." line: ".__LINE__."\n";
  }

  my $plant_names_AE_response_href = EGPlantTHs::ArrayExpress::get_plant_names_AE_API();

  if($plant_names_AE_response_href == 0){

    die "Could not get plant names with processed runs from AE API calling script ".__FILE__." line: ".__LINE__."\n";
  }

  my $organism_assmblAccession_EG_href = EGPlantTHs::EG::get_species_name_assembly_id_hash(); #$hash{"brachypodium_distachyon"} = "GCA_000005505.1"         also:  $hash{"oryza_rufipogon"} = "0000"

  print_registry_registered_number_of_th($registry_obj);
 
  my $unsuccessful_studies_href = make_register_THs_with_logging($registry_obj, \%study_ids , $server_dir_full_path, $organism_assmblAccession_EG_href,$plant_names_AE_response_href); 
  my $counter=0;

  if(scalar (keys %$unsuccessful_studies_href) >0){
    print "\nThere were some studies that failed to be made track hubs:\n\n";
  }

  foreach my $reason_of_failure (keys %$unsuccessful_studies_href){  # hash looks like; $unsuccessful_studies{"Missing all Samples in AE REST API"}{$study_id}= 1;

    foreach my $failed_study_id (keys $unsuccessful_studies_href->{$reason_of_failure}){

      $counter ++;
      print "$counter. $failed_study_id\t".$reason_of_failure."\n";
    }
  }



  my $date_string2 = localtime();
  print " \n Finished creating the files,directories of the track hubs on the server on:\n";
  print "Local date,time: $date_string2\n";

  print "\nAfter the updates:\n";
  print_registry_registered_number_of_th($registry_obj);


  $| = 1; 

  if (scalar @obsolete_studies > 0){
    print "\nObsolete studies list (not any more in AE) but still in THR, I haven't deleted them:\n";
    foreach my $obsolete_study (@obsolete_studies){
      print $obsolete_study."\n";
    }
  }
}


## METHODS ##
sub make_register_THs_with_logging{

  my $registry_obj = shift;
  my $study_ids_href = shift;
  my $server_dir_full_path = shift;
  my $organism_assmblAccession_EG_href = shift;
  my $plant_names_AE_response_href = shift;

  my $return_string;
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

    my $ls_output = `ls $server_dir_full_path`  ;
    my $flag_new_or_update;

    if($ls_output =~/$study_id/){ # i check if the directory of the study exists already
   
      print " (update) "; # if it already exists
      $flag_new_or_update = "update";
      my $method_return= Helper::run_system_command("rm -r $server_dir_full_path/$study_id");
      if (!$method_return){ # returns 1 if successfully deleted or 0 if not, !($method_return is like $method_return=0)
        print STDERR "I cannot rm dir $server_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";
        print STDERR "This study $study_id will be skipped";
        next;
      }
    }else{
      $flag_new_or_update = "new";
      print " (new) ";
    }

    my $track_hub_creator_obj = EGPlantTHs::TrackHubCreation->new($study_id,$server_dir_full_path);
    my $script_output = $track_hub_creator_obj->make_track_hub($plant_names_AE_response_href);

    print $script_output;


    if($script_output !~ /..Done/){  # if for some reason the track hub didn't manage to be made in the server, it shouldn't be registered in the Registry, for example Robert gives me a study id as completed that is not yet in ENA

      print STDERR "Track hub of $study_id could not be made in the server - Folder $study_id will be deleted\n\n" ;
      print "\t..Skipping registration part\n";

      if ($flag_new_or_update eq "update"){ # if the track hub is already registered but in the process of re-creating it smt went wrong with its creation so I removed it from the server, I have to rm it from the THR too
        $registry_obj->delete_track_hub($study_id);
      }

      Helper::run_system_command("rm -r $server_dir_full_path/$study_id")      
        or die "ERROR: failed to remove dir $server_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";

      $line_counter --;

      if ($script_output=~/No ENA Warehouse metadata found/){

        $unsuccessful_studies{"Sample metadata not yet in ENA"} {$study_id}= 1;

      }elsif($script_output=~/Skipping this TH because at least 1 of the cram files of the TH is not yet in ENA/){ 

        $unsuccessful_studies{"At least 1 cram file of study is not yet in ENA"} {$study_id}= 1;

      }else{

        $unsuccessful_studies{"Study not yet in ENA"} {$study_id}= 1;
      }

     }
     else{  # if the study is successfully created in the ftp server, I go ahead and register it

      my $output = register_track_hub_in_TH_registry($registry_obj,$study_obj,$organism_assmblAccession_EG_href );  

      $return_string = $output;

      if($output !~ /is Registered/){# if something went wrong with the registration, i will not make a track hub out of this study
        #Helper::run_system_command("rm -r $server_dir_full_path/$study_id")
         # or die "ERROR: failed to remove dir $server_dir_full_path/$study_id in script: ".__FILE__." line: ".__LINE__."\n";

        $line_counter --;
        $return_string = $return_string . "\t..Something went wrong with the Registration process -- this study will be skipped..\n";
        $unsuccessful_studies{"Registry issue"}{$study_id}= 1;
      }

      print $return_string;
      
    }
 }
  return (\%unsuccessful_studies);

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

  my $all_track_hubs_in_registry_href = $registry_obj->give_all_Registered_track_hub_names();
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