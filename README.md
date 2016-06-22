# plantsTrackHubPipeline
Pipeline that creates Ensembl plant track hubs given ENA study ids and puts them in the Ensembl Track Hub Registry.<br />
The track hubs contain the Array Express' alignments of Ensembl plant genomes to the RNAseq data available in ENA.<br />
Array Express provides the .cram files of the alignments and using their REST API the pipeline communicates with the AE data.<br />
Every track hub represents an ENA study. A track hub can have more than 1 plant species. The tracks of the track hubs are the CRAM alignement files.<br />

Pipeline:

 pipeline_create_register_track_hubs.pl

Parameters:

-server_dir_full_path  (location of where the track hub files to be stored)<br />
-server_url  (server url of the location of the track hubs)<br />
-th_visibility (values accepted: public/hidden -> whether the TH registered in the THR will be public or not)<br />
-do_track_hubs_from_scratch (optional flag) <br />

Example run:

perl pipeline_create_register_track_hubs.pl -server_dir_full_path full_path_for_storing_the_ths -server_url url_of_the_directory_of_the_ths -th_visibility public -do_track_hubs_from_scratch 1> output 2>std_errors


